package device.running
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;

import helpers.DevicePortSettings;
import helpers.DevicePortSettingsHelper;

import mx.core.FlexGlobals;
	
	import device.Device;
	import device.RunningDevice;
	import device.simulator.Simulator;

import helpers.DeviceSettings;

import helpers.DeviceSettingsHelper;

import helpers.PortSwitcher;

public class IosDevice extends RunningDevice
	{
		private static const ATSDRIVER_DRIVER_HOST:String = "ATSDRIVER_DRIVER_HOST";
		
		private static const startInfo:RegExp = new RegExp(ATSDRIVER_DRIVER_HOST + "=(.*):(\\d+)");
		private static const startInfoLocked:RegExp = /isPasscodeLocked:(\s*)YES/;
		private static const noProvisionningProfileError:RegExp = /Xcode couldn't find any iOS App Development provisioning profiles matching(\s*)/;
		private static const noCertificatesError:RegExp = /signing certificate matching team ID(\s*)/;
		private static const noXcodeInstalled:RegExp = /requires Xcode(\s*)/;
		private static const wrongVersionofxCode:RegExp = /which may not be supported by this version of Xcode(\s*)/;

		private var testingProcess:NativeProcess;
		public var procInfo:NativeProcessStartupInfo;
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const xcodeBuildExec:File = new File("/usr/bin/env");
		private static const iosMobileDeviceTools:File = File.applicationDirectory.resolvePath("assets/tools/ios");
		
		private var resultDir: File;

		public function IosDevice(id:String, name:String, simulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = ip;
			this.modelName = name;
			this.manufacturer = "Apple";
			this.simulator = simulator;

			var fileStream:FileStream = new FileStream();
			var file:File = FlexGlobals.topLevelApplication.devicesSettingsFile;

			trace("Getting settings configuration for device:" + id);

			var deviceSettingsHelper:DeviceSettingsHelper = DeviceSettingsHelper.shared;
			var deviceSettings:DeviceSettings = deviceSettingsHelper.getSettingsForDevice(id);
			if (deviceSettings == null) {
				deviceSettings = new DeviceSettings(id);
				deviceSettingsHelper.save(deviceSettings);
			}

			automaticPort = deviceSettings.automaticPort;

			if (simulator == true) {
				var portSwitcher:PortSwitcher = new PortSwitcher();
				settingsPort = portSwitcher.getLocalPort(id, automaticPort).toString();
			} else {
				settingsPort = deviceSettings.port.toString();
			}

			if (simulator) {
				var devicePortSettings:DevicePortSettings = DevicePortSettingsHelper.shared.getPortSetting(id);
				devicePortSettings.port = parseInt(settingsPort);
				DevicePortSettingsHelper.shared.addSettings(devicePortSettings);
			}

			if(FlexGlobals.topLevelApplication.getTeamId() == "" && !simulator) {
				status = Device.FAIL;
				errorMessage = " - No development team id set";
				return;
			}
			
			installing();
			trace("installing the driver");
			testingProcess = new NativeProcess();
			testingProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError, false, 0, true);
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			
			trace("Copy files into temp directory");
			resultDir = File.userDirectory.resolvePath("Library/mobileStationTemp/driver_"+ id);
			var alreadyCopied:Boolean = resultDir.exists;
			if(!alreadyCopied) {
				iosDriverProjectFolder.copyTo(resultDir, true);
			}

			trace("Managing plist file");
			var index:int = 0;
			file = resultDir.resolvePath("atsDriver/Settings.plist");
			if(file.exists && settingsPort != "") {
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				var content:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
				var arrayString:Array = content.split("\n");
				
				for each(var lineSettings:String in arrayString) {
					if(lineSettings.indexOf("CFCustomPort") > -1) {
						if (automaticPort) {
							arrayString[index+1] = "\t<string></string>";
						} else {
							arrayString[index+1] = "\t<string>" + settingsPort + "</string>";
						}
						break;
					}
					index++;
				}				
				fileStream.close();
				
				var writeFileStream:FileStream = new FileStream();
				writeFileStream.open(file, FileMode.UPDATE);
				for each(var str:String in arrayString) {
					writeFileStream.writeUTFBytes(str + "\n");
				}
				writeFileStream.close();
			}
			
			procInfo = new NativeProcessStartupInfo();
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = resultDir;
			
			var args: Vector.<String> = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id];
			if(!simulator) {
				args.push("-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration", "DEVELOPMENT_TEAM=" + FlexGlobals.topLevelApplication.getTeamId());
			}
			
			if(alreadyCopied) {
				args.push("test-without-building");
				trace("test without building on device with id:" + id + " at " + new Date())
			} else {
				args.push("test");
				trace("build and test on device with id:" + id + " at " + new Date())
			}
			getBundleIds(id);
			procInfo.arguments = args;
		}

		protected function addLineToLogs(log: String):void {
			var file:File = resultDir.resolvePath("logs.txt");
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
		
		protected function onGettingBundlesOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess;			
			var apps:Array = proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable).split("\n");			
			var pListFile:File = resultDir.resolvePath("atsDriver/Settings.plist");
			if(pListFile.exists) {
				var fileStreamMobileDevice:FileStream = new FileStream();
				fileStreamMobileDevice.open(pListFile, FileMode.READ);
				var pListContent:String = fileStreamMobileDevice.readUTFBytes(fileStreamMobileDevice.bytesAvailable);
				var arrayStringPList:Array = pListContent.split("\n");				
				fileStreamMobileDevice.close();
				
				var newArray:Array = [];
				var removeNextIndex:Boolean = false;
				for each(var str:String in arrayStringPList) {
					if(str.indexOf("CFAppBundleID") == -1 && !removeNextIndex) {
						newArray.push(str);
					}
					
					removeNextIndex = false;
					if(str.indexOf("CFAppBundleID") > -1) {
						removeNextIndex = true;
					}
				}
				
				var indexApp: int = 0;
				for each (var a:String in apps) 
				{
					if(a != "") {
						newArray.insertAt(4, "\t<key>CFAppBundleID" + indexApp +"</key>\n\t<string>"+a+"</string>");
						indexApp++;
					}
				}
				
				pListFile.deleteFile();
				var file:File = resultDir.resolvePath("atsDriver/Settings.plist");
				var stream:FileStream = new FileStream();
				stream.open(file, FileMode.WRITE);
				for each(var strArray:String in newArray) {
					stream.writeUTFBytes(strArray + "\n");
				}
				stream.close();
			} else {
				trace("Erreur à la génération du fichier settings.plist");
				resultDir.deleteDirectory(true);
				testingProcess.exit();
			}
			
			proc.exit();
		}
		
		public function getBundleIds(id: String):void 
		{
			//Getting App list
			var mobileDeviceProcess:NativeProcess = new NativeProcess();
			var mobileDeviceProcessInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			mobileDeviceProcessInfo.executable = new File("/usr/bin/env");
			mobileDeviceProcessInfo.workingDirectory = iosMobileDeviceTools;
			var args: Vector.<String> = new <String>["./mobiledevice", "list_apps", "-u", id];
			mobileDeviceProcessInfo.arguments = args;
			mobileDeviceProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onGettingBundlesOutput, false, 0, true);
			mobileDeviceProcess.start(mobileDeviceProcessInfo);
		}
		
		public override function start():void{
			//Getting App list
			var mobileDeviceProcess:NativeProcess = new NativeProcess();
			var mobileDeviceProcessInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			mobileDeviceProcessInfo.executable = new File("/usr/bin/env");
			mobileDeviceProcessInfo.workingDirectory = iosMobileDeviceTools;
			var args: Vector.<String> = new <String>["./mobiledevice", "uninstall_app", "-u", id, "com.atsios.xctrunner"];
			mobileDeviceProcessInfo.arguments = args;
			mobileDeviceProcess.addEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
			mobileDeviceProcess.start(mobileDeviceProcessInfo);
		}
		
		override public function dispose():Boolean
		{
			if (testingProcess != null && testingProcess.running) {
				testingProcess.closeInput();
				testingProcess.exit();
				return true;
			}
			return false;
		}
		
		protected function onUninstallExit(ev:NativeProcessExitEvent):void
		{
			ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onUninstallExit);
			testingProcess.start(procInfo);
		}
		
		protected function onTestingExit(ev:NativeProcessExitEvent):void
		{
			removeReceivers();
			trace("testing exit");
			if (errorMessage == "" || status == Simulator.SHUTDOWN) {
				dispatchEvent(new Event(STOPPED_EVENT));
			} else {
				failed();
			}
		}
		
		protected function onTestingOutput(event:ProgressEvent):void
		{
			const data:String = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);

			if (data.indexOf("** WIFI NOT CONNECTED **") > -1) {
				errorMessage = " - WIFI not connected !";
				removeReceivers();
				testingProcess.exit();
			} else if (data.indexOf("** Port unavailable **") > -1) {
				errorMessage = " - Unavailable port !";
				removeReceivers();
				testingProcess.exit();
			} else if(data.indexOf(ATSDRIVER_DRIVER_HOST) > -1) {
				const find:Array = startInfo.exec(data);
				ip = find[1];
				port = find[2];
				removeReceivers();
				if (simulator) {
					var devicePortSettings:DevicePortSettings = DevicePortSettingsHelper.shared.getPortSetting(id);
					devicePortSettings.port = parseInt(port);
					DevicePortSettingsHelper.shared.addSettings(devicePortSettings);
				}
				
				removeReceivers();
				testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
				started();
			}
		}

		protected function removeReceivers():void {
			testingProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			const data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable);
			addLineToLogs(data);
			
			if (noProvisionningProfileError.test(data)) {
				errorMessage = "No provisioning profiles\nMore informations in our Github page";
				testingProcess.exit();
				removeReceivers();
				return;
			}

			if (noCertificatesError.test(data)) {
				errorMessage = "Certificate error\nMore informations in our Github page";
				testingProcess.exit();
				removeReceivers();
				return;
			}

			if (startInfoLocked.test(data)) {
				errorMessage = "Locked with passcode. Please disable code\n and auto-lock in device settings";
				testingProcess.exit();
				removeReceivers();
				return;
			}

			if (noXcodeInstalled.test(data)) {
				errorMessage = "No XCode founded on this computer\nGo to AppStore for download it";
				testingProcess.exit();
				removeReceivers();
				return;
			}

			if (wrongVersionofxCode.test(data)) {
				errorMessage = "Your device need a more recent version\n of xCode. Go to AppStore for download it";
				testingProcess.exit();
				removeReceivers();
				return;
			}
		}
	}
}