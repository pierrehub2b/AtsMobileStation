package device.running {

import avmplus.getQualifiedClassName;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.NativeProcessExitEvent;
import flash.filesystem.File;

import helpers.DeviceSettings;
import helpers.NetworkEvent;
import helpers.NetworkUtils;
import helpers.PortSwitcher;

import servers.tcp.WebServer;
import servers.udp.CaptureServer;

public class AndroidUsbDevice extends AndroidDevice {

    private var webServer:WebServer;
    private var captureServer:CaptureServer;

    private var webServerPort:int;
    private var captureServerPort:int;
    private var webSocketServerPort:int;

    private var webSocketClientPort:int;

    private var _networkUtils:NetworkUtils = new NetworkUtils();

    internal function get networkUtils():NetworkUtils
    {
    	return _networkUtils;
    }

    internal function set networkUtils(value:NetworkUtils):void
    {
    	_networkUtils = value;
    }

    public function AndroidUsbDevice(id:String, adbFile:File, settings:DeviceSettings) {
        super(adbFile, id);

        this.settings = settings;
        this.usbMode = true;
        this.automaticPort = settings.automaticPort;
    }

    override public function close():void
    {
        if (webServer != null) {
            webServer.close();
            webServer = null;
        }

        if (captureServer != null) {
            captureServer.close();
            captureServer = null;
        }

        super.close();
    }

    public override function start():void
    {
        fetchLocalAddress();
    }

    // --

    protected function setupAdbProcess():void {
        process = new AndroidProcess(currentAdbFile, id, "0", true);

        addAndroidProcessEventListeners();

        process.writeInfoLogFile("USB MODE = " + usbMode + " > set port: " + this.port);

        installing();
    }

    override protected function addAndroidProcessEventListeners():void
    {
        super.addAndroidProcessEventListeners();
        process.addEventListener(AndroidProcess.WEBSOCKET_SERVER_START, webSocketServerStartedHandler, false, 0, true);
        process.addEventListener(AndroidProcess.WEBSOCKET_SERVER_STOP, webSocketServerStoppedHandler, false, 0, true);
        process.addEventListener(AndroidProcess.WEBSOCKET_SERVER_ERROR, webSocketServerErrorHandler, false, 0, true);
        process.addEventListener(AndroidProcess.UNINSTALL_EXIT, onUninstallExitHandler, false, 0, true);
    }

    override protected function removeAndroidProcessEventListeners():void
    {
        super.removeAndroidProcessEventListeners();
        process.removeEventListener(AndroidProcess.WEBSOCKET_SERVER_START, webSocketServerStartedHandler);
        process.removeEventListener(AndroidProcess.WEBSOCKET_SERVER_STOP, webSocketServerStoppedHandler);
        process.removeEventListener(AndroidProcess.WEBSOCKET_SERVER_ERROR, webSocketServerErrorHandler);
        process.removeEventListener(AndroidProcess.UNINSTALL_EXIT, onUninstallExitHandler);
    }

    // -- Android Process Events

    private function webSocketServerStartedHandler(event:Event):void
    {
        process.removeEventListener(AndroidProcess.WEBSOCKET_SERVER_START, webSocketServerStartedHandler);

        trace("WebSocketServer started -> " + getQualifiedClassName(this) + id);

        webSocketServerPort = process.webSocketServerPort;
        setupPortForwarding();
    }

    private function webSocketServerStoppedHandler(event:Event):void
    {
        trace("WebSocketServer stopped -> " + getQualifiedClassName(this) + id);
        // usbError("Device server unavailable")
    }

    private function webSocketServerErrorHandler(event:Event):void
    {
        trace("WebSocketServer error -> " + getQualifiedClassName(this) + " " + id + " " + process.webSocketServerError);
        // usbError("Device server unavailable")
    }

    private function onUninstallExitHandler(event:Event):void
    {
        process.removeEventListener(AndroidProcess.UNINSTALL_EXIT, onUninstallExitHandler);
        fetchLocalPort();
    }

    private function fetchLocalAddress():void
    {
        networkUtils.addEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler, false, 0, true);
        networkUtils.addEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler, false, 0, true);

        networkUtils.getClientIPAddress();
    }

    // -- Network Utils Events

    private function localAddressFoundHandler(event:NetworkEvent):void
    {
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler);
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler);
        networkUtils = null;

        this.ip = event.ipAddress;

        setupAdbProcess();
        super.start()
    }

    private function localAddressNotFoundHandler(event:NetworkEvent):void
    {
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_FOUND, localAddressFoundHandler);
        networkUtils.removeEventListener(NetworkEvent.IP_ADDRESS_NOT_FOUND, localAddressNotFoundHandler);
        networkUtils = null;

        usbError("Retrieve local address error");
    }

    // ----

    private function fetchLocalPort():void
    {
        var portSwitcher:PortSwitcher = new PortSwitcher();
        portSwitcher.addEventListener(PortSwitcher.PORT_NOT_AVAILABLE_EVENT, portSwitcherErrorHandler, false, 0, true);

        settings.port = portSwitcher.getLocalPort(this.id, automaticPort);
        this.port = settings.port.toString();

        if (errorMessage == "") {
            setupWebServer(settings.port);
        }
    }

    // -- Port Switcher Events

    private function portSwitcherErrorHandler(event:Event):void
    {
        (event.currentTarget as PortSwitcher).removeEventListener(PortSwitcher.PORT_NOT_AVAILABLE_EVENT, portSwitcherErrorHandler);
        usbError("Port unavailable");
    }

    // ----

    private function setupWebServer(port:int):void
    {
        webServer = new WebServer();
        webServer.addEventListener(WebServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler, false, 0, true);
        webServer.addEventListener(WebServer.WEB_SERVER_STARTED, webServerStartedHandler, false, 0, true);
        webServer.addEventListener(WebServer.WEB_SERVER_ERROR, webServerErrorHandler, false, 0, true);
        webServer.bind(port);
    }

    // -- Web Server Events

    private function webServerInitializedHandler(event:Event):void
    {
        webServer.removeEventListener(WebServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);

        this.webServerPort = webServer.getLocalPort();

        setupCaptureServer();
    }

    private function webServerStartedHandler(event:Event):void
    {
        webServer.removeEventListener(WebServer.WEB_SERVER_STARTED, webServerInitializedHandler);

        captureServer.setupWebSocket(webSocketClientPort);
    }

    private function webServerErrorHandler(event:Event):void
    {
        webServer.removeEventListener(WebServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
        webServer.removeEventListener(WebServer.WEB_SERVER_STARTED, webServerStartedHandler);
        webServer.removeEventListener(WebServer.WEB_SERVER_ERROR, webServerErrorHandler);

        usbError("Web server error");
    }

    // --

    private function setupCaptureServer():void
    {
        captureServer = new CaptureServer();
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_INITIALIZED, captureServerInitializedHandler, false, 0, true);
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_STARTED, captureServerStartedHandler, false, 0, true);
        captureServer.addEventListener(CaptureServer.CAPTURE_SERVER_ERROR, captureServerErrorHandler, false, 0, true);
        captureServer.bind();
    }

    // -- Capture Server Events

    private function captureServerInitializedHandler(event:Event):void
    {
        captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_INITIALIZED, webServerInitializedHandler);

        this.captureServerPort = captureServer.getLocalPort();

        process.executeUsb(ip, webServerPort, captureServerPort);
    }

    private function captureServerStartedHandler(event:Event):void
    {
        captureServer.removeEventListener(CaptureServer.CAPTURE_SERVER_STARTED, webServerInitializedHandler);

        started();
    }

    private function captureServerErrorHandler(event:Event):void
    {
        captureServer.removeEventListener(WebServer.WEB_SERVER_INITIALIZED, webServerInitializedHandler);
        captureServer.removeEventListener(WebServer.WEB_SERVER_STARTED, webServerInitializedHandler);
        captureServer.removeEventListener(WebServer.WEB_SERVER_ERROR, webServerInitializedHandler);

        usbError("Capture server initialization error");
    }

    private function setupPortForwarding():void
    {
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

    private function forwardPortExitHandler(event:Event):void
    {
        (event.currentTarget as NativeProcess).removeEventListener(NativeProcessExitEvent.EXIT, forwardPortExitHandler);

        webServer.setupWebSocket(webSocketClientPort);
    }
}
}
