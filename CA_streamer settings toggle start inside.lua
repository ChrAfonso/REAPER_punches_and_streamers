GMEM_NAME = "CA_Punches_Streamers"

-- setup
currentValue = reaper.GetExtState(GMEM_NAME, "startInside")
currentValue = tonumber(currentValue)
if currentValue == 1 then
  newValue = 0
else
  newValue = 1
end

-- update state
reaper.SetExtState(GMEM_NAME, "startInside", newValue, true)

-- update icon toggle
_, _, sectionID, cmdID, _, _, _ = reaper.get_action_context()
reaper.SetToggleCommandState(sectionID, cmdID, newValue)
reaper.RefreshToolbar2(sectionID, cmdID)