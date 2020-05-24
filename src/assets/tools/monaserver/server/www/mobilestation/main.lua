editors = {}
devices = {}
dataInfo = {}

function getDeviceIndex(ip, port)
	for i, v in ipairs (devices) do 
		if (v.ip == ip and v.port == port) then
			return i 
		end
	end
	return nil
end

function updateDevice(ip, port, locked)
	for i, v in ipairs (devices) do 
		if (v.ip == ip and v.port == port) then
			v.locked = locked
			return true 
		end
	end
	return false
end

function onConnection(client,type,info,...)
	if type == "mobilestation" then
		dataInfo = info
		function client:deviceRemoved(device)
			local idx = getDeviceIndex(device["ip"], device["port"])
			if idx ~= nil then 
				table.remove(devices, idx)
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceRemoved", devices, device)
				end
			end
		end
		function client:pushDevice(device)
			local idx = getDeviceIndex(device["ip"], device["port"])
			if idx == nil then 
				table.insert(devices, device)
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceReady", devices)
				end
			end
		end
		function client:deviceLocked(device)
			local update = updateDevice(device["ip"], device["port"], device["lockedBy"])
			if update then 
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceLocked", device)
				end
			end
		end
	else
		editors[client] = client.writer
		if type == "editor" then
			client.writer:writeInvocation("setData", dataInfo, devices)
		else
			function client:getData()
				client.writer:writeInvocation("setData", dataInfo, devices)
			end
		end
	end
end

function onDisconnection(client)
  editors[client] = nil
end