function onConnection(client)

	function client:devices()
		return devices
	end

	function client:device(id)
		return getDevice(id)
	end

	function client:install(src, deviceIds)

		if not src then
			error("src parameter missing")
		end

		msApp.writer:writeInvocation("install", src, deviceIds)

		return nil
	end

	return nil

end