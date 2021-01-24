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

-- params
local position = reaper.GetCursorPosition()
local color = "green"
local addPunch = true

local length = nil -- default: 2 seconds
local retval, length_csv = reaper.GetUserInputs("Enter Duration", 2, "Duration (seconds),Duration (beats)", ",")
if retval then
	local tokens = {}
	for token in length_csv:gmatch("([^,]*),?") do
		table.insert(tokens, token)
	end
	
	if tokens[1] ~= "" then
		length = tokens[1] -- seconds
	elseif tokens[2] ~= "" then
		local bpm = reaper.TimeMap_GetDividedBpmAtTime(position)
		length = tokens[2] * (60 / bpm)
	end
end

---------------------------------------------------------

if length then
	insertStreamer(position, length, color, addPunch)
end