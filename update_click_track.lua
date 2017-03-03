-- Update click track:
--
-- Use markers "C IN" and "C OUT"

-- define constants
local COMMAND_INSERT_CLICK_SOURCE = 40013

-- Clear console
reaper.ShowConsoleMsg("")

-- Find or create click track
local clickTrack = nil
for t = 0,reaper.CountTracks(0)-1 do
  local track = reaper.GetTrack(0, t)
  local _, trackName = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  reaper.ShowConsoleMsg("Checking track " .. t .. " (" .. trackName .. ")...\n")
  if trackName == "Click" then
    clickTrack = track;
    reaper.ShowConsoleMsg("Found Click track!\n")
  end
  reaper.SetTrackSelected(track, false) -- deselect all for now
end

if not clickTrack then
  reaper.ShowConsoleMsg("Did not find Click track, create new\n")
  reaper.InsertTrackAtIndex(0, true)
  clickTrack = reaper.GetTrack(0, 0)
  reaper.GetSetMediaTrackInfo_String(clickTrack, "P_NAME", "Click", true)
end

-- Cleanup
local numItems = reaper.GetTrackNumMediaItems(clickTrack)
for i = 0,numItems-1 do
  local item = reaper.GetTrackMediaItem(clickTrack, 0)
  if item then
    reaper.DeleteTrackMediaItem(clickTrack, item)
  end  
end

-- Select click track
reaper.SetTrackSelected(clickTrack, true)

function createClickRegion(startpos, endpos)
  reaper.ShowConsoleMsg("Create click region.\n")
  reaper.ShowConsoleMsg("  Clicks in: " .. startpos .. "\n")
  reaper.ShowConsoleMsg("  Clicks out: " .. endpos .. "\n")

  reaper.GetSet_LoopTimeRange(true, true, startpos, endpos, false)
  reaper.Main_OnCommand(COMMAND_INSERT_CLICK_SOURCE, 0)
end

-- cache loop
loopStart, loopEnd = reaper.GetSet_LoopTimeRange(false, true, 0, 0, false)

-- find markers
numMarkers = reaper.CountProjectMarkers(0)

-- find in/out points
local lastIN = nil
for m = 0,numMarkers-1 do
  local _, _, position, _, markerName, _ = reaper.EnumProjectMarkers(m)
  reaper.ShowConsoleMsg("Checking marker " .. m .. " (" .. markerName .. ") at " .. position .. "\n")
  
  if(markerName:find("C IN") == 1 or markerName:find("CLICK IN") == 1) then
    -- TODO
    if not lastIN then
      lastIN = position
    end
  end
  
  if(markerName:find("C OUT") == 1 or markerName:find("CLICK OUT") == 1) then
    -- TODO
    if lastIN then
      createClickRegion(lastIN, position)
      lastIN = nil
    end
  end
end

-- restore loop
reaper.GetSet_LoopTimeRange(true, true, loopStart, loopEnd, false)

reaper.UpdateArrange()
