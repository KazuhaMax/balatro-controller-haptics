-- Controller Haptics 1.2: classified short event pulses for desktop Balatro.
-- Loaded by main.lua after the original game code, before love.load.
-- Uses ordinary two-motor rumble, not native Switch HD / iOS haptics.

local VERSION = '1.2.0'
local LOG_FILE = 'controller_haptics.log'

-- Strength multipliers. Pulse duration is independent of strength and frame rate.
local LEVELS = {
    {label = 'Off', scale = 0},
    {label = 'Low', scale = 0.5},
    {label = 'Medium', scale = 1},
    {label = 'High', scale = 1.75},
    {label = 'Max', scale = 2.5},
}
local DEFAULT_LEVEL = 3
local function classified_mode()
    return G.SETTINGS.haptics_style ~= 'simple'
end

-- Level names in the game's language, in LEVELS order. Other languages use the
-- English labels above.
local LEVEL_NAMES = {
    zh_CN = {'关', '弱', '中', '强', '最强'},
    zh_TW = {'關', '弱', '中', '強', '最強'},
    ja = {'オフ', '弱', '中', '強', '最大'},
    ko = {'끄기', '약하게', '보통', '강하게', '최대'},
}

local start_time = love.timer.getTime()

local function log(fmt, ...)
    local line = string.format('[%6.1fs] ' .. fmt, love.timer.getTime() - start_time, ...)
    print('[Controller Haptics] ' .. line)
    pcall(love.filesystem.append, LOG_FILE, line .. '\n')
end

local function describe(pad, event)
    local vendor, product = pad:getDeviceInfo()
    log('%s: %s [%04x:%04x], rumble %s', event, pad:getName(), vendor, product,
        pad:isVibrationSupported() and 'supported' or 'NOT supported')
end

-- Index into LEVELS for the current settings. G.SETTINGS.rumble is the game's
-- own on/off switch; rumble_level remembers the strength while it is off.
local function rumble_level()
    if G.SETTINGS.rumble == false or G.SETTINGS.rumble == 0 then return 1 end
    local level = tonumber(G.SETTINGS.rumble_level)
    return (level and level > 1 and LEVELS[level]) and level or DEFAULT_LEVEL
end

-- Bluetooth PlayStation pads only take rumble in SDL's enhanced report mode,
-- which SDL leaves off by default. Setting these hints switches pads that are
-- already open, and pads connected later as they open. USB pads and Xbox pads
-- rumble without it.
local function enable_playstation_bluetooth_rumble()
    local ffi = require('ffi')
    pcall(ffi.cdef, 'int SDL_SetHint(const char *name, const char *value);')
    pcall(ffi.cdef, 'void SDL_GetVersion(uint8_t *version);')
    local sdl = ffi.C
    if not pcall(function() return sdl.SDL_SetHint end) then
        sdl = ffi.load('SDL2') -- Windows keeps SDL2.dll out of the global namespace
    end
    sdl.SDL_SetHint('SDL_JOYSTICK_HIDAPI_PS4_RUMBLE', '1')
    sdl.SDL_SetHint('SDL_JOYSTICK_HIDAPI_PS5_RUMBLE', '1')
    local version = ffi.new('uint8_t[3]')
    sdl.SDL_GetVersion(version)
    return string.format('%d.%d.%d', version[0], version[1], version[2])
end

pcall(love.filesystem.write, LOG_FILE, '')
local love_major, love_minor, love_revision = love.getVersion()
log('Controller Haptics %s, Balatro %s, LOVE %d.%d.%d on %s', VERSION, tostring(G.VERSION),
    love_major, love_minor, love_revision, love.system.getOS())

local sdl_ok, sdl_result = pcall(enable_playstation_bluetooth_rumble)
if sdl_ok then
    log('SDL %s: PlayStation rumble hints applied', sdl_result)
else
    log('could not reach SDL, PlayStation pads may only rumble over USB: %s', tostring(sdl_result))
end

-- globals.lua has created G by now. love.load, which reads settings.jkr and
-- picks the first controller when F_RUMBLE is set, hasn't run yet.
G.F_RUMBLE = LEVELS[DEFAULT_LEVEL].scale
if G.SETTINGS.rumble == nil then G.SETTINGS.rumble = true end

