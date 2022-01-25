function Main()
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

  local f = io.open(file, 'r')
  if not f then
    reaper.ShowConsoleMsg("ERROR: Could not open file for reading! Please make sure it exists.")
    return
  else
    f:close()
  end
  
  -- defaults. TODO Read from CSV?
  local positionIndex = 1
  local durationIndex = 2
  local typeIndex = 3
  local colorIndex = 4
  
  local readHeaders = false
  
  for line in io.lines(file) do
    if not readHeaders then
      -- TODO read header indices to replace defaults
      readHeaders = true
    else
      local elements = split_string(line, ",")
      
      local position = elements[positionIndex]
      local duration = elements[durationIndex]
      local type = elements[typeIndex]
      local color = elements[colorIndex]
      
      if type == "P" then
        insertPunch(parse_timecode(position, true))
      elseif type == "F" then
        insertFlutter(parse_timecode(position, true))
      elseif type == "S" then
        pos = parse_timecode(position, true)
        dur = parse_timecode(duration, false)
        insertStreamer(pos + dur, dur, color, false) -- streamers end at specified position. punches are read extra.
      end
    end
  end
end

retval, file = reaper.GetUserFileNameForRead('', "Import punches and streamers from CSV file", "*.csv")
if retval then
  reaper.defer(Main)
end
