package helpers {

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.EventDispatcher;
import flash.events.ProgressEvent;
import flash.filesystem.File;

public class NetworkUtils extends EventDispatcher {

    private var networkInterface:String = "en0";

    public function getClientIPAddress():void
    {
        var processIp:NativeProcess = new NativeProcess();
        var file:File;
        var processArgs:Vector.<String> = new Vector.<String>();

        if(!AtsMobileStation.isMacOs) {
            file = wmicFile;
            processArgs.push("nicconfig", "where", "(IPEnabled=TRUE and DHCPEnabled=TRUE)", "get", "IPAddress", "/format:list");
            processIp.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataWin);
        } else {
            file = new File("/usr/bin/env");
            processArgs.push("ipconfig","getifaddr", networkInterface);
            processIp.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataMac);
        }

        var procInfoIp:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfoIp.executable = file;
        procInfoIp.workingDirectory = file.parent;
        procInfoIp.arguments = processArgs;
        processIp.start(procInfoIp);
    }

    private function onOutputDataWin(event:ProgressEvent):void
    {
        var process:NativeProcess = event.currentTarget as NativeProcess;
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataWin);
        var pattern:RegExp = /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/;
        var output:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
        var arrayAddresses:Array = output.match(pattern);
        if(arrayAddresses != null && arrayAddresses.length > 0) {
            var ev:NetworkEvent = new NetworkEvent(NetworkEvent.IP_ADDRESS_FOUND);
            ev.ipAddress = arrayAddresses[0];
            dispatchEvent(ev);
        }
    }

    private function onOutputDataMac(event:ProgressEvent):void
    {
        var process:NativeProcess = event.currentTarget as NativeProcess;
        process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onOutputDataMac);
        var rex:RegExp = /[\s\r\n]+/gim;

        var ev:NetworkEvent = new NetworkEvent(NetworkEvent.IP_ADDRESS_FOUND);
        ev.ipAddress = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable).replace(rex,"");

        if (ev.ipAddress == "" && networkInterface != "en1") {
            networkInterface = "en1";
            getClientIPAddress();
        } else {
            dispatchEvent(ev);
        }
    }

    private static function get wmicFile():File
    {
        var file:File = null;
        var rootPath:Array = File.getRootDirectories();
        for each(var file:File in rootPath) {
            file = file.resolvePath("Windows/System32/wbem/WMIC.exe");
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
