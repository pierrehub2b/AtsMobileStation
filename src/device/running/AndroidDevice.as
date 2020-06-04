package device.running
{
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.globalization.DateTimeFormatter;
import flash.system.Capabilities;

import helpers.DeviceSettings;
import helpers.DeviceSettingsHelper;

import mx.core.FlexGlobals;

public class AndroidDevice extends RunningDevice
	{
		protected static const ANDROID_DRIVER:String = "com.ats.atsdroid";
		private static const atsdroidFilePath:String = File.applicationDirectory.resolvePath("assets/drivers/atsdroid.apk").nativePath;

		[Transient] public var androidVersion:String//  = "0";
		[Transient] public var androidSdk:String//  = "0";
		[Transient] public var settings:DeviceSettings;

		private static var execExtension:String = Capabilities.os.indexOf("Mac")>-1?"":".exe";
		[Transient] protected var currentAdbFile:File = File.applicationDirectory.resolvePath("assets/tools/android/adb" + execExtension);

		private var logFile:File;
		private var logStream:FileStream = new FileStream();
		private var dateFormatter:DateTimeFormatter = new DateTimeFormatter("en-US");

		protected var process:NativeProcess
		protected var processInfo:NativeProcessStartupInfo

		public function AndroidDevice(id:String, simulator:Boolean) {
			this.id = id;
			this.simulator = simulator;

			installing()
		}

		public static function setup(id:String):AndroidDevice {
			var deviceSettingsHelper:DeviceSettingsHelper = DeviceSettingsHelper.shared;
			var deviceSettings:DeviceSettings = deviceSettingsHelper.getSettingsForDevice(id);

			var isEmulator:Boolean = id.indexOf("emulator") >= 0

			if (deviceSettings == null) {
				deviceSettings = new DeviceSettings(id, true, isEmulator);
				deviceSettingsHelper.save(deviceSettings);
			}
			var automaticPort:Boolean = deviceSettings.automaticPort;
			var usbMode:Boolean = deviceSettings.usbMode;

			if (usbMode) {
				return new AndroidUsbDevice(id, isEmulator, deviceSettings);
			} else {
				var port:int = deviceSettings.port;
				return new AndroidWirelessDevice(id, automaticPort, port);
			}
		}


		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------


		public override function start():void {
			dateFormatter.setDateTimePattern("yyyy-MM-dd hh:mm:ss");
			logFile = FlexGlobals.topLevelApplication.logsFolder.resolvePath("android_" + id + "_" + new Date().time + ".log");

			logStream.open(logFile, FileMode.WRITE);
			logStream.writeUTFBytes("Start Android process");
			logStream.close();

			writeInfoLogFile("USB MODE = " + usbMode + " > set port: " + this.port);

			fetchDeviceInfo()
		}

		public override function dispose():Boolean {
			if (process != null && process.running) {
				process.exit(true);
				return true;
			}

			return false
		}


		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------


		public function writeErrorLogFile(data:String):void {
			writeLogs("ERROR", data);
		}

		public function writeInfoLogFile(data:String):void {
			writeLogs("INFO", data);
		}

		private function writeLogs(type:String, data:String):void{
			data = data.replace("INSTRUMENTATION_STATUS: atsLogs=", "");
			data = data.replace("INSTRUMENTATION_STATUS_CODE: 0", "");
			data = data.replace(/[\u000d\u000a\u0008]+/g, "");
			if(data.length > 0){
				logStream.open(logFile, FileMode.APPEND);
				logStream.writeUTFBytes("[" + dateFormatter.format(new Date()) + "][" + type + "]" + data + "\n");
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


		//---------------------------------------------------------------------------------------------------------
		//---------------------------------------------------------------------------------------------------------


		private var processError:String = ""
		private var processOutput:String = ""

		private function fetchDeviceInfo():void {
			var processInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processInfo.executable = currentAdbFile
			processInfo.arguments = new <String>["-s", id, "shell", "getprop"];

			var adbProcess: NativeProcess = new NativeProcess()
			adbProcess.addEventListener(NativeProcessExitEvent.EXIT, onDeviceInfoExit, false, 0, true);
			adbProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onDeviceInfoError, false, 0, true);
			adbProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onDeviceInfoOutput, false, 0, true);
			adbProcess.start(processInfo)
		}

		private function onDeviceInfoOutput(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			processOutput = processOutput.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable).replace(/\r/g, ""));
		}

		private function onDeviceInfoError(event:ProgressEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			processError = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
		}

		private function onDeviceInfoExit(event:NativeProcessExitEvent):void {
			var process: NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onDeviceInfoOutput)
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onDeviceInfoError)
			process.removeEventListener(NativeProcessExitEvent.EXIT, onDeviceInfoExit)

			if (processError) {
				status = ERROR
				trace("BOOT CHECK ERROR - " + id + " : " + processError)
				// check if device unlocked or not

				if (processError.indexOf("device unauthorized") != -1) {
					authorized = false
					error = "Device not authorized"
					errorMessage = "Check for a confirmation dialog on your device"
					trace("Device not autorized")
				}

				return
			}

			var bootInfo:String

			var propArray:Array = processOutput.split("\n")
			for each (var line:String in propArray)
			{
				if (line.indexOf("[sys.boot_completed]") == 0) {
					bootInfo = getPropValue(line)
				} else if (line.indexOf("[ro.product.brand]") == 0) {
					manufacturer = getPropValue(line)
				} else if (line.indexOf("[ro.product.model]") == 0) {
					modelId = getPropValue(line)
				} else if (line.indexOf("[ro.build.version.release]") == 0) {
					osVersion = getPropValue(line)
				} else if (line.indexOf("[ro.build.version.sdk]") == 0) {
					androidSdk = getPropValue(line)
				} else if (line.indexOf("[ro.semc.product.name]") == 0) {
					modelName = getPropValue(line)
				} else if(line.indexOf("[def.tctfw.brandMode.name]") == 0) {
					modelName = getPropValue(line)
				}
			}

			if (!modelName) modelName = modelId

			if (bootInfo && bootInfo == "1") {
				trace(id + " booted")
				fetchIpAddress()
			} else {
				// dispatchEvent(new Event(ERROR_EVENT));
				// status : not booted
				// errorMessage : not booted
				error = "Device not started"
				errorMessage = "Please wait until the device is started"
				booted = false
			}
		}

		private function getPropValue(value:String):String {
			return /.*:.*\[(.*)\]/.exec(value)[1];
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
			var processInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processInfo.executable = currentAdbFile
			processInfo.arguments = new <String>["-s", id, "shell", "pm", "uninstall", ANDROID_DRIVER];

			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallDriverExit, false, 0, true);
			process.start(processInfo);
		}

		protected function onUninstallDriverExit(event:NativeProcessExitEvent):void {
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallDriverExit);
		}

		private function onUninstallDriverOutput(event:ProgressEvent):void {}
		private function onUninstallDriverError(event:ProgressEvent):void {}


		//---------------------------------------------------------------------------------------------------------
		// -------- DRIVER INSTALL
		//---------------------------------------------------------------------------------------------------------


		protected function installDriver():void {
			var processInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processInfo.executable = currentAdbFile
			processInfo.arguments = new <String>["-s", id, "install", "-r", atsdroidFilePath];

			process = new NativeProcess();
			process.addEventListener(NativeProcessExitEvent.EXIT, onInstallDriverExit, false, 0, true);
			process.start(processInfo);
		}

		private function onInstallDriverOutput():void {}
		private function onInstallDriverError():void {}
		private function onInstallDriverExit(event:NativeProcessExitEvent):void {
			execute()
		}


		//---------------------------------------------------------------------------------------------------------
		//-------- DRIVER EXECUTION
		//---------------------------------------------------------------------------------------------------------


		protected function execute():void {
			trace("WARNING : execute not implemented")
		}

		protected var executeOutput:String
		protected function onExecuteOutput(event:ProgressEvent):void {
			executeOutput = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);

			if (executeOutput.indexOf("Process crashed") > -1) {
				writeErrorLogFile(executeOutput);
				process.standardInput.writeUTFBytes("instrumentCommandLine");
				return
			}

			writeInfoLogFile(executeOutput);
			if (executeOutput.indexOf("ATS_DRIVER_RUNNING") > -1) {
				started()
			} else if (executeOutput.indexOf("ATS_DRIVER_START") > -1) {
				trace("driver start -> " + executeOutput);
			} else if(executeOutput.indexOf("ATS_DRIVER_STOP") > -1){
				trace("driver stop");
			} else if(executeOutput.indexOf("ATS_WIFI_STOP") > -1) {
				// dispatchEvent(new Event(WIFI_ERROR_EVENT));
			} else if(executeOutput.indexOf("ATS_DRIVER_LOCKED_BY:") > -1) {
				locked = getDeviceOwner(executeOutput)
			} else if(executeOutput.indexOf("ATS_DRIVER_UNLOCKED") > -1) {
				locked = null;
			}
		}

		// to refactor -> regex
		private function getDeviceOwner(data:String):String {
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

		protected function onExecuteError(event:ProgressEvent):void {
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			trace("err -> " + data);
			writeErrorLogFile(data);
			error = data;
		}

		protected function onExecuteExit(event:NativeProcessExitEvent):void {
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onExecuteExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteOutput);
			process = null;

			if (error) {
				trace("err -> " + error);
				status = FAIL;
				writeErrorLogFile("Failure on android process");
			} else {
				close()
			}
		}
	}
}