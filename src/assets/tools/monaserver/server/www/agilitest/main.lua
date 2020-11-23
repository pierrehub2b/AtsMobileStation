function onConnection(client)

	if client.protocol ~= "HTTP" then
		error("Protocol not supported")
	end

	function client:devices(data)

		if data ~= nil and data["id"] ~= nil then
			return mona:toJSON(getDevice(data["id"]))
		end

		return mona:toJSON(devices)
	end

	function client:install(data)

		if data == nil or data["src"] == nil then
			error("Error : src parameter missing")
		end

		msApp.writer:writeInvocation("install", data["src"], data["deviceIds"])

		return ok
	end
end