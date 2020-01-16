package device.running
{
	import device.Device;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.InterfaceAddress;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	public class AndroidProcess extends EventDispatcher
	{
		public static const ERROR_EVENT:String = "errorEvent";
		public static const IP_ADDRESS:String = "ipAddress";
		
		public static const USBACTIONRESPONSE:String = "usbResponse";
		public static const USBSCREENSHOTRESPONSE:String = "usbScreenshot";
		public static const USBSCREENSHOTSTARTED:String = "usbScreenshotStarted";
		
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
		
		public function AndroidProcess(adbFile:File, atsdroid:String, id:String, port:String, usbMode:Boolean)
		{
			this.currentAdbFile = adbFile;
			this.id = id;
			this.port = port;
			this.atsdroidFilePath = atsdroid;
			this.deviceInfo = new Device(id);
			this.usbMode = usbMode;
			
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
				//get device ip @
				var ipRouteDataUdp:Array = output.split(/\s+/g);
				var idxUdp:int = ipRouteDataUdp.indexOf("dev");
				if(idxUdp > -1 && ipRouteDataUdp[idxUdp+1] == "wlan0"){
					idxUdp = ipRouteDataUdp.indexOf("src");
					if(idxUdp > -1){
						this.deviceIp = ipRouteDataUdp[idxUdp+1];
						this.ipAddress = ipRouteDataUdp[idxUdp+1];
					}
				} else if(!usbMode) {
					error = " - WIFI not connected !";
					dispatchEvent(new Event(ERROR_EVENT));
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
		
		private var outputIpAdresse:String = "";
		private function getClientIPAddress ():void {
			var file:File;
			var processArgs:Vector.<String> = new Vector.<String>(); 
			if(!AtsMobileStation.isMacOs) {
				file = wmicFile;
				processArgs.push("nicconfig", "where", "(IPEnabled=TRUE and DHCPEnabled=TRUE)", "get", "IPAddress", "/format:list");
			} else {
				file = new File("/usr/bin/env");
				processArgs.push("ipconfig","getpacket","en0");
			}
			
			outputIpAdresse = "";
			processIp = new NativeProcess();
			var procInfoIp:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfoIp.executable = file;
			procInfoIp.workingDirectory = file.parent;
			procInfoIp.arguments = processArgs;
			processIp.start(procInfoIp);
			
			processIp.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
			processIp.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
			processIp.addEventListener(NativeProcessExitEvent.EXIT, onExit);
		}
		
		public function onOutputData(event:ProgressEvent):void
		{
			var pattern:RegExp = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/;
			var arrayAddresses:Array = processIp.standardOutput.readUTFBytes(processIp.standardOutput.bytesAvailable).match(pattern);
			if(arrayAddresses.length > 0) {
				this.ipAddress = outputIpAdresse[0];
				dispatchEvent(new Event(IP_ADDRESS));
			}
		}
		
		public function onErrorData(event:ProgressEvent):void
		{
			trace("ERROR -", processIp.standardError.readUTFBytes(processIp.standardError.bytesAvailable)); 
		}
		
		public function onExit(event:NativeProcessExitEvent):void
		{
			trace("Process exited with ", event.exitCode);
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
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "am", "instrument", "-w", "-r", "-e", "atsPort", port, "-e", "debug", "false", "-e", "class", ANDROIDDRIVER + ".AtsRunner", ANDROIDDRIVER + "/android.support.test.runner.AndroidJUnitRunner"];
			process.start(procInfo);
		}
		
		private function getPropValue(value:String):String{
			return androidPropValueRegex.exec(value)[1];
		}
		
		protected function onExecuteError(event:ProgressEvent):void
		{
			error = new String(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onExecuteData(event:ProgressEvent):void{
			//var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			//trace(data);
			dispatchEvent(new Event(RUNNING));
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