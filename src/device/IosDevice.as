package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	public class IosDevice extends Device
	{
		private var output:String = "";
		
		private static const startInfo:RegExp = /ATSDRIVER_DRIVER_HOST=(.*):(\d+)/
		
		private var testingProcess:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const xcodeBuildExec:File = new File("/usr/bin/env");
		
		public function IosDevice(id:String, name:String, isSimulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = ip;
			this.modelName = name;
			this.manufacturer = "Apple";
			this.isSimulator = isSimulator;
			this.isCrashed = false;
			this.connected = !isSimulator;
			this.errorMessage = "";
			
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
		
			installing()
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
			
			if(lastBuildString != "" && !isSimulator) {
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
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = resultDir;
			
			var args: Vector.<String> = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id];
			if(!isSimulator) {
				args.push("-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration", "DEVELOPMENT_TEAM=" + teamId);
			}
			if(alreadyCopied) {
				args.push("test-without-building");
			} else {
				args.push("test");
			}
			
			procInfo.arguments = args;
			testingProcess.start(procInfo);
		}
		
		override public function dispose():Boolean
		{
			testingProcess.exit(true);
			errorMessage = "";
			return true;
		}
				
		protected function onTestingExit(ev:NativeProcessExitEvent):void{
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
			
			trace("testing exit");
			errorMessage = "";
			AtsMobileStation.devices.restartDev(this);
		}
		
		protected function onTestingOutput(event:ProgressEvent):void
		{
			var data:String = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);
			trace("test output -> " + data);
			
			if(data.indexOf("** WIFI NOT CONNECTED **") > -1) {
				this.errorMessage = "WIFI not connected";
			}
			
			var find:Array = startInfo.exec(data);
			if(find != null){
				errorMessage = "";
				ip = find[1];
				port = find[2];
				started();
			}
		}
		
		protected function onTestingError(event:ProgressEvent):void
		{
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			
			var data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable);
			trace("test error -> " + data);
			if(data.indexOf("Continuing with testing") < 0 && data.indexOf("** TEST EXECUTE FAILED **") > 0 || data.indexOf("** TEST FAILED **") > 0){
				this.changeCrashedStatus();
			}
			if(data.indexOf(id + " was NULL") > -1) {
				this.errorMessage = "Device locked";
			}
		}
		
		protected function changeCrashedStatus():void {
			this.isCrashed = true
		}
	}
}