package com.ats.tools
{
import com.ats.helpers.Settings;
import com.ats.managers.gmsaas.GmsaasInstaller;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class Python extends EventDispatcher
	{
		public static const pythonFolderPath:String = "assets/tools/python";

		public static const workFolder:File = File.userDirectory.resolvePath("AppData/Roaming/Python/Python38")
		private static const scriptsFolder:File = File.applicationDirectory.resolvePath("assets/scripts")

		private static const updateScript:String = "update_app.py";
		private static const updateScriptMac:String = "update-macos-app.py";
		private static const getPipScript:String = "get-pip.py";

		public static var file:File;

		[Bindable]
		public static var folder:File;

		public static var path:String;

		private var updateProcInfo:NativeProcessStartupInfo;
		private var updateProc:NativeProcess;

		public function Python() {
			if (!Settings.isMacOs) {
				var assetsPythonFile:File = File.applicationDirectory.resolvePath(pythonFolderPath);
				if (assetsPythonFile.exists) {
					file = workFolder.resolvePath("python.exe");
					
					if (!workFolder.exists || !file.exists) {
						assetsPythonFile.copyTo(workFolder);
					}										
					
					folder = file.parent;
					path = folder.nativePath;
				}
			}
		}

		public function install():void {

			if (folder.resolvePath("Scripts").resolvePath(GmsaasInstaller.pipFileName).exists) {
				dispatchEvent(new Event(Event.COMPLETE));
				return
			}

			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = file;
			procInfo.workingDirectory = file.parent
			procInfo.arguments = new <String>[scriptsFolder.resolvePath(getPipScript).nativePath, "--no-warn-script-location"]

			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(NativeProcessExitEvent.EXIT, pipInstallExitHandler);
			proc.start(procInfo);
		}
		
		private function pipInstallExitHandler(ev:NativeProcessExitEvent):void{
			dispatchEvent(new Event(Event.COMPLETE));
		}
		
		public function updateApp(zipFile:File, appName:String):void{
			updateProcInfo = new NativeProcessStartupInfo();
			updateProcInfo.executable = file;
			updateProcInfo.workingDirectory = file.parent

			var path:String = File.applicationDirectory.nativePath;
			var parent:File = new File(path);
			parent = parent.parent;

			var script:File
			if (Settings.isMacOs) {
				script = scriptsFolder.resolvePath(updateScriptMac)
				appName += ".app"
				updateProcInfo.arguments = new <String>[StringHelper.unescapeFilePath(script), StringHelper.unescapeFilePath(zipFile), StringHelper.unescapeFilePath(parent), appName]
			} else {
				script = scriptsFolder.resolvePath(updateScript)
				appName += ".exe"
				updateProcInfo.arguments = new <String>[StringHelper.unescapeFilePath(script), StringHelper.unescapeFilePath(zipFile), StringHelper.unescapeFilePath(parent), File.applicationDirectory.name, appName, "&"]
			}

			updateProc = new NativeProcess();
			updateProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onUpdateProcessStarted, false, 0, true);
			updateProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			updateProc.addEventListener(NativeProcessExitEvent.EXIT, processJavaExit, false, 0, true);
		}
		
		private function onUpdateProcessStarted(event:ProgressEvent):void{
			var phase:String = updateProc.standardOutput.readUTFBytes(updateProc.standardOutput.bytesAvailable);
			trace(phase)
		}
		
		public function onOutputErrorShell(event:ProgressEvent):void
		{
			trace(updateProc.standardError.readUTFBytes(updateProc.standardError.bytesAvailable));
		}
		
		public function processJavaExit(event:NativeProcessExitEvent):void
		{
			trace("exit");
		}
		
		public function executeUpdate():void{
			if(updateProc != null){
				updateProc.start(updateProcInfo);
			}
		}

		// ---------

		private var outputData:String
		private var errorData:String

		public function setupMacOsPath():void {
			var startupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			startupInfo.executable = new File("/usr/bin/env")
			startupInfo.arguments = new <String>["which", "python3"]

			outputData = ""
			errorData = ""

			var process:NativeProcess = new NativeProcess()
			process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, process_standardOutputDataHandler)
			process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, process_standardErrorDataHandler)
			process.addEventListener(NativeProcessExitEvent.EXIT, process_exitHandler)
			process.start(startupInfo)
		}

		private function process_standardOutputDataHandler(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			outputData += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
		}

		private function process_standardErrorDataHandler(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			errorData += process.standardError.readUTFBytes(process.standardError.bytesAvailable)
		}

		private function process_exitHandler(event:NativeProcessExitEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, process_standardOutputDataHandler)
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, process_standardErrorDataHandler)
			process.removeEventListener(NativeProcessExitEvent.EXIT, process_exitHandler)

			if (errorData) {
				trace(errorData)
			}

			if (outputData) {
				file = new File(outputData.replace("\n", ""))
				folder = file.parent
				path = folder.nativePath
			}

			outputData = null
			errorData = null

			dispatchEvent(new Event(Event.COMPLETE))
		}

		public function startHttpServer():void {
			var process:NativeProcess = new NativeProcess()
			var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
			info.executable = file
			info.workingDirectory = File.userDirectory.resolvePath(".atsmobilestation").resolvePath("http")

			if (Settings.isMacOs) {
				info.arguments = new <String>["-m", "80"]
			} else {
				info.arguments = new <String>["-m", "http.server", "80"]
			}

			process.start(info)
		}
	}
}