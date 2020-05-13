package tools
{
	import flash.events.NetStatusEvent;
	import flash.net.GroupSpecifier;
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
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			netConnection.client = this;
			netConnection.connect("rtmfp://192.168.1.57:1935/live", "mobilestation");
		}
		
		private function devicesChangeHandler(ev:CollectionEvent):void{
			if(ev.kind != CollectionEventKind.REFRESH){
				netGroup.post(getDevicesData(ev.items, ev.kind));
			}
		}
		
		private function getDevicesData(value:Array, kind:String, destination:String="all"):Object{
			
			var message:Object = {value:value, kind:kind, destination:destination};
			var now:Date = new Date();
			message.time = now.getHours() + ":" + now.getMinutes() + ":" + now.getSeconds();
			
			return message;
		}
				
		private function onNetStatus(ev:NetStatusEvent):void{
			switch(ev.info.code)
			{
				case "NetConnection.Connect.Success":
					createGroup();
					break;
				case "NetGroup.Connect.Success": 
					devices.addEventListener(CollectionEvent.COLLECTION_CHANGE, devicesChangeHandler);
					break;
				case "NetGroup.Neighbor.Connect":
					netGroup.post(getDevicesData(devices.source, CollectionEventKind.RESET, ev.info.peerID));
					break;
				default:
					break;
			}
		}
		
		private function createGroup():void
		{
			var groupSpecifier:GroupSpecifier = new GroupSpecifier("com.ats.mobilestation/");

			groupSpecifier.postingEnabled       = true;
			groupSpecifier.serverChannelEnabled = true;
			groupSpecifier.objectReplicationEnabled = true;
			
			netGroup = new NetGroup(netConnection, groupSpecifier.groupspecWithAuthorizations());
			netGroup.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
		}
	}
}