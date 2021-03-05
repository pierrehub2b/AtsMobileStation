package com.ats.managers {
    import com.ats.device.Device;
    import com.ats.device.running.AndroidDevice;
    import com.ats.device.running.IosDevice;
    import com.ats.device.running.IosDeviceInfo;
    import com.ats.device.running.RunningDevice;
    import com.ats.device.simulator.IosSimulator;
    import com.ats.device.simulator.Simulator;
    import com.ats.helpers.Settings;
    import com.greensock.TweenLite;

    import flash.desktop.NativeProcess;
    import flash.desktop.NativeProcessStartupInfo;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.NativeProcessExitEvent;
    import flash.events.ProgressEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.system.System;

    import mx.collections.ArrayCollection;
    import mx.core.FlexGlobals;
    import mx.events.CollectionEvent;
    import mx.utils.UIDUtil;
    import mx.utils.URLUtil;

    public class RunningDevicesManager extends EventDispatcher {

        private const envFile:File = new File("/usr/bin/env");
        private const sysprofilerArgs:Vector.<String> = new <String>["system_profiler", "SPUSBDataType", "-json"];
        private const adbListDevicesArgs:Vector.<String> = new <String>["devices", "-l"];
        private const adbKillServer:Vector.<String> = new <String>["kill-server"];

        public static const endOfMessage:String = "<$ATSDROID_endOfMessage$>";
        // private const iosDevicePattern:RegExp = /(.*)\(([^\)]*)\).*\[(.*)\](.*)/;
        // private const jsonPattern:RegExp = /\{[^]*\}/;
        public static const responseSplitter:String = "<$atsDroid_ResponseSPLIITER$>";

        public static var devTeamId:String = "";

        private static function isSimulator(info:Array):Boolean {
            var isSimulator:Boolean = false
            for each (var line:String in info) {
                if (line.indexOf("device:") == 0) {
                    var deviceName:String = line.replace("device:", "")
                    return deviceName.indexOf("generic") == 0 || deviceName.indexOf("vbox") == 0
                }
            }

            return isSimulator
        }

        public function RunningDevicesManager() {
            const adbFolder:File = Settings.workAdbFolder;
            if (Settings.isMacOs) {

                adbFile = adbFolder.resolvePath("adb");

                var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo()
                procInfo.executable = new File("/bin/chmod")
                procInfo.workingDirectory = File.applicationDirectory.resolvePath("assets/tools")
                procInfo.arguments = new <String>["+x", "android/adb", "ios/mobiledevice"]

                var proc:NativeProcess = new NativeProcess();
                proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
                proc.start(procInfo);

            } else {
                adbFile = adbFolder.resolvePath("adb.exe");
                // only one type of devices to find, we can do loop faster
                adbLoop = TweenLite.delayedCall(2, launchAdbProcess);
            }
        }

        [Bindable]
        public var collection:ArrayCollection = new ArrayCollection();
        private var adbFile:File;
        private var androidOutput:String;
        private var iosOutput:String;
        private var adbLoop:TweenLite;
        private var iosLoop:TweenLite;
        private var usbDevicesIdList:Vector.<String>;
        private var urlLoader:URLLoader;
		private var isInstalling:Boolean = false

        public function terminate():void {
            adbLoop.pause();
            TweenLite.killDelayedCallsTo(launchAdbProcess)
            if (iosLoop != null) {
                iosLoop.pause();
                TweenLite.killDelayedCallsTo(launchIosProcess)
            }

            var dv:RunningDevice;
            for each(dv in collection) {
                dv.close();
            }

            var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
            procInfo.executable = adbFile;
            procInfo.workingDirectory = File.userDirectory;
            procInfo.arguments = adbKillServer;

            var proc:NativeProcess = new NativeProcess();
            proc.addEventListener(NativeProcessExitEvent.EXIT, onKillServerExit, false, 0, true);
            proc.start(procInfo);
        }

        public function restartDev(dev:Device):void {
            dev.close();
        }

        public function findDevice(id:String):RunningDevice {
            for each(var dv:RunningDevice in collection) {
                if (dv.id == id) {
                    return dv;
                }
            }
            return null;
        }

        private function launchAdbProcess():void {
            androidOutput = ""

            var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
            procInfo.executable = adbFile;
            procInfo.workingDirectory = File.userDirectory;
            procInfo.arguments = adbListDevicesArgs;

            var proc:NativeProcess = new NativeProcess();
            proc.addEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit, false, 0, true);
            proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData, false, 0, true);
            proc.start(procInfo);
        }

        private function getDevicesIds(itmList:Object):void {
            for each (var object:Object in itmList) {
                if (object.hasOwnProperty("_items")) {
                    getDevicesIds(object._items)
                } else {
                    const name:String = object._name.toString().toLowerCase();
                    if (name == "iphone") {
                        var serialNumber:String = object.serial_num
                        if (serialNumber.length == 24) {
                            serialNumber = serialNumber.slice(0, 8) + "-" + serialNumber.slice(8);
                        }

                        usbDevicesIdList.push(serialNumber);
                    }
                }
            }
        }

        private function launchIosProcess():void {
            iosOutput = String("");

            var proc:NativeProcess = new NativeProcess();
            var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();

            procInfo.executable = envFile;
            procInfo.workingDirectory = File.userDirectory;
            procInfo.arguments = sysprofilerArgs;

            proc.addEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
            proc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
            proc.start(procInfo);
        }

        private function loadDevicesId():void {
            if (usbDevicesIdList.length > 0) {

                var id:String = usbDevicesIdList.pop();
                const dev:RunningDevice = findDevice(id) as IosDevice;

                if (dev == null) {
                    var devInfo:IosDeviceInfo = new IosDeviceInfo(id);
                    devInfo.addEventListener(Event.COMPLETE, realDevicesInfoLoaded, false, 0, true);
                    devInfo.load();
                } else {
                    loadDevicesId()
                }
            } else {
                realDevicesLoaded();
            }
        }

        private function realDevicesLoaded():void {
            for each(var sim:Simulator in FlexGlobals.topLevelApplication.simulators.collection) {
                if (sim is IosSimulator) {
                    if (sim.started) {
                        var dev:IosDevice = findDevice(sim.id) as IosDevice;
                        if (dev == null) {
                            dev = (sim as IosSimulator).GetDevice;
                            dev.start();
                            dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);

                            collection.addItem(dev);
                            collection.refresh();
                        }
                    }
                }
            }

            iosLoop.restart(true);
        }

        public function deviceStoppedHandler(ev:Event):void {

            var dv:RunningDevice = ev.currentTarget as RunningDevice;
            dv.removeEventListener(Device.STOPPED_EVENT, deviceStoppedHandler);
            var index:int = collection.getItemIndex(dv);
            collection.removeItemAt(index);
            collection.refresh();
        }

        //---------------------------------------------------------------------------------------------------------
        //---------------------------------------------------------------------------------------------------------

        protected function onChmodExit(ev:NativeProcessExitEvent):void {
            ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
            ev.target.closeInput();

            adbLoop = TweenLite.delayedCall(5, launchAdbProcess);
            iosLoop = TweenLite.delayedCall(5, launchIosProcess);
        }

        protected function onReadAndroidDevicesData(ev:ProgressEvent):void {
            const len:int = ev.target.standardOutput.bytesAvailable;
            const data:String = ev.target.standardOutput.readUTFBytes(len);
            androidOutput += data
        }

        protected function onReadAndroidDevicesExit(ev:NativeProcessExitEvent):void {
            ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onReadAndroidDevicesExit);
            ev.target.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadAndroidDevicesData);
            ev.target.closeInput();

            //------------------------------------------------------------------------------------------

            var data:Array = androidOutput.split("\n");
            var runningIds:Vector.<String> = new Vector.<String>();

            if (data.length > 1) {

                data.shift();

                const len:int = data.length;
                var dev:RunningDevice;

                for (var i:int = 0; i < len; i++) {
                    const info:Array = data[i].split(/\s+/g);
                    const runningId:String = info[0];
                    const deviceState:String = info[1]

                    const isEmulator:Boolean = isSimulator(info)

                    runningIds.push(runningId);

                    if (info.length > 2 && runningId.length > 0 && deviceState == "device") {
                        dev = findDevice(runningId);

                        if (dev != null) {
                            if (dev.status == Device.FAIL) {
                                dev.close();
                            } else if (dev.status == Device.BOOT) {
                                dev.start()
                            }
                        } else {
                            dev = AndroidDevice.setup(runningId, isEmulator);
                            dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);
                            dev.start();

                            collection.addItem(dev);
                            collection.refresh();
                        }
                    }
                }
            }

            for each (var androidDev:RunningDevice in collection) {
                if (androidDev is AndroidDevice && !androidDev.simulator && runningIds.indexOf(androidDev.id) < 0) {
                    androidDev.close()
                }
            }

            System.gc();
            adbLoop.restart(true);
        }

        private function onKillServerExit(ev:NativeProcessExitEvent):void {
            ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onKillServerExit);
            dispatchEvent(new Event(Event.COMPLETE));
        }

        private function onReadIosDevicesData(ev:ProgressEvent):void {
            const len:int = ev.target.standardOutput.bytesAvailable;
            const data:String = ev.target.standardOutput.readUTFBytes(len);
            iosOutput = String(iosOutput.concat(data));
        }

        private function onUsbDeviceExit(ev:NativeProcessExitEvent):void {
            ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onUsbDeviceExit);
            ev.target.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadIosDevicesData);
            ev.target.closeInput();

            //------------------------------------------------------------------------------------------

            usbDevicesIdList = new <String>[]

            const json:Object = JSON.parse(iosOutput)
            getDevicesIds(json["SPUSBDataType"])

            for each(var iosDev:RunningDevice in collection) {
                if (iosDev is IosDevice && !iosDev.simulator && usbDevicesIdList.indexOf(iosDev.id) == -1) {
                    iosDev.close()
                }
            }

            loadDevicesId();

            System.gc();
        }

        private function realDevicesInfoLoaded(ev:Event):void {

            ev.target.removeEventListener(Event.COMPLETE, realDevicesInfoLoaded);

            var dev:IosDevice = ev.target.device;
            dev.addEventListener(Device.STOPPED_EVENT, deviceStoppedHandler, false, 0, true);

            collection.addItem(dev);
            collection.refresh();

            dev.start();

            loadDevicesId()
        }


		// ----------------------------------- //
		// ----------- INSTALL APP ----------- //
		// ----------------------------------- //

        private var appName:String
        private var deviceIds:ArrayCollection
		public function installApp(url:String, target:String, deviceIds:Array):void {
            if (isInstalling) {
                trace("Install app error: ")
                return
            }

            this.deviceIds = new ArrayCollection(deviceIds)

            if (URLUtil.isHttpsURL(url) || URLUtil.isHttpURL(url)) {
                appName = UIDUtil.createUID()
                if (target == "android") {
                    appName += ".apk"
                } else if (target == "ios") {
                    appName += ".ipa"
                } else if (target == "app") {
                    appName += ".app"
                } else {
                    trace("Install app error: unknow target")
                    return
                }

                isInstalling = true
                downloadAppFile(url)
            } else {
                try {
                    var file:File = new File(url)
                } catch (error:ArgumentError) {
                    trace("Install app error: " + error.message)
                    return
                }

                if (file.exists) {
                    isInstalling = true
                    installAppFile(file)
                } else {
                    trace("Install app error: file doesn't exist")
                }
            }
		}

        private function installAppFile(file:File):void {
            collection.addEventListener(CollectionEvent.COLLECTION_CHANGE, deviceChangeHandler, false, 0, true)

            for each(var device:RunningDevice in collection) {
                if (deviceIds.length == 0 || deviceIds.contains(device.id)) {
                    device.installLocalFile(file)
                }
            }
        }

        private function downloadAppFile(url:String):void {
            var urlRequest:URLRequest = new URLRequest(url)
            urlLoader = new URLLoader();
            urlLoader.dataFormat = URLLoaderDataFormat.BINARY
            urlLoader.addEventListener(Event.COMPLETE, onAppDownloadComplete, false, 0, true);
            urlLoader.load(urlRequest)
        }

        internal var temporaryAppFile:File
        private function onAppDownloadComplete(event:Event):void {
            var urlLoader:URLLoader = event.currentTarget as URLLoader
            urlLoader.removeEventListener(Event.COMPLETE, onAppDownloadComplete)

            var fileStream:FileStream = new FileStream();
            temporaryAppFile = File.cacheDirectory.resolvePath(appName)
            fileStream.addEventListener(Event.CLOSE, writeFileComplete);
            try {
                fileStream.openAsync(temporaryAppFile, FileMode.WRITE);
                fileStream.writeBytes(urlLoader.data, 0, urlLoader.data.length);
            } catch (e:Error) {

            } finally {
                fileStream.close();
            }
        }

        private function writeFileComplete(ev:Event):void {
            var fileStream:FileStream = ev.currentTarget as FileStream;
            fileStream.removeEventListener(Event.CLOSE, writeFileComplete);

            installAppFile(temporaryAppFile)
        }

        private function deviceChangeHandler(event:CollectionEvent):void {
            var count:int = 0
            for each(var device:RunningDevice in collection) {
                if (device.status == Device.INSTALL_APP) {
                    count++
                }
            }

            if (count == 0) {
                trace("end installing")
                isInstalling = false
                collection.removeEventListener(CollectionEvent.COLLECTION_CHANGE, deviceChangeHandler)

                if (temporaryAppFile) {
                    temporaryAppFile.deleteFile()
                    temporaryAppFile = null
                }
            } else {
                trace("installing.....")
                isInstalling = true
            }
        }
    }
}