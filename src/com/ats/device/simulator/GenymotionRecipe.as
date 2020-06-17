package com.ats.device.simulator
{
	import com.ats.helpers.Version;
import com.ats.managers.GenymotionManager;
import com.ats.managers.gmsaas.GmsaasManager;

import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	[Bindable]
	public class GenymotionRecipe
	{
		public var uuid:String;
		public var name:String;
		public var version:Version;
		public var width:int;
		public var height:int;
		public var dpi:int;

		public var instances:ArrayCollection = new ArrayCollection()

		public function GenymotionRecipe(info:Object)
		{
			uuid = info['uuid']
			name = info['name']
			version = new Version(info['android_version'])
			width = info['screen_width']
			height = info['screen_width']
			dpi = info['screen_density']
		}
		
		private function generateInstanceName():String {
			var date:Date = new Date()
			return name + "_" + date.time
		}
		
		public function startInstance():void {
			var instanceName:String = generateInstanceName()
			var info:Object = new Object()
			info['name'] = instanceName
			var newInstance:GenymotionSimulator = new GenymotionSimulator(info)
			addInstance(newInstance)

			GmsaasManager.getInstance().startInstance(uuid, instanceName, function(result:GenymotionSimulator, error:String):void {
				if (error) {
					trace(error)
					return
				}

				var name:String = result.name
				var instanceFound:Boolean = false
				for each (var instance:GenymotionSimulator in instances) {
					if (instance.name == name) {
						instanceFound = true

						instance.uuid = result.uuid
						instance.name = result.name
						instance.adbSerial = result.adbSerial
						instance.state = result.state
						instance.adbTunnelState = result.adbTunnelState

						instance.adbConnect()
						break
					}
				}

				if (!instanceFound) {
					/* handle error */
				}
			})
		}
		
		public function stoppedInstanceHandler(event:Event):void {
			var instance:GenymotionSimulator = event.currentTarget as GenymotionSimulator
			removeInstance(instance)
		}
		
		public function addInstance(instance:GenymotionSimulator):void {
			instance.addEventListener(GenymotionSimulator.EVENT_STOPPED, stoppedInstanceHandler, false, 0, true)
			instance.template = this
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