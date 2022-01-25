--[[
 * ReaScript Name: Streamers and Punches
 * Author: Christian Afonso
 * License: GPL v3
 * Version: 0.4
 * REAPER: 5.0
 * Feedback and bug reports to chr DOT afonso AT gmail DOT com
 * addVideoFX function based on code by eugen2777
--]]

--[[
 * Changelog:
 * v0.4
   + Restructured scripts: update_streamers_lib contains function, other scripts import and call these
   + Added scripts for single actions: add_punch, add_streamer_[color]_[length] at cursor position (without markers)
   + Added toolbar buttons
 * v0.3
 * v0.2
   + Replaced prerendered streamer videos with video effects. Smoother playback and more flexibility
   + in colors (but still pre-defined palette for now, as colors must be read in/converted
   + from marker text). Created MIDI items are colored the same as their streamer FX.
   + Punches stay pre-rendered image, for now (no native circle drawing in video fx).
 * v0.1
   + Proof of concept: Read markers and add streamer videos (in 4 colors)
   + and punch images to Streamers/Punches tracks (created if not found).
   + Existing tracks currently must have video effects "chroma key" for colored 
   + streamers and "remove black" (really =additive blend) for punches. FX are
   + created from template files on newly created tracks.
   + This is a bit hacky, but the best I could come up with using the 
   + current video effects...
   + Images/videos currently pre-rendered and read in from fixed data dir.
--]]

-- TODO: Encapsulate in object/namespace

-- Constants
-- Track name defaults
STREAMERS = "Streamers"
PUNCHES = "Punches"

frameRate = reaper.TimeMap_curFrameRate(0)
df = 1 / frameRate

-- global memory
GMEM_NAME = "CA_Punches_Streamers"

function getStartInside()
	return reaper.GetExtState(GMEM_NAME, "startInside")
end

function getEndInside()
	return reaper.GetExtState(GMEM_NAME, "endInside")
end

------

-- Setup: Paths, item files, functions
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  pathSep = "\\"
else
  pathSep = "/"
end

_,ScriptPath = reaper.get_action_context()
ScriptPath = ScriptPath:gsub("[^" .. pathSep .. "]+$", "") -- remove filename
dataPath = ScriptPath .. "data" .. pathSep

-- loaded on demand from settings.lua
-- settings.lua should have the form:
-- settings = {
--   name1 = value1,
--   name2 = {
--     name3 = value3,
--     name4 = value4
--   }
--   ...
-- }
settings = nil

function loadSettings()
  local f = io.open(dataPath .. "settings.lua", "r")
  if f then
    local settingsdef = f:read("*all")
    f:close()
    
    settingsfunc = assert(load(settingsdef))
    if settingsfunc then
      settingsfunc()
      if not settings then
        settings = { read_settings = false }
      end
    end
    
    println("Settings:")
    println("---------")
    for k,v in pairs(settings) do
      println("  " .. k .. ": " .. tostring(v))
    end
  else
    println("Error: Could not open Streamers and Punches settings file")
    settings = {}
  end
end

function readSetting(name)
  -- read file?
  if not settings then
    loadSettings()
  end
  
  return settings[name]
end

-- debug utility
function println(stringy)
  if readSetting("show_console") then
    reaper.ShowConsoleMsg((stringy or "") .. "\n")
  end
end

-- TODO generate when circle drawing is possible in VFX script
-- square image will be scaled and centered
punch_white = dataPath .. "punch_900x900.png"
punch_source = nil
function getPunchSource()
  punch_source = punch_source or reaper.PCM_Source_CreateFromFile(punch_white)
  return punch_source
end

function insertPunch(position, punchNum, length, undo)
  if undo == nil then undo = true end -- default
  
  if undo == true then
    reaper.Undo_BeginBlock()
  end

  local punchItem = reaper.AddMediaItemToTrack(punchTrack)
  local punchTake = reaper.AddTakeToMediaItem(punchItem)
  local punchSource = getPunchSource()
  reaper.GetSetMediaItemTakeInfo_String(punchTake, "P_NAME", "Item P" .. (punchNum or ""), true)
  reaper.SetMediaItemTake_Source(punchTake, punchSource)
  reaper.SetMediaItemPosition(punchItem, position, false)
  reaper.SetMediaItemLength(punchItem, length or 2*df, false) -- 2 frames default helps with frame drops during playback
  reaper.SetMediaItemInfo_Value(punchItem, "D_FADEINLEN", 0)
  reaper.SetMediaItemInfo_Value(punchItem, "D_FADEOUTLEN", 0)
  reaper.SetMediaItemInfo_Value(punchItem, "C_BEATATTACHMODE", -1) -- track default -- can be overriden with beats
  
  if undo == true then
    reaper.Undo_EndBlock("Insert Punch", -1)
  end
