package httpServer
{
	import device.Device;
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.events.TimerEvent;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.text.ReturnKeyLabel;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import usb.AndroidUsb;
	import usb.AndroidUsbActions;
	import usb.UsbAction;
	
	public class HttpServer
	{		
		public var _serverSocket:ServerSocket;
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
		private var _actionQueue:Vector.<UsbAction> = new Vector.<UsbAction>();
		private var isStarted:Boolean;
		
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
		
		public function processStarted():void {
			this.isStarted = true;
		}

		public function listenActions(port:int, currentDevice:AndroidDevice, fixedPort:Boolean, errorCallback:Function):String
		{
			this._device = currentDevice;
			this._errorCallback = errorCallback;
			this.isStarted = false;
			_serverSocket = new ServerSocket();
			_serverSocket.addEventListener(Event.CONNECT, socketConnectHandler);
			initServerSocket(port, fixedPort, errorCallback);
			return _serverSocket != null ? _serverSocket.localPort.toString() : "";
		}
		
		public function initServerSocket(port:int, fixedPort:Boolean, errorCallback:Function):void {
			try {
				_serverSocket.bind(port);
				_serverSocket.listen();
				androidUsb = new AndroidUsbActions(_device);
			} catch (error:Error) {
				if(!fixedPort) {
					initServerSocket(port+1,fixedPort,errorCallback);
				} else {
					_serverSocket = null;	
					_fileController = null;
					errorCallback("Port "+ port +" is in use. Retrying...");
				}
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
		 * Handle new connections to the server.
		 */
		private function socketConnectRunningDevicesHandler(event:ServerSocketConnectEvent):void
		{
			var socket:Socket = event.socket;
			//socket.addEventListener(ProgressEvent.SOCKET_DATA, socketDataRunningDevicesHandler);
		}
		
		/**
		 * Handle data written to open connections. This is where the request is
		 * parsed and routed to a controller.
		 */
		private function socketDataHandler(event:ProgressEvent):void
		{
			try
			{
				if(!isStarted) {
					return;
				}
				_socket = event.target as Socket;
				var bytes:ByteArray = new ByteArray();
				
				// Do not read more than _maxRequestLength bytes
				var bytes_to_read:int = (_socket.bytesAvailable > _maxRequestLength) ? _maxRequestLength : _socket.bytesAvailable;
				
				// Get the request string and pull out the URL 
				var request:String          = _socket.readUTFBytes(_socket.bytesAvailable);
				var url:String              = request.substring(4, request.indexOf("HTTP/") - 1);
				url = url.replace("/","").replace(rex,'');
				var data:Array = new Array();
				data.push("dumpsys", "activity", AndroidProcess.ANDROIDDRIVER);
				
				// It must be a GET request
				if (request.substring(0, 4).toUpperCase() == 'POST') {			
					androidUsb.addEventListener(AndroidProcess.USBACTIONRESPONSE, usbActionResponseEnded, false, 0, true);
					androidUsb.addEventListener(AndroidProcess.USBACTIONERROR, usbActionErrorEnded, false, 0, true);
					androidUsb.addEventListener(AndroidProcess.USBSTARTRESPONSE, usbStartResponseEnded, false, 0, true);
					androidUsb.addEventListener(AndroidProcess.USBSTARTENDEDRESPONSE, usbStartEndedResponseEnded, false, 0, true);
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
					
					if(url == "driver" && data[4] == "start") {
						if(_device.usbMode) {
							data.push(AndroidDevice.UDPSERVER.toString().toLocaleLowerCase());
							AndroidDevice.UDPSERVER ? data.push(_device.udpIpAdresse) : data.push(_device.ip, _device.startScreenshotServer());
						}
					}
					
					if(url == "app" && data[4] == "start") {
						//pushing the start app command before
						var startData:Array = new Array();
						startData.push("dumpsys", "activity", AndroidProcess.ANDROIDDRIVER, "package", data[5]);
						_actionQueue.push(new UsbAction(startData));
					}
					
					if((url == "driver" || url == "app") && data[4] == "stop") {
						var stopData:Array = new Array();
						stopData.push("am", "force", "stop", AndroidProcess.ANDROIDDRIVER);
						_actionQueue.push(new UsbAction(stopData));
						//_device.stopScreenshotServer();
					}
					
					// sending request to the channel
					_actionQueue.push(new UsbAction(data));
					onActionQueueChanged();
				}
			}
			catch (error:Error)
			{
				if (_errorCallback != null) {
					_errorCallback(error, error.message);
				}
				else {
					//Alert.show(error.message, "Error");
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
		
		private function usbStartResponseEnded(ev:Event):void {
			var ActivityName:String = androidUsb.getResponse();
			androidUsb.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbStartResponseEnded);
			var startData:Array = new Array();
			startData.push("am", "start", "-W", "-S","--activity-brought-to-front", 
				"--activity-multiple-task", "--activity-no-animation", "--activity-no-history", "-n", ActivityName);
			_actionQueue.insertAt(0, new UsbAction(startData));
			onActionQueueChanged();
		}
		
		private function usbStartEndedResponseEnded(ev:Event):void {
			androidUsb.removeEventListener(AndroidProcess.USBACTIONRESPONSE, usbStartEndedResponseEnded);
			onActionQueueChanged();
		}
		
		private function onActionQueueChanged():void {
			var usbAction:UsbAction = _actionQueue.shift();
			androidUsb.start(usbAction);
		}
		
		private function usbActionErrorEnded(ev:Event):void {
			androidUsb.removeEventListener(AndroidProcess.USBACTIONERROR, usbActionErrorEnded);
			_device.dispatchEvent(new Event(Device.STOPPED_EVENT));
			androidUsb = null;
			_socket.flush();
			_socket.close();
		}
	}
}