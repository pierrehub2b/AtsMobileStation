package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	
	import mx.utils.StringUtil;

	public class IosDriverCompiler extends EventDispatcher
	{
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var compileProcess:NativeProcess = new NativeProcess();
		private var compileOutput:String = "";
		
		private static const workingFolder:File = File.userDirectory.resolvePath("mobilestation/driver");
		private const driverSourceFolder:File = File.applicationDirectory.resolvePath("assets/drivers/ios");
		
		public var simulatorList:Array;
		private var currentPort:int = 8080;
		
		public function IosDriverCompiler()
		{
			if(workingFolder.exists){
				workingFolder.deleteDirectory(true);
			}
						
			procInfo.executable = new File("/usr/bin/env");
			
			compileProcess.addEventListener(NativeProcessExitEvent.EXIT, onCompileExit, false, 0, true);
			//compileProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onErrorCompileData, false, 0, true);
			//compileProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onReadCompileData, false, 0, true);
		}
				
		public static function getProjectFolder(name:String):File{
			return workingFolder.resolvePath(name);
		}
		
		public function start():void{
			
			if(simulatorList.length > 0){
				
				var model:Object = simulatorList.pop();
				procInfo.workingDirectory = createProject(model.name);
				
				procInfo.arguments = new <String>["xcodebuild", "-workspace", "atsios.xcworkspace", "-scheme", "atsios", "-destination", "platform=iOS Simulator,name=" + model.name, "build-for-testing"];			
				compileProcess.start(procInfo);
				
			}else{
				
				compileProcess.removeEventListener(NativeProcessExitEvent.EXIT, onCompileExit);
				//compileProcess.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadCompileData);
				
				procInfo = null;
				procInfo = null;
				
				dispatchEvent(new Event(Event.COMPLETE));
			}
		}
		
		protected function onReadCompileData(event:ProgressEvent):void{
			compileOutput += StringUtil.trim(compileProcess.standardOutput.readUTFBytes(compileProcess.standardOutput.bytesAvailable));
		}
		
		protected function onErrorCompileData(event:ProgressEvent):void{
			compileOutput += StringUtil.trim(compileProcess.standardError.readUTFBytes(compileProcess.standardError.bytesAvailable));
		}
		
		protected function onCompileExit(event:NativeProcessExitEvent):void
		{
			currentPort++;
			start();
		}
		
		private function createProject(model:String):File{
			
			var projectFolder:File = workingFolder.resolvePath(model);
			if(projectFolder.exists){
				projectFolder.deleteDirectory(true);
			}
			
			driverSourceFolder.copyTo(projectFolder, true);
			
			var settingsFile:File = projectFolder.resolvePath("atsDriver/Settings.plist");
			if(settingsFile.exists) {
				var fileStream:FileStream  = new FileStream();
				fileStream.open(settingsFile, FileMode.READ);
				
				var content:String = fileStream.readUTFBytes(fileStream.bytesAvailable);
				var arrayString:Array = content.split("\n");
				
				var index:int = 0;
				for each(var lineSettings:String in arrayString) {
					if(lineSettings.indexOf("CFCustomPort") > 0) {
						arrayString[index+1] = "\t<string>"+ currentPort +"</string>";
						break;
					}
					index++;
				}
				fileStream.close();
				
				fileStream = new FileStream();
				
				fileStream.open(settingsFile, FileMode.UPDATE);
				for each(var str:String in arrayString) {
					fileStream.writeUTFBytes(str + "\n");
				}
				fileStream.close();
			}
			
			return projectFolder
		}
	}
}