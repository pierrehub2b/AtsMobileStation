package com.ats.tools {
import com.ats.device.running.RunningDevice;
import com.ats.helpers.Settings;
import com.ats.managers.RunningDevicesManager;
import com.greensock.TweenMax;

import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.NativeProcessExitEvent;
import flash.events.NetStatusEvent;
import flash.events.ProgressEvent;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
import flash.net.NetConnection;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.utils.ByteArray;

import mx.collections.ArrayCollection;

import mx.events.CollectionEvent;
import mx.events.CollectionEventKind;

public class PeerGroupConnection extends EventDispatcher {

    public static const monaServerFolder:String = "assets/tools/monaserver";

    private static const rtmpProtocol:String = "RTMP";
    private static const defaultRtmpPort:int = 1935;

    private var httpPort:int = 8989;
    private var rtmpPort:int = defaultRtmpPort;

    private var devicesManager:RunningDevicesManager;

    private var monaServerBinary:File;
    private var monaServerProc:NativeProcess;

    public var description:String = "";
    public var name:String = "";
    public var identifier:String = "";

    private var mona:File;
    private var monaInstallFolder:File;

    [Bindable]
    public var netConnection:NetConnection;

    [Bindable]
    public var clients:ArrayCollection

    public function PeerGroupConnection(workFolder:File, devManager:RunningDevicesManager, port:int) {
        devicesManager = devManager;
        httpPort = port;
        monaInstallFolder = workFolder.resolvePath("monaserver");
        mona = File.applicationDirectory.resolvePath(monaServerFolder);
    }

    public function start():void {
        if (mona.exists) {
            const iniFile:File = monaInstallFolder.resolvePath("server").resolvePath("MonaServer.ini");

            updateMonaServerSiteFolder();

            if (iniFile.exists) {
                const iniFileLoader:URLLoader = new URLLoader();
                iniFileLoader.addEventListener(Event.COMPLETE, iniFileLoaded, false, 0, true);
                iniFileLoader.load(new URLRequest(iniFile.url));
            } else {
                installMonaserver();
            }
        }
    }

    private function iniFileLoaded(ev:Event):void {
        var loader:URLLoader = ev.currentTarget as URLLoader;
        var data:Array = loader.data.split("\n");

        for (var i:int = 0; i < data.length; ++i) {
            if (data[i] == "[" + rtmpProtocol + "]") {
                const dataPort:Array = data[i + 1].split("=");
                connectToMonaserver(parseInt(dataPort[1]));
                break;
            }
        }
    }

    private function connectToMonaserver(port:int):void {
        if (port > 0) {
            netConnection = new NetConnection();
            netConnection.objectEncoding = 3;
            netConnection.addEventListener(NetStatusEvent.NET_STATUS, onFirstConnect);
            netConnection.addEventListener(IOErrorEvent.IO_ERROR, netIOError);
            netConnection.client = this;
            netConnection.connect(rtmpProtocol.toLowerCase() + "://localhost:" + port + "/", "mobilestation");
        }
    }

    private static function netIOError(ev:IOErrorEvent):void {
        trace("io error : " + ev);
    }

    private function onFirstConnect(ev:NetStatusEvent):void {
        // netConnection.removeEventListener(NetStatusEvent.NET_STATUS, onFirstConnect);
        // netConnection.removeEventListener(IOErrorEvent.IO_ERROR, netIOError);

        switch (ev.info.code) {
            case "NetConnection.Connect.Success":
                trace("connected to MonaServer!");
                initData(ev.info);
                break;
            case "NetConnection.Connect.Failed":
                trace("MonaServer not running, launch install ...");
                installMonaserver();
                break;
            default:
                break;
        }
    }

    private function initData(info:Object):void {
        name = info.name
        description = info.description
        identifier = info.identifier
        clients = new ArrayCollection(info.clients)

        devicesManager.collection.addEventListener(CollectionEvent.COLLECTION_CHANGE, devicesChangeHandler);

        dispatchEvent(new Event(Event.INIT))
    }

    //--------------------------------------------------------------------------------------------------------
    // Client methods
    //--------------------------------------------------------------------------------------------------------

    public function onClientDisconnection(disconnectedClient:String):void {
        var index:int = clients.getItemIndex(disconnectedClient)
        if (index > -1) {
            clients.removeItemAt(index)
        }
    }

    public function onClientConnection(client:String):void {
        clients.addItem(client)
    }

    public function installApp(url:String, target:String, deviceIds:Array):void {
        devicesManager.installApp(url, target, deviceIds);
    }

    public function saveValues(desc:String, nm:String):void {
        netConnection.call("updateInfo", null, nm, desc);
    }

    public function devices(devices:Array, updateType:String):void {
    }

    public function msStatus(type:String):void {
    }

    public function catchGesture(path:ByteArray):void {
    }

    public function infoUpdated(nm:String, desc:String):void {
        description = desc;
        name = nm;
    }

    public function close():void {
        clients.removeAll()
        devicesManager.collection.removeEventListener(CollectionEvent.COLLECTION_CHANGE, devicesChangeHandler);
        netConnection.call("close", null);
    }

    public function updateMonaServerSiteFolder():void {
        mona.resolvePath("server").resolvePath("www").copyTo(monaInstallFolder.resolvePath("server").resolvePath("www"), true);
    }

    //--------------------------------------------------------------------------------------------------------
    //--------------------------------------------------------------------------------------------------------

    public function installMonaserver():void {

        if (Settings.isMacOs) {
            mona.resolvePath("server").resolvePath("MonaServer").copyTo(monaInstallFolder.resolvePath("server").resolvePath("MonaServer"), true);
            mona.resolvePath("MonaBase").copyTo(monaInstallFolder.resolvePath("MonaBase"), true);
            mona.resolvePath("MonaCore").copyTo(monaInstallFolder.resolvePath("MonaCore"), true);

            const libName:String = "libluajit-5.1.2.dylib";
            const localLib:File = new File("/usr/local/lib/" + libName);
            if (!localLib.exists) {
                const lib:File = mona.resolvePath(libName);
                lib.copyTo(localLib);
            }

            monaServerBinary = monaInstallFolder.resolvePath("server").resolvePath("MonaServer");
            if (monaServerBinary.exists) {
                const procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
                procInfo.executable = new File("/bin/chmod");
                procInfo.workingDirectory = monaInstallFolder;
                procInfo.arguments = new <String>["+x", "server/MonaServer"];

                const proc:NativeProcess = new NativeProcess();
                proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
                proc.start(procInfo);
            }
        } else {
            mona.resolvePath("server").resolvePath("lua51.dll").copyTo(monaInstallFolder.resolvePath("server").resolvePath("lua51.dll"), true);
            mona.resolvePath("server").resolvePath("MonaServer.exe").copyTo(monaInstallFolder.resolvePath("server").resolvePath("MonaServer.exe"), true);

            monaServerBinary = monaInstallFolder.resolvePath("server").resolvePath("MonaServer.exe");
            if (monaServerBinary.exists) {
                startMonaServer();
            }
        }
    }

    protected function onChmodExit(ev:NativeProcessExitEvent):void {
        ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
        ev.target.closeInput();
        startMonaServer();
    }

    private function startMonaServer():void {

        saveIniFile(monaServerBinary.parent.resolvePath("MonaServer.ini"));

        const procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
        procInfo.executable = monaServerBinary;
        procInfo.workingDirectory = monaServerBinary.parent;

        monaServerProc = new NativeProcess();

        if (Settings.isMacOs) {
            procInfo.arguments.push("--daemon");
            monaServerProc.addEventListener(NativeProcessExitEvent.EXIT, monaServerDaemonExit, false, 0, true);
        } else {
            monaServerProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onMonaServerRun, false, 0, true);
        }

        monaServerProc.start(procInfo);
    }

    protected function monaServerDaemonExit(ev:NativeProcessExitEvent):void {
        monaServerProc.removeEventListener(NativeProcessExitEvent.EXIT, monaServerDaemonExit);
        TweenMax.delayedCall(0.5, connectToPeerGroup);
    }

    protected function onMonaServerRun(ev:ProgressEvent):void {
        const len:int = ev.target.standardOutput.bytesAvailable;
        const data:String = ev.target.standardOutput.readUTFBytes(len);
        trace(data)

        if (data.indexOf(rtmpProtocol + " server started") > -1) {
            //monaServerProc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onMonaServerRun);
            connectToPeerGroup();
        }
    }

    private function connectToPeerGroup():void {
        netConnection = new NetConnection();
        netConnection.objectEncoding = 3;
        netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        netConnection.client = this;
        netConnection.connect(rtmpProtocol.toLowerCase() + "://localhost:" + rtmpPort + "/", "mobilestation");
    }

    private var maxTry:int = 20;

    private function onNetStatus(ev:NetStatusEvent):void {
        netConnection.removeEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        switch (ev.info.code) {
            case "NetConnection.Connect.Success":
                trace("connected to MonaServer!");
                initData(ev.info);
                break;
            case "NetConnection.Connect.Failed":
                maxTry--;
                if (maxTry > 0) {
                    TweenMax.delayedCall(0.5, connectToPeerGroup);
                }
                break;
            default:
                break;
        }
    }

    private function devicesChangeHandler(ev:CollectionEvent):void {
        var dev:RunningDevice
        if (ev.kind == CollectionEventKind.REMOVE) {
            dev = ev.items[0] as RunningDevice
            netConnection.call("deviceRemoved", null, dev.monaDevice);
        } else if (ev.kind == CollectionEventKind.UPDATE) {
            dev = ev.items[0].source as RunningDevice
            if (ev.items[0].property == "status") {
                netConnection.call("updateDevice", null, dev.monaDevice);
                if (ev.items[0].newValue == "ready") {
                    netConnection.call("pushDevice", null, dev.monaDevice);
                }
            } else if (ev.items[0].property == "locked") {
                netConnection.call("deviceLocked", null, dev.monaDevice);
            }
        }
    }

    public function terminate():void {
        netConnection.call("terminate", null);
    }

    private function saveIniFile(monServerIni:File):void {
        const stream:FileStream = new FileStream();
        stream.open(monServerIni, FileMode.WRITE);
        stream.writeUTFBytes("[RTMFP]\nport = " + rtmpPort + "\n[RTMP]\nport = " + rtmpPort + "\n[HTTP]\nport = " + httpPort + "\nindex = index.html\n[RTSP]\nport = 0\n[WebSocket]\ntimeout = 120");
        stream.close();
    }
}
}