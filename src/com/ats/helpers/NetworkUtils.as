package com.ats.helpers {

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class NetworkUtils extends EventDispatcher {

    private var process:NativeProcess;
    private var networkInterface:String = "en0";
    private var outputData:String = "";

    public function getClientIPAddress():void
    {
        trace()

        process = new NativeProcess();
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData, false, 0, true);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData, false, 0, true);
        process.addEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError, false, 0, true);
        process.addEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError, false, 0, true);

        if(AtsMobileStation.isMacOs) {
            process.addEventListener(NativeProcessExitEvent.EXIT, onMacProcessExit, false, 0, true);
            startMacProcess(networkInterface);
        } else {
            process.addEventListener(NativeProcessExitEvent.EXIT, onWinProcessExit, false, 0, true);
            startWinProcess()
        }
    }

    private function startMacProcess(networkInterface:String):void
    {
        var file:File = new File("/usr/bin/env");

        var processArgs:Vector.<String> = new Vector.<String>();
        processArgs.push("ipconfig","getifaddr", networkInterface);

        startProcess(file, processArgs);
    }

    private function startWinProcess():void
    {
        var file:File = wmicFile;

        var processArgs:Vector.<String> = new Vector.<String>();
        processArgs.push("nicconfig", "where", "(IPEnabled=TRUE and DHCPEnabled=TRUE)", "get", "IPAddress", "/format:list");

        startProcess(file, processArgs);
    }

    private function startProcess(executableFile:File, processArguments:Vector.<String>):void
    {
        var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        nativeProcessStartupInfo.executable = executableFile;
        nativeProcessStartupInfo.workingDirectory = executableFile.parent;
        nativeProcessStartupInfo.arguments = processArguments;

        process.start(nativeProcessStartupInfo);
    }

    private function onWinProcessExit(event:NativeProcessExitEvent):void
    {
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
        process.removeEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
        process.removeEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
        process.removeEventListener(NativeProcessExitEvent.EXIT, onWinProcessExit);

        var pattern:RegExp = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/;
        var arrayAddresses:Array = outputData.match(pattern);
        if(arrayAddresses != null && arrayAddresses.length > 0) {
            var ev:NetworkEvent = new NetworkEvent(NetworkEvent.IP_ADDRESS_FOUND);
            ev.ipAddress = arrayAddresses[0];
            dispatchEvent(ev);
        }
    }

    private function removeMacEventListeners():void
    {
        process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onErrorData);
        process.removeEventListener(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, onIOError);
        process.removeEventListener(IOErrorEvent.STANDARD_ERROR_IO_ERROR, onIOError);
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputData);
        process.removeEventListener(NativeProcessExitEvent.EXIT, onMacProcessExit);
    }

    private function onMacProcessExit(event:NativeProcessExitEvent):void
    {
        var rex:RegExp = /[\s\r\n]+/gim;
        var ipAddress:String = outputData.replace(rex,"");

        if (ipAddress == "" && networkInterface == "en0") {
            startMacProcess("en1")
        } else if (ipAddress == "" && networkInterface == "en1") {
            removeMacEventListeners();

            dispatchEvent(new NetworkEvent(NetworkEvent.IP_ADDRESS_NOT_FOUND));
        } else {
            removeMacEventListeners();

            var networkEvent:NetworkEvent = new NetworkEvent(NetworkEvent.IP_ADDRESS_FOUND);
            networkEvent.ipAddress = ipAddress;
            dispatchEvent(networkEvent);
        }
    }

    private function onOutputData(event:ProgressEvent):void
    {
        outputData = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable)
    }

    private function onErrorData(event:ProgressEvent):void
    {
        trace("FETCH LOCAL IP ADDRESS ERROR -", process.standardError.readUTFBytes(process.standardError.bytesAvailable));
    }

    private function onIOError(event:IOErrorEvent):void
    {
        trace(event.toString());
    }

    private static function get wmicFile():File
    {
        var file:File;
        var rootPath:Array = File.getRootDirectories();
        for each(var f:File in rootPath) {
            file = f.resolvePath("Windows/System32/wbem/WMIC.exe");
            if (file.exists) {
                break;
            } else {
                file = null;
            }
        }

        return file;
    }
}
}
