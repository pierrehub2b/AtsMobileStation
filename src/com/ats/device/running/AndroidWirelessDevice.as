package com.ats.device.running {

public class AndroidWirelessDevice extends AndroidDevice {

    public function AndroidWirelessDevice(id:String, automaticPort:Boolean, port:int) {
        super(id, false);

        this.automaticPort = automaticPort;
        this.port = port.toString();
        this.usbMode = false;
    }

    override protected function fetchIpAddress():void {
        var arguments:Vector.<String> = new <String>["-s", id, "shell", "ip", "route"];
        adbProcess.execute(arguments, onReadLanExit)
    }

    protected function onReadLanExit():void {
        var processError:String = adbProcess.error
        if (processError) {
            trace(processError)
            // dispatchEvent(new Event(ERROR_EVENT));
            return
        }

        var ipRouteDataUdp:Array = adbProcess.output.split("\r\r\n");
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

    override protected function onUninstallDriverExit():void {
        installDriver()
    }

    override protected function executeDriver():void {
        var arguments: Vector.<String> = new <String>[
            "-s", id, "shell", "am", "instrument", "-w",
            "-e", "ipAddress", ip,
            "-e", "atsPort", port,
            "-e", "usbMode", String(usbMode),
            "-e", "debug", "false",
            "-e", "class", ANDROID_DRIVER + ".AtsRunnerWifi", ANDROID_DRIVER + "/android.support.test.runner.AndroidJUnitRunner"
        ]

        adbProcess.execute(arguments, onExecuteExit, onExecuteOutput, onExecuteError)
    }
}
}
