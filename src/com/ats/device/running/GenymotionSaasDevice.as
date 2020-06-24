package com.ats.device.running {
import com.ats.helpers.DeviceSettings;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;

public class GenymotionSaasDevice extends AndroidUsbDevice {

    private static const atsdroidRemoteFilePath:String = "http://actiontestscript.com/drivers/mobile/atsdroid.apk"

    public function GenymotionSaasDevice(id:String, settings:DeviceSettings) {
        super(id, true, settings);
    }

    override protected function uninstallDriver():void {
        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = currentAdbFile
        info.arguments = new <String>["-s", id, "shell", "rm", "/sdcard/atsdroid.apk"]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, onUninstallDriverExit);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, downloadError);
        process.start(info)
    }


    override protected function installDriver():void {
        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = currentAdbFile
        info.arguments = new <String>["-s", id, "shell", "wget", "-P", "/sdcard/", atsdroidRemoteFilePath]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, downloadApkExit);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, downloadError);
        process.start(info)
    }

    var errorData: String
    private function downloadError(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        errorData += process.standardError.readUTFBytes(process.standardError.bytesAvailable)
    }

    private function downloadApkExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(NativeProcessExitEvent.EXIT, downloadApkExit)

        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = currentAdbFile
        info.arguments = new <String>["-s", id, "shell", "pm", "install", "/sdcard/atsdroid.apk"]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, onInstallDriverExit);
        process.start(info)
    }
}
}
