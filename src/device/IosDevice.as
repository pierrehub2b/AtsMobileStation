package device
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import mx.core.FlexGlobals;
	
	public class IosDevice extends Device
	{
		private var output:String = "";
		
		private static const startInfo:RegExp = /ATSDRIVER_DRIVER_HOST=(.*):(\d+)/
		
		private var testingProcess:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		//private var testingProcessPhysical:NativeProcess = new NativeProcess();
		//private var procInfoPhysical:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private static const iosDriverProjectFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		private static const xcodeBuildExec:File = new File("/usr/bin/env");
		
		public function IosDevice(id:String, name:String, version:String, isSimulator:Boolean, ip:String)
		{
			this.id = id;
			this.ip = ip;
			this.modelName = name + "(" + version + ")";
			this.manufacturer = "Apple";
			this.isSimulator = isSimulator;
			this.isCrashed = false;
			this.connected = !isSimulator;
			
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
			file = File.userDirectory.resolvePath("actiontestscript/developmentDevTeam.txt");
			if(file.exists) {
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				teamId = fileStream.readUTFBytes(fileStream.bytesAvailable);
				fileStream.close();
			}
		
			installing()
			testingProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingOutput, false, 0, true);
			testingProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError, false, 0, true);
			testingProcess.addEventListener(NativeProcessExitEvent.EXIT, onTestingExit, false, 0, true);
			
			//testingProcessPhysical.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onTestingPhysicalOutput, false, 0, true);
			
			/*var resultDir:File = File.documentsDirectory.resolvePath("tmpDir/driver_"+ id);
			iosDriverProjectFolder.copyTo(resultDir, true);
			var index:int = 0;
			file = resultDir.resolvePath("atsDriver/Settings.plist");
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
			}*/
			
			/*var isDebug:Boolean = false;
			var isRelease:Boolean = false;
			file = resultDir.resolvePath("atsios.xcodeproj/project.pbxproj");
			if(file.exists) {
				fileStream = new FileStream();
				fileStream.open(file, FileMode.READ);
				content = fileStream.readUTFBytes(fileStream.bytesAvailable);
				arrayString = content.split("\n");
				var indexDevTeam:int = 0;
				for each(var lineDevTeam:String in arrayString) {
					if(lineDevTeam.indexOf("/* Debug *//* = {") > -1) {
						isDebug = true;
						isRelease = false;
					}*/
					
					/*if(lineDevTeam.indexOf("/* Release */ /*= {") > -1) {
						isDebug = false;
						isRelease = true;
					}*/
					
					//if(lineDevTeam.indexOf("CODE_SIGN_STYLE") > 0) {
						//if(teamId != "") {
							//arrayString[indexDevTeam] = "\t\t\t\tCODE_SIGN_STYLE = Automatic;";
							//} else {
							//	arrayString[indexDevTeam] = "\t\t\t\tCODE_SIGN_STYLE = Manual;";
						//}
					//}
					/*if(lineDevTeam.indexOf("DEVELOPMENT_TEAM") > 0 && isDebug) {
						if(teamId != "") {
							arrayString[indexDevTeam] = "\t\t\t\tDEVELOPMENT_TEAM = "+ teamId +";";
						}
					}
					indexDevTeam++;
				}
				fileStream.close();
				
				writeFileStream = new FileStream();
				writeFileStream.open(file, FileMode.UPDATE);
				for each(var strDevTeam:String in arrayString) {
					writeFileStream.writeUTFBytes(strDevTeam + "\n");
				}
				writeFileStream.close();
			}*/
			
			procInfo.executable = xcodeBuildExec;
			procInfo.workingDirectory = IosDriverCompiler.getProjectFolder(name);
			
			//procInfoPhysical.executable = xcodeBuildExec;
			//procInfoPhysical.workingDirectory = resultDir;
			
			output = "";
			
			procInfo.arguments = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "id=" + id, "test-without-building"];;
			//procInfoPhysical.arguments = args;
			
			//if(isSimulator) {
				testingProcess.start(procInfo);
			//} else {
				//testingProcessPhysical.start(procInfoPhysical);
			//}
			
		}
		
		override public function dispose():Boolean
		{
			testingProcess.exit(true);
			return true;
		}
				
		protected function onTestingExit(ev:NativeProcessExitEvent):void{
			testingProcess.removeEventListener(NativeProcessExitEvent.EXIT, onTestingExit);
			
			trace("testing exit");
			FlexGlobals.topLevelApplication.devices.restartDev(this);
		}
		
		protected function onTestingOutput(event:ProgressEvent):void
		{
			var data:String = testingProcess.standardOutput.readUTFBytes(testingProcess.standardOutput.bytesAvailable);
			output += data;
			
			var find:Array = startInfo.exec(data);
			if(find != null){
				ip = find[1];
				port = find[2];
				started();
			}
		}
		
		/*protected function onTestingPhysicalOutput(event:ProgressEvent):void
		{
			var data:String = testingProcessPhysical.standardOutput.readUTFBytes(testingProcessPhysical.standardOutput.bytesAvailable);
			trace("test output -> " + data);
			var find:Array = startInfo.exec(data);
			if(find != null){
				ip = find[1];
				port = find[2];
				started();
				testingProcessPhysical.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingPhysicalError, false, 0, true);
			}
			
		}*/
		
		protected function onTestingError(event:ProgressEvent):void
		{
			testingProcess.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			
			var data:String = testingProcess.standardError.readUTFBytes(testingProcess.standardError.bytesAvailable);
			trace("test error -> " + data);
			if(data.indexOf("Continuing with testing") < 0 && data.indexOf("** TEST EXECUTE FAILED **") > 0 || data.indexOf("** TEST FAILED **") > 0){
				this.changeCrashedStatus();
			}
		}
		
		/*protected function onTestingPhysicalError(event:ProgressEvent):void
		{
			testingProcessPhysical.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onTestingError);
			
			var data:String = testingProcessPhysical.standardError.readUTFBytes(testingProcessPhysical.standardError.bytesAvailable);
			trace("test error -> " + data);
			if(data.indexOf("Continuing with testing") < 0 && data.indexOf("** TEST EXECUTE FAILED **") > 0 || data.indexOf("** TEST FAILED **") > 0){
				this.changeCrashedStatus();
			}
		}*/
		
		protected function changeCrashedStatus():void {
			this.isCrashed = true
		}
	}
}