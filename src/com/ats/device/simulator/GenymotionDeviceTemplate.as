package com.ats.device.simulator
{
import com.ats.helpers.Version;
import com.ats.helpers.Version;

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

		public var uuid:String;
		public var name:String;
		public var version:Version;
		public var width:int;
		public var height:int;
		public var dpi:int;

		public var status:String = AVAILABLE

		public var instances:ArrayCollection = new ArrayCollection()
			
		public function GenymotionDeviceTemplate(info:Object, gmsaas:File)
		{
			uuid = info['uuid']
			name = info['name']
			version = new Version(info['android_version'])
			width = info['screen_width']
			height = info['screen_width']
			dpi = info['screen_density']
			
			this.gmsaasFile = gmsaas;
		}

		public var gmsaasFile:File;
		private var loadData:String;
		
		public function startInstance():void{
			status = LOADING
			loadData = ""

			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["instances", "start", uuid, name + "_" + instances.length];
			
			var proc:NativeProcess = new NativeProcess();
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.addEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);
			proc.start(procInfo);
		}
		
		private function gmsaasInstanceStartOutput(ev:ProgressEvent):void{
			var proc:NativeProcess = ev.currentTarget as NativeProcess
			loadData += proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable);
		}
		
		private function gmsaasInstanceStartExit(event:NativeProcessExitEvent):void {
			var proc:NativeProcess = event.currentTarget as NativeProcess
			proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, gmsaasInstanceStartOutput);
			proc.removeEventListener(NativeProcessExitEvent.EXIT, gmsaasInstanceStartExit);

			status = AVAILABLE

			var json:Object = JSON.parse(loadData)
			var instance:GenymotionSimulator = new GenymotionSimulator(json['instance'])
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

			if (instance.adbTunnelState == GenymotionSimulator.ADB_TUNNEL_STATE_DISCONNECTED) {
				instance.adbConnect()
			}
		}

		public function removeInstance(instance:GenymotionSimulator):void {
			instance.removeEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler)
			instances.removeItem(instance)
		}
	}
}