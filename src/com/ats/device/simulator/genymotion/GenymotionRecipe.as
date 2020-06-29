package com.ats.device.simulator.genymotion
{
import com.ats.helpers.Version;

import flash.events.Event;

import mx.collections.ArrayCollection;
import mx.core.FlexGlobals;

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
			var msIdentifier:String = FlexGlobals.topLevelApplication.peerGroup.identifier
			return ["GM", uuid, name, msIdentifier, date.time].join("_")
		}

		public function startInstance():void {
			var instanceName:String = generateInstanceName()
			var newInstance:GenymotionSaasSimulator = new GenymotionSaasSimulator({'name':instanceName})
			newInstance.recipeUuid = uuid
			addInstance(newInstance)
			newInstance.startSim()
		}

		public function addInstance(instance:GenymotionSaasSimulator):void {
			instance.addEventListener(Event.CLOSE, stoppedInstanceHandler, false, 0, true)
			instance.recipeUuid = uuid
			instance.instanceNumber = attributeInstanceNumber()
			instance.modelName = name
			instance.osVersion = version.stringValue
			instances.addItem(instance)

			FlexGlobals.topLevelApplication.simulators.collection.addItem(instance)
		}

		public function removeInstance(instance:GenymotionSaasSimulator):void {
			instance.removeEventListener(Event.CLOSE, stoppedInstanceHandler)
			instances.removeItem(instance)
			FlexGlobals.topLevelApplication.simulators.collection.removeItem(instance)
		}

		private function stoppedInstanceHandler(event:Event):void {
			var instance:GenymotionSaasSimulator = event.currentTarget as GenymotionSaasSimulator
			removeInstance(instance)
		}

		private function attributeInstanceNumber():int {
			var number:int = 0
			for each (var instance:GenymotionSaasSimulator in instances) {
				if (number == instance.instanceNumber) number++
			}

			return number
		}

		public function stopAllInstances():void {
			for each (var instance:GenymotionSaasSimulator in instances) {
				instance.stopSim()
			}
		}
	}
}