-- With F_RUMBLE set, Settings > Game shows the consoles' on/off toggle. Show a
-- strength picker in its place.
local vanilla_create_toggle = create_toggle
function create_toggle(args)
    if not (args and args.ref_table == G.SETTINGS and args.ref_value == 'rumble') then
        return vanilla_create_toggle(args)
    end
    local names = LEVEL_NAMES[G.SETTINGS.language] or {}
    local options = {}
    for i, level in ipairs(LEVELS) do options[i] = names[i] or level.label end
    local strength = create_option_cycle({label = args.label, scale = 0.65, w = 3, options = options,
        current_option = rumble_level(), opt_callback = 'controller_haptics_set_level'})
    local chinese = G.SETTINGS.language == 'zh_CN' or G.SETTINGS.language == 'zh_TW'
    local style = create_option_cycle({label = chinese and '震动风格' or 'Haptic style',
        scale = 0.65, w = 3, options = chinese and {'事件', '简洁'} or {'Events', 'Simple'},
        current_option = classified_mode() and 1 or 2, opt_callback = 'controller_haptics_set_style'})
    return {n = G.UIT.R, config = {align = 'cm', padding = 0.05}, nodes = {
        {n = G.UIT.C, config = {align = 'cm'}, nodes = {strength}},
        {n = G.UIT.C, config = {align = 'cm'}, nodes = {style}},
    }}
end

local silence
G.FUNCS.controller_haptics_set_level = function(args)
    if not (args and LEVELS[args.to_key]) then return end
    if silence then silence() end
    G.SETTINGS.rumble = args.to_key > 1
    if G.SETTINGS.rumble then G.SETTINGS.rumble_level = args.to_key end
    G:save_settings()
end
G.FUNCS.controller_haptics_set_style = function(args)
    if not args or (args.to_key ~= 1 and args.to_key ~= 2) then return end
    if silence then silence() end
    G.SETTINGS.haptics_style = args.to_key == 1 and 'events' or 'simple'
    G:save_settings()
end

-- The native mixer adds the entire decaying screen shake every frame and uses
-- (1 - 15*dt) as decay. Desktop frame rates change its feel; a slow frame can
-- even produce negative amplitudes. Keep its visual work, but own motor output.
-- Only NEW additions to jiggle count as impacts, including scoring animations.
local pulses, pending = {}, 0
local last_room, last_jiggle
local driven_pad, pad_gain, supported
local last_send, last_left, last_right = -math.huge, 0, 0
local last_update
local focused = not love.window or not love.window.hasFocus or love.window.hasFocus()
local described = setmetatable({}, {__mode = 'k'})
local OUTPUT_INTERVAL = 1 / 60
local WATCHDOG = 0.12 -- finite duration if the game stalls before sending stop

