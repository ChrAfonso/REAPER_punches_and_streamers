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
local addPunch = true

local color = nil
local length = nil
local retval, csv = reaper.GetUserInputs("Add custom streamer", 2, "Color,Duration (seconds),Duration (beats)")
if retval then
	local tokens = {}
	for token in csv:gmatch("([^,]*),?") do
		table.insert(tokens, token)
	end
	
	if tokens[2] ~= "" then
		length = tokens[2] -- seconds
	elseif tokens[3] ~= "" then
		local bpm = reaper.TimeMap_GetDividedBpmAtTime(position)
		length = tokens[3] * (60 / bpm)
	end
	
	if tokens[1] ~= "" then
		color = tokens[1]
	end
end

---------------------------------------------------------

if color and length then
	insertStreamer(position, length, color, addPunch)
end