package com.ats.device.running {

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;

public class AndroidWirelessDevice extends AndroidDevice {

    public function AndroidWirelessDevice(id:String, automaticPort:Boolean, port:int) {
        super(id, false);

        this.automaticPort = automaticPort;
        this.port = port.toString();
        this.usbMode = false;
    }

    /*
    override public function runningTestHandler(ev:Event):void
    {
        super.runningTestHandler(ev);

        status = READY;
        tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions";
        started();
    }
 */

    override protected function fetchIpAddress():void {
        processInfo = new NativeProcessStartupInfo()
        processInfo.executable = currentAdbFile
        processInfo.arguments = new <String>["-s", id, "shell", "ip", "route"];

        process = new NativeProcess()
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
        process.addEventListener(NativeProcessExitEvent.EXIT, onReadLanExit, false, 0, true);
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData, false, 0, true);
        process.start(processInfo)
    }

    protected function onOutputErrorShell(event:ProgressEvent):void
    {
        error = String(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
    }

    private var output:String = ""
    protected function onReadLanData(event:ProgressEvent):void{
        output = output.concat(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
    }

    protected function onReadLanExit(event:NativeProcessExitEvent):void{
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
        process.removeEventListener(NativeProcessExitEvent.EXIT, onReadLanExit);
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadLanData);

        if (error != null) {
            // dispatchEvent(new Event(ERROR_EVENT));
        } else {
            var ipRouteDataUdp:Array = output.split("\r\r\n");
            for(var i:int=0;i<ipRouteDataUdp.length;i++) {
                if(ipRouteDataUdp[i].indexOf("dev") > -1 && ipRouteDataUdp[i].indexOf("wlan0") > -1) {
                    var splittedString:Array = ipRouteDataUdp[i].split(/\s+/g);
                    var idxUdp:int = splittedString.indexOf("src");
                    if(idxUdp > -1 && (splittedString[idxUdp+1].toString().indexOf("192") == 0 || splittedString[idxUdp+1].toString().indexOf("10") == 0 || splittedString[idxUdp+1].toString().indexOf("172") == 0)){
                        this.ip = splittedString[idxUdp+1]
                    }
                }
            }

            if(!ip) {
                writeErrorLogFile("WIFI not connected");
                error = "WIFI not connected"
                errorMessage = "Please connect the device to network"
                status = WIFI_ERROR;
            } else {
                uninstallDriver()
            }
        }
    }

    override protected function onUninstallDriverExit(event:NativeProcessExitEvent):void {
        super.onUninstallDriverExit(event)
        installDriver()
    }

    override protected function execute():void {
        var processInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        processInfo.executable = currentAdbFile
        processInfo.arguments = new <String>["-s", id, "shell", "am", "instrument", "-w", "-e", "ipAddress", ip, "-e", "atsPort", port, "-e", "usbMode", String(usbMode), "-e", "debug", "false", "-e", "class", ANDROID_DRIVER + ".AtsRunnerWifi", ANDROID_DRIVER + "/android.support.test.runner.AndroidJUnitRunner"];

        process = new NativeProcess();
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteOutput, false, 0, true);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
        process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
        process.start(processInfo);
    }
}
}
