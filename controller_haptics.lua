-- Controller Haptics 1.3: configurable short event pulses for desktop Balatro.
-- Loaded by main.lua after the original game code, before love.load.
-- Uses ordinary two-motor rumble, not native Switch HD / iOS haptics.

local VERSION = '1.3.0'
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
local get_config

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
        {n = G.UIT.C, config = {align = 'cm', padding = 0.1}, nodes = {
            UIBox_button({label = {chinese and '详细设置' or 'Customize'},
                button = 'controller_haptics_menu', minw = 1.6, minh = 0.65, scale = 0.3}),
        }},
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

-- Settings contain only numbers, booleans, strings and plain tables so the
-- game's existing settings serializer can persist them without a new loader.
local MIXES = {'original', 'light', 'balanced', 'heavy', 'dual'}
local DEVICES = {'auto', 'generic', 'dualsense', 'sony'}
local function valid_choice(value, choices, fallback)
    for _, choice in ipairs(choices) do if value == choice then return value end end
    return fallback
end
local function bounded(value, default, low, high)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return default end
    return math.max(low, math.min(high, value))
end
local function clean_event(raw)
    raw = type(raw) == 'table' and raw or {}
    return {enabled = raw.enabled ~= false, gain = bounded(raw.gain, 1, 0.25, 2),
        duration = bounded(raw.duration, 1, 0.5, 1.5),
        mix = valid_choice(raw.mix, MIXES, 'original')}
end
local function clean_profile(raw)
    raw = type(raw) == 'table' and raw or {}
    local result = {device = valid_choice(raw.device, DEVICES, 'auto'),
        gain = bounded(raw.gain, 1, 0.5, 1.5),
        left = bounded(raw.left, 1, 0.5, 1.5), right = bounded(raw.right, 1, 0.5, 1.5),
        flame = raw.flame == true, flame_strength = bounded(raw.flame_strength, 0.5, 0.25, 1),
        events = {}}
    for category in pairs(EFFECTS) do
        result.events[category] = clean_event(type(raw.events) == 'table' and raw.events[category])
    end
    return result
end
local config_cache
get_config = function()
    local raw = G.SETTINGS.haptics_config
    if type(raw) ~= 'table' or raw ~= config_cache then
        local clean = clean_profile(raw)
        clean.version, clean.slots = 1, {}
        if type(raw) == 'table' and type(raw.slots) == 'table' then
            for i = 1, 3 do
                if type(raw.slots[i]) == 'table' then clean.slots[i] = clean_profile(raw.slots[i]) end
            end
        end
        G.SETTINGS.haptics_config, config_cache = clean, clean
    end
    return config_cache
end

-- Score heat adds body only to scoring pulses, not a continuously running motor.
-- Use the same score/target boundary as the visual flames. Log arithmetic avoids
-- overflow on large vanilla scores; unsupported big-number objects safely skip it.
local function score_heat()
    if not G.STATES or G.STATE ~= G.STATES.HAND_PLAYED or not G.STAGES
        or G.STAGE ~= G.STAGES.RUN or G.SETTINGS.paused or G.OVERLAY_MENU then return 0 end
    local game = G.GAME
    local hand = game and game.current_round and game.current_round.current_hand
    local target = game and game.blind and game.blind.chips
    local chips, mult = hand and hand.chips, hand and hand.mult
    for _, value in ipairs({chips or false, mult or false, target or false}) do
        if type(value) ~= 'number' or value ~= value or value <= 0 or value == math.huge then return 0 end
    end
    local ratio_log = math.log(chips) + math.log(mult) - math.log(target)
    if ratio_log < -1e-9 then return 0 end
    return 0.25 + 0.75 * math.min(1, math.max(0, ratio_log)/math.log(16))
