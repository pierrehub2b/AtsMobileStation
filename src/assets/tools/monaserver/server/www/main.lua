local devices = {}
local sync = nil
local msApp = nil

function getDeviceIndex(id)
	for i, v in ipairs (devices) do 
		if (v.id == id) then
			return i 
		end
	end
	return nil
end

function getDevice(id)
	for i, d in ipairs (devices) do 
		if (d.id == id) then
			return d 
		end
	end
	return nil
end

function updateDevice(id, locked)
	for i, v in ipairs (devices) do 
		if (v.id == id) then
			v.locked = locked
			return true 
		end
	end
	return false
end

function close()
    for i=0, #devices do devices[i]=nil end
    for id, cli in pairs(mona.clients) do
        cli.writer:writeInvocation("msStatus", "close")
    end
end

local charset = {}  do -- [0-9a-zA-Z]
	for c = 48, 57  do table.insert(charset, string.char(c)) end
	for c = 65, 90  do table.insert(charset, string.char(c)) end
	for c = 97, 122 do table.insert(charset, string.char(c)) end
end

local function randomString(length)
	if not length or length <= 0 then return '' end
	math.randomseed(os.clock()^5)
	return randomString(length - 1) .. charset[math.random(1, #charset)]
end

function onConnection(client,type,...)
	if type == "mobilestation" then
		
		msApp = client
		
		if data["info"] == nil then 
			data["info"] = {} 
			data["info"]["description"] = "Mobile Station server"
			
			local libType = package.cpath:match("%p[\\|/]?%p(%a+)")
			if libType == "dll" then
				data["info"]["os"] = "win"
				data["info"]["name"] = "MS-" .. os.getenv("USERNAME")
			elseif libType == "dylib" then
				data["info"]["name"] = "MS-" .. os.getenv("HOME")
				data["info"]["os"] = "mac"
			elseif libType == "so" then
				data["info"]["os"] = "linux"
				data["info"]["name"] = "MS-" .. os.getenv("HOME")
			end
		end

		if data["info"]["identifier"] == nil then
			data["info"]["identifier"] = randomString(6)
		end

		for i=0, #devices do devices[i]=nil end
		
		for id, cli in pairs(mona.clients) do
			cli.writer:writeInvocation("msStatus", "start")
		end
		
		function client:updateInfo(name, description)
			data["info"]["name"] = name
			data["info"]["description"] = description
			for id, cli in pairs(mona.clients) do
				cli.writer:writeInvocation("infoUpdated", name, description)
			end
		end
		
		function client:deviceRemoved(device)
			local idx = getDeviceIndex(device["id"])
			if idx ~= nil then 
				table.remove(devices, idx)
				sync = "removed"
			end
			return #devices
		end
		
		function client:pushDevice(device)
			local idx = getDeviceIndex(device["id"])
			if idx == nil then 
				devices[#devices+1] = device
			    sync = "added"
			end
			return #devices
		end
		
		function client:deviceLocked(device)
			local update = updateDevice(device["id"], device["locked"])
			if update then
			    sync = "updated"
			end
		end
		
		function client:close()
            close()
		end

		function client:terminate()
		    close()
			sync = "exit"
		end

		return {name=data["info"]["name"], description=data["info"]["description"], identifier=data["info"]["identifier"], configs=mona.configs}

	elseif type == "gesturecatcher" then

		function client:catchGesture(paths)
			for id, cli in pairs(mona.clients) do
				cli.writer:writeInvocation("catchGesture", paths)
			end
		end

	else
		if type == "editor" then
		
			function client:installApk(url, deviceId)
				msApp.writer:writeInvocation("installApk", url, deviceId)
			end
			
			return {devices=devices, name=data["info"]["name"], description=data["info"]["description"], httpPort=mona.configs.HTTP.port}
		else
			function client:initData()
				client.writer:writeInvocation("infoUpdated", data["info"]["name"], data["info"]["description"])
			end
			function client:devices()
				return devices
			end
			function client:device(id)
				return getDevice(id)
			end
		end
	end
end

function onManage()
	if sync ~= nil then
		if sync == "exit" then
			os.exit()
		else
			for id, cli in pairs(mona.clients) do
				cli.writer:writeInvocation("devices", devices, sync)
			end
			sync = nil
		end
    end
end

function onDisconnection(client)
end