editors = {}
devices = {}
dataInfo = {}

function getDeviceIndex(tab, ip, port)
	for i, v in ipairs (tab) do 
		if (v.ip == ip and v.port == port) then
			return i 
		end
	end
	return nil
end

function onConnection(client,type,info,...)
	if type == "editor" then
		editors[client] = client.writer
		client.writer:writeInvocation("setInfo", dataInfo)
		client.writer:writeInvocation("setDevices", devices)
	else
		dataInfo = info
		function client:deviceRemoved(id, modelName, modelId, manufacturer, ip, port)
			local idx = getDeviceIndex(devices, ip, port)
			if idx ~= nil then 
				table.remove(devices, idx)
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceRemoved", id, modelName, modelId, manufacturer, ip, port, devices)
				end
			end
		end
		function client:pushDevice(device)
			local idx = getDeviceIndex(devices, device["ip"], device["port"])
			if idx == nil then 
				table.insert(devices, device)
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceReady", devices)
				end
			end
		end
		function client:deviceLocked(by, id, modelName, modelId, manufacturer, ip, port)
			local idx = getDeviceIndex(devices, ip, port)
			if idx ~= nil then 
				for editor,writer in pairs(editors) do
					writer:writeInvocation("deviceLocked", by, id, modelName, modelId, manufacturer, ip, port)
				end
			end
		end
	end
end
function onDisconnection(client)
  editors[client] = nil
end