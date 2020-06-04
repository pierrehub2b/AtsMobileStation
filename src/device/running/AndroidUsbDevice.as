package device.running {

import avmplus.getQualifiedClassName;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.events.ProgressEvent;

import helpers.DeviceSettings;
import helpers.NetworkEvent;
import helpers.NetworkUtils;
import helpers.PortSwitcher;

import servers.tcp.ProxyServer;
import servers.udp.CaptureServer;

public class AndroidUsbDevice extends AndroidDevice {

    private var webServer:ProxyServer;
    private var captureServer:CaptureServer;

    private var webServerPort:int;
    private var captureServerPort:int;
    private var webSocketServerPort:int;
    private var webSocketClientPort:int;

    private var networkUtils:NetworkUtils = new NetworkUtils();

    public function AndroidUsbDevice(id:String, simulator:Boolean, settings:DeviceSettings) {
        super(id, simulator);

        this.settings = settings;
        this.usbMode = true;
        this.automaticPort = settings.automaticPort;
    }

    override public function close():void {
        if (webServer != null) {
            webServer.removeEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
            webServer.removeEventListener(ProxyServer.WEB_SERVER_STARTED, webServerStartedHandler);
            webServer.removeEventListener(ProxyServer.WEB_SERVER_ERROR, webServerErrorHandler);

            webServer.close();
            webServer = null;
        }

        if (captureServer != null) {
            captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_INITIALIZED, captureServerInitializedHandler);
            captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_STARTED, captureServerStartedHandler);
            captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_ERROR, captureServerErrorHandler);

            captureServer.close();
            captureServer = null;
        }

        super.close();
    }

    // -- Android Process Events

    /* private function webSocketServerStarted(port:int):void {
        trace("WebSocketServer started -> " + getQualifiedClassName(this) + id);

        webSocketServerPort = port
        setupPortForwarding();
    }

    private function webSocketServerStoppedHandler(event:Event):void {
        trace("WebSocketServer stopped -> " + getQualifiedClassName(this) + id);
        // usbError("Device server unavailable")
    }

    private function webSocketServerErrorHandler(event:Event):void {
        // trace("WebSocketServer error -> " + getQualifiedClassName(this) + " " + id + " " + process.webSocketServerError);
        // usbError("Device server unavailable")
    } */

    // -- Network Utils Events

    private function localAddressFoundHandler(event:NetworkEvent):void {
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler);
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler);
        networkUtils = null;

        this.ip = event.ipAddress;

        uninstallDriver()
    }

    private function localAddressNotFoundHandler(event:NetworkEvent):void {
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler);
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler);
        networkUtils = null;

        usbError("Retrieve local address error");
    }

    // ----

    private function fetchLocalPort():void {
        var portSwitcher:PortSwitcher = new PortSwitcher();
        portSwitcher.addEventListener(PortSwitcher.PORT_NOT_AVAILABLE_EVENT, portSwitcherErrorHandler, false, 0, true);

        settings.port = portSwitcher.getLocalPort(this.id, automaticPort);
        this.port = settings.port.toString();

        if (!errorMessage) {
            setupWebServer(settings.port);
        }
    }

    // -- Port Switcher Events

    private function portSwitcherErrorHandler(event:Event):void {
        (event.currentTarget as PortSwitcher).removeEventListener(PortSwitcher.PORT_NOT_AVAILABLE_EVENT, portSwitcherErrorHandler);
        usbError("Port unavailable");
    }

    // ----

    private function setupWebServer(port:int):void {
        webServer = new ProxyServer();
        webServer.addEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler, false, 0, true);
        webServer.addEventListener(ProxyServer.WEB_SERVER_STARTED, webServerStartedHandler, false, 0, true);
        webServer.addEventListener(ProxyServer.WEB_SERVER_ERROR, webServerErrorHandler, false, 0, true);
        webServer.bind(port);
    }

    // -- Web Server Events

    private function webServerInitializedHandler(event:Event):void {
        webServer.removeEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);

        this.webServerPort = webServer.getLocalPort();

        setupCaptureServer();
    }

    private function webServerStartedHandler(event:Event):void {
        webServer.removeEventListener(ProxyServer.WEB_SERVER_STARTED, webServerInitializedHandler);

        captureServer.setupWebSocket(webSocketClientPort);
    }

    private function webServerErrorHandler(event:Event):void {
        webServer.removeEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
        webServer.removeEventListener(ProxyServer.WEB_SERVER_STARTED, webServerStartedHandler);
        webServer.removeEventListener(ProxyServer.WEB_SERVER_ERROR, webServerErrorHandler);

        usbError("Web server error");
    }

    // --

    private function setupCaptureServer():void {
        captureServer = new CaptureServer();
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_INITIALIZED, captureServerInitializedHandler, false, 0, true);
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_STARTED, captureServerStartedHandler, false, 0, true);
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_ERROR, captureServerErrorHandler, false, 0, true);
        captureServer.bind();
    }

    // -- Capture Server Events

    private function captureServerInitializedHandler(event:Event):void {
        captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_INITIALIZED, webServerInitializedHandler);

        this.captureServerPort = captureServer.getLocalPort();

        installDriver()
        // process.executeUsb(ip, webServerPort, captureServerPort);
    }

    private function captureServerStartedHandler(event:Event):void {
        captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_STARTED, webServerInitializedHandler);
        started();
    }

    private function captureServerErrorHandler(event:Event):void {
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_STARTED, webServerStartedHandler);
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_ERROR, webServerErrorHandler);

        usbError("Capture server initialization error");
    }

    private function setupPortForwarding():void {
        var process:NativeProcess = new NativeProcess();
        var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();

        procInfo.executable = currentAdbFile;
        procInfo.workingDirectory = currentAdbFile.parent;
        process.addEventListener(NativeProcessExitEvent.EXIT, forwardPortExitHandler, false, 0, true);

        webSocketClientPort = PortSwitcher.getAvailableLocalPort();

        procInfo.arguments = new <String>["-s", id, "forward", "tcp:" + webSocketClientPort, "tcp:" + webSocketServerPort];
        process.start(procInfo);
    }

    // -- Native Process Exit Events

    private function forwardPortExitHandler(event:Event):void {
        (event.currentTarget as NativeProcess).removeEventListener(NativeProcessExitEvent.EXIT, forwardPortExitHandler);
        webServer.setupWebSocket(webSocketClientPort);
    }

    override protected function fetchIpAddress():void {
        networkUtils.addEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler, false, 0, true);
        networkUtils.addEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler, false, 0, true);

        networkUtils.getClientIPAddress();
    }

    override protected function onUninstallDriverExit(event:NativeProcessExitEvent):void {
        super.onUninstallDriverExit(event)
        fetchLocalPort();
    }

    override protected function execute():void {
        var processInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
        processInfo.executable = currentAdbFile
        processInfo.arguments = new <String>["-s", id, "shell"]

        process = new NativeProcess();
        process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onExecuteOutput, false, 0, true);
        process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onExecuteError, false, 0, true);
        process.addEventListener(NativeProcessExitEvent.EXIT, onExecuteExit, false, 0, true);
        process.start(processInfo);

        process.standardInput.writeUTFBytes("am instrument -w -e ipAddress " + ip + " -e atsPort " + port +" -e usbMode " + usbMode + " -e udpPort " + captureServerPort + " -e debug false -e class " + ANDROID_DRIVER + ".AtsRunnerUsb " + ANDROID_DRIVER + "/android.support.test.runner.AndroidJUnitRunner &\r\n")
    }

    override protected function onExecuteOutput(event:ProgressEvent):void {
        super.onExecuteOutput(event)

        if (executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_START:") > -1) {
            webSocketServerPort = getWebSocketServerPort(executeOutput);
            setupPortForwarding();
        } else if(executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_ERROR") > -1) {
            var webSocketServerError:String = getWebSocketServerError(executeOutput);
            trace("WebSocketServer error -> " + getQualifiedClassName(this) + " " + id + " " + webSocketServerError);
            // usbError("Device server unavailable")
        } else if(executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_STOP") > -1) {
            trace("WebSocketServer stopped -> " + getQualifiedClassName(this) + id);
            // usbError("Device server unavailable")
        }
    }

    private function getWebSocketServerPort(data:String):int
    {
        var array:Array = data.split("\n");
        for each(var line:String in array) {
            if (line.indexOf("ATS_WEB_SOCKET_SERVER_START") > -1) {
                var parameters:Array = line.split("=");
                var subparameters:Array = (parameters[1] as String).split(":");
                return parseInt(subparameters[1]);
            }
        }

        return -1;
    }

    private function getWebSocketServerError(data:String):String
    {
        var array:Array = data.split("\n");
        for each(var line:String in array) {
            if (line.indexOf("ATS_WEB_SOCKET_SERVER_ERROR") > -1) {
                var firstIndex:int = line.length;
                var lastIndex:int = line.lastIndexOf("ATS_WEB_SOCKET_SERVER_ERROR:") + "ATS_WEB_SOCKET_SERVER_ERROR:".length;
                return line.substring(lastIndex, firstIndex);
            }
        }

        return "";
    }
}
}
