package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class ConnectedDevices
	{
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var output:String = "";
		
		private var timer:Timer = new Timer(3000);
		private var port:String = "8080";
		
		[Bindable]
		public var devices:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public function ConnectedDevices(port:String)
		{
			this.port = port;
			this.devices.sort = ipSort;
			
			var adbPath:String = "assets/tools/android/adb";
			if(Capabilities.os.indexOf("Mac") > -1){
				this.adbFile = File.applicationDirectory.resolvePath(adbPath);
				
				var chmod:File = new File("/bin/chmod");
				this.procInfo.executable = chmod;			
				this.procInfo.workingDirectory = adbFile.parent;
				this.procInfo.arguments = new <String>["+x", "adb"];
				
				this.process.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
				this.process.start(this.procInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				startAdbProcess();
			}
		}
		
		protected function onChmodExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			process = new NativeProcess();
			
			startAdbProcess();
			startSystemProfilerProcess();
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		// MacOS specific
		//----------------------------------------------------------------------------------------------------------------
		
		private var sysProcInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var sysProc:NativeProcess = new NativeProcess();
		
		private var sysProfiler:String = "";
		
		private function startSystemProfilerProcess():void{
			
			sysProfiler = "";
			
			sysProcInfo.executable = new File("/usr/sbin/system_profiler");			
			sysProcInfo.arguments = new <String>["SPUSBDataType", "-xml"];
			
			//sysProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			sysProc.addEventListener(NativeProcessExitEvent.EXIT, onSysProcInfoExit, false, 0, true);
			sysProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onSysProcInfoData, false, 0, true);
			sysProc.start(sysProcInfo);
		}
		
		protected function onSysProcInfoData(event:ProgressEvent):void{
			sysProfiler += StringUtil.trim(sysProc.standardOutput.readUTFBytes(sysProc.standardOutput.bytesAvailable));
		}
		
		protected function onSysProcInfoExit(event:NativeProcessExitEvent):void
		{
			sysProc.removeEventListener(NativeProcessExitEvent.EXIT, onSysProcInfoExit);
			sysProc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onSysProcInfoData);
			
			trace(sysProfiler);
		}
		
		//----------------------------------------------------------------------------------------------------------------
		//----------------------------------------------------------------------------------------------------------------
		
		private function startAdbProcess():void{
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			procInfo.arguments = new <String>["devices"];
			
			timer.addEventListener(TimerEvent.TIMER, devicesTimerComplete, false, 0, true);
			launchProcess();
		}
		
		public function terminate():void{
			var dv:AndroidDevice;
			for each(dv in devices){
				dv.dispose();
			}
			
			process.exit(true);
			
			procInfo.arguments = new <String>["kill-server"];
			process.start(procInfo);
		}
		
		private function launchProcess():void{
			output = "";
			errorStack = "";
			
			try{
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData, false, 0, true);
				process.start(procInfo);
			}catch(err:Error){}
		}
		
		private function devicesTimerComplete(ev:TimerEvent):void{
			launchProcess();
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			errorStack += process.standardError.readUTFBytes(process.standardError.bytesAvailable);;
			trace(errorStack);
			
			timer.start();
		}
		
		protected function onReadDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadDevicesExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			var dv:AndroidDevice;
			for each(dv in devices){
				dv.connected = false;
			}
			
			var data:Array = output.split("\n");
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var device:AndroidDevice;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					if(info.length == 2){
						device = findDevice(info[0]);
						if(device == null){
							device = new AndroidDevice(adbFile, port, info[0], info[1]);
							device.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
							devices.addItem(device);
							devices.refresh();
						}else{
							device.connected = true;
						}
					}
				}
			}
			
			
			/*for each(var line:String in data){
			var info:Array = line.split(/\s+/g);
			if(info != null && info.length > 6){
			var deviceId:String = info[1];
			var device:AndroidDevice = findDevice(deviceId);
			if(device == null){
			device = new AndroidDevice(port, deviceId, info[2], info[3]);
			device.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
			devices.addItem(device);
			
			devices.refresh();
			}else{
			device.connected = true;
			}
			}
			}*/
			
			for each(dv in devices){
				if(!dv.connected){
					dv.dispose();
					devices.removeItem(dv);
					devices.refresh();
				}
			}
			
			timer.start();
		}
		
		private function findDevice(id:String):AndroidDevice{
			for each(var dv:AndroidDevice in devices){
				if(dv.id == id){
					return dv;
				}
			}
			return null;
		}
		
		private function deviceStoppedHandler(ev:Event):void{
			var dv:AndroidDevice = ev.currentTarget as AndroidDevice;
			dv.removeEventListener("deviceStopped", deviceStoppedHandler);
			dv.dispose();
			devices.removeItem(dv);
		}
	}
}