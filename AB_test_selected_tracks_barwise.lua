-- Toggle solo between selected tracks each bar

local currentMeasure = 0
local currentTrackIndex = 1

local cSelectedTracks = reaper.CountSelectedTracks(0)
local selectedTracks = {}
for i = 0,cSelectedTracks-1 do
  selectedTracks[i+1] = reaper.GetSelectedTrack(0, i)
end

function soloTrack(index1)
  reaper.SoloAllTracks(0)
  reaper.SetMediaTrackInfo_Value(selectedTracks[index1], "I_SOLO", 1)
end

function loop()
  reaper.ClearConsole()
  
  local playPosition = reaper.GetPlayPosition()
  local qn = reaper.TimeMap2_timeToQN(0, playPosition)
  local measure, _, _ = reaper.TimeMap_QNToMeasures(0, qn)
  
  --[[ 
  reaper.ShowConsoleMsg("playPosition:   " .. playPosition .. "\n")
  reaper.ShowConsoleMsg("qn:             " .. qn .. "\n")
  reaper.ShowConsoleMsg("measure:        " .. measure .. "\n")
  ]]--
  
  if currentMeasure == 0 then
    -- initial measure
    currentMeasure = measure
  elseif measure > currentMeasure then
    -- next measure, toggle next track
    currentMeasure = measure
    currentTrackIndex = currentTrackIndex + 1
    if currentTrackIndex > #selectedTracks then
      currentTrackIndex = 1
    end
    
    soloTrack(currentTrackIndex)
  end
  
  local playState = reaper.GetPlayState()
  if playState > 0 then
    reaper.runloop(loop)
  else
    --reaper.ShowConsoleMsg("Stopped.")
  end
end

------------------------------------------
-- Start playback and run loop until stop.
soloTrack(currentTrackIndex)
reaper.OnPlayButton()
loop()
