-- Streamers and Punches
-- by Christian Afonso
-- Feedback and bug reports to chr DOT afonso AT gmail DOT com
--
-- addVideoFX function based on code by eugen2777

-- Changelog:
-- ----------
-- v0.2: Replaced prerendered streamer videos with video effects. Smoother playback and more flexibility
--       in colors (but still pre-defined palette for now, as colors must be read in/converted
--       from marker text). Created MIDI items are colored the same as their streamer FX.
--       Punches stay pre-rendered image, for now (no native circle drawing in video fx).
--
-- v0.1: Proof of concept: Read markers and add streamer videos (in 4 colors)
--       and punch images to Streamers/Punches tracks (created if not found).
--       Existing tracks currently must have video effects "chroma key" for colored 
--       streamers and "remove black" (really =additive blend) for punches. FX are
--       created from template files on newly created tracks.
--       This is a bit hacky, but the best I could come up with using the 
--       current video effects...
--       Images/videos currently pre-rendered and read in from fixed data dir.

-- Constants
-- Track name defaults
STREAMERS = "Streamers"
PUNCHES = "Punches"

-- Setup: Paths, item files, functions
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  pathSep = "\\"
else
  pathSep = "/"
end

local _, fullScriptPath = reaper.get_action_context()
fullScriptPath = fullScriptPath:gsub("[^/\\]*$", "")

dataPath = fullScriptPath .. "update_streamers_data" .. pathSep
-- TODO check existence

-- open io scripts
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

-- debug utility
function println(stringy)
  if readSetting("show_console") then
	reaper.ShowConsoleMsg((stringy or "") .. "\n")
  end
end

-- TODO generate, or cache multiple resolution versions? Or a square image to be scaled and centered
punch_white = dataPath .. "punch_1600x900.png"

function getPunchSource()
  return reaper.PCM_Source_CreateFromFile(punch_white)
end

function insertPunch(position, punchNum)
    local punchItem = reaper.AddMediaItemToTrack(punchTrack)
    local punchTake = reaper.AddTakeToMediaItem(punchItem)
    local punchSource = getPunchSource()
    reaper.GetSetMediaItemTakeInfo_String(punchTake, "P_NAME", "Item P" .. (punchNum or ""), true)
    reaper.SetMediaItemTake_Source(punchTake, punchSource)
    reaper.SetMediaItemPosition(punchItem, position, false)
    reaper.SetMediaItemLength(punchItem, 0.08, false) -- duration = 2 typical frames
    reaper.SetMediaItemInfo_Value(punchItem, "D_FADEINLEN", 0)
    reaper.SetMediaItemInfo_Value(punchItem, "D_FADEOUTLEN", 0)
end

-- optional colors: replace in video effect params
function addVideoFX(trackOrItem, FX, isItem, r, g, b)
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
		local width = readSetting("streamer_width") or 0.1
        local duration = reaper.GetMediaItemInfo_Value(trackOrItem, "D_LENGTH")
        
        -- replace colors, set thickness, set duration
        fxChunk = fxChunk:gsub("CODEPARM .*$", "CODEPARM " .. width .. " " .. r .. " " .. g .. " " .. b .. " 1 " .. duration) -- alpha 1
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
    else
      -- additional one - clean up
      reaper.DeleteTrack(track)
      track = nil
    end
  elseif trackName == PUNCHES then
    punchTrack = track
  end
  
  -- if not deleted
  if track then
    reaper.SetTrackSelected(track, false) -- deselect all, then select Streamer track later
    t = t + 1
  end
end

-- create new if not found -- TODO create video fx
if punchTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  punchTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(punchTrack, "P_NAME", PUNCHES, true)
  
  addVideoFX(punchTrack, "punchFX.txt")
end

if streamerTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  streamerTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(streamerTrack, "P_NAME", STREAMERS, true)
  
  -- NEW: replaced with take VFX
  -- addVideoFX(streamerTrack, "streamerFX.txt")
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

