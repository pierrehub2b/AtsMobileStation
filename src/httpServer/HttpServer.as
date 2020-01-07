package httpServer
{
	import device.running.AndroidDevice;
	import device.running.AndroidProcess;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.ServerSocketConnectEvent;
	import flash.filesystem.File;
	import flash.net.ServerSocket;
	import flash.net.Socket;
	import flash.net.URLVariables;
	import flash.utils.ByteArray;
	
	import mx.controls.Alert;
	
	/**
	 * HttpServer is a simple HTTP server capable of responding to GET requests
	 * for Controllers that have been registered with it and files that can
	 * be found relative to webroot under an AIR application's applicationStorage
	 * directory. This server only binds to a port on localhost and is meant as
	 * a way to provide access to services within/for a local process.
	 * <p>
	 * After construction, instances of controllers may be added to respond to
	 * various HTTP GET requests. @see com.minihttp.HttpController for more on this.
	 * </p>
	 * <p>
	 * If a matching controller to a request is found, the action (defaulting to
	 * index) specified is called along with any provided parameters.
	 * </p>
	 * </p>
	 * If no matching controller is found, the server attempts to use its FileController
	 * to load the specified file (@see com.minihttp.FileController).
	 * <p>
	 * <p>
	 * The following is a simple example showing how to initialize and start a server
	 * instance. This example will respond to the urls <code>http://localhost/app/config</code>
	 * and <code>http://localhost/app/status</code>.
	 * </p>
	 * <code>
	 * ...
	 *   var webserv:HttpServer = new HttpServer();
	 * 
	 *   webserv.registerController(new Appcontroller(myApplication));
	 *   webserv.listen(4567);
	 * ...
	 * </code>
	 * 
	 */
	public class HttpServer
	{
		private const adbPath:String = "assets/tools/android/adb.exe";
		private const androidDriverFullName:String = "com.ats.atsdroid";
		
		private var _serverSocket:ServerSocket;
		private var _mimeTypes:Object = new Object();
		private var _controllers:Object = new Object();
		private var _fileController:FileController;
		private var _errorCallback:Function = null;
		private var _isConnected:Boolean = false;
		private var _maxRequestLength:int = 2048;
		private var _process:AndroidProcess;
		private var androidOutput:String;
		private var adbFile:File;
		private var proc:NativeProcess;
		private var procInfo:NativeProcessStartupInfo;
		private var socket:Socket;
		private var _deviceId:String;
		
		public function HttpServer()
		{
			_fileController = new FileController();  
		}
		
		/**
		 * Retrieve the document root from the server.
		 */
		public function get docRoot():String
		{
			return _fileController.docRoot;
		}
		
		public function get isConnected():Boolean
		{
			return _isConnected;
		}
		
		/**
		 * Get the maximum lenght of a request in bytes.
		 * Requests longer than this will be truncated.
		 */
		public function get maxRequestLength():int
		{
			return _maxRequestLength;
		}
		
		private function launchAdbProcess():void{
			
			androidOutput = new String();
			
			proc = new NativeProcess();
			procInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = File.userDirectory;
			procInfo.arguments = new <String>[];
			
			proc.addEventListener(NativeProcessExitEvent.EXIT, onSendAndroidDevicesActionExit, false, 0, true);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onSendAndroidDevicesAction, false, 0, true);
		}
		
		protected function onSendAndroidDevicesAction(ev:ProgressEvent):void{
			androidOutput = androidOutput.concat(proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable));
			//androidOutput = proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		protected function onSendAndroidDevicesActionExit(ev:NativeProcessExitEvent):void
		{
			proc = ev.currentTarget as NativeProcess;
			var output:Array = androidOutput.split("\r\r\n");
			var response:String = output[output.length-1];
			if(response != "") {
				socket.writeUTFBytes(ActionController.responseJSON(response))
			}
			socket.flush();
			socket.close();
		}
		
		/**
		 * Set the maximum lenght of a request in bytes.
		 * Requests longer than this will be truncated.
		 */
		public function set maxRequestLength(value:int):void
		{
			_maxRequestLength = value;
		}
		
		/**
		 * Begin listening on a specified port.
		 * 
		 * @param port The localhost port to begin listening on.
		 * @param errorCallback The callback to call when an error occurs. If this
		 * is null, an Alert box is displayed.
		 * 
		 * @return true if the port was opened, false if it could not be opened.
		 */
		public function listen(port:int, deviceId:String, errorCallback:Function = null):String
		{
			this._errorCallback = errorCallback;
			_serverSocket = new ServerSocket();
			_serverSocket.addEventListener(Event.CONNECT, socketConnectHandler);
			initServerSocket(port, errorCallback);
			
			_deviceId = deviceId;
			adbFile = File.applicationDirectory.resolvePath(adbPath);
			launchAdbProcess();
			
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
				socket = event.target as Socket;
				var bytes:ByteArray = new ByteArray();
				
				// Do not read more than _maxRequestLength bytes
				var bytes_to_read:int = (socket.bytesAvailable > _maxRequestLength) ? _maxRequestLength : socket.bytesAvailable;
				
				// Get the request string and pull out the URL 
				var request:String          = socket.readUTFBytes(socket.bytesAvailable);
				var url:String              = request.substring(4, request.indexOf("HTTP/") - 1);
				
				// It must be a GET request
				if (request.substring(0, 4).toUpperCase() == 'POST') {
					//retrieving the dbody data
					var requestData:Array = request.split("\n");
					var data:Array = new Array();
					var isData:Boolean = false;
					procInfo.arguments = new <String>["-s", _deviceId, "shell", "dumpsys", "activity", androidDriverFullName, url.replace("/","")];
					for(var i:int=0;i<requestData.length;i++){
						if(isData) {
							data.push(requestData[i]);
							procInfo.arguments.push(requestData[i]);
						}
						if(requestData[i] == "\r") {
							isData = true;
						}
					}
					
					// sending request to the device
					androidOutput = "";
					proc.start(procInfo);	
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
	}
}