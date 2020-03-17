package webServer
{
	import com.worlize.websocket.WebSocket;
	import com.worlize.websocket.WebSocketErrorEvent;
	import com.worlize.websocket.WebSocketEvent;
	import com.worlize.websocket.WebSocketMessage;
	
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
	
	public class WebServer
	{	
		private var serverSocket:ServerSocket = new ServerSocket();
		private var clientSocket:Socket;
		private var clientData:ByteArray;
		private var webSocket:WebSocket;

		private var proxySocket:Socket = new Socket();

		private var devicePort:int;
			
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
			
			try {
				serverSocket.bind(port);
				
			} catch (e: Error) {
				setup(0);
				// TODO return error if automaticPort == false
			}

			serverSocket.addEventListener(ServerSocketConnectEvent.CONNECT, onConnect);
			
			serverSocket.listen();
			this.devicePort = getAvailablePort();
			
			webSocket = new WebSocket("ws://localhost:" + devicePort.toString(), "*");
			webSocket.addEventListener(WebSocketEvent.OPEN, webSocketOpenHandler);
			webSocket.addEventListener(WebSocketEvent.MESSAGE, webSocketOnMessageHandler);
			webSocket.addEventListener(WebSocketErrorEvent.CONNECTION_FAIL, webSocketConnectionFailHandler);
			webSocket.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
		}
			
		private function webSocketOnMessageHandler(event:WebSocketEvent):void
		{
			if (event.message.type === WebSocketMessage.TYPE_UTF8) {
			
			} 
			
			else if (event.message.type === WebSocketMessage.TYPE_BINARY) {
				var buffer:ByteArray = event.message.binaryData
				clientSocket.writeBytes(buffer, 0, buffer.length);
				clientSocket.flush();
			}
		}
		
		private function webSocketConnectionFailHandler(event:WebSocketErrorEvent):void 
		{
			trace("WebSocket ERROR : " + event.text);
		}
		
		private function webSocketOpenHandler(event:WebSocketEvent):void 
		{
			trace("Connected to websocket");
			webSocket.sendBytes(clientData);
		}
		
		// Une connexion entrante est arrivée sur le serveur
		private function onConnect(event:ServerSocketConnectEvent):void
		{
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
			if (webSocket.connected == true) {
				webSocket.sendBytes(clientData);
			} else {
				webSocket.connect();
			}
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
				
		private function onSocketClose(ev:Event):void {}
						
		private function closeHandler(event:Event):void {}
				
		private function ioErrorHandler(event:IOErrorEvent):void
		{
			trace("ioErrorHandler: " + event);
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