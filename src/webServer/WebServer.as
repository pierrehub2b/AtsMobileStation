package webServer
{
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import events.AndroidUsbChannelEvent;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	
	// import usb.UsbAction;
	
	// import webServer.mimetype.MimeType;
	
	public class WebServer
	{	
		// private static const MAX_PACKET:int=1048576;
		private var serverSocket:ServerSocket = new ServerSocket();
		private var clientSocket:Socket;
		private var clientData:ByteArray;

		private var proxySocket:Socket;
		// private var proxyData:ByteArray;
		
		//private var returnData:ByteArray;
		// private var returnPos:int;
		
		// private var rex:RegExp = /[\s\r\n]+/gim;
		// private var currentDevice:AndroidDevice;
		private var errorCallback:Function = null;
		// private var socket:Socket;
		
		// private var port:int;
		private var devicePort:int;
		
		// private var ipAdress:String;
		
		// private var socketSender:Socket;
		// private var remoteRequest:String;
					
		/*public function WebServer(device:AndroidDevice)
		{			
			currentDevice = device
			// currentDevice.addEventListener(AndroidUsbChannelEvent.BAD_COMMAND_ERROR, usbActionResponseError, false, 0, true);
		}*/
				
		/* public function initServerSocket(port:int, automaticPort:Boolean, errorCallback:Function):String {
			try {
				server=new ServerSocket();
				server.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
				
				if (automaticPort) {
					server.bind();
				} else {
					server.bind(port);

				}
				server.listen();

				return server.localPort.toString();
			} catch (error:Error) {
				if(automaticPort) {
					return initServerSocket(port+1,automaticPort,errorCallback);
				} else {
					errorCallback("Port "+ port +" is in use. Retrying...");
					if(server.bound) {
						server.close();
					}
				}
			}
			return port.toString();
		} */
			
		public function getPort():int 
		{
			return serverSocket.localPort;
		}
		
		public function getDevicePort():int 
		{
			return this.devicePort;
		}
		
		public function close():void 
		{
			if (serverSocket.bound) {
				serverSocket.close();
			}
		}
		
		public function WebServer(port:int = 0):void
		{
			setup(port);
		}
		
		public function setup(port:int):void 
		{
			if (serverSocket.bound) {
				serverSocket.close();
				serverSocket = new ServerSocket();
			}
			
			serverSocket.bind(port);
			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
			serverSocket.listen();
			
			this.devicePort = getAvailablePort();			
		}
			
		// Une connexion entrante est arrivée sur le serveur
		private function onConnect(event:ServerSocketConnectEvent):void
		{
			trace("récupération socket");
			clientSocket = event.socket;

			clientSocket.addEventListener(ProgressEvent.SOCKET_DATA, onClientSocketData);
			clientSocket.addEventListener(Event.CLOSE, onSocketClose);
		}
		
		// 1. get from client
		private function onClientSocketData(event:ProgressEvent):void 
		{
			// read data
			clientData = new ByteArray();
			clientSocket.readBytes(clientData, 0, clientSocket.bytesAvailable);
			
			// forward data
			openSocketRemote();
		}
		
		// 2. back to client
		private function onProxySocketData(event:ProgressEvent):void 
		{
			// read data
			var buffer:ByteArray = new ByteArray();
			proxySocket.readBytes(buffer, 0, proxySocket.bytesAvailable);
			
			// return data
			clientSocket.writeBytes(buffer, 0, buffer.length);
			clientSocket.flush()
		}
				
		private function onSocketClose(ev:Event):void 
		{
			trace("socket fermée");
		}
		
		private function openSocketRemote():void 
		{
			proxySocket = new Socket();
			configureListeners(proxySocket);
			proxySocket.connect("localhost", devicePort);
		}		
				
		private function configureListeners(socket:Socket):void 
		{
			socket.addEventListener(Event.CLOSE, closeHandler);
			socket.addEventListener(Event.CONNECT, connectHandler);
			socket.addEventListener(ProgressEvent.SOCKET_DATA, onProxySocketData);
			socket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
		}
				
		private function closeHandler(event:Event):void
		{
			trace("closeHandler: " + event);
		}
		
		private function connectHandler(event:Event):void
		{
			proxySocket.writeBytes(clientData, 0, clientData.length);
			proxySocket.flush();
		}
		
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace("ioErrorHandler: " + event);
		}
		
		private function securityErrorHandler(event:SecurityErrorEvent):void
		{
			trace("securityErrorHandler: " + event);
		}
		
		// TO.DO Anthony: A refactorer
		private static function getAvailablePort():int 
		{
			var server:ServerSocket = new ServerSocket();
			server.bind();
			server.listen();
			var availablePort:int = server.localPort;
			server.close();
			return availablePort;
		}
	}
}