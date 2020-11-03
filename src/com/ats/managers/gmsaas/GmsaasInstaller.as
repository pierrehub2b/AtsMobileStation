package com.ats.managers.gmsaas {
import com.ats.helpers.Settings;
import com.ats.tools.Python;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.EventDispatcher;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class GmsaasInstaller extends EventDispatcher {
		
		public static const GMSAAS_INSTALLER_STATE_INSTALLING:String = "Installing GMSAAS"
		public static const GMSAAS_INSTALLER_STATE_INSTALL_COMPLETED:String = "GMSAAS configuration completed"
		public static const GMSAAS_INSTALLER_STATE_UNINSTALLING:String = "Uninstalling GMSAAS"
		public static const GMSAAS_INSTALLER_STATE_UNINSTALL_COMPLETED:String = "GMSAAS uninstall completed"
				
		public static const pipFileName:String = "pip3.exe"
		
		private var gmsaasFile:File

		public function install():void {
			if (Settings.isMacOs) {
				dispatchEvent(new GmsaasInstallerErrorEvent("MacOS is not supported yet !"))
				return
			}

			var pipFile:File = Python.folder.resolvePath("Scripts").resolvePath(pipFileName);
			
			if(pipFile.exists){
				dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_INSTALLING))
				
				var args:Vector.<String> = new Vector.<String>();
				args.push("install");
				args.push("--upgrade");
				args.push("gmsaas");
				args.push("--user")
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = Python.workFolder.resolvePath("Scripts").resolvePath(pipFileName);
				procInfo.arguments = args;
				
				var newProc:NativeProcess = new NativeProcess();
				newProc.addEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
				newProc.start(procInfo);
			}else{
				dispatchEvent(new GmsaasInstallerErrorEvent(pipFileName + " file not found !"))
			}
		}
		
		private function gmInstallExit(event:NativeProcessExitEvent):void {
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmInstallExit);
			
			gmsaasFile = Python.folder.resolvePath("Scripts").resolvePath(GmsaasProcess.gmsaasFileName);
			if (!gmsaasFile.exists) {
				dispatchEvent(new GmsaasInstallerErrorEvent("GMSAAS file not found !"))
				return
			}
			
			defineJSONOutputFormat()
			defineAndroidSdk()
			
			dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_INSTALL_COMPLETED))
		}
		
		private function defineAndroidSdk():void {
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["config", "set", "android-sdk-path", Settings.workAdbFolder.nativePath];
			
			var proc:NativeProcess = new NativeProcess();
			proc.start(procInfo);
		}
		
		private function defineJSONOutputFormat():void {
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["config", "set", "output-format", "compactjson"];
			
			var proc:NativeProcess = new NativeProcess();
			proc.start(procInfo);
		}

		public function uninstall():void {
			
			var pipFile:File = Python.folder.resolvePath("Scripts").resolvePath(pipFileName);
			if (!pipFile.exists) {
				dispatchEvent(new GmsaasInstallerErrorEvent("PIP file not found !"))
				return
			}
			
			dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_UNINSTALLING))
			
			var args:Vector.<String> = new Vector.<String>();
			args.push("uninstall");
			args.push("gmsaas");
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = pipFile;
			procInfo.arguments = args;
			
			var newProc:NativeProcess = new NativeProcess();
			newProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, uninstallOutputDataHandler);
			newProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, uninstallErrorDataHandler);
			newProc.addEventListener(NativeProcessExitEvent.EXIT, uninstallExit);
			newProc.start(procInfo);
		}
		
		private function uninstallExit(event:NativeProcessExitEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(NativeProcessExitEvent.EXIT, uninstallExit)
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, uninstallOutputDataHandler);
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, uninstallErrorDataHandler);
			
			try {
				GmsaasProcess.gmsaasExec.deleteFile();
			} catch (err:Error) {
				trace("gmsass file not found")
			} finally {
				dispatchEvent(new GmsaasInstallerProgressEvent(GMSAAS_INSTALLER_STATE_UNINSTALL_COMPLETED))
			}
		}
		
		private function uninstallErrorDataHandler(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable))
		}
		
		private function uninstallOutputDataHandler(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			var outputData:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
			
			if (outputData.indexOf("Proceed (y/n)?") > -1) {
				process.standardInput.writeUTFBytes("y\r\n")
			}
		}
	}
}
