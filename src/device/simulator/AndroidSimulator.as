package device.simulator {
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.system.Capabilities;

import helpers.Settings;

public class AndroidSimulator extends Simulator {

    private var outputData:String
    private var errorData:String

    private var emulatorProcess: NativeProcess

    public function AndroidSimulator(id:String = "") {
        super(id);

        this.modelName = id

        checkBootedDevice()
    }

    private function checkBootedDevice():void {
        var processInfo: NativeProcessStartupInfo = new NativeProcessStartupInfo()
        processInfo.executable = File.applicationDirectory.resolvePath("assets/tools/android/adb.exe");
        processInfo.arguments = new <String>["-s", id, "shell", "getprop", "sys.boot_completed"];

        var adbProcess: NativeProcess = new NativeProcess()
        adbProcess.addEventListener(NativeProcessExitEvent.EXIT, onBootCompletedExit, false, 0, true);
        adbProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootCompletedError, false, 0, true);
        adbProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootCompletedOutput, false, 0, true);
        adbProcess.start(processInfo)
    }

    override public function startSim():void {
        var file:File = Settings.getInstance().androidSDKDirectory
        if (Capabilities.os.indexOf("Mac") > -1) {
            file = file.resolvePath("emulator/emulator")
        } else {
            file = file.resolvePath("emulator/emulator.exe")
        }

        if (!file.exists) {
            trace("No Android SDK found")
            statusOff()
            return
        }

        var info:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        info.executable = file
        info.arguments = new <String>["-avd", id]

        emulatorProcess = new NativeProcess()
        emulatorProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false, 0, true);
        emulatorProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false, 0, true);
        emulatorProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit, false, 0, true);
        emulatorProcess.start(info)
    }

    private function onExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false);
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false);
        process.removeEventListener(NativeProcessExitEvent.EXIT, onExit, false);
    }

    private function onErrorData(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        errorData = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
        process.exit(true)
        statusOff()
    }

    private function onOutputData(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        outputData = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
        process.exit()
        statusOn()
    }

    override public function stopSim():void {
        emulatorProcess.exit(true)
    }

    private var bootCompletedError: String
    private var bootCompletedOutput: String

    private function onBootCompletedExit(event:NativeProcessExitEvent):void {
        var process: NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onBootCompletedOutput)
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onBootCompletedError)
        process.removeEventListener(NativeProcessExitEvent.EXIT, onBootCompletedExit)

        if (bootCompletedError) {
            statusOff()
            return
        }

        if (bootCompletedOutput && bootCompletedOutput.charAt(0) == "1") {
            statusOn()
        } else {
            statusOff()
        }
    }

    private function onBootCompletedError(event:ProgressEvent):void {
        var process: NativeProcess = event.currentTarget as NativeProcess
        bootCompletedError = process.standardError.readUTFBytes(process.standardError.bytesAvailable)
    }

    private function onBootCompletedOutput(event:ProgressEvent):void {
        var process: NativeProcess = event.currentTarget as NativeProcess
        bootCompletedOutput = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
    }
}
}