function getItemColor(item)
    local color = nil
    local retval, chunk = reaper.GetItemStateChunk(item, "")
    if retval then
      for line in (chunk.."\n"):gmatch("(.-)\n") do
        if line:find("COLOR") then
          local m = line:match(".*COLOR ([0-9]+) R.*")
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
function clearTrack(track, leaveTextItems)
  local numItems = reaper.GetTrackNumMediaItems(track)
  local index = 0 -- should stay 0 (deleting items from the front) unless items are left, then go on to the next
  for i = 0,numItems-1 do
    local item = reaper.GetTrackMediaItem(track, index) -- delete from the front
    if item then
      local delete = true
      local notes = getItemNotes(item)
      if leaveTextItems and notes then
        delete = false
        
        -- TODO move out to somewhere more appropriate!
        -- Other possibility to detect manual items: no marker at end!
        local color = getItemColor(item)
        if color then
          if reaper.GetMediaItemNumTakes(item) < 1 then 
            reaper.AddTakeToMediaItem(item)
          end
          
          local r, g, b = getColorValues(color)
          addVideoFX(item, "streamerVFX.txt", true, r, g, b)
          
          -- Punch? marked by "P" note
          if notes == "P" then
            insertPunch(reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH"))
          end
        end
      end
      
      if delete then
        reaper.DeleteTrackMediaItem(track, item)
      else
        index = index + 1
      end
    end
  end
end

function getColorValues(color)
  local asnum = tonumber(color)
  if(type(asnum) == "number") then
    println("Color number value!")
    return (asnum&0xFF)/255, ((asnum&0xFF00) >> 8)/255, ((asnum&0xFF0000) >> 16)/255
  elseif(color == "white") then
    return 1, 1, 1
  elseif(color == "red") then
    return 1, 0, 0
  elseif(color == "green") then
    return 0, 1, 0
  elseif(color == "blue") then
    return 0, 0, 1
  elseif(color == "yellow") then
    return 1, 1, 0
  elseif(color == "magenta") then
    return 1, 0, 1
  elseif(color == "cyan") then
    return 0, 1, 1
  elseif(color == "black") then
    return 0, 0, 0
  else
    -- default if color unknown: white
    return 1, 1, 1
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

function RGB(r, g, b)
  return (r*255) + (g*255 << 8) + (b*255 << 16)
end

clearTrack(punchTrack)
clearTrack(streamerTrack, true)
-- TODO: Clear/remove additional streamer tracks!

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
      
      currentIndex = currentIndex + 1
      currentTrack = reaper.GetTrack(0, currentIndex)
      
      -- check if next track already is a Streamers track
      local retval, trackName = reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", "", false)
      println("Checking track " .. currentIndex .. " (" .. trackName .. ")")
      if not retval or trackName ~= STREAMERS then
        -- else create new track in-between
        reaper.InsertTrackAtIndex(currentIndex, false)
        currentTrack = reaper.GetTrack(0, currentIndex)
        reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", STREAMERS, true)
      end
    end
    
    -- insert midi item
    local streamerItem = reaper.CreateNewMIDIItemInProj(currentTrack, position - length, position, false)
    
    -- calculate color
    println("color: " .. color)
    local r, g, b = getColorValues(color)
    
    reaper.SetMediaItemInfo_Value(streamerItem, "I_CUSTOMCOLOR", RGB(r,g,b)|0x1000000)
    
    -- apply vfx
    if(streamerItem) then
      addVideoFX(streamerItem, "streamerVFX.txt", true, r, g, b)
    else
      println("Error creating empty MIDI item: " .. streamerItem)
    end
  end
  
  if (markerName == "P") or (markerName == "PUNCH") or showPunch then
    insertPunch(position, m)
  end
end

-- restore loop
reaper.GetSet_LoopTimeRange(true, true, loopStart, loopEnd, false)

reaper.UpdateArrange()
