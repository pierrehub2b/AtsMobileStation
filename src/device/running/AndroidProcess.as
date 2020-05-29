package device.running
{
	import device.Device;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.globalization.DateTimeFormatter;
	
	import mx.core.FlexGlobals;
	
	public class AndroidProcess extends EventDispatcher
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public static const ERROR_EVENT:String = "errorEvent";
		public static const WIFI_ERROR_EVENT:String = "wifiErrorEvent";
		public static const IP_ADDRESS:String = "ipAddress";
		public static const SCREENSHOTRESPONSE:String = "screenshotResponse";
		public static const USBACTIONRESPONSE:String = "usbResponse";
		public static const USBSTARTRESPONSE:String = "usbResponseStart";
		public static const USBSTARTENDEDRESPONSE:String = "usbResponseStartEnded";
		public static const UNINSTALL_EXIT:String = "uninstallExit";
		public static const WAITING_FOR_DEVICE:String = "waitingForDevice";

		public static const WEBSOCKET_SERVER_START:String = "webSocketServerStart";
		public static const WEBSOCKET_SERVER_STOP:String = "webSocketServerStop";
		public static const WEBSOCKET_SERVER_ERROR:String = "webSocketServerError";

		public static const DEVICE_INFO:String = "deviceInfo";
		public static const DEVICE_LOCKED_STATUS:String = "deviceLockedStatus";

		public static const RUNNING:String = "running";
		public static const STOPPED:String = "stopped";
		
		public static const ANDROIDDRIVER:String = "com.ats.atsdroid";
		private const androidPropValueRegex:RegExp = /.*:.*\[(.*)\]/;

		private var udpPort:String;
		private var port:String;

		private var id:String;
		private var usbMode:Boolean;
		
		private var output:String = "";
		
		public var ipAddress:String;
		public var deviceIp:String;
		public var error:String;
		public var deviceInfo:Device;
		public var lockedBy:String;
		
		private var process:NativeProcess;
		private var procInfo:NativeProcessStartupInfo;
		private var currentAdbFile:File;
		
		private var logFile:File;
		private var logStream:FileStream = new FileStream();
		private var dateFormatter:DateTimeFormatter = new DateTimeFormatter("en-US");
		
		private var instrumentCommandLine:String;

		public var webSocketServerPort:int;
		public var webSocketServerError:String;
		
		public function AndroidProcess(adbFile:File, id:String, port:String, usbMode:Boolean)
		{
			this.currentAdbFile = adbFile;
			this.id = id;
			this.port = port;
			this.deviceInfo = new Device(id);
			this.usbMode = usbMode;

			//---------------------------------------------------------------------------------------

			dateFormatter.setDateTimePattern("yyyy-MM-dd hh:mm:ss");
			logFile = FlexGlobals.topLevelApplication.logsFolder.resolvePath("android_" + id + "_" + new Date().time + ".log");
			
			logStream.open(logFile, FileMode.WRITE);
			logStream.writeUTFBytes("Start Android process");
			logStream.close();
			
			//---------------------------------------------------------------------------------------

			// check if device booted
			// checkBootedDevice()

			process = new NativeProcess();
			procInfo = new NativeProcessStartupInfo();
			
			procInfo.executable = currentAdbFile;
			procInfo.workingDirectory = currentAdbFile.parent;

			if (usbMode) {
				process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);

				procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", ANDROIDDRIVER];
			} else {
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
				
				procInfo.arguments = new <String>["-s", id, "shell", "ip", "route"];
			}
		}

		// private var adbProcess: NativeProcess

		private function checkBootedDevice():void {
			var processInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processInfo.executable = File.applicationDirectory.resolvePath("assets/tools/android/adb.exe");
			processInfo.arguments = new <String>["-s", id, "shell", "getprop", "sys.boot_completed"];

			var adbProcess: NativeProcess = new NativeProcess()
			adbProcess.addEventListener(NativeProcessExitEvent.EXIT, onBootCompletedExit, false, 0, true);
			adbProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootCompletedError, false, 0, true);
			adbProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootCompletedOutput, false, 0, true);
			adbProcess.start(processInfo)
		}

		public function start():void{
			// process.start(procInfo);
			checkBootedDevice()
		}
		
		public function terminate():Boolean{
			if(process != null && process.running){
				process.exit(true);
				return true;
			}
			return false;
		}
		
		public function writeErrorLogFile(data:String):void {
			writeLogs("ERROR", data);
		}
		
		public function writeInfoLogFile(data:String):void {
			writeLogs("INFO", data);
		}
		
		private function writeLogs(type:String, data:String):void{
			data = data.replace("INSTRUMENTATION_STATUS: atsLogs=", "");
			data = data.replace("INSTRUMENTATION_STATUS_CODE: 0", "");
			data = data.replace(/[\u000d\u000a\u0008]+/g, "");
			if(data.length > 0){
				logStream.open(logFile, FileMode.APPEND);
				logStream.writeUTFBytes("[" + dateFormatter.format(new Date()) + "][" + type + "]" + data + "\n");
				logStream.close();
			}
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			error = String(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}

		protected function onReadLanData(event:ProgressEvent):void{
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadLanExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			if (error != null) {
				dispatchEvent(new Event(ERROR_EVENT));
			} else {
				var ipFounded:Boolean = false;
				var ipRouteDataUdp:Array = output.split("\r\r\n");
				for(var i:int=0;i<ipRouteDataUdp.length;i++) {
					if(ipRouteDataUdp[i].indexOf("dev") > -1 && ipRouteDataUdp[i].indexOf("wlan0") > -1) {
						var splittedString:Array = ipRouteDataUdp[i].split(/\s+/g);
						var idxUdp:int = splittedString.indexOf("src");
						if(idxUdp > -1 && (splittedString[idxUdp+1].toString().indexOf("192") == 0 || splittedString[idxUdp+1].toString().indexOf("10") == 0 || splittedString[idxUdp+1].toString().indexOf("172") == 0)){
							this.deviceIp = splittedString[idxUdp+1];
							this.ipAddress = splittedString[idxUdp+1];
							ipFounded = true;
						}
					}
				}
				
				if(!ipFounded) {
					error = " - WIFI not connected !";
					writeErrorLogFile("WIFI not connected");
					dispatchEvent(new Event(WIFI_ERROR_EVENT));
					return;
				} else {
					dispatchEvent(new Event(IP_ADDRESS));
				}

				process = new NativeProcess();
				process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);
				procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", ANDROIDDRIVER];
				process.start(procInfo);
			}
		}



		protected function onUninstallExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);

			if (this.usbMode) {
				dispatchEvent(new Event(UNINSTALL_EXIT));
			} else {
				startInstall();
			}
		}

		protected function startInstall():void
		{
			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
			procInfo.arguments = new <String>["-s", id, "install", "-r", atsdroidFilePath];
			process.start(procInfo);
		}

		protected function onInstallExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstallExit);
			
			output = "";
			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onGetPropExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "getprop"];
			process.start(procInfo);
		}
		
		protected function onReadPropertyData(event:ProgressEvent):void{
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable).replace(/\r/g, ""));
		}
		
		protected function onGetPropExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onGetPropExit);

			var propArray:Array = output.split("\n");
			for each (var line:String in propArray){
				if(line.indexOf("[ro.product.brand]") == 0){
					deviceInfo.manufacturer = getPropValue(line)
				}else if(line.indexOf("[ro.product.model]") == 0){
					deviceInfo.modelId = getPropValue(line)
				}else if(line.indexOf("[ro.semc.product.name]") == 0){
					deviceInfo.modelName = getPropValue(line)
				}else if(line.indexOf("[def.tctfw.brandMode.name]") == 0){
					deviceInfo.modelName = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.release]") == 0){
					deviceInfo.osVersion = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.sdk]") == 0){
					deviceInfo.sdkVersion = getPropValue(line)
				}
			}

			deviceInfo.checkName();
			dispatchEvent(new Event(DEVICE_INFO));
				
			process = new NativeProcess();
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
				
			procInfo.arguments = new <String>["-s", id, "shell"];
			process.start(procInfo);
				
			if (usbMode) {
				instrumentCommandLine = "am instrument -w -e ipAddress " + ipAddress + " -e atsPort " + port + " -e usbMode " + usbMode + " -e udpPort " + udpPort + " -e debug false -e class " + ANDROIDDRIVER + ".AtsRunnerUsb " + ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n";
			} else {
				instrumentCommandLine = "am instrument -w -e ipAddress " + ipAddress + " -e atsPort " + port + " -e usbMode " + usbMode + " -e debug false -e class " + ANDROIDDRIVER + ".AtsRunnerWifi " + ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n";
			}

			process.standardInput.writeUTFBytes(instrumentCommandLine);
		}

		public function executeUsb(ipAddress:String, port:int, udpPort:int):void
		{
			this.ipAddress = ipAddress;
			this.port = port.toString();
			this.udpPort = udpPort.toString();

			startInstall();
		}
		
		private function getPropValue(value:String):String
		{
			return androidPropValueRegex.exec(value)[1];
		}
		
		protected function onExecuteError(event:ProgressEvent):void
		{
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			trace("err -> " + data);
			writeErrorLogFile(data);
			error = data;
		}
				
		protected function onExecuteData(event:ProgressEvent):void{
			var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);

			if(data.indexOf("Process crashed") > -1){
				writeErrorLogFile(data);
				process.standardInput.writeUTFBytes(instrumentCommandLine);
			} else {
				writeInfoLogFile(data);
				if(data.indexOf("ATS_DRIVER_RUNNING") > -1){
					dispatchEvent(new Event(RUNNING));
				} else if(data.indexOf("ATS_DRIVER_START") > -1){
					trace("driver start -> " + data);
				} else if(data.indexOf("ATS_DRIVER_STOP") > -1){
					trace("driver stop");
				} else if(data.indexOf("ATS_WIFI_STOP") > -1) {
					dispatchEvent(new Event(WIFI_ERROR_EVENT));
				} else if(data.indexOf("ATS_DRIVER_LOCKED_BY:") > -1) {
					lockedBy = getDeviceOwner(data)
					dispatchEvent(new Event(DEVICE_LOCKED_STATUS))
				} else if(data.indexOf("ATS_DRIVER_UNLOCKED") > -1) {
					lockedBy = null;
					dispatchEvent(new Event(DEVICE_LOCKED_STATUS))
				} else if(data.indexOf("ATS_WEB_SOCKET_SERVER_START:") > -1) {
					webSocketServerPort = getWebSocketServerPort(data);
					dispatchEvent(new Event(WEBSOCKET_SERVER_START));
				} else if(data.indexOf("ATS_WEB_SOCKET_SERVER_ERROR") > -1) {
					webSocketServerError = getWebSocketServerError(data);
					dispatchEvent(new Event(WEBSOCKET_SERVER_ERROR));
				} else if(data.indexOf("ATS_WEB_SOCKET_SERVER_STOP") > -1) {
					dispatchEvent(new Event(WEBSOCKET_SERVER_STOP));
				}
			}
		}

		private function getDeviceOwner(data:String):String {
			var array:Array = data.split("\n");
			for each(var line:String in array) {
				if (line.indexOf("ATS_DRIVER_LOCKED_BY") > -1) {
					var firstIndex:int = line.length;
					var lastIndex:int = line.lastIndexOf("ATS_DRIVER_LOCKED_BY:") + "ATS_DRIVER_LOCKED_BY:".length;
					return line.substring(lastIndex, firstIndex).slice(0, -1);
				}
			}

			return null;
		}

		private function getWebSocketServerError(data:String):String
		{
			var array:Array = data.split("\n");
			for each(var line:String in array) {
				if (line.indexOf("ATS_WEB_SOCKET_SERVER_ERROR") > -1) {
					var firstIndex:int = line.length;
					var lastIndex:int = line.lastIndexOf("ATS_WEB_SOCKET_SERVER_ERROR:") + "ATS_WEB_SOCKET_SERVER_ERROR:".length;
					return line.substring(lastIndex, firstIndex);
				}
			}

			return "";
		}

		private function getWebSocketServerPort(data:String):int
		{
			var array:Array = data.split("\n");
			for each(var line:String in array) {
				if (line.indexOf("ATS_WEB_SOCKET_SERVER_START") > -1) {
					var parameters:Array = line.split("=");
					var subparameters:Array = (parameters[1] as String).split(":");
					return parseInt(subparameters[1]);
				}
			}

			return -1;
		}
		
		public function screenshot():void
		{
			process.standardInput.writeUTFBytes("screenshot\r\n");
		}
		
		protected function onExecuteExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData);
			
			process.exit(true);
			process = null;
			procInfo = null;
			currentAdbFile = null;
			
			if (error != null) {
				dispatchEvent(new Event(ERROR_EVENT));
			} else {
				dispatchEvent(new Event(STOPPED));
			}
		}

		private var bootCompletedError: String
		private var bootCompletedOutput: String = ""

		private function onBootCompletedExit(event:NativeProcessExitEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootCompletedOutput)
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootCompletedError)
			process.removeEventListener(NativeProcessExitEvent.EXIT, onBootCompletedExit)

			if (bootCompletedError) {
				trace("BOOT CHECK ERROR - " + id + " : " + bootCompletedError)
				dispatchEvent(new Event(ERROR_EVENT));
				return
			}

			if (bootCompletedOutput.charAt(0) == "1") {
				trace(id + " booted")
				this.process.start(procInfo)
			} else {
				dispatchEvent(new Event(ERROR_EVENT));
			}
		}

		private function onBootCompletedError(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			bootCompletedError = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
		}

		private function onBootCompletedOutput(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			bootCompletedOutput = bootCompletedOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable).replace(/\r/g, ""));
		}
	}
}