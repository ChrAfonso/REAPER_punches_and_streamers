-- Streamers and Punches
-- by Christian Afonso
--
-- addVideoFX function based on code by eugen2777

-- v0.1: Proof of concept: Read markers and add streamer videos (in 4 colors)
--       and punch images to Streamers/Punches tracks (created if not found).
--       Existing tracks currently must have video effects "chroma key" for colored 
--       streamers and "remove black" (really =additive blend) for punches. FX are
--       created from template files on newly created tracks.
--       This is a bit hacky, but the best I could come up with using the 
--       current video effects...
--       Images/videos currently pre-rendered and read in from fixed data dir.

--- gfx debug utility
function println(stringy)
  gfx.drawstr(stringy)
  gfx.x = 10
  gfx.y = gfx.y + 10
end

-- Uncomment to see debug console
--gfx.init("Output", 800, 300, 0, 100, 100)
gfx.x = 10
gfx.y = 10

-- Setup: Paths, item files, functions
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  pathSep = "\\"
else
  pathSep = "/"
end

dataPath = reaper.GetResourcePath() .. pathSep .. "Scripts" .. pathSep .. "CAfonso" .. pathSep
if not reaper.file_exists(dataPath .. "update_streamers.lua") then
  println("dataPath " .. dataPath .. " not found!")
else
  dataPath = dataPath .. "update_streamers_data" .. pathSep
  println("dataPath: " .. dataPath)
end

streamers = {}
streamers["white"] = dataPath .. "streamer_4s_white_bs.avi"
streamers["yellow"] = dataPath .. "streamer_4s_yellow_bs.avi"
streamers["green"] = dataPath .. "streamer_4s_green_bs.avi"
streamers["red"] = dataPath .. "streamer_4s_red_bs.avi"

punch_white = dataPath .. "punch_1600x900.png"

function getStreamerSource(color)
  println("Looking for streamer in " .. color)
  duration = 2 -- NOTE: use just one and stretch? Then omit param
  if not streamers[color] then
    color = "white"
  end
  
  local streamerSrc = streamers[color];
  return streamerSrc
end

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
for t = 0, reaper.CountTracks(0)-1 do
  local track = reaper.GetTrack(0, t)
  local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if trackName == "Streamers" then
    streamerTrack = track
    --punchTrack = track -- TEST: If bluescreen works on everything, we only need one track
  elseif trackName == "Punches" then
    punchTrack = track
  end
  reaper.SetTrackSelected(track, false) -- deselect all, then select Streamer track later
end

-- create new if not found -- TODO create video fx
if punchTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  punchTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(punchTrack, "P_NAME", "Punches", true)
  
  addVideoFX(punchTrack, "punchFX.txt")
end

if streamerTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  streamerTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(streamerTrack, "P_NAME", "Streamers", true)
  
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

clearTrack(punchTrack)
clearTrack(streamerTrack)

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
    
    -- calculate color
    println("color: " .. color)
    local r, g, b = getColorValues(color)
    
    -- insert midi item    
    local streamerItem = reaper.CreateNewMIDIItemInProj(streamerTrack, position - length, position, false)
    
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
