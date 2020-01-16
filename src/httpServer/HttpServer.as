package httpServer
{
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	import device.running.AndroidUsb;
	import device.running.AndroidUsbActions;
	import device.running.AndroidUsbCaptureScreen;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.*;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.filesystem.File;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	import flash.utils.flash_proxy;
	
	import mx.controls.Alert;
	
	public class HttpServer
	{		
		private var _serverSocket:ServerSocket;
		private var _mimeTypes:Object = new Object();
		private var _controllers:Object = new Object();
		private var _fileController:FileController;
		private var _errorCallback:Function = null;
		private var _isConnected:Boolean = false;
		private var _maxRequestLength:int = 2048;
		private var _socket:Socket;
		private var androidUsb:AndroidUsb;
		private var rex:RegExp = /[\s\r\n]+/gim;
		private var _device:AndroidDevice;
		
		public function HttpServer()
		{
			_fileController = new FileController();  
		}
		
		public function get docRoot():String
		{
			return _fileController.docRoot;
		}
		
		public function get isConnected():Boolean
		{
			return _isConnected;
		}
		
		public function closeServer():void {
			this.androidUsb = null;
			this._serverSocket.close();
		}
		
		public function get maxRequestLength():int
		{
			return _maxRequestLength;
		}
		
		public function set maxRequestLength(value:int):void
		{
			_maxRequestLength = value;
		}
		
		public function listen(port:int, currentDevice:AndroidDevice, type:String, errorCallback:Function = null):String
		{
			this._device = currentDevice;
			this._errorCallback = errorCallback;
			_serverSocket = new ServerSocket();
			_serverSocket.addEventListener(Event.CONNECT, socketConnectHandler);
			initServerSocket(port, errorCallback);
			androidUsb = new AndroidUsbActions(_device.id);
			return _serverSocket.localPort.toString();
		}
		
		public function initServerSocket(port:int, errorCallback:Function = null):void {
			try {
				_serverSocket.bind(port);
				_serverSocket.listen();
			} catch (error:Error)
			{
				var message:String = "Port " + port.toString() +
					" may be in use. Enter another port number and try again.\n(" +
					error.message +")";
				if (errorCallback != null) {
					errorCallback(error, message);
				}
				initServerSocket(port+1,errorCallback);
			}
		}
		
		/**
		 * Add a Controller to the Server
		 */
		public function registerController(controller:ActionController):HttpServer
		{
			_controllers[controller.route] = controller;
			return this;  
		}
		
		/**
		 * Handle new connections to the server.
		 */
		private function socketConnectHandler(event:ServerSocketConnectEvent):void
		{
			var socket:Socket = event.socket;
			socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataHandler);
		}
		
		/**
		 * Handle data written to open connections. This is where the request is
		 * parsed and routed to a controller.
		 */
		private function socketDataHandler(event:ProgressEvent):void
		{
			try
			{
				_socket = event.target as Socket;
				var bytes:ByteArray = new ByteArray();
				
				// Do not read more than _maxRequestLength bytes
				var bytes_to_read:int = (_socket.bytesAvailable > _maxRequestLength) ? _maxRequestLength : _socket.bytesAvailable;
				
				// Get the request string and pull out the URL 
				var request:String          = _socket.readUTFBytes(_socket.bytesAvailable);
				var url:String              = request.substring(4, request.indexOf("HTTP/") - 1);
				url = url.replace("/","").replace(rex,'');
				var data:Array = new Array();
				// It must be a GET request
				if (request.substring(0, 4).toUpperCase() == 'POST') {
					androidUsb.addEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionResponseEnded, false, 0, true);
					var requestData:Array = request.split("\n");
					
					data.push(url);
					if(url == "screenshot") {
						data.push("screenshot", "hires");
					}
					var isData:Boolean = false;
					for(var i:int=0;i<requestData.length;i++){
						if(isData) {
							data.push(requestData[i]);
						}
						if(requestData[i] == "\r") {
							isData = true;
						}
					}
					
					if(url == "driver" && data[1] == "start") {
						data.push(AndroidDevice.UDPSERVER.toString().toLocaleLowerCase());
						AndroidDevice.UDPSERVER ? data.push(_device.udpIpAdresse) : data.push(_device.startScreenshotServer());
					}
					
					if(url == "driver" && data[1] == "stop") {
						_device.stopScreenshotServer();
					}
					
					// sending request to the device
					androidUsb.start(data);
				}
			}
			catch (error:Error)
			{
				if (_errorCallback != null) {
					_errorCallback(error, error.message);
				}
				else {
					Alert.show(error.message, "Error");
				}
			}
		}
		
		private function usbActionResponseEnded(ev:Event):void {
			if(androidUsb.getResponse() != "") {
				_socket.writeUTFBytes(ActionController.responseJSON(androidUsb.getResponse()));
			}
			androidUsb.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionResponseEnded);
			_socket.flush();
			_socket.close();
		}
	}
}