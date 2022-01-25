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

function mainloop()
  -- input
  if gfx.mouse_wheel ~= 0 then
    font_size = font_size + (gfx.mouse_wheel / 120)
    gfx.mouse_wheel = 0
  end

  -- update and draw
  
  local listEntries = create_table_from_streamer_items()
  
  -- display
  local x = 10
  local y = 10
  local tab_width = 200
  
  gfx.setfont(1, font, font_size)
  
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


