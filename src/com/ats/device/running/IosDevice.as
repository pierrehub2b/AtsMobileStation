package com.ats.device.running
{
	import com.ats.device.Device;
	import com.ats.device.simulator.Simulator;
	import com.ats.helpers.DevicePortSettings;
	import com.ats.helpers.DevicePortSettingsHelper;
	import com.ats.helpers.DeviceSettings;
	import com.ats.helpers.DeviceSettingsHelper;
	import com.ats.helpers.PortSwitcher;
	import com.ats.helpers.Settings;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.globalization.DateTimeFormatter;
	
	import mx.core.FlexGlobals;
	
	public class IosDevice extends RunningDevice
	{
		private static const ATSDRIVER_DRIVER_HOST:String = "ATSDRIVER_DRIVER_HOST";
		
		private static const startInfo:RegExp = new RegExp(ATSDRIVER_DRIVER_HOST + "=(.*):(\\d+)");
		private static const startInfoLocked:RegExp = /isPasscodeLocked:(\s*)YES/;
		private static const noProvisionningProfileError:RegExp = /Xcode couldn't find any iOS App Development provisioning profiles matching(\s*)/;
		private static const noCertificatesError:RegExp = /signing certificate matching team ID(\s*)/;
		private static const noXcodeInstalled:RegExp = /requires Xcode(\s*)/;
		private static const wrongVersionofxCode:RegExp = /which may not be supported by this version of Xcode(\s*)/;
		
		private var logFile:File;
		private var logStream:FileStream = new FileStream();
		private var dateFormatter:DateTimeFormatter = new DateTimeFormatter("en-US");
		
		private var driverProcess:NativeProcess;
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const iosMobileDeviceTools:File = File.applicationDirectory.resolvePath("assets/tools/ios");
		
		private var driverDirectory:File;
		
		override public function get modelName():String {
			return simulator ? "Simulator " + _modelName : _modelName;
		}
		
		public function IosDevice(id:String, name:String, osVersion:String, simulator:Boolean, ip:String) {
			this.id = id;
			this.ip = ip;
			this.osVersion = osVersion
			this.modelName = name;
			this.manufacturer = "Apple";
			this.simulator = simulator;
			
			this.driverDirectory =  File.userDirectory.resolvePath("Library/mobileStationTemp/driver_"+ id)
			
			//---------------------------------------------------------------------------------------
			
			dateFormatter.setDateTimePattern("yyyy-MM-dd hh:mm:ss")
			logFile = Settings.logsFolder.resolvePath("ios_" + id + "_" + new Date().time + ".log")
			
			logStream.open(logFile, FileMode.WRITE)
			logStream.writeUTFBytes("Start iOS process")
			logStream.writeUTFBytes("Getting settings configuration for device:" + id)
			logStream.close()
			
			//---------------------------------------------------------------------------------------
			
			var deviceSettingsHelper:DeviceSettingsHelper = DeviceSettingsHelper.shared;
			var deviceSettings:DeviceSettings = deviceSettingsHelper.getSettingsForDevice(id);
			if (deviceSettings == null) {
				deviceSettings = new DeviceSettings(id);
				deviceSettingsHelper.save(deviceSettings);
			}
			
			automaticPort = deviceSettings.automaticPort;
			
			if (simulator) {
				var portSwitcher:PortSwitcher = new PortSwitcher();
				settingsPort = portSwitcher.getLocalPort(id, automaticPort).toString();
				
				var devicePortSettings:DevicePortSettings = DevicePortSettingsHelper.shared.getPortSetting(id);
				devicePortSettings.port = parseInt(settingsPort);
				DevicePortSettingsHelper.shared.addSettings(devicePortSettings);
			} else {
				settingsPort = deviceSettings.port.toString();
			}
		}
		
		override public function dispose():Boolean {
			if (driverProcess != null && driverProcess.running) {
				driverProcess.closeInput();
				driverProcess.exit();
				return true;
			}
			return false;
		}
		
		override public function start():void {
			if(!FlexGlobals.topLevelApplication.getTeamId()  && !simulator) {
				status = Device.FAIL;
				errorMessage = " - No development team id set";
				return;
			}
			
			iosDriverProjectFolder.copyTo(driverDirectory, true);
			
			installing();
			uninstallDriver()
		}
		
		private function uninstallDriver():void {
			var processStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processStartupInfo.executable = new File("/usr/bin/env")
			processStartupInfo.workingDirectory = iosMobileDeviceTools
			processStartupInfo.arguments = new <String>["./mobiledevice", "uninstall_app", "-u", id, "com.atsios.xctrunner"]
			
			var process:NativeProcess = new NativeProcess()
			process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallDriverExit)
			process.start(processStartupInfo)
		}
		
		private function onUninstallDriverExit(event:NativeProcessExitEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallDriverExit)
			
			fetchBundleIds()
		}
		
		//------------------------------------------------------------------
		
		private var bundlesData:String
		private function fetchBundleIds():void {
			bundlesData = ""
			
			var processStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			processStartupInfo.executable = new File("/usr/bin/env")
			processStartupInfo.workingDirectory = iosMobileDeviceTools
			processStartupInfo.arguments = new <String>["./mobiledevice", "list_apps", "-u", id]
			
			var process:NativeProcess = new NativeProcess()
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onGettingBundlesOutput, false, 0, true)
			process.addEventListener(NativeProcessExitEvent.EXIT, onGettingBundlesExit, false, 0, true)
			process.start(processStartupInfo)
		}
		
		private function onGettingBundlesOutput(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			bundlesData += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
		}
		
		private function onGettingBundlesExit(event:NativeProcessExitEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onGettingBundlesOutput)
			process.removeEventListener(NativeProcessExitEvent.EXIT, onGettingBundlesExit)
			
			var apps:Array = bundlesData.split("\n")
			apps.pop()
			
			var json:Object = {
				"apps": apps,
				"customPort": automaticPort ? null : settingsPort
			}
			
			writeLogs("Managing JSON file", "info");
			var settingsFile:File = driverDirectory.resolvePath("atsDriver/settings.json");
			var fileStream:FileStream = new FileStream()
			fileStream.open(settingsFile, FileMode.WRITE)
			fileStream.writeUTFBytes(JSON.stringify(json))
			fileStream.close()
			
			startDriver()
		}
		
		// -------------------------
		
		private function startDriver():void {
			writeLogs("build and test on device with id:" + id, "info");
			writeLogs("installing the driver", "info");
			
			var processStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			processStartupInfo.executable = new File("/usr/bin/xcodebuild")
			processStartupInfo.workingDirectory = driverDirectory;
			
			var arguments: Vector.<String> = new <String>["test", "-scheme", "atsios", "-destination", "id=" + id];
			if (!simulator) {
				arguments.push("-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration", "DEVELOPMENT_TEAM=" + FlexGlobals.topLevelApplication.getTeamId());
			}
			
			processStartupInfo.arguments = arguments
			
			driverProcess = new NativeProcess()
			driverProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onDriverOutput, false, 0, true)
			driverProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onDriverError, false, 0, true)
			driverProcess.addEventListener(NativeProcessExitEvent.EXIT, onDriverExit, false, 0, true)
			driverProcess.start(processStartupInfo)
		}
		
		private function onDriverOutput(event:ProgressEvent):void {
			const data:String = driverProcess.standardOutput.readUTFBytes(driverProcess.standardOutput.bytesAvailable);

			if (data.indexOf("** WIFI NOT CONNECTED **") > -1) {
				errorMessage = " - WIFI not connected !";
				dispose()
			} else if (data.indexOf("** DEVICE LOCKED BY : ") > -1) {
				this.locked = getDeviceOwner(data);
			} else if (data.indexOf("** DEVICE UNLOCKED **") > -1) {
				this.locked = null;
			} else if (data.indexOf("** Port unavailable **") > -1) {
				errorMessage = " - Unavailable port !";
				dispose()
			} else if(data.indexOf(ATSDRIVER_DRIVER_HOST) > -1) {
				const find:Array = startInfo.exec(data);
				ip = find[1];
				port = find[2];
				
				if (simulator) {
					var devicePortSettings:DevicePortSettings = DevicePortSettingsHelper.shared.getPortSetting(id);
					devicePortSettings.port = parseInt(port);
					DevicePortSettingsHelper.shared.addSettings(devicePortSettings);
				}
				
				started();
			} else {
				writeLogs(data);
			}
		}
		
		private static function getDeviceOwner(data:String):String {
			var array:Array = data.split("\n");
			for each(var line:String in array) {
				if (line.indexOf("** DEVICE LOCKED BY : ") > -1) {
					var firstIndex:int = line.length;
					var lastIndex:int = line.lastIndexOf("** DEVICE LOCKED BY : ") + "** DEVICE LOCKED BY : ".length;
					return line.substring(lastIndex, firstIndex).slice(0, -3);
				}
			}
			
			return null;
		}
		
		private  function onDriverError(event:ProgressEvent):void {
			const data:String = driverProcess.standardError.readUTFBytes(driverProcess.standardError.bytesAvailable);
			addLineToLogs(data);

			if (noProvisionningProfileError.test(data)) {
				error = "No provisioning profiles"
				errorMessage = "More informations in our Github page";
				dispose()
				return;
			}
			
			if (noCertificatesError.test(data)) {
				error = "Certificate error"
				errorMessage = "More informations in our Github page";
				dispose()
				return;
			}
			
			if (startInfoLocked.test(data)) {
				error = "Locked with passcode"
				errorMessage = "Please disable code and auto-lock in device settings";
				dispose()
				return;
			}
			
			if (noXcodeInstalled.test(data)) {
				error = "No XCode founded on this computer"
				errorMessage = "Go to AppStore for download it";
				dispose()
				return;
			}
			
			if (wrongVersionofxCode.test(data)) {
				error = "Your device need a more recent version of Xcode"
				errorMessage = "Go to AppStore for download it";
				dispose()
			}
		}
		
		protected function onDriverExit(ev:NativeProcessExitEvent):void {
			driverProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onDriverError);
			driverProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onDriverError);
			driverProcess.removeEventListener(NativeProcessExitEvent.EXIT, onDriverExit);
			
			writeLogs("test exit", "error");
			if (status == Simulator.SHUTDOWN) {
				dispatchEvent(new Event(STOPPED_EVENT));
			} else {
				failed();
			}
		}
		
		
		// --------------
		
		private function writeLogs(data:String, type:String = null):void {
			if (!data) { return }
			
			var logString:String = "[" + dateFormatter.format(new Date()) + "]"
			if (type) {
				logString += "[" + type.toUpperCase() + "]"
			}
			logString += " " + data
			
			logStream.open(logFile, FileMode.APPEND);
			logStream.writeUTFBytes(logString);
			logStream.close();
		}
		
		private function addLineToLogs(log: String):void {
			var file:File = driverDirectory.resolvePath("logs.txt");
			var fileStream:FileStream = new FileStream();
			if(file.exists) {
				fileStream.open(file, FileMode.APPEND);
				fileStream.writeUTFBytes(log);
			} else {
				fileStream.open(file, FileMode.WRITE);
				fileStream.writeUTFBytes(log);
			}
			
			fileStream.close();
		}
	}
}