package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class ConnectedDevices
	{
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		private var adbFile:File = File.applicationDirectory.resolvePath("assets/tools/android/adb.exe");
		private var errorStack:String = "";
		private var output:String = "";
		
		private var listDevicesTimer:Timer;
		
		private var port:String = "8080";
		
		[Bindable]
		public var devices:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort();
		
		public function ConnectedDevices(port:String)
		{
			this.port = port;
			
			
			ipSort.fields = [new SortField("ip")];
			devices.sort = ipSort;
			
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			procInfo.arguments = new <String>["devices", "-l"];
			
			listDevicesTimer = new Timer(2000);
			listDevicesTimer.addEventListener(TimerEvent.TIMER, devicesTimerComplete, false, 0, true);
			listDevicesTimer.start();
		}
		
		public function terminate():void{
			var dv:Device;
			for each(dv in devices){
				dv.dispose();
			}
			
			process.exit(true);
		}
		
		private function devicesTimerComplete(ev:TimerEvent):void{
			output = "";
			errorStack = "";
			
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			process.addEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit, false, 0, true);
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData, false, 0, true);
			process.start(procInfo);
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			errorStack += process.standardError.readUTFBytes(process.standardError.bytesAvailable);;
			trace(errorStack);
			
			listDevicesTimer.start();
		}
		
		protected function onReadDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadDevicesExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			var dv:Device;
			//var refresh:Boolean = false;
			
			for each(dv in devices){
				dv.connected = false;
			}
			
			var data:Array = output.split("\n");
			for each(var line:String in data){
				var info:Array = line.split(/(\w+)\s*(\w+) *product:(\w+)\s*/g);
				if(info != null && info.length > 4){
					var deviceId:String = info[1];
					var device:Device = findDevice(deviceId);
					if(device == null){
						device = new Device(port, deviceId, info[2], info[3]);
						device.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
						devices.addItem(device);
						
						devices.refresh();
						//refresh = true;
					}else{
						device.connected = true;
					}
				}
			}
			
			for each(dv in devices){
				if(!dv.connected){
					dv.dispose();
					devices.removeItem(dv);
					//refresh = true;
					devices.refresh();
				}
			}
			
			//if(refresh){
			//	devices.refresh();
			//}
			
			listDevicesTimer.start();
		}
		
		private function findDevice(id:String):Device{
			for each(var dv:Device in devices){
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
			devices.removeItem(dv);
		}
	}
}