end

function insertFlutter(position, count)
  count = count or 3
  if count < 3 then count = 3 end
  
  reaper.Undo_BeginBlock()
  
  local max_pre = math.ceil(count/2) - 1
  for pre = 1,max_pre do
    insertPunch(position - 2*pre*df, "", df, false)
  end
  insertPunch(position, "", df, false)
  for post = 1,(count - 1 - max_pre) do
    insertPunch(position + 2*post*df, "", df, false)
  end
  
  reaper.Undo_EndBlock("Insert Flutter", -1)
end

-- optional colors: replace in video effect params
function addVideoFX(trackOrItem, FX, isItem, r, g, b, startInside, endInside)
  -- read cached FX chunk from text file and add to track chunk
  local retval, trackOrItemChunk
  if not isItem then
    println("Trying to get Track state chunk...")
    retval, trackOrItemChunk = reaper.GetTrackStateChunk(trackOrItem, "", true)
  else
    println("Trying to get MediaItem state chunk...")
    retval, trackOrItemChunk = reaper.GetItemStateChunk(trackOrItem, "", true)
  end
  if retval then
    println("Found chunk!")
    local fxGUID = reaper.genGuid("")
    local file = io.open(dataPath .. "FX" .. pathSep .. FX, "r")
    if file then
      local fxChunk = file:read("*all")
      file:close()
      
      -- replace colors and set duration for item vfx
      if isItem then
        -- assign some defaults if not defined...
        r = r or 0
        g = g or 0
        b = b or 0
		alpha = 1
		startInside = startInside or getStartInside()
		endInside = endInside or getEndInside()
        local width = readSetting("streamer_width") or 0.1
        local duration = reaper.GetMediaItemInfo_Value(trackOrItem, "D_LENGTH")
        
        -- set thickness, replace colors, set duration, set start/end inside
        fxChunk = fxChunk:gsub("CODEPARM .*$", "CODEPARM " .. width .. " " .. r .. " " .. g .. " " .. b .. " " .. alpha .. " " .. duration .. " " .. startInside .. " " .. endInside)
      end
      
      fxChunk = fxChunk .. 
[[  FXID ]] .. fxGUID .. [[
  WAK 0
  >
>]]
      trackOrItemChunk = trackOrItemChunk:sub(1,-3) -- remove closing tag
      trackOrItemChunk = trackOrItemChunk .. fxChunk
      if not isItem then
        reaper.SetTrackStateChunk(trackOrItem, trackOrItemChunk)
      else
        reaper.SetItemStateChunk(trackOrItem, trackOrItemChunk)
      end
    else
      println("Could not read FX file " .. FX)
    end
  else
    println("Could not create video FX " .. FX)
  end
end

-- find Streamer and Punches tracks
streamerTrack = nil
punchTrack = nil
local t = 0
while t < reaper.CountTracks(0) do
  local track = reaper.GetTrack(0, t)
  local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if trackName == STREAMERS then
    if not streamerTrack then
      -- first one = default Streamers track
      streamerTrack = track
    end
  elseif trackName == PUNCHES then
    punchTrack = track -- there should only be one
  end
  
  reaper.SetTrackSelected(track, false) -- deselect all, then select Streamer track later
  t = t + 1
end

if streamerTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  streamerTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(streamerTrack, "P_NAME", STREAMERS, true)
  
  -- NEW: replaced with take VFX
  -- addVideoFX(streamerTrack, "streamerFX.txt")
end

-- create new if not found -- TODO create video fx
if punchTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  punchTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(punchTrack, "P_NAME", PUNCHES, true)
  
  addVideoFX(punchTrack, "punchFX.txt")
end


