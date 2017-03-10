-- utility function, if not set
println = println or function(stringy)
end

-- default data path, if not set
if not dataPath then
  local _, fullScriptPath = reaper.get_action_context()
  fullScriptPath = fullScriptPath:gsub("[^/\\]*$", "")
  
  sep = "/"
  if reaper.GetOS():find("Win") == 1 then
    sep = "\\"
  end
  
  dataPath = fullScriptPath .. "update_streamers_data" .. sep
end

function loadSettings()
	local f = io.open(dataPath .. "settings.lua", "r")
	if f then
		local settingsdef = f:read("*all")
		f:close()
		
		settingsfunc = assert(load(settingsdef))
		if settingsfunc then
			settingsfunc()
			if not settings then
				settings = { read_settings = false }
			end
		end
	  
		println("Settings:")
		println("---------")
		for k,v in pairs(settings) do
			println("  " .. k .. ": " .. tostring(v))
		end
	else
		println("Error: Could not open Streamers and Punches settings file")
		settings = {}
	end
end

function writeSettings()
	local f = io.open(dataPath .. "settings.lua", "w")
	if f then
		println("Writing Settings:")
		println("-----------------")
		println("settings = {")
		f:write("settings = {\n")
		
		local first = true
		for k,v in pairs(settings) do
			if first then
				first = false
			else
				f:write(",\n")
			end
		
			println("  " .. k .. ": " .. tostring(v))
			f:write("\t" .. k .. " = " .. tostring(v))
		end
		
		println("}")
		f:write("\n}\n")
		
		f:close()
	else
		println("Error: Could not open Streamers and Punches settings file for writing")
	end
end
	
function readSetting(name)
  -- read file?
  if not settings then
    loadSettings()
  end
  
  return settings[name]
end

-- for now: only flat values
function writeSetting(name, value)
  -- read file?
  if not settings then
    loadSettings()
  end
  
  settings[name] = value
  
  writeSettings()
end
