package com.ats.device.simulator.genymotion {
import com.ats.device.simulator.*;


import com.ats.managers.gmsaas.GmsaasManager;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.core.FlexGlobals;

public class GenymotionInstance extends Simulator {
		
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
		
		public var templateName:String
		
		[Bindable]
		public var instanceNumber:int = 0
		
		public var template:GenymotionRecipe
		public var gmsaasFile:File
		
		private var errorData:String = ""
		private var outputData:String = ""

		public function GenymotionInstance(info:Object) {
			this.uuid = info['uuid']
			this.name = info['name']
			this.adbSerial = info['adb_serial']
			this.state = info['state']
			this.adbTunnelState = info['adbtunnel_state']
		}
		
		// ADB CONNECT
		public function adbConnect():void {
			GmsaasManager.getInstance().adbConnect(uuid, function(result:GenymotionInstance, error:String):void {
				if (error) {
					trace(error)
					return
				}

				if (!template) {
					adbSerial = result.adbSerial
					adbTunnelState = result.adbTunnelState

					fetchTemplateName()
				}
			})
		}
		
		public function stop():void {
			state = STATE_STOPPING

			var gmsaasManager:GmsaasManager = GmsaasManager.getInstance()

			gmsaasManager.adbDisconnect(uuid, function(result:GenymotionInstance, error:String):void {
				if (error) {
					trace(error)
					return
				}

				gmsaasManager.stopInstance(uuid, function(result:GenymotionInstance, error:String):void {
					if (error) {
						trace(error)
						return
					}

					if (result.state != STATE_DELETED) {
						// handle error
					}

					dispatchEvent(new Event(EVENT_STOPPED))
				})
			})
		}

		public function fetchTemplateName():void {
			outputData = ""
			errorData = ""
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = FlexGlobals.topLevelApplication.adbFile;
			procInfo.arguments = new <String>["-s", adbSerial, "shell", "getprop"];
			
			var proc:NativeProcess = new NativeProcess()
			proc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onFetchInfoStandardErrorData);
			proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onFetchInfoStandardOutputData);
			proc.addEventListener(NativeProcessExitEvent.EXIT, onFetchInfoExit);
			proc.start(procInfo)
		}
		
		private function onFetchInfoStandardErrorData(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			errorData += process.standardError.readUTFBytes(process.standardError.bytesAvailable)
		}
		
		private function onFetchInfoStandardOutputData(event:ProgressEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			outputData += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
		}
		
		private function onFetchInfoExit(event:NativeProcessExitEvent):void {
			var process:NativeProcess = event.currentTarget as NativeProcess
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onFetchInfoStandardErrorData);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onFetchInfoStandardOutputData);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onFetchInfoExit);
			
			if (errorData) {
				trace(errorData)
				return
			}
			
			var propArray:Array = outputData.split(File.lineEnding)
			for each (var line:String in propArray) {
				if (line.indexOf("[ro.product.model]") == 0) {
					templateName = /.*:.*\[(.*)]/.exec(line)[1];
					dispatchEvent(new Event(EVENT_TEMPLATE_NAME_FOUND))
				}
			}
		}
	}
}