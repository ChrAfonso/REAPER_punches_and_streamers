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

-- global memory
function writeLastLength(length)
	reaper.SetExtState(GMEM_NAME, "lastLength", length, true)
end
function getLastLength()
	return reaper.GetExtState(GMEM_NAME, "lastLength")
end

function writeLastColor(color)
	reaper.SetExtState(GMEM_NAME, "lastColor", color, true)
end
function getLastColor()
	return reaper.GetExtState(GMEM_NAME, "lastColor")
end

---------------------------------------------------------

-- params
local position = reaper.GetCursorPosition()
local addPunch = true

local color = nil
local length = nil
local retval, csv = reaper.GetUserInputs("Add custom streamer", 3, "Color,Duration (seconds),Duration (beats)", getLastColor() .. "," .. getLastLength() .. ",")
if retval then
	local tokens = {}
	for token in csv:gmatch("([^,]*),?") do
		table.insert(tokens, token)
	end
	
	if tokens[2] ~= "" then
		length = tonumber(tokens[2]) -- seconds
	elseif tokens[3] ~= "" then
		local bpm = reaper.TimeMap_GetDividedBpmAtTime(position)
		length = tonumber(tokens[3] * (60 / bpm))
	end
	
	if tokens[1] ~= "" then
		color = tokens[1]
	end
end

---------------------------------------------------------

if color and length then
	insertStreamer(position, length, color, addPunch)
	
	writeLastLength(length)
	writeLastColor(color)
end
