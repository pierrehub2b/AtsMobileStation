package device.running
{
	import device.Device;
	import device.RunningDevice;
	
	import flash.events.Event;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import mx.collections.ArrayList;
	import mx.events.CollectionEvent;
	
	import udpServer.ScreenshotServer;
	
	import usb.UsbAction;
	import usb.UsbActionProcess;
	import usb.UsbScreenshotProcess;
	
	import webServer.WebServer;
	
	public class AndroidDevice extends RunningDevice
	{
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		private var process:AndroidProcess;
		private var webServActions:WebServer;
		private var udpServScreenshot:ScreenshotServer;
		private var currentAdbFile:File;
		
		private var actionQueue:Vector.<UsbAction> = new Vector.<UsbAction>();
		public var androidUsbAction:UsbActionProcess;
		public var androidUsbScreenshot:UsbScreenshotProcess;
		public static const UDPSERVER:Boolean = false;
				
		public function AndroidDevice(adbFile:File, port:String, id:String)
		{
			this.id = id;
			this.status = INSTALL;
			this.currentAdbFile = adbFile;
			
			var portAutomatic:Boolean = false;
			
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
							portAutomatic = arrayLineAttributes.length > 0 ? arrayLineAttributes[0].toString().toLocaleLowerCase() == "true" : false;
							this.port = arrayLineAttributes.length > 1 && !portAutomatic ? arrayLineAttributes[1] : port;
							this.usbMode = arrayLineAttributes.length > 2 ? arrayLineAttributes[2].toString().toLocaleLowerCase() == "true" : false;
						}
					}
				}
				fileStream.close();
			}
			errorMessage = "";
			if(usbMode) {
				webServActions = new WebServer(this);
				udpServScreenshot = new ScreenshotServer();
				this.port = webServActions.initServerSocket(parseInt(this.port), portAutomatic, httpServerError);
				this.androidUsbAction = new UsbActionProcess(this.id);
				this.androidUsbScreenshot = new UsbScreenshotProcess(this.id);
			}
			
			process = new AndroidProcess(adbFile, atsdroidFilePath, id, this.port, usbMode);
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
			process.addEventListener(AndroidProcess.IP_ADDRESS, ipAdressHandler, false, 0, true);
			
			installing();
		}
		
		public function httpServerError(error:String):void {
			errorMessage = error;
			if(androidUsbAction != null) {
				androidUsbAction.closeProcess();
			}
		}
		
		public function get getCurrentAdbFile():File {
			return this.currentAdbFile;
		}
	
		public override function start():void{
			if(process != null) {
				process.start();
			}
			
		}
		
		public function actionsInsertAt(pos:int, act:UsbAction):void {
			this.actionQueue.insertAt(pos, act);
		}
		
		public function actionsPush(act:UsbAction):void {
			this.actionQueue.push(act);
		}
		
		public function actionsShift():UsbAction {
			return this.actionQueue.shift();
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
			this.udpServScreenshot = new ScreenshotServer();
		}
		
		public function startScreenshotServer():int {
			udpServScreenshot.bind(ip, this);
			return this.udpServScreenshot._datagramSocket.localPort;
		}
		
		private function runningTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.RUNNING, runningTestHandler);
			if(this.usbMode && this.webServActions == null) {
				status = FAIL;
				tooltip = "ths usb WebServer is not running";
				failed();
			} else {
				status = READY;
				tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions";
				started();
			}
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