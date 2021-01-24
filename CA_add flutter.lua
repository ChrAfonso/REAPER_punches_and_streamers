-- TODO package to simplify loading

-- Setup: Paths, item files, functions
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  pathSep = "\\"
else
  pathSep = "/"
end

local _,ScriptPath = reaper.get_action_context()
ScriptPath = ScriptPath:gsub("[^" .. pathSep .. "]+$", "") -- remove filename

-- local update_streamers = require 'update_streamers'
dofile(ScriptPath .. "CA_streamers_lib.lua")

---------------------------------------------------------

local position = reaper.GetCursorPosition()
local frameRate = reaper.TimeMap_curFrameRate(0)
local df = 1 / frameRate
insertPunch(position - 2*df, "", df)
insertPunch(position, "", df)
insertPunch(position + 2*df, "", df)