package tools
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.NativeProcessExitEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.SharedObject;
	
	import mx.collections.ArrayCollection;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	
	import device.RunningDevice;
	
	public class PeerGroupConnection
	{
		public static const monServerPath:String = "assets/tools/monaserver/work/MonaServer";
		
		private static const rtmpProtocol:String = "RTMFP";
		
		private var netConnection:NetConnection;
		private var netGroup:NetGroup;
		
		private var devices:ArrayCollection;
		
		private var monaServerFile:File;
		private var monaServerProc:NativeProcess;
		
		public var so:SharedObject = SharedObject.getLocal("MobileStationSettings");
		
		public var description:String = "";
		
		public function PeerGroupConnection(devicesManager:RunningDevicesManager, sims:AvailableSimulatorsManager)
		{
			if(so.data["MSInfo"] != null){
				description = so.data["MSInfo"].description;
			}else{
				saveDescription("");
			}
			
			if (AtsMobileStation.isMacOs) {
				monaServerFile = File.applicationDirectory.resolvePath(monServerPath);
				
				if(monaServerFile.exists){
					devices = devicesManager.collection;
					
					var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					procInfo.executable = new File("/bin/chmod");			
					procInfo.workingDirectory = File.applicationDirectory.resolvePath("assets/tools");
					procInfo.arguments = new <String>["+x", "monaserver/work/MonaServer"];
					
					var proc:NativeProcess = new NativeProcess();
					proc.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
					proc.start(procInfo);
				}

			} else {
				monaServerFile = File.applicationDirectory.resolvePath(monServerPath + ".exe");
				if(monaServerFile.exists){
					devices = devicesManager.collection;
					startMonaServer();
				}
			}
		}
		
		private function get info():Object{
			var o:Object = {description:description}
			if(AtsMobileStation.isMacOs){
				o.os = "mac"
			}else{
				o.os = "win"
			}
			return o;
		}
				
		public function saveDescription(desc:String):void{
			
			description = desc;
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
			var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
			procInfo.executable = monaServerFile;			
			procInfo.workingDirectory = monaServerFile.parent;
			
			monaServerProc = new NativeProcess();
			monaServerProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onMonaServerRun, false, 0, true);
			monaServerProc.start(procInfo);
		}
		
		protected function onMonaServerRun(ev:ProgressEvent):void{
			const len:int = ev.target.standardOutput.bytesAvailable;
			const data:String = ev.target.standardOutput.readUTFBytes(len);
			
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
			netConnection.connect(rtmpProtocol.toLowerCase() + "://localhost/mobilestation", "mobilestation");
		}
		
		private function getDevicesData(value:Array, kind:String, destination:String="all"):Object{
			
			var now:Date = new Date();
			
			var message:Object = {value:value, kind:kind, destination:destination};
			message.time = now.getHours() + ":" + now.getMinutes() + ":" + now.getSeconds();
			
			return message;
		}
		
		private function onNetStatus(ev:NetStatusEvent):void{
			switch(ev.info.code)
			{
				case "NetConnection.Connect.Success":
					trace("connected to MonaServer!")
					for each(var dev:RunningDevice in devices){
						if(dev.status == "ready"){
							pushDevice(dev);
						}
					}
					devices.addEventListener(CollectionEvent.COLLECTION_CHANGE, devicesChangeHandler);

					break;
				default:
					break;
			}
		}
		
		private function pushDevice(dev:RunningDevice):void{
			netConnection.call("pushDevice", null, {modelName:dev.modelName, modelId:dev.modelId, manufacturer:dev.manufacturer, ip:dev.ip, port:dev.port});
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
	}
}