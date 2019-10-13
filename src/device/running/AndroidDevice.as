package device.running
{
	import flash.events.Event;
	import flash.filesystem.File;
	
	import device.RunningDevice;
	
	public class AndroidDevice extends RunningDevice
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		private var process:AndroidProcess;
				
		public function AndroidDevice(adbFile:File, port:String, id:String)
		{
			this.port = port;
			this.id = id;
			this.status = INSTALL;
			
			process = new AndroidProcess(adbFile, atsdroidFilePath, id, port);
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
			process.addEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler, false, 0, true);
			
			installing()
		}
		
		public override function start():void{
			process.start();
		}
		
		private function processErrorHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler);
			status = FAIL
		}
		
		private function runningTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.RUNNING, runningTestHandler);
			status = READY
			tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions"
			started();
		}
		
		private function stoppedTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.STOPPED, stoppedTestHandler);
			dispatchEvent(new Event(STOPPED_EVENT));
		}
		
		private function deviceInfoHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler);
			manufacturer = process.deviceInfo.manufacturer
			modelId = process.deviceInfo.modelId
			modelName = process.deviceInfo.modelName
			androidVersion = process.deviceInfo.osVersion
			androidSdk = process.deviceInfo.sdkVersion
		}
		
		private function ipAdressHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler);
			ip = process.ipAddress;
		}
				
		override public function dispose():Boolean{
			var running:Boolean = process.terminate();
			process = null;
			
			return running;
		}
	}
}