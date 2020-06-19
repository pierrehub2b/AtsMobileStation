package com.ats.device.simulator.genymotion
{
import com.ats.helpers.Version;
import com.ats.managers.gmsaas.GmsaasManager;

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
			var msIdentifier = FlexGlobals.topLevelApplication.peerGroup.identifier
			return ["GM", uuid, msIdentifier, date.time].join("_")
		}
		
		public function startInstance():void {
			var instanceName:String = generateInstanceName()
			var info:Object = new Object()
			info['name'] = instanceName
			var newInstance:GenymotionInstance = new GenymotionInstance(info)
			addInstance(newInstance)

			GmsaasManager.getInstance().startInstance(uuid, instanceName, function(result:GenymotionInstance, error:String):void {
				if (error) {
					trace(error)

					return
				}

				var instanceName:String = result.name
				var instanceFound:Boolean = false
				for each (var instance:GenymotionInstance in instances) {
					if (instance.name == instanceName) {
						instanceFound = true

						instance.adbSerial = result.adbSerial
						instance.state = result.state
						instance.adbTunnelState = result.adbTunnelState
						instance.uuid = result.uuid

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
			var instance:GenymotionInstance = event.currentTarget as GenymotionInstance
			removeInstance(instance)
		}
		
		public function addInstance(instance:GenymotionInstance):void {
			instance.addEventListener(GenymotionInstance.EVENT_STOPPED, stoppedInstanceHandler, false, 0, true)
			instance.recipeUuid = uuid
			instance.instanceNumber = attributeInstanceNumber()
			instances.addItem(instance)
		}
		
		private function attributeInstanceNumber():int {
			var number:int = 0
			for each (var instance:GenymotionInstance in instances) {
				if (number == instance.instanceNumber) number++
			}
			
			return number
		}
		
		public function removeInstance(instance:GenymotionInstance):void {
			instance.removeEventListener(GenymotionInstance.EVENT_STOPPED, stoppedInstanceHandler)
			instances.removeItem(instance)
		}
	}
}