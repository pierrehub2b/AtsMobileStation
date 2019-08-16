package 
{
	import device.AndroidDevice;
	import device.Device;
	import device.IosDevice;
	
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
	
	import simulator.IosSimulator;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class RunningDevicesManager
	{
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var output:String = "";
		
		private var timer:Timer = new Timer(3000);
		private var port:String = "8080";
		
		[Bindable]
		public var collection:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public function RunningDevicesManager(port:String)
		{
			this.port = port;
			this.collection.sort = ipSort;
			
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
		
		public function simulatorChanged(sim:IosSimulator):void{
			trace(sim.name + " -> " + sim.phase)
			
			var ios:IosDevice = new IosDevice(sim.id, sim);
			
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
			
			var profiler:XML = new XML(sysProfiler);
			var array:XMLList = profiler.array.children().children();
			var catchArray:Boolean = false;
			
			for each(var keyItems:XML in array){
				if(catchArray){
					for each(var dev:XML in keyItems.dict.children()){
						if(dev.dict != undefined){
							for each(var deviceInfo:XML in dev.dict){
								var dict:Object = new Object();
								var pairNumber:int = deviceInfo.children().length();
								for (var i:int = 0; i<pairNumber; i+=2){
									dict[deviceInfo.children()[i]] = deviceInfo.children()[i+1];
								}
								
								if(dict._name == "iPhone"){
									trace(dict.serial_num)
									
									
									
								}
							}
						}
					}
					
					break;
				}else if(keyItems == "_items"){
					catchArray = true;
				}
			}
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
			var dv:Device;
			for each(dv in collection){
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
				//process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
				process.start(procInfo);
			}catch(err:Error){}
		}
		
		private function devicesTimerComplete(ev:TimerEvent):void{
			launchProcess();
		}
		
		protected function onReadAndroidDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadAndroidDevicesExit(event:NativeProcessExitEvent):void
		{
			//process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
			
			var dv:Device;
			for each(dv in collection){
				dv.connected = false;
			}
			
			var data:Array = output.split("\n");
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var dev:Device;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					if(info.length >= 2){
						dev = findDevice(info[0]);
						if(dev == null){
							dev = new AndroidDevice(adbFile, port, info[0], info[1]);
							dev.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
							collection.addItem(dev);
							collection.refresh();
						}else{
							dev.connected = true;
						}
					}
				}
			}
			
			for each(dv in collection){
				if(!dv.connected){
					dv.dispose();
					collection.removeItem(dv);
					collection.refresh();
				}
			}
			
			timer.start();
		}
		
		private function findDevice(id:String):Device{
			for each(var dv:Device in collection){
				if(dv.id == id){
					return dv;
				}
			}
			return null;
		}
		
		private function deviceStoppedHandler(ev:Event):void{
			var dv:Device = ev.currentTarget as Device;
			dv.removeEventListener("deviceStopped", deviceStoppedHandler);
			dv.dispose();
			collection.removeItem(dv);
		}
	}
}