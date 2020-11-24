function onConnection(client)

	agilitestEditor = client

	return { devices = devices, name = data["info"]["name"], description = data["info"]["description"], httpPort = mona.configs.HTTP.port }

end