-- Search chunk for notes, and parse this:
-- <NOTES
--     |foo
--     |bar
--  |...
-- >
function getItemNotes(item)
  local notes = ""
  local retval, chunk = reaper.GetItemStateChunk(item, "")
  if retval then
    local inNotesBlock = false
    for line in (chunk.."\n"):gmatch("(.-)\n") do
      if line:find("<NOTES") then
        inNotesBlock = true
      elseif inNotesBlock then
        if not line:find("|") then
          inNotesBlock = false
        else -- Notes line beginning with |
          if notes ~= "" then 
            notes = notes .. "\n"
          end
          notes = notes .. line:gsub(".*|", "")
        end
      end
    end
  end
  
  if notes ~= "" then
    return notes
  else
    return nil
  end
end

function getMarker(index)
  local _, _, position, _, markerName, _ = reaper.EnumProjectMarkers(index)
  return position, markerName
end

function getItemStartEnd(item)
  local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return itemStart, itemEnd
end

-- returns true if the item has a punch marker at the start
function hasMarkerAtStart(item)
  local startPosition, _ = getItemStartEnd(item)
  
  local numMarkers = reaper.CountProjectMarkers(0)
  for m = 0,numMarkers-1 do
    local position, name = getMarker(m)
    
    -- TODO error margin? Or is precise position fine?
    -- TODO check for - at end of streamer markers
    if tostring(startPosition) == tostring(position) then
      if name == "P" or name:sub(1,5) == "PUNCH" or name:sub(1,2) == "S " or name:sub(1,8) == "STREAMER" then
--        println("      hasMarkerAtStart: Found marker at position " .. position .. ", name: " .. name)
        return true
      end
    end
  end

  return false -- TEMP WIP: this will leave all generated items!
end

-- returns true if the item has a streamer marker at the end
function hasMarkerAtEnd(item)
--  println("      hasMarkerAtEnd:")
  local _, endPosition = getItemStartEnd(item)
--  println("        (endPosition: " .. endPosition .. ")")
  
  local numMarkers = reaper.CountProjectMarkers(0)
--  println("        (numMarkers: " .. numMarkers .. ")")
  for m = 0,numMarkers-1 do
    local position, name = getMarker(m)
--    println("          M " .. m .. " at " .. position)
    
    -- TODO error margin? Or is precise position fine?
    if tostring(endPosition) == tostring(position) then
--      println("        Found marker at position " .. position .. ", name: " .. name)
      if name:sub(1,2) == "S " or name:sub(1,8) == "STREAMER" then
--        println("        yes")
        return true
      end
    end
  end

  println("        no")
  return false -- TEMP WIP: this will leave all generated items!
end

function getItemColor(item)
  local color = nil
  local retval, chunk = reaper.GetItemStateChunk(item, "")
  if retval then
    for line in (chunk.."\n"):gmatch("(.-)\n") do
      if line:find("COLOR") then
        local m = line:match(".*COLOR ([0-9]+) [RB].*") -- NOTE: seems R on win, B on Mac
        if m then
          color = m
        end
      end
    end
  end
  
  if color then
    return color
  else
    return nil
  end
end

-- clear tracks and add FX to manual streamers (TODO: move this out to somewhere else)
function clearTrack(track, leaveTextItems, leaveUnmarkedStreamersAndPunches)
  local numItems = reaper.GetTrackNumMediaItems(track)
  println("    clearTrack: " .. numItems .. " items")

  local index = 0 -- should stay 0 (deleting items from the front) unless items are left, then go on to the next
  for i = 0,numItems-1 do
    local item = reaper.GetTrackMediaItem(track, index) -- delete from the front
    if item then
      local delete = true
      local notes = getItemNotes(item)
      if leaveTextItems and notes then
        println("      Leaving item " .. i .. ", has notes")
        delete = false
      end
	  
      -- don't delete punches that won't get regenerated
      if track == punchTrack then
	    if leaveUnmarkedStreamersAndPunches and not hasMarkerAtStart(item) then
          println("      Leaving item " .. i .. ", is unmarked punch")
          delete = false
        end
      elseif leaveUnmarkedStreamersAndPunches and not hasMarkerAtEnd(item) then
        println("      Leaving item " .. i .. ", is unmarked streamer")
	    delete = false
	  end
      
      if delete then
        println("      Deleting item " .. i)
        reaper.DeleteTrackMediaItem(track, item)
        numItems = numItems - 1
      else
        index = index + 1
      end
    end
  end
end

