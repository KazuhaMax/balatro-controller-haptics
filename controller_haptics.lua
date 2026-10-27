-- Controller Haptics 1.1: short event pulses for desktop Balatro.
-- Loaded by main.lua after the original game code, before love.load.
-- Uses ordinary two-motor rumble, not native Switch HD / iOS haptics.

local VERSION = '1.1.0'
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
    return create_option_cycle({label = args.label, scale = 0.8, w = 3, options = options,
        current_option = rumble_level(), opt_callback = 'controller_haptics_set_level'})
end

local silence
G.FUNCS.controller_haptics_set_level = function(args)
    if not (args and LEVELS[args.to_key]) then return end
    if silence then silence() end
    G.SETTINGS.rumble = args.to_key > 1
    if G.SETTINGS.rumble then G.SETTINGS.rumble_level = args.to_key end
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
    if not connected(pad) then return end
    if pad.isVibrationSupported then
        local ok, result = pcall(pad.isVibrationSupported, pad)
        supported = ok and result
    end
    local ok, name = pcall(pad.getName, pad)
    name = ok and tostring(name):lower() or ''
    local vendor
    if pad.getDeviceInfo then
        local info_ok, value = pcall(pad.getDeviceInfo, pad)
        if info_ok then vendor = value end
    end
    -- A conservative Sony preset; Steam Input may instead expose an Xbox pad.
    if vendor == 0x054c or name:find('dualsense', 1, true) or name:find('ps5', 1, true) then
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
    if not focused or not supported or scale == 0 or stalled then
        if last_left ~= 0 or last_right ~= 0 then stop_pad(driven_pad) end
        pulses, pending = {}, 0
        last_left, last_right = 0, 0
        return
    end

    local fresh = pending > 0.01
    if fresh then
        -- 40-100 ms pulses, with less low-frequency body than high-frequency
        -- detail. Overlapping pulses use max, never accumulate into a buzz.
        pulses[#pulses + 1] = {
            time = now, duration = 0.035 + 0.025 * pending,
            left = 0.08 + 0.10 * pending, right = 0.22 + 0.16 * pending,
        }
        if #pulses > 16 then table.remove(pulses, 1) end
    end
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