end
local function event_pulse(category, now, cfg, preview)
    local base, opt = EFFECTS[category], cfg.events[category]
    if not base or not opt or not opt.enabled then return end
    local left, right = base[2], base[3]
    local peak = math.max(left, right)
    if opt.mix == 'light' then left, right = peak*0.25, peak
    elseif opt.mix == 'balanced' then left, right = peak*0.7, peak*0.7
    elseif opt.mix == 'heavy' then left, right = peak, peak*0.25
    elseif opt.mix == 'dual' then left, right = peak, peak end
    local heat = not preview and cfg.flame and category:match('^score_') and score_heat() or 0
    local gain = opt.gain * (1 + heat*cfg.flame_strength)
    return {time = now, duration = math.max(0.020, math.min(0.180, base[1]*opt.duration)),
        left = left*gain, right = right*gain}
end
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
local preview_request
local function clear_events()
    event_queue, event_seen, event_last = {}, {}, {}
    blind_pending = nil
    preview_request = nil
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
    local cfg = get_config()
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
    if preview_request then
        local preview = preview_request
        preview_request = nil
        local pulse
        if preview == '_left' or preview == '_right' then
            pulse = {time = now, duration = 0.070,
                left = preview == '_left' and 0.35 or 0,
                right = preview == '_right' and 0.35 or 0}
        else
            pulse = event_pulse(preview, now, cfg, true)
        end
        if pulse then pulses[#pulses + 1] = pulse; fresh = true end
    elseif classified then
        for _, category in ipairs(event_queue) do
            -- Confirmation wins over incidental focus movement in the same frame.
            if not (category == 'ui_focus' and event_seen.ui_confirm) then
                -- Coalesce same-category bursts without extending a held envelope.
                if now - (event_last[category] or -math.huge) >= 0.025 then
                    event_last[category] = now
                    local pulse = event_pulse(category, now, cfg)
                    if pulse then pulses[#pulses + 1] = pulse; fresh = true end
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
    local device_gain = cfg.device == 'auto' and pad_gain
        or cfg.device == 'dualsense' and 1.4 or cfg.device == 'sony' and 0.7 or 1
    left = math.min(1, left * scale * device_gain * cfg.gain * cfg.left)
    right = math.min(1, right * scale * device_gain * cfg.gain * cfg.right)
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

-- Compact native game menus. No Steamodded, Lovely or web UI dependency.
local function tr(zh, en)
    local language = G.SETTINGS.language
    return (language == 'zh_CN' or language == 'zh_TW') and zh or en
end
local EVENT_NAMES = {
    ui_focus = {'菜单移动', 'Menu focus'}, ui_confirm = {'菜单确认', 'Menu confirm'},
    card_draw = {'抽牌', 'Card draw'}, hand_played = {'出牌', 'Hand played'},
    card_debuff = {'卡牌减益', 'Card debuff'}, card_destroy = {'卡牌销毁', 'Card destruction'},
    card_shatter = {'玻璃碎裂', 'Glass shatter'},
    score_chips = {'筹码计分', 'Score chips'}, score_mult = {'倍率计分', 'Score mult'},
    score_xmult = {'乘倍率', 'Score XMult'}, score_edition = {'版本计分', 'Score edition'},
    score_generic = {'其他计分', 'Other scoring'},
    coin = {'逐枚金币', 'Individual coin'}, money_gain = {'获得金钱', 'Money gain'},
    cash_out = {'结算总额', 'Cash-out total'}, blind_reveal = {'盲注揭示', 'Blind reveal'},
    startup_open = {'标题开场', 'Title opening'}, startup_close = {'标题收尾', 'Title closing'},
}
local GROUPS = {
    {name = {'菜单', 'Menus'}, events = {'ui_focus', 'ui_confirm'}},
    {name = {'卡牌', 'Cards'}, events = {'card_draw', 'hand_played', 'card_debuff', 'card_destroy', 'card_shatter'}},
    {name = {'计分', 'Scoring'}, events = {'score_chips', 'score_mult', 'score_xmult', 'score_edition', 'score_generic'}},
    {name = {'金币与盲注', 'Money and blinds'}, events = {'coin', 'money_gain', 'cash_out', 'blind_reveal'}},
    {name = {'标题', 'Title'}, events = {'startup_open', 'startup_close'}},
}
local ui = {group = 1, event = 'ui_focus', preset = 1, slot = 1, status = ''}
local open_page
local function text_row(value, size)
    return {n = G.UIT.R, config = {align = 'cm', padding = 0.04}, nodes = {
        {n = G.UIT.T, config = {text = value, scale = size or 0.3, colour = G.C.UI.TEXT_LIGHT}},
    }}
end
local function button(zh, en, callback, small)
    return UIBox_button({label = {tr(zh, en)}, button = callback,
        minw = small and 2.7 or 5.8, minh = 0.6, scale = 0.34})
end
local function pair(a, b)
    return {n = G.UIT.R, config = {align = 'cm', padding = 0.08}, nodes = {
        {n = G.UIT.C, config = {align = 'cm'}, nodes = {a}},
        {n = G.UIT.C, config = {align = 'cm'}, nodes = {b}},
    }}
end
local function selected(value, values)
    for i, entry in ipairs(values) do if value == entry then return i end end
    return 1
end
local function cycle(zh, en, labels, values, value, callback)
    return create_option_cycle({label = tr(zh, en), options = labels,
        current_option = selected(value, values), opt_callback = callback,
        scale = 0.6, w = 5.6, h = 0.55, no_pips = true})
end
local GAINS = {0.5, 0.75, 1, 1.25, 1.5}
local GAIN_LABELS = {'50%', '75%', '100%', '125%', '150%'}
local EVENT_GAINS = {0.25, 0.5, 0.75, 1, 1.25, 1.5, 2}
local EVENT_GAIN_LABELS = {'25%', '50%', '75%', '100%', '125%', '150%', '200%'}
local function save_change()
    silence()
    G:save_settings()
end
local function set_option(values, apply)
    return function(args)
        local value = args and values[args.to_key]
        if value == nil then return end
        apply(get_config(), value)
        save_change()
    end
end
G.FUNCS.controller_haptics_event_on = set_option({true, false}, function(cfg, value) cfg.events[ui.event].enabled = value end)
G.FUNCS.controller_haptics_event_gain = set_option(EVENT_GAINS, function(cfg, value) cfg.events[ui.event].gain = value end)
G.FUNCS.controller_haptics_event_duration = set_option(GAINS, function(cfg, value) cfg.events[ui.event].duration = value end)
G.FUNCS.controller_haptics_event_mix = set_option(MIXES, function(cfg, value) cfg.events[ui.event].mix = value end)
G.FUNCS.controller_haptics_device_select = set_option(DEVICES, function(cfg, value) cfg.device = value end)
G.FUNCS.controller_haptics_gain = set_option(GAINS, function(cfg, value) cfg.gain = value end)
G.FUNCS.controller_haptics_left = set_option(GAINS, function(cfg, value) cfg.left = value end)
G.FUNCS.controller_haptics_right = set_option(GAINS, function(cfg, value) cfg.right = value end)
G.FUNCS.controller_haptics_flame = set_option({false, true}, function(cfg, value) cfg.flame = value end)
G.FUNCS.controller_haptics_flame_strength = set_option({0.25, 0.5, 1}, function(cfg, value) cfg.flame_strength = value end)

local function preview(category)
    silence()
    preview_request = category
end
G.FUNCS.controller_haptics_preview = function() preview(ui.event) end
G.FUNCS.controller_haptics_test_left = function() preview('_left') end
G.FUNCS.controller_haptics_test_right = function() preview('_right') end
G.FUNCS.controller_haptics_event_reset = function()
    get_config().events[ui.event] = clean_event()
    save_change()
    open_page('event', true)
end
G.FUNCS.controller_haptics_preset_select = function(args)
    if args and ({1, 2, 3})[args.to_key] then ui.preset = args.to_key end
end
G.FUNCS.controller_haptics_slot_select = function(args)
    if args and ({1, 2, 3})[args.to_key] then ui.slot = args.to_key end
end
local function replace_profile(profile)
    local slots = get_config().slots
    local clean = clean_profile(profile)
    clean.version, clean.slots = 1, slots
    G.SETTINGS.haptics_config, config_cache = clean, clean
    save_change()
end
G.FUNCS.controller_haptics_preset_apply = function()
    local profile = clean_profile()
    if ui.preset == 2 then
        for _, event in pairs(profile.events) do event.mix, event.duration = 'balanced', 1.25 end
    elseif ui.preset == 3 then
        profile.gain = 0.75
        for _, event in pairs(profile.events) do event.duration = 0.75 end
    end
    replace_profile(profile)
    ui.status = tr('预设已应用', 'Preset applied')
    open_page('profiles', true)
end
G.FUNCS.controller_haptics_slot_save = function()
    local cfg = get_config()
    cfg.slots[ui.slot] = clean_profile(cfg)
    save_change()
    ui.status = tr('已保存到槽位 ', 'Saved to slot ') .. ui.slot
    open_page('profiles', true)
end
G.FUNCS.controller_haptics_slot_load = function()
    local profile = get_config().slots[ui.slot]
    if profile then
        replace_profile(profile)
        ui.status = tr('已载入槽位 ', 'Loaded slot ') .. ui.slot
    else ui.status = tr('所选槽位为空', 'Selected slot is empty') end
    open_page('profiles', true)
end

for index in ipairs(GROUPS) do
    local group_index = index
    G.FUNCS['controller_haptics_group_' .. index] = function()
        ui.group = group_index
        open_page('group')
    end
end
for category in pairs(EVENT_NAMES) do
    local event = category
    G.FUNCS['controller_haptics_event_' .. event] = function()
        ui.event = event
        open_page('event')
    end
end
for _, page in ipairs({'menu', 'profiles', 'events', 'group', 'device', 'flames'}) do
    local target = page
    G.FUNCS['controller_haptics_' .. target] = function() open_page(target) end
end
G.FUNCS.controller_haptics_back = function()
    silence()
    G.FUNCS.settings(nil, true)
end

open_page = function(page, refresh)
    silence()
    local cfg, rows = get_config(), {}
    local back, title = 'controller_haptics_menu', tr('震动设置', 'Controller haptics')
    if page == 'menu' then
        back = 'controller_haptics_back'
        rows = {
            button('预设与保存槽位', 'Presets and saved profiles', 'controller_haptics_profiles'),
            button('按事件调整', 'Customize events', 'controller_haptics_events'),
            button('手柄与左右强度', 'Controller tuning', 'controller_haptics_device'),
            button('计分火焰反馈', 'Score flame feedback', 'controller_haptics_flames'),
            text_row(tr('事件设置仅用于“事件”风格', 'Event settings apply to the Events style')),
            text_row(tr('设置自动保存；总强度在游戏设置中调整', 'Changes save automatically; master strength is in Game settings')),
        }
    elseif page == 'profiles' then
        title = tr('预设与保存槽位', 'Presets and profiles')
        rows = {
            cycle('内置预设', 'Built-in preset', {tr('清晰（1.2 默认）', 'Crisp (1.2 default)'), tr('均衡', 'Balanced'), tr('柔和', 'Soft')}, {1, 2, 3}, ui.preset, 'controller_haptics_preset_select'),
            button('应用所选预设', 'Apply selected preset', 'controller_haptics_preset_apply'),
            cycle('保存槽位', 'Profile slot', {tr('槽位 1', 'Slot 1'), tr('槽位 2', 'Slot 2'), tr('槽位 3', 'Slot 3')}, {1, 2, 3}, ui.slot, 'controller_haptics_slot_select'),
            pair(button('保存当前设置', 'Save current', 'controller_haptics_slot_save', true),
                button('载入所选槽位', 'Load selected', 'controller_haptics_slot_load', true)),
            text_row(tr('保存会替换所选槽位；包含事件、手柄和火焰设置', 'Saving replaces the slot: events, controller and flame settings')),
            text_row(tr('总强度与事件／简洁风格保持不变', 'Master strength and Events/Simple style are kept')),
            text_row(ui.status),
        }
    elseif page == 'events' then
        title = tr('事件分类', 'Event categories')
        for i, group in ipairs(GROUPS) do rows[#rows + 1] = button(group.name[1], group.name[2], 'controller_haptics_group_' .. i) end
    elseif page == 'group' then
        back = 'controller_haptics_events'
        local group = GROUPS[ui.group]
        title = tr(group.name[1], group.name[2])
        for _, category in ipairs(group.events) do
            local name = EVENT_NAMES[category]
            rows[#rows + 1] = button(name[1], name[2], 'controller_haptics_event_' .. category)
        end
    elseif page == 'event' then
        back = 'controller_haptics_group'
        local name, opt = EVENT_NAMES[ui.event], cfg.events[ui.event]
        title = tr(name[1], name[2])
        rows = {
            cycle('事件反馈', 'Event feedback', {tr('开', 'On'), tr('关', 'Off')}, {true, false}, opt.enabled, 'controller_haptics_event_on'),
            cycle('事件强度', 'Event strength', EVENT_GAIN_LABELS, EVENT_GAINS, opt.gain, 'controller_haptics_event_gain'),
            cycle('脉冲时长', 'Pulse duration', GAIN_LABELS, GAINS, opt.duration, 'controller_haptics_event_duration'),
            cycle('左右混合', 'Channel mix', {tr('原始比例', 'Original'), tr('偏右（轻）', 'Right / light'), tr('双侧均衡', 'Balanced'), tr('偏左（重）', 'Left / heavy'), tr('双侧全量', 'Dual full')}, MIXES, opt.mix, 'controller_haptics_event_mix'),
            pair(button('预览震动', 'Preview pulse', 'controller_haptics_preview', true),
                button('重置此事件', 'Reset event', 'controller_haptics_event_reset', true)),
            text_row(tr('用手柄操作预览；关闭总震动时不会输出', 'Use the controller to preview; master Off stays silent')),
        }
    elseif page == 'device' then
        title = tr('手柄调校', 'Controller tuning')
        rows = {
            cycle('设备预设', 'Device preset', {tr('自动', 'Auto'), 'Xbox / Generic', 'DualSense', 'Other Sony'}, DEVICES, cfg.device, 'controller_haptics_device_select'),
            cycle('额外增益', 'Additional gain', GAIN_LABELS, GAINS, cfg.gain, 'controller_haptics_gain'),
            cycle('左侧强度', 'Left strength', GAIN_LABELS, GAINS, cfg.left, 'controller_haptics_left'),
            cycle('右侧强度', 'Right strength', GAIN_LABELS, GAINS, cfg.right, 'controller_haptics_right'),
            pair(button('测试左侧', 'Test left', 'controller_haptics_test_left', true),
                button('测试右侧', 'Test right', 'controller_haptics_test_right', true)),
            text_row(tr('Steam Input 隐藏型号时可手动选择设备', 'Select the device manually if Steam Input hides its identity')),
        }
    elseif page == 'flames' then
        title = tr('计分火焰反馈', 'Score flame feedback')
        rows = {
            cycle('火焰增强', 'Flame boost', {tr('关', 'Off'), tr('开', 'On')}, {false, true}, cfg.flame, 'controller_haptics_flame'),
            cycle('最大增强幅度', 'Maximum boost', {'+25%', '+50%', '+100%'}, {0.25, 0.5, 1}, cfg.flame_strength, 'controller_haptics_flame_strength'),
            text_row(tr('计分达到盲注后，随分数比例增强计分脉冲', 'Scoring pulses grow stronger once the hand reaches the blind')),
            text_row(tr('达到目标的 16 倍时触及增强上限', 'Boost reaches its cap at 16 times the blind target')),
            text_row(tr('不延长脉冲，不在菜单或等待时持续震动', 'No longer pulses or continuous rumble during menus or idle')),
            text_row(tr('仅在“事件”风格中生效，默认关闭', 'Events style only; disabled by default')),
        }
    end
    table.insert(rows, 1, text_row(title, 0.45))
    local previous_stack = G.NO_MOD_CURSOR_STACK
    if refresh then G.NO_MOD_CURSOR_STACK = true end
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({definition = create_UIBox_generic_options({back_func = back,
        contents = {{n = G.UIT.C, config = {align = 'cm', padding = 0.08}, nodes = rows}}})})
    G.NO_MOD_CURSOR_STACK = previous_stack
end

