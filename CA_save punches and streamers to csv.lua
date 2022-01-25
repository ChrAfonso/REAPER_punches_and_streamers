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

function Main()
  local f = io.open(file, 'w')
  if(not f) then
    reaper.ShowConsoleMsg("ERROR: Could not open file for writing! Please make sure it is not open in another application.")
    return
  end  
  
  f:write("Timecode,Duration,Type,Color\n")
  
  local streamersList = create_table_from_streamer_items()
  
  for i = 1,#listEntries do
    local entry = listEntries[i]
    
    f:write(format_timecode(entry.position) .. ",")
    
    if entry.type == "S" then
      f:write(format_seconds_frames(entry.length) .. ",")
    else
      f:write(",")
    end
    
    f:write(entry.type .. ",")
    
    if entry.type == "S" then
      f:write(getColorName(entry.color))
    end
    
    f:write("\n")
  end
  
  f:close()
end

-- dialog handling based on code by X-Raym
if not reaper.JS_Dialog_BrowseForSaveFile then
  reaper.ShowConsoleMsg("Please install JS_ReaScript REAPER extension, available in Reapack extension, under ReaTeam Extensions repository.")
else

  retval, file = reaper.JS_Dialog_BrowseForSaveFile( "Save Punches and Streamers to CSV", '', "", 'csv files (.csv)\0*.csv\0All Files (*.*)\0*.*\0' )
  
  if retval and file ~= '' then
    if not file:find('.csv') then file = file .. ".csv" end
    reaper.defer(Main)
  end

end
