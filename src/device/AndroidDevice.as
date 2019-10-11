package device
{
	import flash.events.Event;
	import flash.filesystem.File;
	
	public class AndroidDevice extends Device
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";
		
		public var type:String;
		private var process:AndroidProcess;
				
		public function AndroidDevice(adbFile:File, port:String, id:String, type:String)
		{
			this.port = port;
			this.connected = true;
			this.id = id;
			this.type = type;
			
			this.status = INSTALL;
			
			process = new AndroidProcess(adbFile, atsdroidFilePath, id, port);
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
			process.addEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler, false, 0, true);
			
			process.start();
		}
		
		private function processErrorHandler(ev:Event):void{
			
			process.removeEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler);
			
			status = FAIL
			connected = false;
			
			terminate();
		}
		
		private function runningTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.RUNNING, runningTestHandler);
			status = READY
			tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions"
		}
		
		private function stoppedTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.STOPPED, stoppedTestHandler);
			terminate();
		}
		
		private function deviceInfoHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler);
			manufacturer = process.deviceInfo.manufacturer
			modelId = process.deviceInfo.modelId
			modelName = process.deviceInfo.modelName
			androidVersion = process.deviceInfo.androidVersion
			androidSdk = process.deviceInfo.androidSdk
		}
		
		private function ipAdressHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler);
			ip = process.ipAddress;
		}
				
		override public function dispose():Boolean{
			return process.terminate();
		}
		
		private function terminate():void{
			if(!dispose()){
				dispatchEvent(new Event(STOPPED_EVENT));
			}
		}
	}
}