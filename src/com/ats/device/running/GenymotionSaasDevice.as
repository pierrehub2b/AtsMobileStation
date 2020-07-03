package com.ats.device.running {
import com.ats.helpers.DeviceSettings;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;

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
        writeDebugLogs("Downloading APK")

        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = adbFile

        // -q (quiet): delete output logs interpreted as errors
        // -O (output document): always overwrites file
        info.arguments = new <String>["-s", id, "shell", "wget", "-q", atsdroidRemoteFilePath, "-O", apkOutputPath]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, downloadApkExit);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, downloadError);
        process.start(info)
    }

    private var errorData:String = ""
    private function downloadError(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        errorData += process.standardError.readUTFBytes(process.standardError.bytesAvailable)
    }

    private function downloadApkExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(NativeProcessExitEvent.EXIT, downloadApkExit)

        if (errorData) {
            status = ERROR
            errorMessage = errorData
            return
        }

        writeDebugLogs("Installing driver")

        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = adbFile
        info.arguments = new <String>["-s", id, "shell", "pm", "install", apkOutputPath]

        process = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, onInstallDriverExit);
        process.start(info)
    }
}
}
