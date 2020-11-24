function onConnection(client)

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

	for i = 0, #devices do devices[i] = nil end

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

	function client:updateDeviceStatus(device)
		local update = updateDevice(device["id"], device["status"])
		if update then
			sync = "updated"
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
			devices[#devices + 1] = device
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

	return { name = data["info"]["name"], description = data["info"]["description"], identifier = data["info"]["identifier"], configs = mona.configs }

end