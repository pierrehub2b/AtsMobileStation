package com.ats.device.simulator
{
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
		private var manager:GenymotionManager
		
		public function GenymotionDeviceTemplate(info:Object, manager: GenymotionManager)
		{
			uuid = info['uuid']
			name = info['name']
			version = new Version(info['android_version'])
			width = info['screen_width']
			height = info['screen_width']
			dpi = info['screen_density']
			
			this.gmsaasFile = manager.gmsaasFile;
			this.manager = manager
		}
		
		public var gmsaasFile:File;
		private var loadData:String;
		
		private function generateInstanceName():String {
			var date:Date = new Date()
			return name + "_" + date.time
		}
		
		public function startInstance():void {
			if (manager.numberOfInstances() >= 2) {
				trace("GMSAAS ERROR: Too much instances")
				return
			}
			
			status = LOADING
			loadData = ""
			
			var instanceName:String = generateInstanceName()
			var info:Object = new Object()
			info['name'] = instanceName
			var newInstance:GenymotionSimulator = new GenymotionSimulator(info)
			addInstance(newInstance)
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = gmsaasFile;
			procInfo.arguments = new <String>["--format", "compactjson", "instances", "start", uuid, instanceName];
			
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
			
			if (!loadData) {
				
			}
			
			try{
				var json:Object = JSON.parse(loadData)
				var info:Object = json['instance']
			}catch(err:Error){
				return
			}
			
			if (!info) /* handle error */ return
			
			var name:String = info['name']
			var instanceFound:Boolean = false
			for each (var instance:GenymotionSimulator in instances) {
				if (instance.name == name) {
					instanceFound = true
					instance.update(info)
					instance.adbConnect()
					break
				}
			}
			
			if (!instanceFound) {
				/* handle error */
			}
		}
		
		public function stoppedInstanceHandler(event:Event):void {
			var instance:GenymotionSimulator = event.currentTarget as GenymotionSimulator
			removeInstance(instance)
		}
		
		public function addInstance(instance:GenymotionSimulator):void {
			instance.addEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler, false, 0, true)
			instance.template = this
			instance.gmsaasFile = gmsaasFile
			instance.instanceNumber = attributeInstanceNumber()
			instances.addItem(instance)
		}
		
		private function attributeInstanceNumber():int {
			var number:int = 0
			for each (var instance:GenymotionSimulator in instances) {
				if (number == instance.instanceNumber) number++
			}
			
			return number
		}
		
		public function removeInstance(instance:GenymotionSimulator):void {
			instance.removeEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler)
			instances.removeItem(instance)
		}
	}
}