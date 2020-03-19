package servers
{
	import flash.net.ServerSocket;
	
	public class PortManager
	{				
		public static function getAvailableLocalPort():int 
		{
			var server:ServerSocket = new ServerSocket();
			server.bind();
			var localPort:int = server.localPort;
			server.close();
			return localPort;
		}
	}
}