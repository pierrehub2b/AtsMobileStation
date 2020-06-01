local devices = {}
local sync = nil

function getDeviceIndex(id)
	for i, v in ipairs (devices) do 
		if (v.id == id) then
			return i 
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

function onConnection(client,type,...)
	if type == "mobilestation" then
		
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

		count = #devices
		for i=0, count do devices[i]=nil end
		
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
		    os.exit()
		end

		return {name=data["info"]["name"], description=data["info"]["description"], configs=mona.configs}
	else
		if type == "editor" then
			return {devices=devices, name=data["info"]["name"], description=data["info"]["description"], httpPort=mona.configs.HTTP.port}
		else
			function client:initData()
				client.writer:writeInvocation("infoUpdated", data["info"]["name"], data["info"]["description"])
				for i, device in pairs(devices) do
					client.writer:writeInvocation("deviceConnected", device)
				end
			end
		end
	end
end

function onManage()
	if sync ~= nil then
		for id, cli in pairs(mona.clients) do
			cli.writer:writeInvocation("devices", devices, sync)
		end
		sync = nil
    end
end

function onDisconnection(client)
end