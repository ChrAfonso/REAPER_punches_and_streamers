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

-- debug utility -- uncomment to show console window
function println(stringy)
  --reaper.ShowConsoleMsg(stringy .. "\n")
end

-- Setup: Paths, item files, functions
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  pathSep = "\\"
else
  pathSep = "/"
end

dataPath = reaper.GetResourcePath() .. pathSep .. "Scripts" .. pathSep .. "CAfonso" .. pathSep

-- try nested alternative
if not reaper.file_exists(dataPath .. "update_streamers.lua") then
  dataPath = reaper.GetResourcePath() .. pathSep .. "Scripts" .. pathSep .. "User" .. pathSep .. "CAfonso" .. pathSep
end

if not reaper.file_exists(dataPath .. "update_streamers.lua") then
  println("dataPath " .. dataPath .. " not found!")
  return -- quit
else
  dataPath = dataPath .. "update_streamers_data" .. pathSep
  println("dataPath: " .. dataPath)
end

-- TODO generate, or cache multiple resolution versions? Or a square image to be scaled and centered
punch_white = dataPath .. "punch_1600x900.png"

-- Constants
STREAMERS = "Streamers"
PUNCHES = "Punches"

function getPunchSource()
  return reaper.PCM_Source_CreateFromFile(punch_white)
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
        local duration = reaper.GetMediaItemInfo_Value(trackOrItem, "D_LENGTH")
        
        -- replace colors, leave thickness as in template, set duration
        fxChunk = fxChunk:gsub("CODEPARM ([0-9.]+) .*$", "CODEPARM %1 " .. r .. " " .. g .. " " .. b .. " 1 " .. duration) -- alpha 1
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

-- clear tracks
function clearTrack(track)
  local numItems = reaper.GetTrackNumMediaItems(track)
  for i = 0,numItems-1 do
    local item = reaper.GetTrackMediaItem(track, 0) -- delete from the front
    if item then
      reaper.DeleteTrackMediaItem(track, item)
    end
  end
end

function getColorValues(color)
  if(color == "white") then
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
clearTrack(streamerTrack)
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
    
    -- TODO: Does not work?
    reaper.SetMediaItemInfo_Value(streamerItem, "I_CUSTOMCOLOR", RGB(r,g,b)|0x1000000)
    
    -- apply vfx
    if(streamerItem) then
      addVideoFX(streamerItem, "streamerVFX.txt", true, r, g, b)
    else
      println("Error creating empty MIDI item: " .. streamerItem)
    end
  end
  
  if (markerName == "P") or (markerName == "PUNCH") or showPunch then
    -- insert punch
    local punchItem = reaper.AddMediaItemToTrack(punchTrack)
    local punchTake = reaper.AddTakeToMediaItem(punchItem)
    local punchSource = getPunchSource()
    reaper.GetSetMediaItemTakeInfo_String(punchTake, "P_NAME", "Item P" .. m, true)
    reaper.SetMediaItemTake_Source(punchTake, punchSource)
    reaper.SetMediaItemPosition(punchItem, position, false)
    reaper.SetMediaItemLength(punchItem, 0.08, false) -- duration = 2 typical frames
    reaper.SetMediaItemInfo_Value(punchItem, "D_FADEINLEN", 0)
    reaper.SetMediaItemInfo_Value(punchItem, "D_FADEOUTLEN", 0)
  end
end

-- restore loop
reaper.GetSet_LoopTimeRange(true, true, loopStart, loopEnd, false)

reaper.UpdateArrange()
