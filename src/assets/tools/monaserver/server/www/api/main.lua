function onConnection(client)

	if client.protocol ~= "HTTP" then
		return nil
	end

	function client:devices(data)

		if data ~= nil and data["id"] ~= nil then
			return getDevice(data["id"])
		end

		return devices
	end

	function client:install(data)

		if data == nil or data["src"] == nil then
			return "Error : src parameter missing"
		end

		msApp.writer:writeInvocation("install", data["src"], data["deviceIds"])

		return nil
	end
end

function onDisconnection(client)
end