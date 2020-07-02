package com.ats.tools
{
	import com.ats.managers.gmsaas.GmsaasInstaller;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.NativeProcessExitEvent;
	import flash.filesystem.File;
	
	public class Python extends EventDispatcher
	{
		public static const pythonFolderPath:String = "assets/tools/python";
		
		public static var file:File;
		public static var folder:File;
		public static var path:String;
		
		public static var gmsaasInstalled:Boolean = false;
		
		public function Python(workFolder:File):void{
			var assetsPythonFile:File = File.applicationDirectory.resolvePath(pythonFolderPath);
			if (assetsPythonFile.exists) {
				var workPythonFile:File = workFolder.resolvePath("python");
				if(!workPythonFile.exists){
					assetsPythonFile.copyTo(workPythonFile);
				}
				file = workPythonFile.resolvePath("python.exe");
				folder = file.parent;
				path = folder.nativePath;
			}
		}
		
		public function install():void{
			if(file == null){
				dispatchEvent(new Event(Event.COMPLETE));
			}else{
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = file;
				procInfo.workingDirectory = file.parent;
				procInfo.arguments = new <String>["get-pip.py", "--no-warn-script-location"]
				
				var proc:NativeProcess = new NativeProcess();
				proc.addEventListener(NativeProcessExitEvent.EXIT, pipInstallExitHandler);
				proc.start(procInfo);
			}
		}
		
		private function pipInstallExitHandler(ev:NativeProcessExitEvent):void{
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}
}