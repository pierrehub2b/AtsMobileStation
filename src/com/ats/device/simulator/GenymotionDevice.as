package com.ats.device.simulator
{
	import com.adobe.utils.StringUtil;
	
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;

	[Bindable]
	public class GenymotionDevice
	{
		public var id:String;
		public var name:String;
		public var version:String;
		public var width:int;
		public var height:int;
		public var dpi:int;		
		public var status:String = "offline";
			
		public function GenymotionDevice(data:Array, gmsaas:File)
		{
			id = data[1];
			name = StringUtil.trim(data[2]);
			version = data[3];
			width = parseInt(data[5]);
			height = parseInt(data[6]);
			dpi = parseInt(data[7]);
			
			this.gmsaasFile = gmsaas;
		}

		private var gmsaasFile:File;
		private var loadData:String;
		
		public function startInstance():void{
			status = "starting"
			loadData = "";
			
			var args:Vector.<String> = new Vector.<String>();
			args.push("instances");
			args.push("start");
			args.push(id);
			args.push("GenymotionMobile");
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = args;
			
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);
			
			proc.start(procInfo);
		}
		
		private function gmsaasInstanceStartOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		private function gmsaasInstanceStartExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);
			
			loadData = StringUtil.trim(loadData);
			if(loadData.length > 0){
				
				status = "online"
				
				var args:Vector.<String> = new Vector.<String>();
				args.push("instances");
				args.push("adbconnect");
				args.push(loadData);
				
				var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
				procInfo.executable = gmsaasFile;
				procInfo.arguments = args;
								
				var newProc:NativeProcess = new NativeProcess();
				newProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbConnectOutput);
				newProc.addEventListener(NativeProcessExitEvent.EXIT, adbConnectExit);
				
				newProc.start(procInfo);
			}
		}
		
		private function adbConnectOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			trace(proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable));
		}
		
		private function adbConnectExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbConnectOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, adbConnectExit);
		}
	}
}