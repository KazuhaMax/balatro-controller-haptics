-- Controller Haptics loader.
--
-- LÖVE looks in Balatro's save folder before the game's own files, so the game
-- runs this file in place of its own main.lua. It runs the real main.lua, then
-- the mod. To uninstall, delete this file and controller_haptics.lua.

local identity = love.filesystem.getIdentity()

-- Search the game's files first just long enough to load its main.lua.
love.filesystem.setIdentity(identity, true)
local game_main_dir = love.filesystem.getRealDirectory('main.lua')
local game_main = game_main_dir ~= love.filesystem.getSaveDirectory() and assert(love.filesystem.load('main.lua'))
love.filesystem.setIdentity(identity, false)

if not game_main then
    error('Controller Haptics could not find Balatro\'s own main.lua. Delete main.lua from '
        .. love.filesystem.getSaveDirectory() .. ' to play without the mod.')
end

game_main()

local ok, err = pcall(require, 'controller_haptics')
if not ok then print('Controller Haptics failed to load: ' .. tostring(err)) end
