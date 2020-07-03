package com.ats.managers.gmsaas {
import com.ats.tools.Python;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class GmsaasProcess extends NativeProcess {
		
		public static const gmsaasFileName:String = "gmsaas.exe"
			
		public static function get gmsaasExec():File {
			const gm:File = Python.file.parent.resolvePath("Scripts").resolvePath(gmsaasFileName);
			if(gm.exists){
				return gm;
			}
			return null;
		}
		
		public static function startProcess(args:Array, callback:Function):void{
			const gmFile:File = gmsaasExec
			if(gmFile != null){
				var arguments:Vector.<String> = new <String>["--format", "compactjson"]
				for each (var arg:String in args) {
					arguments.push(arg);
				}
				new GmsaasProcess(gmFile, arguments, callback).run();
			}else{
				callback({error:{message:"GMSAAS executable file not found !"}})
			}
		}
		
		private var data:String = "";
		private var callback:Function;
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		public function GmsaasProcess(gmsaasFile:File, arguments:Vector.<String>, callback:Function) {
			this.callback = callback;
			this.procInfo.executable = gmsaasFile;
			this.procInfo.arguments = arguments;
		}
		
		public function run():void{
			addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procOutputDataHandler, false, 0, true)
			addEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErrorDataHandler, false, 0, true)
			addEventListener(NativeProcessExitEvent.EXIT, procExitHandler, false, 0, true)
			start(procInfo)
		}
		
		private function procOutputDataHandler(event:ProgressEvent):void {
			data += standardOutput.readUTFBytes(standardOutput.bytesAvailable)
		}
		
		private function procErrorDataHandler(event:ProgressEvent):void {
			data += standardError.readUTFBytes(standardError.bytesAvailable)
		}
		
		private function procExitHandler(ev:NativeProcessExitEvent):void{
			removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, procOutputDataHandler)
			removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, procErrorDataHandler)
			removeEventListener(NativeProcessExitEvent.EXIT, procExitHandler);
			
			try {
				callback(JSON.parse(data));
			} catch (error:Error) {
				callback({error:{message:error.message}});
			}
			
			procInfo = null;
			callback = null;
		}
	}
}