function clearGeneratedItems()
  println("clearGeneratedItems ---")
  local t = 0
  local numTracks = reaper.CountTracks(0)
  while t < numTracks do
    local track = reaper.GetTrack(0, t)
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == STREAMERS then
	  println("  track " .. t .. " " .. trackName .. " is Streamer track")
      clearTrack(track, true, true) -- leave text items, leave unmarked items - only deletes items that will be regenerated from markers
    
      -- first one = default Streamers track - all others can be deleted if empty
      if track ~= streamerTrack then
	    local numItems = reaper.CountTrackMediaItems(track)
		if numItems == 0 then
          reaper.DeleteTrack(track)
          track = nil
		  numTracks = numTracks - 1
		end
      end
    elseif trackName == PUNCHES then
	  println("  track " .. t .. " " .. trackName .. " is Punch track")
      clearTrack(track, true, true) -- leave text items, leave unmarked items
    end
    
    -- if not deleted
    if track then
      reaper.SetTrackSelected(track, false) -- deselect all, then select Streamer track later
      t = t + 1
    end
  end
end

function RGB(nativeColor)
  local r,g,b = reaper.ColorFromNative(nativeColor)
  return string.format("0x%02X%02X%02X", r, g, b)
end

function getColorValues(userColor)
  if (type(userColor) == "string") and (userColor:sub(1,1) == "#") and (#userColor == 7) then
    -- html-style userColor (#rrggbb), transform to hex form
	userColor = "0x" .. userColor:sub(2)
  end
  local asnum = tonumber(userColor)
  if(type(asnum) == "number") then
    println("Color number value!")
    return ((asnum&0xFF0000) >> 16)/255, ((asnum&0xFF00) >> 8)/255, (asnum&0xFF)/255
  elseif(userColor == "white") then
    return 1, 1, 1
  elseif(userColor == "red") then
    return 1, 0, 0
  elseif(userColor == "green") then
    return 0, 1, 0
  elseif(userColor == "blue") then
    return 0, 0, 1
  elseif(userColor == "yellow") then
    return 1, 1, 0
  elseif(userColor == "magenta") then
    return 1, 0, 1
  elseif(userColor == "cyan") then
    return 0, 1, 1
  elseif(userColor == "black") then
    return 0, 0, 0
  else
    -- default if userColor unknown: white
    return 1, 1, 1
  end
end

function getColorName(nativeColor)
  color = RGB(nativeColor)
  if color == "0xFFFFFF" then
  	return "white"
  elseif color == "0xFF0000" then
  	return "red"
  elseif color == "0x00FF00" then
  	return "green"
  elseif color == "0x0000FF" then
  	return "blue"
  elseif color == "0xFFFF00" then
  	return "yellow"
  elseif color == "0xFF00FF" then
  	return "magenta"
  elseif color == "0x00FFFF" then
	return "cyan"
  elseif color == "0x000000" then
    return "black"
  else
	return color
  end
end

-- provide either item, or track and start/end
function isOverlappingOtherItems(item, track, itemStart, itemEnd)
  if item then
    track = reaper.GetMediaItem_Track(item)
    local itemStart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local itemEnd = itemStart + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  end
  
  if (track == nil) or (itemEnd <= itemStart) then
    println("Error: invalid params to isOverlappingOtherItems (need item, or track, startTime, endTime)")
  end
  
  local numItems = reaper.CountTrackMediaItems(track)
  
  for i = 0,numItems-1 do
    local other = reaper.GetTrackMediaItem(track, i)
    if other ~= item then
      local otherStart = reaper.GetMediaItemInfo_Value(other, "D_POSITION")
      local otherEnd = otherStart + reaper.GetMediaItemInfo_Value(other, "D_LENGTH")
      
      if (itemStart > otherStart and itemStart < otherEnd)
      or (otherStart > itemStart and otherStart < itemEnd) then
        return true
      end
    end
  end
  
  return false
end

function insertStreamer(position, length, color, showPunch, undo)
	if undo == nil then undo = true end -- default
	
	if undo == true then
		reaper.Undo_BeginBlock()
	end
	
	-- prevent overlaps (vfx don't work overlapped on same track)
	local currentIndex = reaper.GetMediaTrackInfo_Value(streamerTrack, "IP_TRACKNUMBER")
	if (currentIndex == 0) then
	  println("Error: track number for Streamers track not found! Abort.")
	  return
	else
	  -- track number is 1-based (0 = not found, -1 = master track), track index is 0-based
	  currentIndex = currentIndex - 1
	end
	
	local currentTrack = streamerTrack
	 local l = 0
	while l < 20 and isOverlappingOtherItems(nil, currentTrack, position - length, position) do
	  println("Loop " .. l)
	  l = l + 1
	  println("Streamer item overlaps previous streamer, trying to find/create additional Streamer tracks...")
	  
	  local lastTrack = currentTrack
	  local lastFolderDepth = reaper.GetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH")
	  
	  currentIndex = currentIndex + 1
	  currentTrack = reaper.GetTrack(0, currentIndex)
	  
	  -- check if next track already is a Streamers track
	  local retval = nil
	  local trackName = ""
	  if currentTrack then
	    retval, trackName = reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", "", false)
	    println("Checking track " .. currentIndex .. " (" .. trackName .. ")")
	  end
	  
	  if not retval or trackName ~= STREAMERS then
		-- else create new track in-between
		reaper.InsertTrackAtIndex(currentIndex, false)
		
		currentTrack = reaper.GetTrack(0, currentIndex)
		reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", STREAMERS, true)
		
		reaper.SetMediaTrackInfo_Value(lastTrack, "I_FOLDERDEPTH", 0) -- normal
		reaper.SetMediaTrackInfo_Value(currentTrack, "I_FOLDERDEPTH", lastFolderDepth) -- folder nesting info from previous track
	  end
	end
	
	-- insert midi item
	local streamerItem = reaper.CreateNewMIDIItemInProj(currentTrack, position - length, position, false)
	
	-- calculate color
	println("color: " .. color)
	local r, g, b = getColorValues(color)
	
	reaper.SetMediaItemInfo_Value(streamerItem, "I_CUSTOMCOLOR", reaper.ColorToNative(r*255, g*255, b*255)|0x1000000)
	
	-- keep item fixed in time
	reaper.SetMediaItemInfo_Value(streamerItem, "C_BEATATTACHMODE", 0)
	reaper.SetMediaItemInfo_Value(streamerItem, "B_LOOPSRC", 0)
	local timesig_num, timesig_denom, tempo = reaper.TimeMap_GetTimeSigAtTime(0, position)
	reaper.BR_SetMidiTakeTempoInfo(reaper.GetMediaItemTake(streamerItem, 0), 1, tempo, timesig_num, timesig_denom)
	
	-- apply vfx
	if(streamerItem) then
	  addVideoFX(streamerItem, "streamerVFX.txt", true, r, g, b)
	else
	  println("Error creating empty MIDI item: " .. streamerItem)
	end
	
	if showPunch then
		insertPunch(position, m, false)
	end
	
	if undo == true then
		reaper.Undo_EndBlock("Insert streamer", -1)
		
		reaper.UpdateArrange()
	end
end

function update_punches_and_streamers_from_markers()
	reaper.Undo_BeginBlock()

	clearGeneratedItems()

	reaper.SetTrackSelected(streamerTrack, true) -- needed for InsertMedia

	-- find markers
	numMarkers = reaper.CountProjectMarkers(0)

	-- cache loop
	loopStart, loopEnd = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)

	for m = 0,numMarkers-1 do
	  println("Checking marker " .. m)
	  local _, _, position, _, markerName, _ = reaper.EnumProjectMarkers(m)
	  local showPunch = false
	  
	  if(markerName:find("STREAMER") == 1 or markerName:find("S ") == 1) then
		-- insert streamer. Format: "S[TREAMER] [<length_in_s> [[-]<color>]"
		local args = {}
		for str in markerName:gmatch("[^ ]+") do
		  table.insert(args, str)
		end
		local numargs = #args
		
		-- defaults:
		local length = 2
		local color = "white"
		
		-- calculate start, length
		if numargs > 1 then
		  length = args[2]
		end
		
		if numargs > 2 then
		  -- set color; also show punch if not "-" before color
		  color = args[3]
		  if color:sub(1,1) == "-" then
			color = color:sub(2)
		  else
			showPunch = true
		  end
		else
		  showPunch = true -- no color defined = default show
		end
		
		insertStreamer(position, length, color, showPunch, false)
	  end
	  
	  if (markerName == "P") or (markerName == "PUNCH") then
		insertPunch(position, m, false)
	  end
	end

	-- restore loop
	reaper.GetSet_LoopTimeRange(true, true, loopStart, loopEnd, false)
	
	reaper.Undo_EndBlock("Update punches and streamers from markers", -1)
	
	reaper.UpdateArrange()
end

-- string utilities

function split_string(str, delimiters)
  local elements = {}
  local pattern = '([^'..delimiters..']*)'
  string.gsub(str, pattern, function(value) elements[#elements + 1] = value;  end);
  return elements
end

-- timecode utilities

function format_timecode(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time - (hours * 3600)) / 60)
  local seconds = math.floor(time - (hours * 3600) - (minutes * 60))
  local ms = (time - (hours * 3600) - (minutes * 60) - seconds)
  local frames = math.floor(ms * frameRate)
  return string.format("%02d", hours) .. ":" 
    .. string.format("%02d", minutes) .. ":" 
    .. string.format("%02d", seconds) .. ":" -- TODO: ; for drop-frame
    .. string.format("%02d", frames)
end

function format_seconds_frames(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time - (hours * 3600)) / 60)
  local seconds = math.floor(time - (hours * 3600) - (minutes * 60))
  local ms = (time - (hours * 3600) - (minutes * 60) - seconds)
  local frames = math.floor(ms * frameRate)
  return string.format("%02d", seconds) .. ":" -- TODO: ; for drop-frame
    .. string.format("%02d", frames)
end

-- timecode format expected: [[HH:]MM:]SS:FF
function parse_timecode(timecodeString, applyProjectOffset)
  applyProjectOffset = applyProjectOffset or false

  local tokens = split_string(timecodeString, ":")
  
  local frames = tonumber(tokens[#tokens])
  local seconds = tonumber(tokens[#tokens - 1])
  local minutes = 0
  local hours = 0
  if #tokens > 2 then
    minutes = tonumber(tokens[#tokens - 2])
    if #tokens > 3 then
      hours = tonumber(tokens[#tokens - 3])
    end
  end
  
  local time = (frames / frameRate) + seconds + (minutes * 60) + (hours * 3600)
  if applyProjectOffset then
    return time - reaper.GetProjectTimeOffset(0, true)
  else
    return time
  end
end

-- save/load

-- TODO also provide function to create from punch/streamer markers?
--      or: reference X-Raym markers-to-csv script?
function create_table_from_streamer_items()
  listEntries = {}
  
  -- find punches
  local countPunchItems = reaper.GetTrackNumMediaItems(punchTrack)
  local flutterCount = 0
  for i = 0,countPunchItems-1 do
    local punchItem = reaper.GetTrackMediaItem(punchTrack, i)
    local position = reaper.GetMediaItemInfo_Value(punchItem, "D_POSITION") + reaper.GetProjectTimeOffset(0, true)
    local length = reaper.GetMediaItemInfo_Value(punchItem, "D_LENGTH")
    
    local foundFlutter = false
    if (#listEntries > 0) and (position - listEntries[#listEntries].position) < (df*2.5) then
      flutterCount = flutterCount + 1
      if flutterCount == 2 then
        foundFlutter = true
        
        -- keep middle punch
        listEntries[#listEntries - 1] = listEntries[#listEntries]
        listEntries[#listEntries - 1].type = "F"
        listEntries[#listEntries] = nil
      end
    else
      flutterCount = 0
    end
      
    if not foundFlutter then
      local entry = { type = "P", position = position, length = length }
      table.insert(listEntries, entry)
    end
  end
  
  -- find streamers
  local numTracks = reaper.CountTracks(0)
  for t = 0,numTracks-1 do
    local track = reaper.GetTrack(0, t)
    local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
    if trackName == STREAMERS then
      local countStreamerItems = reaper.GetTrackNumMediaItems(track)
      for i = 0,countStreamerItems-1 do
        local streamerItem = reaper.GetTrackMediaItem(track, i)
        local position = reaper.GetMediaItemInfo_Value(streamerItem, "D_POSITION") + reaper.GetProjectTimeOffset(0, true)
        local length = reaper.GetMediaItemInfo_Value(streamerItem, "D_LENGTH")
        local color = getItemColor(streamerItem)
        
        local entry = { type = "S", position = position, length = length, color = color }
        table.insert(listEntries, entry)
      end
	end
  end
  
  table.sort(listEntries, function(a, b) return a.position < b.position end)
  
  return listEntries
end
