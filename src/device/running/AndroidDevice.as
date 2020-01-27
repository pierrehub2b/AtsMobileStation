package device.running
{
	import device.Device;
	import device.RunningDevice;
	
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import httpServer.HttpServer;
	
	import mx.collections.ArrayList;
	import mx.events.CollectionEvent;
	
	import udpServer.ScreenshotServer;
	
	import usb.UsbAction;
	
	public class AndroidDevice extends RunningDevice
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		private var process:AndroidProcess;
		private var webServActions:HttpServer;
		private var udpServScreenshot:ScreenshotServer;
		private var currentAdbFile:File;
		
		public static const UDPSERVER:Boolean = true;
				
		public function AndroidDevice(adbFile:File, port:String, id:String)
		{
			
			this.id = id;
			this.status = INSTALL;
			this.currentAdbFile = adbFile;
			
			var fixedPort:Boolean = false;
			
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
							fixedPort = (arrayLineAttributes[0] != "true");
							this.port = arrayLineAttributes[1];
							this.usbMode = (arrayLineAttributes[2] == "true");
						}
					}
				}
				fileStream.close();
			}
			
			webServActions = (new HttpServer());
			udpServScreenshot = new ScreenshotServer();
			
			if(usbMode) {
				this.port = webServActions.listenActions(parseInt(this.port), this, fixedPort, httpServerError);
			}
			
			if(this.port == "") {
				webServActions = null;
			}
			
			process = new AndroidProcess(adbFile, atsdroidFilePath, id, this.port, usbMode);
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
			process.addEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler, false, 0, true);
			installing()
		}
		
		public function httpServerError(error:String):void {
			status = FAIL;
			errorMessage = error;
		}
		
		public function get getCurrentAdbFile():File {
			return this.currentAdbFile;
		}
	
		public override function start():void{
			if(process != null) {
				process.start();
			}
			
		}
		
		private function processErrorHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler);
			status = FAIL
		}
		
		private function onActionQueueChanged(ev:Event):void {
			process.start();
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
			status = READY;
			tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions";
			webServActions.processStarted();
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