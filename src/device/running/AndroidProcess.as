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
	
	public class AndroidProcess extends EventDispatcher
	{
		public static const ERROR_EVENT:String = "errorEvent";
		public static const WIFI_ERROR_EVENT:String = "wifiErrorEvent";
		public static const IP_ADDRESS:String = "ipAddress";
		public static const SCREENSHOTRESPONSE:String = "screenshotResponse";
		public static const USBACTIONRESPONSE:String = "usbResponse";
		public static const USBSTARTRESPONSE:String = "usbResponseStart";
		public static const USBACTIONERROR:String = "usbActionError";
		public static const USBSTARTENDEDRESPONSE:String = "usbResponseStartEnded"
		
		public static const DEVICE_INFO:String = "deviceInfo";
		
		public static const RUNNING:String = "running";
		public static const STOPPED:String = "stopped";
		
		public static const ANDROIDDRIVER:String = "com.ats.atsdroid";
		private const androidPropValueRegex:RegExp = /.*:.*\[(.*)\]/;
		
		private var port:String;
		private var id:String;
		private var atsdroidFilePath:String;
		private var usbMode:Boolean;
		
		private var output:String = "";
		
		public var ipAddress:String;
		public var deviceIp:String;
		public var error:String;
		public var deviceInfo:Device;
		
		private var process:NativeProcess;
		private var procInfo:NativeProcessStartupInfo
		public var processIp:NativeProcess;
		private static var _wmicFile:File = null;
		private var currentAdbFile:File;
		
		private var instrumentCommandLine:String;
		
		public function AndroidProcess(adbFile:File, atsdroid:String, id:String, port:String, usbMode:Boolean)
		{
			this.currentAdbFile = adbFile;
			this.id = id;
			this.port = port;
			this.atsdroidFilePath = atsdroid;
			this.deviceInfo = new Device(id);
			this.usbMode = usbMode;
			
			this.instrumentCommandLine = "am instrument -w -e ipAddress " + ipAddress + " -e atsPort " + port + " -e usbMode " + usbMode + " -e debug false -e class " + ANDROIDDRIVER + ".AtsRunner " + ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n";
			
			process = new NativeProcess();
			procInfo = new NativeProcessStartupInfo()
			
			procInfo.executable = currentAdbFile;
			procInfo.workingDirectory = currentAdbFile.parent;
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "ip", "route"];
		}
		
		public function start():void{
			process.start(procInfo);
		}
		
		public function terminate():Boolean{
			if(process != null && process.running){
				process.exit();
				return true;
			}
			return false;
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			error = new String(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onReadLanData(event:ProgressEvent):void{
			output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadLanExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			if(error != null){
				dispatchEvent(new Event(ERROR_EVENT));
			}else{
				var ipFounded:Boolean = false;
				var ipRouteDataUdp:Array = output.split("\r\r\n");
				for(var i:int=0;i<ipRouteDataUdp.length;i++) {
					if(ipRouteDataUdp[i].indexOf("dev") > -1 && ipRouteDataUdp[i].indexOf("wlan0") > -1) {
						var splittedString:Array = ipRouteDataUdp[i].split(/\s+/g);
						var idxUdp:int = splittedString.indexOf("src");
						if(idxUdp > -1){
							this.deviceIp = splittedString[idxUdp+1];
							this.ipAddress = splittedString[idxUdp+1];
							ipFounded = true;
							continue;
						}
					}
				}
				
				if(!ipFounded && !usbMode) {
					error = " - WIFI not connected !";
					writeIntoLogFile("WIFI note connected");
					dispatchEvent(new Event(WIFI_ERROR_EVENT));
					return;
				}
				
				if(usbMode) {
					getClientIPAddress();
				} else {
					dispatchEvent(new Event(IP_ADDRESS));
				}
				
				process = new NativeProcess();
				process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);
				procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", ANDROIDDRIVER];
				process.start(procInfo);
				return;
			}
		}
		
		private function getClientIPAddress ():void {
			processIp = new NativeProcess();
			var file:File;
			var processArgs:Vector.<String> = new Vector.<String>(); 
			if(!AtsMobileStation.isMacOs) {
				file = wmicFile;
				processArgs.push("nicconfig", "where", "(IPEnabled=TRUE and DHCPEnabled=TRUE)", "get", "IPAddress", "/format:list");
				processIp.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataWin);
			} else {
				file = new File("/usr/bin/env");
				processArgs.push("ipconfig","getifaddr","en1");
				processIp.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataMac);
			}
			
			var procInfoIp:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfoIp.executable = file;
			procInfoIp.workingDirectory = file.parent;
			procInfoIp.arguments = processArgs;
			processIp.start(procInfoIp);
		}
		
		public function onOutputDataWin(event:ProgressEvent):void
		{
			processIp.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataWin);
			var pattern:RegExp = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/;
			var output:String = processIp.standardOutput.readUTFBytes(processIp.standardOutput.bytesAvailable);
			var arrayAddresses:Array = output.match(pattern);
			if(arrayAddresses != null && arrayAddresses.length > 0) {
				this.ipAddress = arrayAddresses[0];
				writeIntoLogFile("getting ip Addresse from MS " + this.ipAddress);
				dispatchEvent(new Event(IP_ADDRESS));
			}
		}
		
		public function onOutputDataMac(event:ProgressEvent):void
		{
			processIp.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataMac);
			var rex:RegExp = /[\s\r\n]+/gim;
			this.ipAddress = processIp.standardOutput.readUTFBytes(processIp.standardOutput.bytesAvailable).replace(rex,"");
			dispatchEvent(new Event(IP_ADDRESS));
		}
		
		protected function onUninstallExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
			
			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
			procInfo.arguments = new <String>["-s", id, "install", "-r", atsdroidFilePath];
			
			process.start(procInfo);
		}
		
		private static function get wmicFile():File{
			if(_wmicFile == null){
				var rootPath:Array = File.getRootDirectories();
				for each(var file:File in rootPath){
					_wmicFile = file.resolvePath("Windows/System32/wbem/WMIC.exe");
					if(_wmicFile.exists){
						break;
					}else{
						_wmicFile = null;
					}
				}
			}
			return _wmicFile;
		}
		
		protected function onInstallExit(event:NativeProcessExitEvent):void{
			
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
			if(port != "") {
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
				
				process.standardInput.writeUTFBytes("am instrument -w -e ipAddress " + ipAddress + " -e atsPort " + port + " -e usbMode " + usbMode.toString() + " -e debug false -e class " + ANDROIDDRIVER + ".AtsRunner " + ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n");
				
			} else {
				process.exit(true);
				process = null;
				procInfo = null;
				
				if(error != null){
					dispatchEvent(new Event(ERROR_EVENT));
					AndroidProcess.writeIntoLogFile(error);
				}else{
					dispatchEvent(new Event(STOPPED));
				}
			}
		}
		
		private function getPropValue(value:String):String{
			return androidPropValueRegex.exec(value)[1];
		}
		
		protected function onExecuteError(event:ProgressEvent):void
		{
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			trace("err -> " + data);
			writeIntoLogFile(data);
			error = data;
		}
		
		public static function writeIntoLogFile(data:String):void {
			var file:File = File.userDirectory; 
			file = file.resolvePath(".agilitest/log/atsDroid_error.txt"); 
			var stream:FileStream = new FileStream();
			stream.open(file, FileMode.APPEND);
			stream.writeUTFBytes(data);
			stream.close();
		}
		
		protected function onExecuteData(event:ProgressEvent):void{
			var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			writeIntoLogFile(data);
			if(data.indexOf("Process crashed") > -1){
				process.standardInput.writeUTFBytes("am instrument -w -e ipAddress " + ipAddress + " -e atsPort " + port + " -e usbMode " + usbMode.toString() + " -e debug false -e class " + ANDROIDDRIVER + ".AtsRunner " + ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n");
			}else{
				
				if(data.indexOf("ATS_DRIVER_RUNNING") > -1){
					dispatchEvent(new Event(RUNNING));
				}else if(data.indexOf("ATS_DRIVER_START") > -1){
					trace("driver start -> " + data);
				}else if(data.indexOf("ATS_DRIVER_STOP") > -1){
					trace("driver stop");
				} else if(data.indexOf("ATS_WIFI_STOP") > -1) {
					dispatchEvent(new Event(WIFI_ERROR_EVENT));
				}
			}
			

		}
		
		public function screenshot():void{
			process.standardInput.writeUTFBytes("screenshot\r\n");
		}
		
		protected function onExecuteExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData);
			
			process.exit(true);
			process = null;
			procInfo = null;
			
			if(error != null){
				dispatchEvent(new Event(ERROR_EVENT));
			}else{
				dispatchEvent(new Event(STOPPED));
			}
		}
	}
}