-- Iterate through all trackcs and toggle hide on those that have a parent matching /^Tk\./
-- toggle state is checked on first found Take child

local visibleState = nil
local visibleHeight = 0
local numTracks = reaper.CountTracks(0)
local lastParent = nil
for i = 0,numTracks-1 do
  local track = reaper.GetTrack(0, i)
  local parentTrack = reaper.GetParentTrack(track)
  if (parentTrack ~= nil) then
    local trackName = reaper.GetTrackState(track)
    local retval,parentName = reaper.GetSetMediaTrackInfo_String(parentTrack, "P_NAME", "", false)
    if parentName:find("Tk.") == 1 then
      if visibleState == nil then
        if reaper.IsTrackVisible(track, false) then 
          visibleState = 0
        else
          visibleState = 1
        end
      end
      
      reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", visibleState)
      
      --[[
      if(parentName ~= lastParent) then
        reaper.TrackList_AdjustWindows(true)
        lastParent = parentName
      end
      --]]
    end
  end
end

reaper.TrackList_AdjustWindows(true)

