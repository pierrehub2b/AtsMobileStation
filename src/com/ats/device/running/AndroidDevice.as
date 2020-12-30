package com.ats.device.running
{
	import com.ats.helpers.DeviceSettings;
	import com.ats.helpers.DeviceSettingsHelper;
	import com.ats.helpers.Settings;
	import com.ats.helpers.Version;

	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.globalization.DateTimeFormatter;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;

	public class AndroidDevice extends RunningDevice {
		protected static const ANDROID_DRIVER:String = "com.ats.atsdroid";
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;
		
		[Transient]
		public var androidVersion:String
		[Transient]
		public var androidSdk:String
		[Transient]
		public var settings:DeviceSettings;
		
		protected var adbProcess:AdbProcess
		
		private var logFile:File;
		
		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------
		private var logStream:FileStream = new FileStream();
		private var dateFormatter:DateTimeFormatter = new DateTimeFormatter("en-US");
		
		override public function get modelName():String {
			return simulator ? "Emulator " + _modelName : _modelName;
		}
		
		public static function setup(id:String, isEmulator:Boolean):AndroidDevice {
			var deviceSettingsHelper:DeviceSettingsHelper = DeviceSettingsHelper.shared;
			var deviceSettings:DeviceSettings = deviceSettingsHelper.getSettingsForDevice(id);
			
			if (deviceSettings == null) {
				deviceSettings = new DeviceSettings(id, true, isEmulator);
				deviceSettingsHelper.save(deviceSettings);
			}
			var automaticPort:Boolean = deviceSettings.automaticPort;
			var usbMode:Boolean = deviceSettings.usbMode;
			
			if (usbMode) {
				if (id.indexOf("localhost") == 0) {
					return new GenymotionSaasDevice(id, deviceSettings)
				} else {
					return new AndroidUsbDevice(id, isEmulator, deviceSettings);
				}
			} else {
				var port:int = deviceSettings.port;
				return new AndroidWirelessDevice(id, automaticPort, port);
			}
		}
		
		//---------------------------------------------------------------------------------------------------------
		// Download APK
		//---------------------------------------------------------------------------------------------------------
		
		private var apkFile:File;
		private var urlStream:URLStream;
		private var downloadedData:ByteArray;

		public override function installLocalFile(file:File):void {
			installing()

			var arguments: Vector.<String> = new <String>["-s", id, "install", file.nativePath]
			var adbProcess:AdbProcess = new AdbProcess()
			adbProcess.execute(arguments, onInstallApkExit)
		}

		public override function installRemoteFile(url:String):void{
			status = INSTALL_APP

			printDebugLogs("Start apk download : " + url)
			
			downloadedData = new ByteArray();
			
			urlStream = new URLStream();
			urlStream.addEventListener(ProgressEvent.PROGRESS, streamProgress);
			urlStream.addEventListener(Event.COMPLETE, streamComplete);
			
			urlStream.load(new URLRequest(url));
		}
		
		private function streamProgress(ev:ProgressEvent):void{
			urlStream.readBytes(downloadedData, downloadedData.length, urlStream.bytesAvailable);
		}
		
		private function streamComplete(ev:Event):void{
			urlStream.removeEventListener(ProgressEvent.PROGRESS, streamProgress);
			urlStream.removeEventListener(Event.COMPLETE, streamComplete);
			
			printDebugLogs("Apk downloaded")
			
			urlStream.close();
			urlStream = null;
			
			apkFile = File.userDirectory.resolvePath(".atsmobilestation").resolvePath("temp").resolvePath("install.apk")
			if(apkFile.exists){
				apkFile.deleteFile();
			}
			
			var fileStream:FileStream = new FileStream();
			fileStream.addEventListener(Event.CLOSE, writeFileComplete);
			try {
				fileStream.openAsync(apkFile, FileMode.WRITE);
				fileStream.writeBytes(downloadedData);
			} catch (e:Error) {
			} finally {
				fileStream.close();
			}
		}
		
		private function writeFileComplete(ev:Event):void{
			var fileStream:FileStream = ev.currentTarget as FileStream;
			fileStream.removeEventListener(Event.CLOSE, writeFileComplete);
			
			var apkPath:String = apkFile.nativePath.replace(/\\/g, "/");
			printDebugLogs("Installing apk -> " + apkPath)
			
			var arguments: Vector.<String> = new <String>["-s", id, "install", apkPath]
			var adbProcess:AdbProcess = new AdbProcess()
			adbProcess.execute(arguments, onInstallApkExit)
		}
		
		protected function onInstallApkExit():void {
			printDebugLogs("Apk installed")

			started()
		}
		
		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------

		private static function getPropValue(value:String):String {
			return /.*:.*\[(.*)]/.exec(value)[1];
		}
		
		// to refactor -> regex
		private static function getDeviceOwner(data:String):String {
			var array:Array = data.split("\n");
			for each(var line:String in array) {
				if (line.indexOf("ATS_DRIVER_LOCKED_BY") > -1) {
					var firstIndex:int = line.length;
					var lastIndex:int = line.lastIndexOf("ATS_DRIVER_LOCKED_BY:") + "ATS_DRIVER_LOCKED_BY:".length;
					return line.substring(lastIndex, firstIndex).slice(0, -1);
				}
			}
			
			return null;
		}
		
		public function AndroidDevice(id:String, simulator:Boolean) {
			this.id = id;
			this.simulator = simulator;
			
			installing()
		}
		
		public override function start():void {
			dateFormatter.setDateTimePattern("yyyy-MM-dd hh:mm:ss");
			
			logFile = Settings.logsFolder.resolvePath("android_" + id.replace(/[.:]/g, "") + "_" + new Date().time + ".log");
			logStream.open(logFile, FileMode.WRITE);
			logStream.writeUTFBytes("Start Android process");
			logStream.close();
			
			writeInfoLogFile("USB MODE = " + usbMode + " > set port: " + this.port);
			
			adbProcess = new AdbProcess()
			
			fetchDeviceInfo()
		}
		
		public override function dispose():Boolean {
			if (adbProcess != null && adbProcess.running) {
				adbProcess.exit(true);
				return true;
			}
			
			return false
		}
		
		public function writeErrorLogFile(data:String):void {
			writeLogs("ERROR", data);
		}
		
		public function writeInfoLogFile(data:String):void {
			writeLogs("INFO", data);
		}
		
		private function writeLogs(label:String, data:String):void {
			data = data.replace("INSTRUMENTATION_STATUS: atsLogs=", "");
			data = data.replace("INSTRUMENTATION_STATUS_CODE: 0", "");
			data = data.replace(/[\u000d\u000a\u0008]+/g, "");
			if (data.length > 0) {
				logStream.open(logFile, FileMode.APPEND);
				logStream.writeUTFBytes("[" + dateFormatter.format(new Date()) + "][" + label + "]" + data + "\n");
				logStream.close();
			}
		}
		
		//---------------------------------------------------------------------------------------------------------
		// Step 1 : fetch device info
		// Step 2 : fetch ip address
		// Step 3 : uninstall apk driver
		// Step 4 : install apk driver
		// Step 5 : execute apk driver
		//---------------------------------------------------------------------------------------------------------
		
		private function fetchDeviceInfo():void {
			printDebugLogs("Fetching device info")
			
			var arguments: Vector.<String> = new <String>["-s", id, "shell", "getprop"];
			adbProcess.execute(arguments, onDeviceInfoExit)
		}
		
		private function onDeviceInfoExit():void {
			var processError:String = adbProcess.error
			if (processError) {
				status = ERROR
				trace("BOOT CHECK ERROR - " + id + " : " + processError)
				
				if (processError.indexOf("device unauthorized") != -1) {
					authorized = false
					error = "Device not authorized"
					errorMessage = "Check for a confirmation dialog on your device"
				} else if (processError.indexOf("device offline") != -1) {
					error = "Device not started"
					errorMessage = "Please wait until the device is started"
					booted = false
					status = BOOT
				} else {
					error = "Unknow error"
					errorMessage = "Please wait until the device is started"
				}
				
				return
			}
			
			var bootInfo:String
			var modelName:String
			var propArray:Array = adbProcess.output.split("\n")
			for each (var line:String in propArray) {
				if (line.indexOf("[sys.boot_completed]") == 0) {
					bootInfo = getPropValue(line)
				} else if (line.indexOf("[ro.product.model]") == 0) {
					modelId = getPropValue(line)
				} else if (line.indexOf("[ro.build.version.release]") == 0) {
					osVersion = getPropValue(line)
				} else if (line.indexOf("[ro.build.version.sdk]") == 0) {
					androidSdk = getPropValue(line)
				} else if (line.indexOf("[ro.product.manufacturer]") == 0) {
					manufacturer = getPropValue(line)
				}
				
				if (simulator) {
					if (modelId.indexOf("GM") == 0) {
						var parameters:Array = modelId.split("_")
						modelName = parameters[1]
					} else {
						if (line.indexOf("[ro.product.cpu.abi]") == 0) {
							modelName = getPropValue(line)
						}
					}
					
				} else {
					if (line.indexOf("[ro.semc.product.name]") == 0) {
						modelName = getPropValue(line)
					} else if (line.indexOf("[def.tctfw.brandMode.name]") == 0) {
						modelName = getPropValue(line)
					}
				}
			}
			
			if (!modelName) modelName = modelId
			
			var myRegexPattern:RegExp = new RegExp(manufacturer + "\\s?", "i")
			this.modelName = modelName.replace(myRegexPattern, "");
			
			var deviceOsVersion:Version = new Version(osVersion)
			if (deviceOsVersion.compare(new Version("5.1")) == Version.INFERIOR) {
				status = ERROR
				error = "Android version not compatible"
				errorMessage = "Only supports Android devices running version 5.1 or higher"
				return
			}
			
			if (bootInfo && bootInfo == "1") {
				fetchIpAddress()
				status = INSTALL
				error = null
				errorMessage = null
			} else {
				error = "Device not started"
				errorMessage = "Please wait until the device is started"
				booted = false
				status = BOOT
			}
		}
		
		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------
		
		protected function fetchIpAddress():void {
			trace("WARNING : fetchIpAddress not implemented")
		}
		
		//---------------------------------------------------------------------------------------------------------
		// -------- DRIVER UNINSTALL
		//---------------------------------------------------------------------------------------------------------
		
		protected function uninstallDriver():void {
			printDebugLogs("Uninstall driver")
			
			var arguments: Vector.<String> = new <String>["-s", id, "shell", "pm", "uninstall", ANDROID_DRIVER]
			adbProcess.execute(arguments, onUninstallDriverExit)
		}
		
		protected function onUninstallDriverExit():void {
			trace("WARNING : onUninstallDriverExit not implemented")
		}
		
		//---------------------------------------------------------------------------------------------------------
		// -------- DRIVER INSTALL
		//---------------------------------------------------------------------------------------------------------
		
		protected function installDriver():void {
			var arguments: Vector.<String> = new <String>["-s", id, "install", "-r", atsdroidFilePath];
			adbProcess.execute(arguments, onInstallDriverExit)
		}
		
		protected function onInstallDriverExit():void {
			executeDriver()
		}
		
		//---------------------------------------------------------------------------------------------------------
		//-------- DRIVER EXECUTION
		//---------------------------------------------------------------------------------------------------------
		
		protected function executeDriver():void {
			trace("WARNING : executeDriver not implemented")
		}
		
		protected function onExecuteOutput():void {
			var executeOutput:String = adbProcess.partialOutput
			writeErrorLogFile(executeOutput);
			
			if (executeOutput.indexOf("Process crashed") > -1) {
				adbProcess.standardInput.writeUTFBytes("instrumentCommandLine");
				return
			}
			
			if (executeOutput.indexOf("ATS_DRIVER_RUNNING") > -1) {
				started()
			} else if (executeOutput.indexOf("ATS_DRIVER_START") > -1) {
				trace("driver start -> " + executeOutput);
			} else if (executeOutput.indexOf("ATS_DRIVER_STOP") > -1) {
				trace("driver stop");
			} else if (executeOutput.indexOf("ATS_WIFI_STOP") > -1) {
				// dispatchEvent(new Event(WIFI_ERROR_EVENT));
			} else if (executeOutput.indexOf("ATS_DRIVER_LOCKED_BY:") > -1) {
				locked = getDeviceOwner(executeOutput)
			} else if (executeOutput.indexOf("ATS_DRIVER_UNLOCKED") > -1) {
				locked = null;
			}
		}
		
		protected function onExecuteError():void {
			writeErrorLogFile(adbProcess.error);
		}
		
		protected function onExecuteExit():void {
			var executeError:String = adbProcess.error
			if (executeError) {
				status = FAIL;
				trace("ATSDroid Execution error : " + executeError);
				writeErrorLogFile("Failure on android process");
			} else {
				close()
			}
			
			adbProcess = null
		}
	}
}