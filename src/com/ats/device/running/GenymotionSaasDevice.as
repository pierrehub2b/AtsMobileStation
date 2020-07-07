package com.ats.device.running {
import com.ats.helpers.DeviceSettings;

public class GenymotionSaasDevice extends AndroidUsbDevice {

    private static const atsdroidRemoteFilePath:String = "http://actiontestscript.com/drivers/mobile/atsdroid.apk"
    private static const apkOutputPath:String = "/sdcard/atsdroid.apk"

    public function GenymotionSaasDevice(id:String, settings:DeviceSettings) {
        super(id, true, settings);
    }

    override public function get modelName():String {
        return _modelName;
    }

    override protected function installDriver():void {
        printDebugLogs("Downloading APK")

        // -q (quiet): delete output logs interpreted as errors
        // -O (output document): always overwrites file
        var arguments: Vector.<String> = new <String>["-s", id, "shell", "wget", "-q", atsdroidRemoteFilePath, "-O", apkOutputPath]
        adbProcess.execute(arguments, downloadApkExit)
    }

    private function downloadApkExit():void {
        var errorData:String = adbProcess.error
        if (errorData) {
            status = ERROR
            errorMessage = errorData
            return
        }

        printDebugLogs("Installing driver")

        var arguments: Vector.<String> = new <String>["-s", id, "shell", "pm", "install", apkOutputPath]
        adbProcess.execute(arguments, onInstallDriverExit)
    }
}
}
