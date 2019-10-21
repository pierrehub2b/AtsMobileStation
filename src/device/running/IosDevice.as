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
	
	import device.Device;
	import device.RunningDevice;
	import device.simulator.Simulator;
	
	public class IosDevice extends RunningDevice
	{
		private var output:String = "";
		
		private static const ATSDRIVER_DRIVER_HOST:String = "ATSDRIVER_DRIVER_HOST";
		
		private static const startInfo:RegExp = new RegExp(ATSDRIVER_DRIVER_HOST + "=(.*):(\\d+)");
		private static const startInfoLocked:RegExp = /isPasscodeLocked:(\s*)YES/
		private static const noProvisionningProfileError:RegExp = /Xcode couldn't find any iOS App Development provisioning profiles matching(\s*)/
		private static const noCertificatesError:RegExp = /signing certificate matching team ID(\s*)/	

		private var testingProcess:NativeProcess
		public var procInfo:NativeProcessStartupInfo;
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const xcodeBuildExec:File = new File("/usr/bin/env");
		
		public function IosDevice(id:String, name:String, simulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = ip;
			this.modelName = name;
			this.manufacturer = "Apple";
			this.simulator = simulator;
			
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
							automaticPort = (arrayLineAttributes[0] == "true");
							settingsPort = arrayLineAttributes[1];
						}
					}
				}
				fileStream.close();
			}
			
			var teamId:String = "";
			var lastBuildString:String = "";
			file = File.userDirectory.resolvePath("actiontestscript/settings.txt");
			if(file.exists) {
				
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				
				var settingsContent:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
				var settingsContentArray: Array = settingsContent.split("\n");
				
				for each(var setting:String in settingsContentArray) {
					if(setting != "") {
						var key:String = setting.split("==")[0];
						switch(key)
						{
							case "development_team":
							{
								teamId = setting.split("==")[1];
								break;
							}
								
							case "last_build":
							{
								lastBuildString = setting.split("==")[1];
								break;
							}
						}
					}
				}
				fileStream.close();
			}
			
			if(teamId == "" && !simulator) {
				trace("No Development Team ID set for " + name);
				status = Device.FAIL;
				errorMessage = " - No development team id set"
				return;
			}
			
			installing()
			
			testingProcess = new NativeProcess();
			testingProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError, false, 0, true);
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			
			var resultDir:File = File.userDirectory.resolvePath("Library/mobileStationTemp/driver_"+ id);
			var alreadyCopied:Boolean = resultDir.exists;
			iosDriverProjectFolder.copyTo(resultDir, true);
			var index:int = 0;
			file = resultDir.resolvePath("atsDriver/Settings.plist");
			var xcworkspaceFile:File = resultDir.resolvePath("atsios.xcworkspace");
			if(file.exists) {
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				content = fileStream.readUTFBytes(fileStream.bytesAvailable);
				arrayString = content.split("\n");
				
				for each(var lineSettings:String in arrayString) {
					if(lineSettings.indexOf("CFCustomPort") > 0) {
						if(!automaticPort) {
							arrayString[index+1] = "\t<string>"+ settingsPort +"</string>";
						} else {
							arrayString[index+1] = "\t<string></string>";
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
			
			if(lastBuildString != "") {
				var d:Date = new Date();
				d.setTime(Date.parse(lastBuildString));
				var modificationDate:int = (xcworkspaceFile.modificationDate.time/1000);
				var oldDate:int = (d.time/1000);
				alreadyCopied = !(modificationDate > oldDate)
			}
			
			var fileSettings:File = File.userDirectory.resolvePath("actiontestscript/settings.txt");
			var fileStreamSettings:FileStream = new FileStream();
			fileStreamSettings.open(fileSettings, FileMode.WRITE);
			fileStreamSettings.writeUTFBytes("development_team==" + teamId + "\n");
			fileStreamSettings.writeUTFBytes("last_build==" + xcworkspaceFile.modificationDate.toString());
			fileStreamSettings.close();
			
			procInfo = new NativeProcessStartupInfo()
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = resultDir;
			
			var args: Vector.<String> = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id];
			if(!simulator) {
				args.push("-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration", "DEVELOPMENT_TEAM=" + teamId);
			}
			
			if(!AtsMobileStation.alreadyBuilded) {
				AtsMobileStation.alreadyBuilded = true;
				args.push("test-without-building");
			} else {
				args.push("test");
			}
			
			procInfo.arguments = args;
		}
		
		public override function start():void{
			testingProcess.start(procInfo);
		}
		
		override public function dispose():Boolean
		{
			if(testingProcess != null && testingProcess.running){
				
				testingProcess.closeInput();
				testingProcess.exit();
				
				return true;
			}
			return false;
		}
		
		protected function onTestingExit(ev:NativeProcessExitEvent):void{
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput);
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
						
			testingProcess = null;
			procInfo = null;
			
			trace("testing exit");
			if(errorMessage == "" || status == Simulator.SHUTDOWN){
				dispatchEvent(new Event(STOPPED_EVENT));
			}else{
				failed();
			}
		}
		
		protected function onTestingOutput(event:ProgressEvent):void
		{
			const data:String = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);

			if(data.indexOf("** WIFI NOT CONNECTED **") > -1) {
				
				errorMessage = " - WIFI not connected !";
				testingProcess.exit();
				
			}else if(data.indexOf(ATSDRIVER_DRIVER_HOST) > -1){
				
				testingProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput);
				
				const find:Array = startInfo.exec(data);
				ip = find[1];
				port = find[2];
				started();
			}
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			const data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable);
			trace("test error -> " + data);
			
			if(noProvisionningProfileError.test(data)){
				errorMessage = " - No provisioning profiles !";
				testingProcess.exit();
			}
			
			if(noCertificatesError.test(data)){
				errorMessage = " - Certificate error !";
				testingProcess.exit();
			}
			
			if(startInfoLocked.test(data)){
				errorMessage = " - Locked with passcode !";
				testingProcess.exit();
			}
		}
	}
}