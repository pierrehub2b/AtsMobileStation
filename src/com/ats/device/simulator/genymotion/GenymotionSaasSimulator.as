package com.ats.device.simulator.genymotion {
	import com.ats.device.running.GenymotionSaasDevice;
	import com.ats.device.simulator.*;
	import com.ats.managers.gmsaas.GmsaasManager;
	import com.ats.managers.gmsaas.GmsaasManagerEvent;
	
	import flash.events.Event;
	
	import mx.core.FlexGlobals;
	import mx.events.CloseEvent;
	
	import spark.components.Alert;
	
	public class GenymotionSaasSimulator extends Simulator {
		
		public static const GENYMOTION_ERROR_INCOMPATIBLE_VERSION_NUMBERS:String = "incompatible version numbers"
		public static const GENYMOTION_ERROR_NO_NETWORK_CONNECTION:String = "no network connection"
		
		public static const EVENT_STOPPED:String = "stopped";
		public static const EVENT_TEMPLATE_NAME_FOUND:String = "info found";
		public static const EVENT_ADB_CONNECTED:String = "adb connected";
		public static const EVENT_ADB_DISCONNECTED:String = "adb disconnected";
		
		public static const STATE_ONLINE:String = "ONLINE"
		public static const STATE_BOOTING:String = "BOOTING"
		public static const STATE_STARTING:String = "STARTING"
		public static const STATE_CREATING:String = "CREATING"
		public static const STATE_STOPPING:String = "STOPPING"
		public static const STATE_DELETED:String = "DELETED"
		
		public static const ADB_TUNNEL_STATE_CONNECTED:String = "CONNECTED"
		public static const ADB_TUNNEL_STATE_PENDING:String = "PENDING"
		public static const ADB_TUNNEL_STATE_DISCONNECTED:String = "DISCONNECTED";
		
		[Bindable]
		public static var count:int = 0;
		
		[Bindable]
		public var name:String
		
		public var uuid:String
		public var adbSerial:String
		
		[Bindable]
		public var state:String
		public var adbTunnelState:String
		
		public var recipeUuid:String
		
		[Bindable]
		public var mobileStationIndentifer:String
		
		[Bindable]
		public var instanceNumber:int = 0;
		
		[Bindable]
		public var owned:Boolean = true;
		
		[Bindable]
		public var enabled:Boolean = false
		
		public function GenymotionSaasSimulator(info:Object) {
			uuid = info['uuid']
			name = info['name']
			adbSerial = info['adb_serial']
			state = info['state']
			adbTunnelState = info['adbtunnel_state']
			
			var properties:Array = name.split("_")
			if (properties.length != 5) {
				throw new Error('Unreadable name')
			}
			
			if (properties[0] != 'GM') {
				throw new Error('Unknow instance')
			}
			
			tooltip = "Simulator starting, please wait ..."
			
			recipeUuid = properties[1]
			mobileStationIndentifer = properties[3]
			
			if(mobileStationIndentifer != FlexGlobals.topLevelApplication.peerGroup.identifier){
				owned = false;
			}
		}
		
		public function adbConnect():void {
			enabled = true
			
			var manager:GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.ERROR, adbConnectErrorHandler, false, 0, true)
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, adbConnectCompleteHandler, false, 0, true)
			manager.adbConnect(uuid)
		}
		
		private function adbConnectErrorHandler(event:GmsaasManagerEvent):void {
			trace("GM - ADB Connect Error : " + event.error)
		}
		
		private function adbConnectCompleteHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, adbConnectErrorHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, adbConnectCompleteHandler)
			trace("GM - ADB Connection complete")
		}
		
		public function adbDisconnect():void {
			enabled = false
			statusOff()
			
			var manager:GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.ERROR, adbDisconnectErrorHandler, false, 0, true)
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, adbDisconnectCompleteHandler, false, 0, true)
			manager.adbDisconnect(uuid)
		}
		
		private function adbDisconnectErrorHandler(event:GmsaasManagerEvent):void {
			trace("GM - ADB Disconnect Error : " + event.error)
		}
		
		private function adbDisconnectCompleteHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, adbDisconnectErrorHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, adbDisconnectCompleteHandler)
			trace("GM - ADB Disconnect complete")
		}
		
		override public function startSim():void {
			var manager:GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.ERROR, startErrorHandler, false, 0, true);
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, startCompletedHandler, false, 0, true);
			manager.startInstance(recipeUuid, name)
		}
		
		private function startErrorHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, startErrorHandler);
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, startCompletedHandler);
			
			dispatchEvent(new Event(EVENT_STOPPED))
		}
		
		private function startCompletedHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, startErrorHandler);
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, startCompletedHandler);
			
			count++;
			
			var instance:GenymotionSaasSimulator = event.data[0] as GenymotionSaasSimulator
			adbSerial = instance.adbSerial
			state = instance.state
			adbTunnelState = instance.adbTunnelState
			uuid = instance.uuid
			statusOn()
			adbConnect()
		}
		
		override public function startStop():void{
			if(status == RUNNING){
				stopSim();
			}
		}
		
		override public function stopSim():void {
			if (!owned) {
				Alert.show(
					"This instance is owned by another MobileStation.\nAre you sure you want to stop this instance ?",
					"Stop Genymotion instance",
					Alert.YES | Alert.NO,
					FlexGlobals.topLevelApplication as AtsMobileStation,
					function(event:CloseEvent):void {
						if (event.detail == Alert.YES) {
							stop()
						}
					})
				return
			}
			
			stop()
		}
		
		private function stop():void {
			state = STATE_STOPPING
			status = SHUTDOWN;
			enabled = false
			tooltip = "Simulator is terminating ...";
			
			var manager:GmsaasManager = new GmsaasManager()//.getInstance()
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, adbDisconnectCompletedHandler, false, 0, true);
			manager.addEventListener(GmsaasManagerEvent.ERROR, adbDisconnectErrorHandler, false, 0, true)
			manager.adbDisconnect(uuid)
		}
		
		private function adbDisconnectCompletedHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, adbDisconnectCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, adbDisconnectErrorHandler)
			
			var manager: GmsaasManager = new GmsaasManager()
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, stopInstanceCompletedHandler, false, 0, true);
			manager.addEventListener(GmsaasManagerEvent.COMPLETED, stopInstanceErrorHandler, false, 0, true);
			manager.stopInstance(uuid)
		}
		
		private function stopInstanceCompletedHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, stopInstanceCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, stopInstanceErrorHandler)
			
			count--;
			
			var instance:GenymotionSaasSimulator = event.data[0] as GenymotionSaasSimulator
			if (instance.state != STATE_DELETED) {
				// handle error
				return
			}
			
			dispatchEvent(new Event(EVENT_STOPPED))
		}
		
		private function stopInstanceErrorHandler(event:GmsaasManagerEvent):void {
			event.currentTarget.removeEventListener(GmsaasManagerEvent.COMPLETED, stopInstanceCompletedHandler)
			event.currentTarget.removeEventListener(GmsaasManagerEvent.ERROR, stopInstanceErrorHandler)
		}
	}
}