-- Conservative authored presets, NOT measured iOS/Switch waveforms.
-- Each tuple is duration (seconds), left strength, right strength.
local EFFECTS = {
    ui_focus = {0.035, 0.04, 0.24}, ui_confirm = {0.045, 0.10, 0.32},
    card_draw = {0.040, 0.06, 0.25}, hand_played = {0.070, 0.19, 0.34},
    coin = {0.035, 0.04, 0.26}, money_gain = {0.035, 0.03, 0.22},
    cash_out = {0.090, 0.26, 0.38},
    score_chips = {0.038, 0.06, 0.27}, score_mult = {0.045, 0.08, 0.32},
    score_xmult = {0.060, 0.18, 0.42}, score_edition = {0.050, 0.10, 0.34},
    score_generic = {0.038, 0.05, 0.24}, card_debuff = {0.040, 0.10, 0.14},
    card_destroy = {0.075, 0.28, 0.24}, card_shatter = {0.065, 0.20, 0.40},
    blind_reveal = {0.085, 0.24, 0.34},
    startup_open = {0.080, 0.20, 0.30}, startup_close = {0.095, 0.27, 0.38},
}
-- Sound-category mapping adapted from delta9690/balatro-rumble/categories.lua.
-- Copyright (c) 2026 Luna-Terra. MIT License; full notice is included below
-- so that installing just the two Lua files preserves the upstream notice.
--[[
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
local SOUND_EVENTS = {
    card1 = 'card_draw', cardFan2 = 'hand_played', coin1 = 'money_gain',
    coin6 = 'cash_out', coin7 = 'cash_out', chips1 = 'score_chips',
    multhit1 = 'score_mult', multhit2 = 'score_xmult', foil2 = 'score_edition',
    generic1 = 'score_generic', cancel = 'card_debuff',
    explosion_release1 = 'card_destroy', introPad1 = 'startup_open',
    magic_crumple2 = 'startup_close', magic_crumple3 = 'startup_close',
    button = 'ui_confirm',
}
local event_queue, event_seen, event_last = {}, {}, {}
local blind_pending
local function clear_events()
    event_queue, event_seen, event_last = {}, {}, {}
    blind_pending = nil
end
local function enqueue(category)
    if not classified_mode() or not focused or event_seen[category] or not EFFECTS[category] then return end
    event_seen[category] = true
    event_queue[#event_queue + 1] = category
end

local original_sound = play_sound
if type(original_sound) == 'function' then
    function play_sound(name, ...)
        if classified_mode() and type(name) == 'string' then
            local category = SOUND_EVENTS[name]
            if name == 'coin3' then
                -- Individual dollars stay short; the total uses coin6/coin7.
                category = 'coin'
            elseif name:match('^glass[1-6]$') then
                category = 'card_shatter'
            elseif name == 'chips1' and blind_pending then
                if love.timer.getTime() <= blind_pending.expires and blind_pending.object.blind_set then
                    category = 'blind_reveal'
                    blind_pending = nil
                elseif love.timer.getTime() > blind_pending.expires then
                    blind_pending = nil
                end
            end
            enqueue(category)
        end
        -- Observe before vanilla's mute early return; preserve all return values.
        return original_sound(name, ...)
    end
end
if Controller and type(Controller.update_focus) == 'function' then
    local original_focus_update = Controller.update_focus
    function Controller:update_focus(...)
        local before = self.focused and self.focused.target
        local vibration = G.VIBRATION or 0
        local result = original_focus_update(self, ...)
        if self.focused and self.focused.target and self.focused.target ~= before
            and (G.VIBRATION or 0) > vibration then enqueue('ui_focus') end
        return result
    end
end
if Controller and type(Controller.capture_focused_input) == 'function' then
    local original_capture = Controller.capture_focused_input
    function Controller:capture_focused_input(button, input_type, ...)
        local result = original_capture(self, button, input_type, ...)
        if result == true and input_type == 'press' then enqueue('ui_confirm') end
        return result
    end
end
if Blind and type(Blind.set_blind) == 'function' then
    local original_set_blind = Blind.set_blind
    function Blind:set_blind(blind, reset, silent, ...)
        blind_pending = nil
        if classified_mode() and blind and not reset and not silent then
            blind_pending = {object = self, expires = love.timer.getTime() + 5}
        end
        return original_set_blind(self, blind, reset, silent, ...)
    end
end

local function positive(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge then return 0 end
    return math.max(0, value)
end

local function sample_events()
    local room = G.ROOM
    local jiggle = positive(room and room.jiggle)
    local added = room == last_room and math.max(0, jiggle - (last_jiggle or jiggle)) or 0
    pending = math.max(pending, math.min(2.5, positive(G.VIBRATION)), math.min(2.5, added))
    last_room, last_jiggle = room, jiggle
end

local function stop_pad(pad)
    if pad and pad.setVibration then pcall(pad.setVibration, pad, 0, 0, 0) end
end

silence = function()
    stop_pad(driven_pad)
    pulses, pending = {}, 0
    clear_events()
    last_left, last_right, last_send = 0, 0, -math.huge
    G.VIBRATION, G.CURR_VIBRATION = 0, 0
    last_room, last_jiggle = G.ROOM, positive(G.ROOM and G.ROOM.jiggle)
end

local function connected(pad)
    if not (pad and pad.isConnected and pad.setVibration) then return false end
    local ok, result = pcall(pad.isConnected, pad)
    return ok and result
end

local function select_pad(pad)
    -- Stop the old device BEFORE sending anything to the newly selected one.
    stop_pad(driven_pad)
    pulses = {}
    last_left, last_right, last_send = 0, 0, -math.huge
    driven_pad, pad_gain, supported = pad, 1, false
    event_last = {}
    if not connected(pad) then return end
    if pad.isVibrationSupported then
        local ok, result = pcall(pad.isVibrationSupported, pad)
        supported = ok and result
    end
    local ok, name = pcall(pad.getName, pad)
    name = ok and tostring(name):lower() or ''
    local vendor, product
    if pad.getDeviceInfo then
        local info_ok, vendor_id, product_id = pcall(pad.getDeviceInfo, pad)
        if info_ok then vendor, product = vendor_id, product_id end
    end
    -- DualSense's emulated rumble needs more gain than the preview's 0.7.
    -- Keep other Sony pads and Xbox/general controllers at their existing gain.
    -- Steam Input may hide the physical identity behind a virtual Xbox pad.
    if name:find('dualsense', 1, true) or name:find('ps5', 1, true)
        or (vendor == 0x054c and product == 0x0ce6) then
        pad_gain = 1.4
    elseif vendor == 0x054c then
        pad_gain = 0.7
    end
    if not described[pad] then
        described[pad] = true
        pcall(describe, pad, 'using')
    end
end

local vanilla_update_canvas_juice = update_canvas_juice
function update_canvas_juice(dt)
    sample_events()
    local flag = G.F_RUMBLE
    -- 0 is truthy in Lua: nil is necessary to suppress the native motor call.
    G.F_RUMBLE = nil
    local ok, err = pcall(vanilla_update_canvas_juice, dt)
    G.F_RUMBLE = flag
    if not ok then
        silence()
        error(err, 0)
    end
    G.CURR_VIBRATION = 0
    last_room, last_jiggle = G.ROOM, positive(G.ROOM and G.ROOM.jiggle)
end

local function update_haptics()
    -- Run AFTER game/controller/event updates. Menu actions and card effects
    -- therefore reach the motors in this frame, rather than the following one.
    sample_events()
    G.VIBRATION = 0
    local now = love.timer.getTime()
    local stalled = last_update and now - last_update > 0.25
    last_update = now
    local pad = G.CONTROLLER and G.CONTROLLER.GAMEPAD and G.CONTROLLER.GAMEPAD.object
    if not connected(pad) then pad = nil end
    if pad ~= driven_pad then select_pad(pad) end
    local scale = LEVELS[rumble_level()].scale
    G.F_RUMBLE = scale
    if not pad or not focused or not supported or scale == 0 or stalled then
        if last_left ~= 0 or last_right ~= 0 then stop_pad(driven_pad) end
        pulses, pending = {}, 0
        clear_events()
        last_left, last_right = 0, 0
        return
    end

    local classified = classified_mode() and #event_queue > 0
    local fresh = false
    if classified then
        for _, category in ipairs(event_queue) do
            -- Confirmation wins over incidental focus movement in the same frame.
            if not (category == 'ui_focus' and event_seen.ui_confirm) then
                local effect = EFFECTS[category]
                -- Coalesce same-category bursts without extending a held envelope.
                if now - (event_last[category] or -math.huge) >= 0.025 then
                    event_last[category] = now
                    pulses[#pulses + 1] = {time = now, duration = effect[1],
                        left = effect[2], right = effect[3]}
                    fresh = true
                end
            end
        end
    elseif pending > 0.01 then
        fresh = true
        -- 40-100 ms pulses, with less low-frequency body than high-frequency
        -- detail. Overlapping pulses use max, never accumulate into a buzz.
        pulses[#pulses + 1] = {
            time = now, duration = 0.035 + 0.025 * pending,
            left = 0.08 + 0.10 * pending, right = 0.22 + 0.16 * pending,
        }
    end
    -- Classified events replace the aggregate signal for this frame, preventing
    -- a single action from producing both its named effect and a generic hit.
    event_queue, event_seen = {}, {}
    while #pulses > 16 do table.remove(pulses, 1) end
    pending = 0
    local left, right = 0, 0
    for i = #pulses, 1, -1 do
        local pulse = pulses[i]
        local age = math.max(0, now - pulse.time)
        if age >= pulse.duration then
            table.remove(pulses, i)
        else
            -- Brief attack plateau, followed by a bounded linear release.
            local envelope = math.min(1, (pulse.duration - age) / (pulse.duration - 0.012))
            left = math.max(left, pulse.left * envelope)
            right = math.max(right, pulse.right * envelope)
        end
    end
    left = math.min(1, left * scale * pad_gain)
    right = math.min(1, right * scale * pad_gain)
    if left < 0.005 then left = 0 end
    if right < 0.005 then right = 0 end
    local stopping = left == 0 and right == 0
    if stopping and last_left == 0 and last_right == 0 then return end
    -- A new impact or stop is immediate; only envelope refreshes are throttled.
    if not fresh and not stopping and now - last_send < OUTPUT_INTERVAL then return end
    local ok, result = pcall(pad.setVibration, pad, left, right, stopping and 0 or WATCHDOG)
    if not ok or result == false then
        stop_pad(pad)
        supported = false -- retry only on controller selection/reconnection
        pulses = {}
        last_left, last_right = 0, 0
        pcall(log, 'rumble unavailable; muted until controller reconnects: %s', tostring(result))
        return
    end
    last_send, last_left, last_right = now, left, right
end

local vanilla_update = love.update
function love.update(dt)
    vanilla_update(dt)
    update_haptics()
end

local vanilla_focus, vanilla_quit = love.focus, love.quit
function love.focus(has_focus)
    focused = has_focus
    silence()
    if vanilla_focus then return vanilla_focus(has_focus) end
end

function love.quit(...)
    silence()
    if vanilla_quit then return vanilla_quit(...) end
end

local vanilla_joystickadded, vanilla_joystickremoved = love.joystickadded, love.joystickremoved
function love.joystickadded(joystick)
    if joystick == driven_pad then silence(); driven_pad = nil end
    pcall(describe, joystick, 'connected')
    if vanilla_joystickadded then return vanilla_joystickadded(joystick) end
end

function love.joystickremoved(joystick)
    if joystick == driven_pad then silence(); driven_pad = nil end
    described[joystick] = nil
    pcall(log, 'disconnected: %s', tostring(joystick:getName()))
    if vanilla_joystickremoved then return vanilla_joystickremoved(joystick) end
end

