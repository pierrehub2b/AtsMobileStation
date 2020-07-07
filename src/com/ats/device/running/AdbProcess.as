package com.ats.device.running {
import com.ats.helpers.Settings;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;

public class AdbProcess extends NativeProcess {

    private var info:NativeProcessStartupInfo

    private var errorCallback:Function
    private var outputCallback:Function
    private var exitCallback:Function

    public var output:String
    public var error:String

    public function AdbProcess() {
        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = Settings.adbFile
        this.info = info
    }

    public function execute(arguments:Vector.<String>, exitCallback:Function, outputCallback:Function = null, errorCallback:Function = null):void {
        output = ""
        error = ""

        info.arguments = arguments

        this.exitCallback = exitCallback
        addEventListener(NativeProcessExitEvent.EXIT, onExitHandler)
        addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputHandler)
        addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorHandler)

        if (outputCallback != null) {
            this.outputCallback = outputCallback
        }

        if (errorCallback != null) {
            this.errorCallback = errorCallback
        }

        start(info)
    }

    private function onOutputHandler(event:ProgressEvent):void {
        output += standardOutput.readUTFBytes(standardOutput.bytesAvailable)

        if (outputCallback != null) {
            outputCallback()
        }
    }

    private function onErrorHandler(event:ProgressEvent):void {
        error += standardError.readUTFBytes(standardError.bytesAvailable)

        if (errorCallback != null) {
            errorCallback()
        }
    }

    private function onExitHandler(event:NativeProcessExitEvent):void {
        removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputHandler)
        removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorHandler)
        removeEventListener(NativeProcessExitEvent.EXIT, onExitHandler)

        exitCallback()
    }
}
}
