package com.ats.device.running {
	import com.ats.helpers.DeviceSettings;

	public class GenymotionSaasDevice extends AndroidUsbDevice {

		private static const atsdroidRemoteFilePath:String = "http://actiontestscript.com/drivers/mobile/atsdroid.apk"
		private static var apkOutputPath:String

		private var installingDriver:Boolean = false
		
		public function GenymotionSaasDevice(id:String, settings:DeviceSettings) {
			super(id, true, settings);
		}

		override public function get modelName():String {
			return _modelName;
		}
		
		override protected function installDriver():void {
			installingDriver = true
			
			installApk(atsdroidRemoteFilePath)
		}
		
		private var apkName:String
		
		public override function installApk(url:String):void {
			apkName = url.split("/").pop()
			printDebugLogs("Downloading " + apkName)
			apkOutputPath = "/sdcard/" + apkName
			
			// -q (quiet): delete output logs interpreted as errors
			// -O (output document): always overwrites file
			var arguments:Vector.<String> = new <String>["-s", id, "shell", "wget", "-q", url, "-O", apkOutputPath]
			adbProcess.execute(arguments, apkDownloadComplete)
		}
		
		private function apkDownloadComplete():void {
			var errorData:String = adbProcess.error
			if (errorData) {
				status = ERROR
				errorMessage = errorData
				return
			}
			
			printDebugLogs("Installing " + apkName)
			
			var arguments:Vector.<String> = new <String>["-s", id, "shell", "pm", "install", apkOutputPath]
			
			if (installingDriver == true) {
				installingDriver = false
				adbProcess.execute(arguments, onInstallDriverExit)
			} else {
				adbProcess.execute(arguments, onInstallApkExit)
			}
		}
	}
}
