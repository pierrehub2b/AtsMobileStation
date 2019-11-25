package tools
{
	import flash.events.NetStatusEvent;
	import flash.net.GroupSpecifier;
	import flash.net.NetConnection;
	import flash.net.NetGroup;

	public class PeerGroupConnection
	{
		private var netConnection:NetConnection;
		private var netGroup:NetGroup;
		
		public function PeerGroupConnection()
		{
			netConnection = new NetConnection();
			netConnection.addEventListener(NetStatusEvent.NET_STATUS, onConnectionHandler, false,0,true);
		}
		
		protected function start():void
		{
			netConnection.connect("rtmfp:");
		}
		
		private function onConnectionHandler(ev:NetStatusEvent):void{
			
			trace("connection -> " + ev.info.code);
			switch(ev.info.code)
			{
				// Handle connection success
				case "NetConnection.Connect.Success":
					netConnectionSuccess();
					break;
				
				case "NetGroup.Connect.Success": 
					//netGroup.sendToAllNeighbors("klmkmlklmkm");
					break;
				
			}
		}
		
		private function netConnectionSuccess():void
		{
			var groupSpecifier:GroupSpecifier;
			
			groupSpecifier = new GroupSpecifier("com.ats.mobilestation");
			groupSpecifier.multicastEnabled     = true;
			groupSpecifier.objectReplicationEnabled = true;
			groupSpecifier.postingEnabled       = true;
			groupSpecifier.routingEnabled       = true;
			groupSpecifier.ipMulticastMemberUpdatesEnabled = true; 
			
			groupSpecifier.addIPMulticastAddress("239.252.252.1:20000"); 
			
			netGroup = new NetGroup(netConnection, groupSpecifier.groupspecWithAuthorizations());
			netGroup.addEventListener(NetStatusEvent.NET_STATUS, onNetGroupHandler);
		}
		
		private function onNetGroupHandler(ev:NetStatusEvent):void
		{
			trace("group -> " + ev.info.code);
			switch(ev.info.code)
			{
				case "NetGroup.Connect.Rejected":
				case "NetGroup.Connect.Failed": 
					
					break;
				
				case "NetGroup.SendTo.Notify": 
					break;
				case "NetGroup.Posting.Notify":
					
					break;
				
				case "NetGroup.Neighbor.Connect":
					
					// no break here to continue on the same segment than the disconnect part
				case "NetGroup.Neighbor.Disconnect":
					
					break;
				
				case "NetGroup.LocalCoverage.Notify":
				case "NetGroup.MulticastStream.PublishNotify": 
				case "NetGroup.MulticastStream.UnpublishNotify":
				case "NetGroup.Replication.Fetch.SendNotify":
				case "NetGroup.Replication.Fetch.Failed":
				case "NetGroup.Replication.Fetch.Result":
				case "NetGroup.Replication.Request":
				default:
					break;
			}
		}
	}
}