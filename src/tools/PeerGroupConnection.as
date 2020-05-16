package tools
{
	import device.RunningDevice;
	
	import flash.events.NetStatusEvent;
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	
	import mx.collections.ArrayCollection;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	
	public class PeerGroupConnection
	{
		private var netConnection:NetConnection;
		private var netGroup:NetGroup;
		
		private var devices:ArrayCollection;
		
		public function PeerGroupConnection(devicesManager:RunningDevicesManager, sims:AvailableSimulatorsManager)
		{
			devices = devicesManager.collection;
			//Start MonaServer process here
			connectToPeerGroup();
		}
		
		private function connectToPeerGroup():void{
			netConnection = new NetConnection();
			netConnection.objectEncoding = 3;
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			netConnection.client = this;
			netConnection.connect("rtmp://localhost/mobilestation", "mobilestation");
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