-- Streamers and Punches
-- by Christian Afonso

-- v0.1: Proof of concept: Read markers and add streamer videos (in 4 colors)
--       and punch images to Streamers/Punches tracks (created if not found).
--       Tracks currently must have video effects "chroma key" for colored 
--       streamers and "remove black" (really =additive blend) for punches/
--       white streamers. This is a bit hacky, but the best I could come up
--       with using the current video effects...
--       Images/videos currently pre-rendered and read in from fixed dir/project dir.

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

-- streamer items
-- TODO save generic? Currently have to be in project dir
path = reaper.GetProjectPath("")
os = reaper.GetOS();
if(os == "Win32" or os == "Win64") then
  path = path .. "\\"
else
  path = path .. "/"
end

streamers = {}
streamers["white"] = path .. "streamer_4s_white.avi" -- HACK: White must be filtered with remove_black? chroma key filter is strange...
streamers["yellow"] = path .. "streamer_4s_yellow_bs.avi"
streamers["green"] = path .. "streamer_4s_green_bs.avi"
streamers["red"] = path .. "streamer_4s_red_bs.avi"

punch_white = path .. "punch_1600x900.png"

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

-- select Streamer track
streamerTrack = nil
punchTrack = nil
for t = 0, reaper.CountTracks(0)-1 do
  local track = reaper.GetTrack(0, t)
  local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if trackName == "Streamers" then
    streamerTrack = track
  elseif trackName == "Punches" then
    punchTrack = track
  end
  reaper.SetTrackSelected(track, false) -- deselect all, then select Streamer track later
end

-- create new if not found
if punchTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  punchTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(punchTrack, "P_NAME", "Punches", true)
end

if streamerTrack == nil then
  reaper.InsertTrackAtIndex(0, true)
  streamerTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(streamerTrack, "P_NAME", "Streamers", true)
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

clearTrack(punchTrack)
clearTrack(streamerTrack)

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
    
    println("color: " .. color)
    
    -- create streamer
    local streamerSrc = getStreamerSource(color)
    if streamerSrc then
      -- needed for InsertMedia
      if (color == "white") then -- HACK: filter with remove_black, chroma key filter is strange...
        println("Select punch track")
        reaper.SetTrackSelected(punchTrack, true)
        reaper.SetTrackSelected(streamerTrack, false)
      else
        println("Select streamer track")
        reaper.SetTrackSelected(punchTrack, false)
        reaper.SetTrackSelected(streamerTrack, true)
      end
    
      reaper.SetEditCurPos(position, false, false)
      reaper.GetSet_LoopTimeRange(true, true, position - length, position, false)
      local retval = reaper.InsertMedia(streamerSrc, 4)
      println("InsertMedia retval: " .. retval)
      
      -- TODO how to do this? Have to find inserted media item
      --reaper.SetMediaItemInfo_Value(streamerItem, "D_FADEINLEN", 0)
      --reaper.SetMediaItemInfo_Value(streamerItem, "D_FADEOUTLEN", 0)
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
