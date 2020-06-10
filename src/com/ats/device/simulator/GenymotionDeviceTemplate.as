package com.ats.device.simulator
{
import com.adobe.utils.StringUtil;
import com.ats.device.GenymotionSimulator;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.collections.ArrayCollection;

[Bindable]
	public class GenymotionDeviceTemplate
	{
		public static const AVAILABLE:String = "turnon"
		public static const LOADING:String = "starting"

		public var id:String;
		public var name:String;
		public var version:String;
		public var width:int;
		public var height:int;
		public var dpi:int;		
		public var status:String = AVAILABLE;

		public var instances:ArrayCollection = new ArrayCollection()
			
		public function GenymotionDeviceTemplate(data:Array, gmsaas:File)
		{
			id = data[1];
			name = StringUtil.trim(data[2]);
			version = data[3];
			width = parseInt(data[5]);
			height = parseInt(data[6]);
			dpi = parseInt(data[7]);
			
			this.gmsaasFile = gmsaas;
		}

		public var gmsaasFile:File;
		private var loadData:String;
		
		public function startInstance():void{
			status = LOADING
			loadData = ""
			errorData = ""
			
			var args:Vector.<String> = new Vector.<String>();
			args.push("instances");
			args.push("start");
			args.push(id);
			args.push(name + " (" + instances.length + ")");
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = args;
			
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, gmsaasInstanceStartError);
			proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);
			proc.start(procInfo);
		}
		
		private function gmsaasInstanceStartOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}

		private var errorData:String
		private function gmsaasInstanceStartError(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			errorData += proc.standardError.readUTFBytes(proc.standardError.bytesAvailable);
		}
		
		private function gmsaasInstanceStartExit(event:NativeProcessExitEvent):void{
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);

			status = AVAILABLE

			if (errorData) {
				trace(errorData)
				return
			}

			loadData = StringUtil.trim(loadData);
			if (!loadData) {
				trace("WARNING: Bad Genymotion instance UUID")
				return
			}

			var instance:GenymotionSimulator = new GenymotionSimulator(loadData, name + " (" + instances.length + ")", null, null)
			addInstance(instance)
		}

		public function stoppedInstanceHandler(event:Event):void {
			var instance:GenymotionSimulator = event.currentTarget as GenymotionSimulator
			removeInstance(instance)
		}

		public function addInstance(instance:GenymotionSimulator):void {
			instance.addEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler, false, 0, true)
			instances.addItem(instance)
			instance.template = this

			if (instance.state != GenymotionSimulator.STATE_ONLINE) {
				instance.adbConnect()
			}
		}

		public function removeInstance(instance:GenymotionSimulator):void {
			instance.removeEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler)
			instances.removeItem(instance)
		}
	}
}