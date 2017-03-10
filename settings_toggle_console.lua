-- open io scripts
local _, fullScriptPath = reaper.get_action_context()
fullScriptPath = fullScriptPath:gsub("[^/\\]*$", "")

local io_file = io.open(fullScriptPath .. "file_io.lua", "r")
if io_file then
  local file_io = assert(load(io_file:read("*all")))
  io_file:close()
  if file_io then
    file_io()
  else
    reaper.ShowConsoleMsg("Error: Could not read file_io for Streamers and Punches! Aborting.")
    return
  end
else
  reaper.ShowConsoleMsg("Error: Could not open file_io for Streamers and Punches! Aborting.")
  return
end

-- toggle
local show = readSetting("show_console")
if type(show) == string then
	show = (show == "true")
end

show = not show

writeSetting("show_console", show)
