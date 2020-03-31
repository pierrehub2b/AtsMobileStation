package helpers
{
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.net.ServerSocket;
	
	public class PortSwitcher extends EventDispatcher
	{
		public static const PORT_NOT_AVAILABLE_EVENT:String = "portNotAvailableEvent";

		private var portSettings:DevicePortSettingsHelper = DevicePortSettingsHelper.shared;

		// public static function getAvailablePort():int
		public function getLocalPort(deviceId:String, automatic:Boolean):int
		{
			var port:int = portSettings.getPortOfDevice(deviceId)

			// unknown device
			if (port == -1) {
				var newPort:int = generateAvailablePort();
				var porta:DevicePortSettings = new DevicePortSettings(deviceId, newPort);
				portSettings.addSettings(porta);
				return newPort;
			} else {
				var portIsAvailable:Boolean = checkPortAvailability(port)
				if (portIsAvailable == false) {
					if (automatic == true) {
						var newPortb:int = generateAvailablePort();
						var portb:DevicePortSettings = new DevicePortSettings(deviceId, newPortb);
						portSettings.addSettings(portb);
						return newPortb;
					} else {
						dispatchEvent(new Event(PORT_NOT_AVAILABLE_EVENT));
						return port;
					}
				} else {
					return port;
				}
			}
		}

		private function generateAvailablePort():int {
			var nextPortAvailable:int = portSettings.nextPortAvailable();
			while (checkSocketPortAvailability(nextPortAvailable) == false) {
				nextPortAvailable = portSettings.nextPortAvailable(nextPortAvailable);
			}

			return nextPortAvailable;
		}

		public function checkPortAvailability(port:int):Boolean {
			if (portSettings.portIsAvailable(port) == false) {
				return false
			} else {
				return checkSocketPortAvailability(port)
			}
		}

		public function checkSocketPortAvailability(port:int):Boolean {
			try {
				var server:ServerSocket = new ServerSocket();
				server.bind(port, "127.0.0.1");
				var localPort:int = server.localPort;
				server.close();
				return localPort != 0;
			} catch (e:Error) {
				return false;
			}

			return false;
		}

		public static function getAvailableLocalPort():int {
			var server:ServerSocket = new ServerSocket();
			server.bind(0, "127.0.0.1");
			var localPort:int = server.localPort;
			server.close();
			return localPort;
		}
	}
}