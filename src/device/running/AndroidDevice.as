package device.running
{
import device.RunningDevice;

import flash.events.Event;
import flash.filesystem.File;

import helpers.DeviceSettings;
import helpers.DeviceSettingsHelper;

public class AndroidDevice extends RunningDevice
	{		
		public var androidVersion:String = "";
		public var androidSdk:String = "";

		protected var process:AndroidProcess;
		protected var currentAdbFile:File;

		public var settings: DeviceSettings;
				
		public function AndroidDevice(adbFile:File, id:String)
		{
			this.id = id;
			this.status = INSTALL;
			this.currentAdbFile = adbFile;
		}

		public override function start():void
		{
			if(process != null) {
				process.start();
			}
		}

		public override function dispose():Boolean
		{
			if (process != null) {
				return process.terminate();
			} else {
				return false;
			}
		}

		protected function addAndroidProcessEventListeners():void {
			process.addEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler, false, 0, true);
			process.addEventListener(AndroidProcess.RUNNING, runningTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.STOPPED, stoppedTestHandler, false, 0, true);
			process.addEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler, false, 0, true);
		}

		protected function removeAndroidProcessEventListeners():void {
			process.removeEventListener(AndroidProcess.ERROR_EVENT, processErrorHandler);
			process.removeEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler);
			process.removeEventListener(AndroidProcess.RUNNING, runningTestHandler);
			process.removeEventListener(AndroidProcess.STOPPED, stoppedTestHandler);
		}

		protected function processErrorHandler(ev:Event):void{
			removeAndroidProcessEventListeners();
			status = FAIL;

			process.writeErrorLogFile("Faillure on android process"); //TODO add more detailed info
		}

		public function runningTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.RUNNING, runningTestHandler);
		}

		protected function stoppedTestHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.STOPPED, stoppedTestHandler);
			close();
		}
		
		protected function deviceInfoHandler(ev:Event):void{
			process.removeEventListener(AndroidProcess.DEVICE_INFO, deviceInfoHandler);
			manufacturer = process.deviceInfo.manufacturer;
			modelId = process.deviceInfo.modelId;
			modelName = process.deviceInfo.modelName;
			androidVersion = process.deviceInfo.osVersion;
			androidSdk = process.deviceInfo.sdkVersion
		}

		public static function setup(id:String, adbFile:File):AndroidDevice {
			var deviceSettingsHelper:DeviceSettingsHelper = DeviceSettingsHelper.shared;
			var deviceSettings:DeviceSettings = deviceSettingsHelper.getSettingsForDevice(id);
			if (deviceSettings == null) {
				deviceSettings = new DeviceSettings(id);
			}

			var automaticPort:Boolean = deviceSettings.automaticPort;
			var usbMode = deviceSettings.usbMode;

			if (usbMode) {
				return new AndroidUsbDevice(id, adbFile, deviceSettings);
			} else {
				var port:int = deviceSettings.port;
				return new AndroidWirelessDevice(id, adbFile, automaticPort, port);
			}
		}
	}
}