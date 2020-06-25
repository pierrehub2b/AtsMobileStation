package com.ats.device.simulator.genymotion {
import com.ats.device.simulator.*;
import com.ats.managers.gmsaas.GmsaasManager;

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
	public var instanceNumber:int = 0

	public function get isMS():Boolean {
		return mobileStationIndentifer == FlexGlobals.topLevelApplication.peerGroup.identifier
	}

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

		recipeUuid = properties[1]
		mobileStationIndentifer = properties[3]
	}

	public function adbConnect():void {
		enabled = true

		GmsaasManager.getInstance().adbConnect(uuid, function(result:GenymotionSaasSimulator, error:String):void {
			if (error) {
				trace("GM - ADB Connect Error : " + error)
			}
		})
	}

	public function adbDisconnect():void {
		enabled = false
		statusOff()

		GmsaasManager.getInstance().adbDisconnect(uuid, function(result:GenymotionSaasSimulator, error:String):void {
			if (error) {
				trace("GM - ADB Connect Error : " + error)
			}
		})
	}

	override public function startSim():void {

	}

	override public function startStop():void{
		stopSim();
	}

	override public function stopSim():void {
		if (!isMS) {
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

		var gmsaasManager:GmsaasManager = GmsaasManager.getInstance()

		/* gmsaasManager.adbDisconnect(uuid, function(result:GenymotionSaasSimulator, error:String):void {
			if (error) {
				trace(error)
				return
			} */

			gmsaasManager.stopInstance(uuid, function(result:GenymotionSaasSimulator, error:String):void {
				if (error) {
					trace(error)
					return
				}

				if (result.state != STATE_DELETED) {
					// handle error
				}

				dispatchEvent(new Event(EVENT_STOPPED))
			})
		// })
	}
}
}