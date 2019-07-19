package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	public class Device extends EventDispatcher
	{
		private static const mobileTempFolder:String = "/data/local/tmp/atsdroid";
		private static const driverFullName:String = "com.ats.atsdroid";
		
		private static const propValueRegex:RegExp = /.*:.*\[(.*)\]/;
		
		private static const apkFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public static const INSTALL:String = "install";
		public static const START:String = "start";
		public static const READY:String = "ready";
		public static const FAIL:String = "fail";
		
		[Bindable]
		public var ip:String;
		
		[Bindable]
		public var status:String = START;
		
		[Bindable]
		public var error:String = null;
		
		[Bindable]
		public var id:String;
		
		[Bindable]
		public var manufacturer:String = "";
		
		[Bindable]
		public var modelId:String = "";
		
		[Bindable]
		public var modelName:String = "";
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";
		
		[Bindable]
		public var tooltip:String = "Start driver";
		
		public var product:String;
		public var type:String;
		
		[Bindable]
		public var port:String = "8080";
		
		public var connected:Boolean;
		
		private var output:String = "";
		
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
		
		private var adbFile:File = File.applicationDirectory.resolvePath("assets/tools/android/adb.exe");
		
		public function Device(port:String, id:String, type:String, product:String)
		{
			this.port = port;
			this.connected = true;
			this.id = id;
			this.type = type;
			this.product = product;
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
			
			//procInfo.arguments = new <String>["-s", id, "shell", "ip", "addr", "show", "wlan0"];
			procInfo.arguments = new <String>["-s", id, "shell", "ip", "route"];
			
			process.start(procInfo);
		}
		
		public function dispose():Boolean{
			if(process.running){
				process.exit(true);
				return true;
			}
			return false;
		}
		
		public function close():void{
			if(!dispose()){
				connected = false;
				dispatchEvent(new Event("deviceStopped"));
			}
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			error = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
		}
		
		protected function onReadLanData(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
		}
		
		protected function onReadLanExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);
			
			var ipRouteData:Array = output.split(/\s+/g);
			
			var idx:int = ipRouteData.indexOf("dev");
			if(idx > -1 && ipRouteData[idx+1] == "wlan0"){
				idx = ipRouteData.indexOf("src");
				if(idx > -1){
					ip = ipRouteData[idx+1];
					status = INSTALL
					tooltip = "Installing driver to the device ..."
					
					process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);
					procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", driverFullName];
					process.start(procInfo);

					return;
				}
			}
			
			status = FAIL
			tooltip = "Unable to get a local ip address for this device\nplease change it's network configuration and restart the driver";
			
			/*var dataLan:Array = output.split(/.* inet\s*(.*)\//g);
			if(dataLan != null && dataLan.length > 1){
			ip = dataLan[1];
			}
			
			if(ip == null){
			status = FAIL
			tooltip = "Unable to get a local ip address for this device\nplease disconnect the device, change it's network configuration and reconnect the device";
			}else{
			
			status = INSTALL
			tooltip = "Installing driver to the device ..."
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
			procInfo.arguments = new <String>["-s", id, "install", "-r", apkFilePath];
			
			//process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit, false, 0, true);
			//procInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", driverFullName];
			process.start(procInfo);
			}*/
		}
		
		protected function onUninstallExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
			
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
			procInfo.arguments = new <String>["-s", id, "install", "-r", apkFilePath];
			
			process.start(procInfo);
		}
		
		/*protected function onUninstallExit(event:NativeProcessExitEvent):void{
		process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
		
		status = INSTALL
		
		var apkFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		process.addEventListener(NativeProcessExitEvent.EXIT, onPushExit, false, 0, true);
		procInfo.arguments = new <String>["-s", id, "push", apkFilePath, mobileTempFolder];
		process.start(procInfo);
		}
		
		protected function onPushExit(event:NativeProcessExitEvent):void{
		process.removeEventListener(NativeProcessExitEvent.EXIT, onPushExit);
		
		process.addEventListener(NativeProcessExitEvent.EXIT, onInstallExit, false, 0, true);
		procInfo.arguments = new <String>["-s", id, "shell", "pm", "install", "-t", "-r", mobileTempFolder];
		process.start(procInfo);
		}*/
		
		protected function onInstallExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(NativeProcessExitEvent.EXIT, onInstallExit);
			
			output = "";
			process.addEventListener(NativeProcessExitEvent.EXIT, onGetPropExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "getprop"];
			process.start(procInfo);
		}
		
		protected function onReadPropertyData(event:ProgressEvent):void{
			output += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
		}
		
		protected function onGetPropExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadPropertyData);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onGetPropExit);
			
			
			var propArray:Array = output.split("\r\n");
			for each (var line:String in propArray){
				if(line.indexOf("[ro.product.brand]") == 0){
					manufacturer = getPropValue(line)
				}else if(line.indexOf("[ro.product.model]") == 0){
					modelId = getPropValue(line)
				}else if(line.indexOf("[ro.semc.product.name]") == 0){
					modelName = getPropValue(line)
				}else if(line.indexOf("[def.tctfw.brandMode.name]") == 0){
					modelName = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.release]") == 0){
					androidVersion = getPropValue(line)
				}else if(line.indexOf("[ro.build.version.sdk]") == 0){
					androidSdk = getPropValue(line)
				}
			}
			
			if(modelName == ""){
				modelName = modelId;
			}
				
			tooltip = "Driver installed, launch the test process ..."
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData, false, 0, true);
			
			procInfo.arguments = new <String>["-s", id, "shell", "am", "instrument", "-w", "-r", "-e", "atsPort", port, "-e", "debug", "false", "-e", "class", driverFullName + ".AtsRunner", driverFullName + "/android.support.test.runner.AndroidJUnitRunner"];
			process.start(procInfo);
		}
		
		private function getPropValue(value:String):String{
			return propValueRegex.exec(value)[1];
		}
		
		protected function onExecuteError(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData);
			
			status = FAIL
			connected = false;
			dispatchEvent(new Event("deviceStopped"));
			
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onExecuteData(event:ProgressEvent):void{
			var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			trace("last command -> " + data);
			status = READY
			tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions"
		}
		
		protected function onExecuteExit(event:NativeProcessExitEvent):void{
			
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteData);
			
			status = FAIL
			connected = false;
			dispatchEvent(new Event("deviceStopped"));
		}
	}
}