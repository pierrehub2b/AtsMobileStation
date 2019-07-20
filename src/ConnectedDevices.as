package
{
	import flash.desktop.NativeProcess;
	import flash.desktop.NativeProcessStartupInfo;
	import flash.events.Event;
	import flash.events.NativeProcessExitEvent;
	import flash.events.ProgressEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.system.Capabilities;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.utils.StringUtil;
	
	import spark.collections.Sort;
	import spark.collections.SortField;
	
	public class ConnectedDevices
	{
		protected var procInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		protected var process:NativeProcess = new NativeProcess();
		
		private var adbFile:File;
		private var errorStack:String = "";
		private var output:String = "";
		
		private var timer:Timer = new Timer(3000);
		private var port:String = "8080";
		
		[Bindable]
		public var devices:ArrayCollection = new ArrayCollection();
		
		private var ipSort:Sort = new Sort([new SortField("ip")]);
		
		public function ConnectedDevices(port:String)
		{
			this.port = port;
			this.devices.sort = ipSort;
			
			var adbPath:String = "assets/tools/android/adb";
			if(Capabilities.os.indexOf("Mac") > -1){
				this.adbFile = File.applicationDirectory.resolvePath(adbPath);
				
				var chmod:File = new File("/bin/chmod");
				this.procInfo.executable = chmod;			
				this.procInfo.workingDirectory = adbFile.parent;
				this.procInfo.arguments = new <String>["+x", "adb"];
				
				this.process.addEventListener(NativeProcessExitEvent.EXIT, onChmodExit, false, 0, true);
				this.process.start(this.procInfo);
				
			}else{
				this.adbFile = File.applicationDirectory.resolvePath(adbPath + ".exe");
				startAdbProcess();
			}
		}
		
		protected function onChmodExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(NativeProcessExitEvent.EXIT, onChmodExit);
			process = new NativeProcess();
			
			startAdbProcess();
			startSystemProfilerProcess();
		}
		
		
		//----------------------------------------------------------------------------------------------------------------
		// MacOS specific
		//----------------------------------------------------------------------------------------------------------------
		
		private var sysProcInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		private var sysProc:NativeProcess = new NativeProcess();
		
		private var sysProfiler:String = "";
		
		private function startSystemProfilerProcess():void{
			
			sysProfiler = "";
			
			sysProcInfo.executable = new File("/usr/sbin/system_profiler");			
			sysProcInfo.arguments = new <String>["SPUSBDataType", "-xml"];
			
			//sysProc.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
			sysProc.addEventListener(NativeProcessExitEvent.EXIT, onSysProcInfoExit, false, 0, true);
			sysProc.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onSysProcInfoData, false, 0, true);
			sysProc.start(sysProcInfo);
		}
		
		protected function onSysProcInfoData(event:ProgressEvent):void{
			sysProfiler += StringUtil.trim(sysProc.standardOutput.readUTFBytes(sysProc.standardOutput.bytesAvailable));
		}
		
		protected function onSysProcInfoExit(event:NativeProcessExitEvent):void
		{
			sysProc.removeEventListener(NativeProcessExitEvent.EXIT, onSysProcInfoExit);
			sysProc.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onSysProcInfoData);
			
			var profiler:XML = new XML(sysProfiler);
			trace(profiler);
		}
		
		/*
		<plist version="1.0">
		<array>
		<dict>
		<key>_SPCommandLineArguments</key>
		<array>
		<string>/usr/sbin/system_profiler</string>
		<string>-nospawn</string>
		<string>-xml</string>
		<string>SPUSBDataType</string>
		<string>-detailLevel</string>
		<string>full</string>
		</array>
		<key>_SPCompletionInterval</key>
		<real>0.071593999862670898</real>
		<key>_SPResponseTime</key>
		<real>0.162087082862854</real>
		<key>_dataType</key>
		<string>SPUSBDataType</string>
		<key>_detailLevel</key>
		<integer>-1</integer>
		<key>_items</key>
		<array>
		<dict>
		<key>_items</key>
		<array>
		<dict>
		<key>Built-in_Device</key>
		<string>Yes</string>
		<key>_items</key>
		<array>
		<dict>
		<key>Built-in_Device</key>
		<string>Yes</string>
		<key>_name</key>
		<string>Bluetooth USB Host Controller</string>
		<key>bcd_device</key>
		<string>1.50</string>
		<key>bus_power</key>
		<string>500</string>
		<key>bus_power_used</key>
		<string>0</string>
		<key>device_speed</key>
		<string>full_speed</string>
		<key>extra_current_used</key>
		<string>0</string>
		<key>location_id</key>
		<string>0x14330000 / 7</string>
		<key>manufacturer</key>
		<string>Apple Inc.</string>
		<key>product_id</key>
		<string>0x828f</string>
		<key>vendor_id</key>
		<string>apple_vendor_id</string>
		</dict>
		</array>
		<key>_name</key>
		<string>BRCM20702 Hub</string>
		<key>bcd_device</key>
		<string>1.00</string>
		<key>bus_power</key>
		<string>500</string>
		<key>bus_power_used</key>
		<string>94</string>
		<key>device_speed</key>
		<string>full_speed</string>
		<key>extra_current_used</key>
		<string>0</string>
		<key>location_id</key>
		<string>0x14300000 / 4</string>
		<key>manufacturer</key>
		<string>Apple Inc.</string>
		<key>product_id</key>
		<string>0x4500</string>
		<key>vendor_id</key>
		<string>0x0a5c  (Broadcom Corp.)</string>
		</dict>
		<dict>
		<key>_name</key>
		<string>iPhone</string>
		<key>bcd_device</key>
		<string>10.06</string>
		<key>bus_power</key>
		<string>500</string>
		<key>bus_power_used</key>
		<string>500</string>
		<key>device_speed</key>
		<string>high_speed</string>
		<key>extra_current_used</key>
		<string>1600</string>
		<key>location_id</key>
		<string>0x14200000 / 10</string>
		<key>manufacturer</key>
		<string>Apple Inc.</string>
		<key>product_id</key>
		<string>0x12a8</string>
		<key>serial_num</key>
		<string>667698daf1684c10884e691231272130f5cc5d31</string>
		<key>sleep_current</key>
		<string>2100</string>
		<key>vendor_id</key>
		<string>apple_vendor_id</string>
		</dict>
		</array>
		<key>_name</key>
		<string>USB30Bus</string>
		<key>host_controller</key>
		<string>AppleUSBXHCIWPT</string>
		<key>pci_device</key>
		<string>0x9cb1</string>
		<key>pci_revision</key>
		<string>0x0003</string>
		<key>pci_vendor</key>
		<string>0x8086</string>
		</dict>
		</array>
		<key>_parentDataType</key>
		<string>SPHardwareDataType</string>
		<key>_properties</key>
		<dict>
		<key>1284DeviceID</key>
		<dict>
		<key>_order</key>
		<string>13</string>
		</dict>
		<key>_name</key>
		<dict>
		<key>_isColumn</key>
		<string>YES</string>
		<key>_isOutlineColumn</key>
		<string>YES</string>
		<key>_order</key>
		<string>0</string>
		</dict>
		<key>bcd_device</key>
		<dict>
		<key>_order</key>
		<string>3</string>
		<key>_suppressLocalization</key>
		<string>YES</string>
		</dict>
		<key>bsd_name</key>
		<dict>
		<key>_order</key>
		<string>42</string>
		</dict>
		<key>bus_power</key>
		<dict>
		<key>_order</key>
		<string>8</string>
		</dict>
		<key>bus_power_desired</key>
		<dict>
		<key>_order</key>
		<string>9</string>
		</dict>
		<key>bus_power_used</key>
		<dict>
		<key>_order</key>
		<string>10</string>
		</dict>
		<key>detachable_drive</key>
		<dict>
		<key>_order</key>
		<string>39</string>
		</dict>
		<key>device_manufacturer</key>
		<dict>
		<key>_order</key>
		<string>20</string>
		</dict>
		<key>device_model</key>
		<dict>
		<key>_order</key>
		<string>22</string>
		</dict>
		<key>device_revision</key>
		<dict>
		<key>_order</key>
		<string>24</string>
		</dict>
		<key>device_serial</key>
		<dict>
		<key>_order</key>
		<string>26</string>
		</dict>
		<key>device_speed</key>
		<dict>
		<key>_order</key>
		<string>5</string>
		</dict>
		<key>disc_burning</key>
		<dict>
		<key>_order</key>
		<string>32</string>
		</dict>
		<key>extra_current_used</key>
		<dict>
		<key>_order</key>
		<string>11</string>
		</dict>
		<key>file_system</key>
		<dict>
		<key>_order</key>
		<string>40</string>
		</dict>
		<key>free_space</key>
		<dict>
		<key>_deprecated</key>
		<true/>
		<key>_order</key>
		<string>19</string>
		</dict>
		<key>free_space_in_bytes</key>
		<dict>
		<key>_isByteSize</key>
		<true/>
		<key>_order</key>
		<string>19</string>
		</dict>
		<key>location_id</key>
		<dict>
		<key>_order</key>
		<string>7</string>
		</dict>
		<key>manufacturer</key>
		<dict>
		<key>_order</key>
		<string>6</string>
		</dict>
		<key>mount_point</key>
		<dict>
		<key>_order</key>
		<string>44</string>
		</dict>
		<key>optical_drive_type</key>
		<dict>
		<key>_order</key>
		<string>30</string>
		</dict>
		<key>optical_media_type</key>
		<dict>
		<key>_order</key>
		<string>31</string>
		</dict>
		<key>product_id</key>
		<dict>
		<key>_order</key>
		<string>1</string>
		</dict>
		<key>removable_media</key>
		<dict>
		<key>_order</key>
		<string>34</string>
		</dict>
		<key>serial_num</key>
		<dict>
		<key>_order</key>
		<string>4</string>
		<key>_suppressLocalization</key>
		<string>YES</string>
		</dict>
		<key>size</key>
		<dict>
		<key>_deprecated</key>
		<true/>
		<key>_order</key>
		<string>18</string>
		</dict>
		<key>size_in_bytes</key>
		<dict>
		<key>_isByteSize</key>
		<true/>
		<key>_order</key>
		<string>18</string>
		</dict>
		<key>sleep_current</key>
		<dict>
		<key>_order</key>
		<string>12</string>
		</dict>
		<key>vendor_id</key>
		<dict>
		<key>_order</key>
		<string>2</string>
		</dict>
		<key>volumes</key>
		<dict>
		<key>_detailLevel</key>
		<string>0</string>
		</dict>
		<key>writable</key>
		<dict>
		<key>_order</key>
		<string>36</string>
		</dict>
		</dict>
		<key>_timeStamp</key>
		<date>2019-07-20T15:19:09Z</date>
		<key>_versionInfo</key>
		<dict>
		<key>com.apple.SystemProfiler.SPUSBReporter</key>
		<string>900.4.2</string>
		</dict>
		</dict>
		</array>
		</plist>
		
		*/
		
		//----------------------------------------------------------------------------------------------------------------
		//----------------------------------------------------------------------------------------------------------------
		
		private function startAdbProcess():void{
			procInfo.executable = adbFile;			
			procInfo.workingDirectory = adbFile.parent;
			procInfo.arguments = new <String>["devices"];
			
			timer.addEventListener(TimerEvent.TIMER, devicesTimerComplete, false, 0, true);
			launchProcess();
		}
		
		public function terminate():void{
			var dv:AndroidDevice;
			for each(dv in devices){
				dv.dispose();
			}
			
			process.exit(true);
			
			procInfo.arguments = new <String>["kill-server"];
			process.start(procInfo);
		}
		
		private function launchProcess():void{
			output = "";
			errorStack = "";
			
			try{
				process.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell, false, 0, true);
				process.addEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit, false, 0, true);
				process.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData, false, 0, true);
				process.start(procInfo);
			}catch(err:Error){}
		}
		
		private function devicesTimerComplete(ev:TimerEvent):void{
			launchProcess();
		}
		
		protected function onOutputErrorShell(event:ProgressEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			errorStack += process.standardError.readUTFBytes(process.standardError.bytesAvailable);;
			trace(errorStack);
			
			timer.start();
		}
		
		protected function onReadDevicesData(event:ProgressEvent):void{
			output += StringUtil.trim(process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable));
		}
		
		protected function onReadDevicesExit(event:NativeProcessExitEvent):void
		{
			process.removeEventListener(ProgressEvent.STANDARD_ERROR_DATA, onOutputErrorShell);
			process.removeEventListener(NativeProcessExitEvent.EXIT, onReadDevicesExit);
			process.removeEventListener(ProgressEvent.STANDARD_OUTPUT_DATA, onReadDevicesData);
			
			var dv:AndroidDevice;
			for each(dv in devices){
				dv.connected = false;
			}
			
			var data:Array = output.split("\n");
			if(data.length > 1){
				
				var len:int = data.length;
				var info:Array;
				var device:AndroidDevice;
				
				for(var i:int=1; i<len; i++){
					info = data[i].split(/\s+/g);
					if(info.length == 2){
						device = findDevice(info[0]);
						if(device == null){
							device = new AndroidDevice(adbFile, port, info[0], info[1]);
							device.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
							devices.addItem(device);
							devices.refresh();
						}else{
							device.connected = true;
						}
					}
				}
			}
			
			
			/*for each(var line:String in data){
			var info:Array = line.split(/\s+/g);
			if(info != null && info.length > 6){
			var deviceId:String = info[1];
			var device:AndroidDevice = findDevice(deviceId);
			if(device == null){
			device = new AndroidDevice(port, deviceId, info[2], info[3]);
			device.addEventListener("deviceStopped", deviceStoppedHandler, false, 0, true);
			devices.addItem(device);
			
			devices.refresh();
			}else{
			device.connected = true;
			}
			}
			}*/
			
			for each(dv in devices){
				if(!dv.connected){
					dv.dispose();
					devices.removeItem(dv);
					devices.refresh();
				}
			}
			
			timer.start();
		}
		
		private function findDevice(id:String):AndroidDevice{
			for each(var dv:AndroidDevice in devices){
				if(dv.id == id){
					return dv;
				}
			}
			return null;
		}
		
		private function deviceStoppedHandler(ev:Event):void{
			var dv:AndroidDevice = ev.currentTarget as AndroidDevice;
			dv.removeEventListener("deviceStopped", deviceStoppedHandler);
			dv.dispose();
			devices.removeItem(dv);
		}
	}
}