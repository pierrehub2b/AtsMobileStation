package com.ats.device.running {

import avmplus.getQualifiedClassName;

import com.ats.helpers.DeviceSettings;
import com.ats.helpers.NetworkUtils;
import com.ats.helpers.PortSwitcher;
import com.ats.servers.tcp.ProxyServer;
import com.ats.servers.udp.CaptureServer;

import flash.events.Event;

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

    // ----

    private function fetchLocalPort():void {
        printDebugLogs("Fetching local port")

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
    }

    private function captureServerStartedHandler(event:Event):void {
        captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_STARTED, webServerInitializedHandler);
    }

    private function captureServerErrorHandler(event:Event):void {
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_STARTED, webServerStartedHandler);
        captureServer.removeEventListener(ProxyServer.WEB_SERVER_ERROR, webServerErrorHandler);

        usbError("Capture server initialization error");
    }

    private static function getWebSocketServerPort(data:String):int {
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

    // -- Native Process Exit Events

    private static function getWebSocketServerError(data:String):String {
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

    override protected function executeDriver():void {
        printDebugLogs("Starting driver")

        var arguments:Vector.<String> = new <String>[
            "-s", id, "shell", "am", "instrument", "-w",
            "-e", "ipAddress", ip,
            "-e", "atsPort", port,
            "-e", "usbMode", String(usbMode),
            "-e", "udpPort", String(captureServerPort),
            "-e", "debug", "false",
            "-e", "class", ANDROID_DRIVER + ".AtsRunnerUsb", ANDROID_DRIVER + "/android.support.test.runner.AndroidJUnitRunner"
        ]

        adbProcess = new AdbProcess();
        adbProcess.execute(arguments, onExecuteExit, onExecuteOutput, onExecuteError)
    }

    override protected function fetchIpAddress():void {
        printDebugLogs("Fetching ip address")
		
		ip = NetworkUtils.getClientLocalIpAddress();
		if(ip != null){
			uninstallDriver();
		}else{
			usbError("Retrieve local address error");
		}
    }

    private function setupPortForwarding():void {
        webSocketClientPort = PortSwitcher.getAvailableLocalPort();

        var adbProcess:AdbProcess = new AdbProcess()
        var arguments:Vector.<String> = new <String>["-s", id, "forward", "tcp:" + webSocketClientPort, "tcp:" + webSocketServerPort];
        adbProcess.execute(arguments, forwardPortExitHandler)
    }

    override protected function onUninstallDriverExit():void {
        fetchLocalPort();
    }

    override protected function onExecuteOutput():void {
        super.onExecuteOutput()

        var executeOutput:String = adbProcess.partialOutput
        if (executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_START:") > -1) {
            webSocketServerPort = getWebSocketServerPort(executeOutput);
            setupPortForwarding();
        } else if (executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_ERROR") > -1) {
            var webSocketServerError:String = getWebSocketServerError(executeOutput);
            trace("WebSocketServer error -> " + getQualifiedClassName(this) + " " + id + " " + webSocketServerError);
        } else if (executeOutput.indexOf("ATS_WEB_SOCKET_SERVER_STOP") > -1) {
            trace("WebSocketServer stopped -> " + getQualifiedClassName(this) + id);
        }
    }

    private function forwardPortExitHandler():void {
        webServer.setupWebSocket(webSocketClientPort);
    }
}
}
