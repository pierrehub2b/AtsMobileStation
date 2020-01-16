package device.running
{
	import device.RunningDevice;
	
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import httpServer.*;
	
	import udpServer.ScreenshotServer;
	
	public class AndroidDevice extends RunningDevice
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		public static const SCREENSHOTSERVER:String = "screenshotServer";
		public static const ACTIONSSERVER:String = "actionsServer";
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		private var process:AndroidProcess;
		private var webServActions:HttpServer;
		private var udpServScreenshot:ScreenshotServer;
		
		public static const UDPSERVER:Boolean = false;
				
		public function AndroidDevice(adbFile:File, port:String, id:String)
		{
			
			this.id = id;
			this.status = INSTALL;
			
			var fileStream:FileStream = new FileStream();
			var file:File = File.userDirectory.resolvePath("actiontestscript/devicesPortsSettings.txt");
			if(file.exists) {
				fileStream.open(file, FileMode.READ);
				var content:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
				var arrayString: Array = content.split("\n");
				for each(var line:String in arrayString) {
					if(line != "") {
						var arrayLineId: Array = line.split("==");
						if(arrayLineId[0].toString().toLowerCase() == id.toString().toLowerCase()) {
							var arrayLineAttributes: Array = arrayLineId[1].split(";");
							this.usbMode = (arrayLineAttributes[2] == "true");
						}
					}
				}
				fileStream.close();
			}
			
			webServActions = (new HttpServer());
			udpServScreenshot = new ScreenshotServer();
			
			process = new AndroidProcess(adbFile, atsdroidFilePath, id, port, usbMode);
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
			process.addEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler, false, 0, true);
			
			this.port = usbMode ? webServActions.listen(8080, this, ACTIONSSERVER) : port;
			
			installing()
		}
		
		public override function start():void{
			process.start();
		}
		
		private function processErrorHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler);
			status = FAIL
		}
		
		public function get getProcess():AndroidProcess
		{
			return this.process;
		}
		
		public function stopScreenshotServer():void {
			this.udpServScreenshot._datagramSocket.close();
			this.udpServScreenshot = new ScreenshotServer();
		}
		
		public function startScreenshotServer():int {
			this.udpServScreenshot.bind(ip, id);
			return this.udpServScreenshot._datagramSocket.localPort;
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
			udpIpAdresse = process.deviceIp;
		}
				
		override public function dispose():Boolean{
			return process.terminate();
		}
	}
}