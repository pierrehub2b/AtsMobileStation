package tools
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.SharedObject;
	
	import mx.core.FlexGlobals;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	
	import device.RunningDevice;
	
	public class PeerGroupConnection
	{
		public static const monServerFolder:String = "assets/tools/monaserver";
		
		private static const rtmpProtocol:String = "RTMP";
		private static const rtmpPort:int = 1935;
		private var httpPort:int = 8989;
		
		private var netConnection:NetConnection;
		private var netGroup:NetGroup;
		
		private var devicesManager:RunningDevicesManager;
		
		private var monaServerBinary:File;
		private var monaServerProc:NativeProcess;
		
		public var so:SharedObject = SharedObject.getLocal("MobileStationSettings");
		
		public var description:String = "";
		public var name:String = "";
		
		public function PeerGroupConnection(devManager:RunningDevicesManager, simManager:AvailableSimulatorsManager, port:int)
		{
			devicesManager = devManager;
			httpPort = port;
			
			if(so.data["MSInfo"] != null){
				description = so.data["MSInfo"].description;
				name = so.data["MSInfo"].name;
			}else{
				saveValues("Description of this station", "Mobile Station");
			}
			
			var mona:File = File.applicationDirectory.resolvePath(monServerFolder);
			if(mona.exists){
				var monaTempFolder:File = File.userDirectory.resolvePath(".atsmobilestation").resolvePath("monaserver");
				if(monaTempFolder.exists){
					monaTempFolder.deleteDirectory(true);
				}
				monaTempFolder.createDirectory();
				mona.copyTo(monaTempFolder, true);
				
				if (AtsMobileStation.isMacOs) {
					monaServerBinary = monaTempFolder.resolvePath("server").resolvePath("MonaServer");
					if(monaServerBinary.exists){
						var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
						procInfo.executable = new File("/bin/chmod");			
						procInfo.workingDirectory = monaTempFolder;
						procInfo.arguments = new <String>["+x", "server/MonaServer"];
						
						var proc:NativeProcess = new NativeProcess();
						proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
						proc.start(procInfo);
					}
				} else {
					monaServerBinary = monaTempFolder.resolvePath("server").resolvePath("MonaServer.exe");
					if(monaServerBinary.exists){
						startMonaServer();
					}
				}
			}
		}
		
		private function get info():Object{
			var o:Object = {description:description, name:name, httpPort:httpPort}
			if(AtsMobileStation.isMacOs){
				o.os = "mac"
			}else{
				o.os = "win"
			}
			return o;
		}
		
		public function saveValues(d:String, n:String):void{
			description = d;
			name = n;
			so.setProperty("MSInfo", info);
			so.flush();
		}
		
		public function close():void{
			if(monaServerProc != null && monaServerProc.running){
				monaServerProc.exit(true);
			}
		}
		
		protected function onChmodExit(ev:NativeProcessExitEvent):void
		{
			ev.target.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			ev.target.closeInput();
			startMonaServer();
		}
		
		private function startMonaServer():void{

			saveIniFile(monaServerBinary.parent.resolvePath("MonaServer.ini"));
			
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = monaServerBinary;			
			procInfo.workingDirectory = monaServerBinary.parent;
			
			monaServerProc = new NativeProcess();
			monaServerProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onMonaServerRun, false, 0, true);
			monaServerProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onMonaServerError, false, 0, true);
			monaServerProc.start(procInfo);
		}
		
		protected function onMonaServerError(ev:ProgressEvent):void{
			const len:int = monaServerProc.standardError.bytesAvailable;
			FlexGlobals.topLevelApplication.log = monaServerProc.standardError.readUTFBytes(len);
		}
		
		protected function onMonaServerRun(ev:ProgressEvent):void{
			const len:int = ev.target.standardOutput.bytesAvailable;
			const data:String = ev.target.standardOutput.readUTFBytes(len);
			trace(data)
			if(data.indexOf(rtmpProtocol + " server started") > -1){
				monaServerProc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onMonaServerRun);
				connectToPeerGroup();
			}
		}
		
		private function connectToPeerGroup():void{
			netConnection = new NetConnection();
			netConnection.objectEncoding = 3;
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			netConnection.client = this;
			netConnection.connect(rtmpProtocol.toLowerCase() + "://localhost:" + rtmpPort + "/mobilestation", "mobilestation", info);
		}
		
		private function onNetStatus(ev:NetStatusEvent):void{
			switch(ev.info.code)
			{
				case "NetConnection.Connect.Success":
					trace("connected to MonaServer!");
					for each(var dev:RunningDevice in devicesManager.collection){
					if(dev.status == "ready"){
						pushDevice(dev);
					}
				}
					devicesManager.collection.addEventListener(CollectionEvent.COLLECTION_CHANGE, devicesChangeHandler);
					
					break;
				default:
					break;
			}
		}
		
		private function pushDevice(dev:RunningDevice):void{
			netConnection.call("pushDevice", null, {modelName:dev.modelName, modelId:dev.modelId, manufacturer:dev.manufacturer, ip:dev.ip, port:dev.port, locked:dev.lockedBy});
		}
		
		private function devicesChangeHandler(ev:CollectionEvent):void{
			var dev:RunningDevice
			if(ev.kind == CollectionEventKind.REMOVE){
				dev = ev.items[0] as RunningDevice
				netConnection.call("deviceRemoved", null, dev.id, dev.modelName, dev.modelId, dev.manufacturer, dev.ip, dev.port);
			}else if(ev.kind == CollectionEventKind.UPDATE){
				dev = ev.items[0].source as RunningDevice
				if(ev.items[0].property == "status" && ev.items[0].newValue == "ready"){
					pushDevice(dev);
				}else if (ev.items[0].property == "lockedBy"){
					netConnection.call("deviceLocked", null, ev.items[0].newValue, dev.id, dev.modelName, dev.modelId, dev.manufacturer, dev.ip, dev.port);
				}
			}
		}
		
		private function saveIniFile(monServerIni:File):void{
			var stream:FileStream = new FileStream();
			stream.open(monServerIni, FileMode.WRITE);
			stream.writeUTFBytes("[RTMFP]\nport = " + rtmpPort + "\n[RTMP]\nport = " + rtmpPort + "\n[HTTP]\nport = " + httpPort + "\nindex = index.html\n[RTSP]\nport = 0");
			stream.close();
		}
	}
}