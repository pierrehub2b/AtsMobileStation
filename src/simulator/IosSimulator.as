package simulator
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.net.InterfaceAddress;
	import flash.net.NetworkInfo;
	import flash.net.NetworkInterface;
	
	import mx.utils.StringUtil;
	
	import device.IosDevice;
	
	public class IosSimulator extends Simulator
	{
		public var error:String = null;
		private var output:String = "";
		
		private var process:NativeProcess = new NativeProcess();
		private var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		
		private static const xcrunExec:File = new File("/usr/bin/xcrun");
		private static const openExec:File = new File("/usr/bin/open");
		
		public function IosSimulator(id:String, name:String, version:String, isBooted: Boolean)
		{
			this.id = id;
			this.name = StringUtil.trim(name);
			this.version = version;
			this.phase = isBooted ? RUN : OFF;
			if(isBooted) {
				tooltip = "Shutdown simulator";
			}
		}
		
		public function get device():IosDevice{
			var ipAddress:String = "---";
			var netInterfaces:Vector.<NetworkInterface> = NetworkInfo.networkInfo.findInterfaces();
			if(netInterfaces.length > 1){
			var addresses:Vector.<InterfaceAddress> = netInterfaces[1].addresses;
			for each(var intAddress:InterfaceAddress in addresses){
				ipAddress = intAddress.address;
				if(intAddress.ipVersion == "IPv4"){
					break;
				}
			}
			}
			return new IosDevice(id, name + " (" + version +")", true, ipAddress);
		}
		
		override public function startStop():void{
			
			if(phase == OFF){
				phase = WAIT;
				tooltip = "Simulator is starting ...";
				
				procInfo.executable = xcrunExec;
				procInfo.workingDirectory = File.userDirectory;
				
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onBootExit, false, 0, true);

				procInfo.arguments = new <String>["simctl", "bootstatus", id, "-b"];
				process.start(procInfo);
			} else{
				phase = WAIT;
				tooltip = "Simulator is terminating ...";
				dispatchEvent(new Event(STATUS_CHANGED));
				
				procInfo.executable = xcrunExec;
				process.addEventListener(NativeProcessExitEvent.EXIT, onShutdownExit, false, 0, true);
				
				procInfo.arguments = new <String>["simctl", "shutdown", id];
				process.start(procInfo);
			}
		}
		
		protected function onShutdownExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onShutdownExit);
			phase = OFF;
			tooltip = "Start simulator";
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			trace(process.standardError.readUTFBytes(process.standardError.bytesAvailable));
		}
		
		protected function onBootExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onBootExit);
			process.addEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit, false, 0, true);
			
			trace("Simulator started, open simulator app ...")
			
			procInfo.executable = openExec;
			procInfo.arguments = new <String>["-a", "simulator"];
			process.start(procInfo);
		}
		
		protected function onSimulatorStartedExit(event:NativeProcessExitEvent):void{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onSimulatorStartedExit);
			
			phase = RUN;
			tooltip = "Shutdown simulator";
			dispatchEvent(new Event(STATUS_CHANGED));
		}
	}
}