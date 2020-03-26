package device.running {
import flash.events.Event;
import flash.filesystem.File;

public class AndroidWirelessDevice extends AndroidDevice {

    public function AndroidWirelessDevice(id:String, adbFile:File, automaticPort:Boolean, port:int) {
        super(adbFile, id);

        this.automaticPort = automaticPort;
        this.port = port.toString();
        this.usbMode = false;

        setupAdbProcess();
    }

    protected function setupAdbProcess():void {

        process = new AndroidProcess(currentAdbFile, id, this.port, usbMode);

        addAndroidProcessEventListeners();

        process.writeInfoLogFile("USB MODE = " + usbMode + " > set port: " + this.port);

        installing();
    }

    override protected function addAndroidProcessEventListeners():void
    {
        super.addAndroidProcessEventListeners()
        process.addEventListener(AndroidProcess.IP_ADDRESS, ipAddressHandler, false, 0, true);
        process.addEventListener(AndroidProcess.WIFI_ERROR_EVENT, processWifiErrorHandler, false, 0, true);
    }

        override protected function removeAndroidProcessEventListeners():void
    {
        super.removeAndroidProcessEventListeners();
        process.removeEventListener(AndroidProcess.WIFI_ERROR_EVENT, processWifiErrorHandler);
        process.removeEventListener(AndroidProcess.IP_ADDRESS, ipAddressHandler);
    }

    private function ipAddressHandler(ev:Event):void{
        process.removeEventListener(AndroidProcess.IP_ADDRESS, ipAddressHandler);
        ip = process.ipAddress;
        udpIpAdresse = process.deviceIp;
    }

    override public function runningTestHandler(ev:Event):void
    {
        super.runningTestHandler(ev);

        status = READY;
        tooltip = "Android " + androidVersion + ", API " + androidSdk + " [" + id + "]\nready and waiting testing actions";
        started();
    }

    private function processWifiErrorHandler(ev:Event):void{
        removeAndroidProcessEventListeners();
        status = WIFI_ERROR;

        process.writeErrorLogFile("WIFI error"); //TODO add more detailed info
    }
}
}
