package com.ats.device {

import com.ats.device.simulator.GenymotionDeviceTemplate;
import com.ats.device.simulator.Simulator;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

import mx.core.FlexGlobals;
import mx.utils.StringUtil;

public class GenymotionSimulator extends Simulator {

    public static const EVENT_STOPPED:String = "stopped";
    public static const EVENT_TEMPLATE_NAME_FOUND:String = "info found";
    public static const EVENT_ADB_CONNECTED:String = "adb connected";
    public static const EVENT_ADB_DISCONNECTED:String = "adb disconnected";

    public static const STATE_ONLINE:String = "ONLINE"
    public static const STATE_BOOTING:String = "BOOTING"
    public static const STATE_STARTING:String = "STARTING"

    public var uuid:String
    public var name:String
    public var adbSerial:String
    public var state:String

    public var templateName:String

    private var _template:GenymotionDeviceTemplate

    public var gmsaasFile:File

    private var errorData:String
    private var outputData:String

    public function set template(value:GenymotionDeviceTemplate):void {
        gmsaasFile = value.gmsaasFile
        _template = value;
    }

    public function GenymotionSimulator(uuid:String, name:String, adbSerial:String, state:String) {
        this.uuid = uuid
        this.name = name
        this.adbSerial = adbSerial
        this.state = state

        modelName = name
    }

    // ADB CONNECT
    public function adbConnect():void {
        errorData = ""
        outputData = ""

        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = gmsaasFile;
        procInfo.arguments = new <String>["instances", "adbconnect", uuid];

        var newProc:NativeProcess = new NativeProcess();

        if (!_template) {
            newProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbConnectOutput);
            newProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, adbConnectError);
            newProc.addEventListener(NativeProcessExitEvent.EXIT, adbConnectExit);
        }

        newProc.start(procInfo);
    }

    private function adbConnectError(ev:ProgressEvent):void{
        var proc:NativeProcess = ev.currentTarget as NativeProcess
        trace(proc.standardError.readUTFBytes(proc.standardError.bytesAvailable));
    }

    private function adbConnectOutput(ev:ProgressEvent):void{
        var proc:NativeProcess = ev.currentTarget as NativeProcess
        trace(proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable));
    }

    private function adbConnectExit(event:NativeProcessExitEvent):void{
        var proc:NativeProcess = event.currentTarget as NativeProcess
        proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbConnectOutput);
        proc.removeEventListener(NativeProcessExitEvent.EXIT, adbConnectExit);

        if (errorData) {
            trace(errorData)
            return
        }

        fetchAdbSerial()
    }

    public function stop():void {
        outputData = ""
        errorData = ""

        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        procInfo.executable = gmsaasFile
        procInfo.arguments = new <String>["instances", "stop", uuid]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onStopStandardErrorData);
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onStopStandardOutputData);
        process.addEventListener(NativeProcessExitEvent.EXIT, onStopExit);
        process.start(procInfo)
    }

    private function onStopStandardErrorData(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        errorData += process.standardError.readUTFBytes(process.standardError.bytesAvailable);
    }

    private function onStopStandardOutputData(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        outputData += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
    }

    private function onStopExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onStopStandardErrorData)
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onStopStandardOutputData)
        process.removeEventListener(NativeProcessExitEvent.EXIT, onStopExit)

        if (errorData) {
            trace(errorData)
            return
        }

        adbDisconnect()
        dispatchEvent(new Event(EVENT_STOPPED))
    }

    public function adbDisconnect():void {
        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        procInfo.executable = gmsaasFile;
        procInfo.arguments = new <String>["instances", "adbdisconnect", uuid];

        var proc:NativeProcess = new NativeProcess();
        proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbDisconnectOutput);
        proc.addEventListener(NativeProcessExitEvent.EXIT, adbDisconnectExit);

        proc.start(procInfo);
    }

    private function adbDisconnectOutput(ev:ProgressEvent):void{
        var proc:NativeProcess = ev.currentTarget as NativeProcess
        trace(proc.standardOutput.readUTFBytes(proc.standardOutput.bytesAvailable));
    }

    private function adbDisconnectExit(event:NativeProcessExitEvent):void{
        var proc:NativeProcess = event.currentTarget as NativeProcess
        proc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, adbDisconnectOutput);
        proc.removeEventListener(NativeProcessExitEvent.EXIT, adbDisconnectExit);

        dispatchEvent(new Event(EVENT_ADB_DISCONNECTED))
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
                templateName = /.*:.*\[(.*)\]/.exec(line)[1];
                dispatchEvent(new Event(EVENT_TEMPLATE_NAME_FOUND))
            }
        }
    }

    private function fetchAdbSerial():void {
        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        procInfo.executable = gmsaasFile
        procInfo.arguments = new <String>["instances", "list"]

        var process:NativeProcess = new NativeProcess()
        process.addEventListener(NativeProcessExitEvent.EXIT, fetchAdbSerialExit)
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, fetchAdbSerialError);
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, fetchAdbSerialOutput);
        process.start(procInfo)
    }

    private function fetchAdbSerialExit(event:NativeProcessExitEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        process.removeEventListener(NativeProcessExitEvent.EXIT, fetchAdbSerialExit)

        var data:Array = outputData.split(File.lineEnding);
        var delimiters:Array = data[1].split("  ")

        for(var i:int=2; i<data.length; i++) {
            var info:String = data[i]
            if (!info) return

            var uuid:String = info.substr(0, (delimiters[0] as String).length)

            if (uuid == this.uuid) {
                adbSerial = StringUtil.trim(info.substr((delimiters[0] as String).length + 2 + (delimiters[1] as String).length + 2, (delimiters[2] as String).length))
                fetchTemplateName()
                break
            }
        }
    }

    private function fetchAdbSerialOutput(event:ProgressEvent):void {
        var process:NativeProcess = event.currentTarget as NativeProcess
        outputData += process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
    }

    private function fetchAdbSerialError(event:ProgressEvent):void {
    }
}
}
