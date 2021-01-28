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

reaper.Undo_BeginBlock()

insertPunch(position - 2*df, "", df, false)
insertPunch(position, "", df, false)
insertPunch(position + 2*df, "", df, false)

reaper.Undo_EndBlock("Insert Flutter", -1)