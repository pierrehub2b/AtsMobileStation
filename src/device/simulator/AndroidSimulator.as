package device.simulator {
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.net.SharedObject;

import helpers.Settings;

public class AndroidSimulator extends Simulator {

    private var outputData:String
    private var errorData:String

    public function AndroidSimulator(id:String = "") {
        super(id);

        this.modelName = id
    }

    override public function startSim():void {
        var file = Settings.getInstance().androidSDKDirectory.resolvePath("emulator/emulator.exe")
        if (!file.exists) {
            trace("No Android SDK found")
            return
        }

        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = file
        info.arguments = new <String>["-avd", id]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false, 0, true);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false, 0, true);
        process.addEventListener(NativeProcessExitEvent.EXIT, onExit, false, 0, true);
        process.start(info)
    }

    private function onExit(event:NativeProcessExitEvent):void {
        var process = event.currentTarget as NativeProcess
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false);
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false);
        process.removeEventListener(NativeProcessExitEvent.EXIT, onExit, false);
    }

    private function onErrorData(event:ProgressEvent):void {
        var process = event.currentTarget as NativeProcess
        errorData = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
    }

    private function onOutputData(event:ProgressEvent):void {
        var process = event.currentTarget as NativeProcess
        outputData = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
    }
}
}
