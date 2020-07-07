package com.ats.tools
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

public class Python extends EventDispatcher
	{
		public static const pythonFolderPath:String = "assets/tools/python";
		
		public static var file:File;
		public static var folder:File;
		public static var path:String;
		
		private static const updateScript:String = "update_app.py";
		
		private var updateProcInfo:NativeProcessStartupInfo;
		private var updateProc:NativeProcess;

		public function Python(workFolder:File):void{
			var assetsPythonFile:File = File.applicationDirectory.resolvePath(pythonFolderPath);
			if (assetsPythonFile.exists) {
				var workPythonFile:File = workFolder.resolvePath("python");
				if (!workPythonFile.exists) {
					assetsPythonFile.copyTo(workPythonFile);
				}
				file = workPythonFile.resolvePath("python.exe");
				folder = file.parent;
				path = folder.nativePath;
			}
		}

		public function install():void {
			if (folder.resolvePath("Scripts").resolvePath("pip3.exe").exists) {
				dispatchEvent(new Event(Event.COMPLETE));
				return
			}

			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = file;
			procInfo.workingDirectory = file.parent;
			procInfo.arguments = new <String>["get-pip.py", "--no-warn-script-location"]

			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(NativeProcessExitEvent.EXIT, pipInstallExitHandler);
			proc.start(procInfo);
		}
		
		private function pipInstallExitHandler(ev:NativeProcessExitEvent):void{
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function updateApp(zipFile:File, appName:String):void{
			
			appName += ".exe";
			
			var script:File = folder.resolvePath(updateScript);
			File.applicationDirectory.resolvePath("assets/scripts").resolvePath(updateScript).copyTo(script, true);
			
			updateProcInfo = new NativeProcessStartupInfo();
			updateProcInfo.executable = file;
			updateProcInfo.workingDirectory = file.parent;
			
			var path:String = File.applicationDirectory.nativePath;
			var parent:File = new File(path);
			parent = parent.parent;
			
			updateProcInfo.arguments = new <String>[StringHelper.unescapeFilePath(script), StringHelper.unescapeFilePath(zipFile), StringHelper.unescapeFilePath(parent), File.applicationDirectory.name, appName, "&"]
			updateProc = new NativeProcess();
			updateProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUpdateProcessStarted, false, 0, true);
			updateProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			updateProc.addEventListener(NativeProcessExitEvent.EXIT, processJavaExit, false, 0, true);
		}
		
		private function onUpdateProcessStarted(event:ProgressEvent):void{
			//var phase:String = updateProc.standardOutput.readUTFBytes(updateProc.standardOutput.bytesAvailable);
			//trace(phase)
		}
		
		public function onOutputErrorShell(event:ProgressEvent):void
		{
			//trace(updateProc.standardError.readUTFBytes(updateProc.standardError.bytesAvailable));
		}
		
		public function processJavaExit(event:NativeProcessExitEvent):void
		{
			//trace("exit");
		}
		
		public function executeUpdate():void{
			if(updateProc != null){
				updateProc.start(updateProcInfo);
			}
		}
	}
}