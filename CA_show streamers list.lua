-- Setup ------------------------------------------
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
---------------------------------------------------

---- SET UP Window ----

-- init
gfx.init("Punches and Streamers", 600, 400, 0x101)
font = "Arial"
font_size = 36
font_color = reaper.ColorToNative(255, 255, 255)

function format_timecode(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time - hours) / 60)
  local seconds = math.floor(time - hours - minutes)
  local ms = (time - hours - minutes - seconds)
  local frames = math.floor(ms * frameRate)
  return string.format("%02d", hours) .. ":" 
    .. string.format("%02d", minutes) .. ":" 
    .. string.format("%02d", seconds) .. ":" -- TODO: ; for drop-frame
    .. string.format("%02d", frames)
end

function format_seconds_frames(time)
  local hours = math.floor(time / 3600)
  local minutes = math.floor((time - hours) / 60)
  local seconds = math.floor(time - hours - minutes)
  local ms = (time - hours - minutes - seconds)
  local frames = math.floor(ms * frameRate)
  return string.format("%02d", seconds) .. ":" -- TODO: ; for drop-frame
    .. string.format("%02d", frames)
end

function mainloop()
  -- input
  if gfx.mouse_wheel ~= 0 then
    font_size = font_size + (gfx.mouse_wheel / 120)
    gfx.mouse_wheel = 0
  end

  -- update and draw
  
  listEntries = {}
  
  gfx.setfont(1, font, font_size)
  
  -- find punches
  local countPunchItems = reaper.GetTrackNumMediaItems(punchTrack)
  local flutterCount = 0
  for i = 0,countPunchItems-1 do
    local punchItem = reaper.GetTrackMediaItem(punchTrack, i)
    local position = reaper.GetMediaItemInfo_Value(punchItem, "D_POSITION")
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
  local countStreamerItems = reaper.GetTrackNumMediaItems(streamerTrack)
  for i = 0,countStreamerItems-1 do
    local streamerItem = reaper.GetTrackMediaItem(streamerTrack, i)
    local position = reaper.GetMediaItemInfo_Value(streamerItem, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(streamerItem, "D_LENGTH")
    local color = getItemColor(streamerItem)
    
    local entry = { type = "S", position = position, length = length, color = color }
    table.insert(listEntries, entry)
  end
  
  -- display
  local x = 10
  local y = 10
  local tab_width = 200
  
  gfx.x = x
  gfx.y = y
  gfx.drawstr("Position")
  gfx.x = x + tab_width
  gfx.drawstr("Duration")
  gfx.x = x + 2*tab_width
  gfx.drawstr("Type")
  gfx.x = x + 2.5*tab_width
  gfx.drawstr("Color")
  -- TODO start/end inside
  y = y + 2*gfx.texth
  
  table.sort(listEntries, function(a, b) return a.position < b.position end) 
  
  for i = 1,#listEntries do
    local entry = listEntries[i]
    gfx.x = x
    gfx.y = y
    gfx.drawstr(format_timecode(entry.position))
    gfx.x = x + 1.5*tab_width
    if entry.type == "S" then
      gfx.drawstr(format_seconds_frames(entry.length))
    end
    gfx.x = x + 2*tab_width
    gfx.drawstr(entry.type)
    gfx.x = x + 2.5*tab_width
    if entry.type == "S" then
      r,g,b = reaper.ColorFromNative(entry.color)
      gfx.set(r/255, g/255, b/255)
      gfx.drawstr(getColorName(entry.color))
      gfx.set(reaper.ColorFromNative(font_color))
    end
    y = y + gfx.texth
  end
  
  gfx.update()
  reaper.defer(mainloop)
end

---

mainloop()


