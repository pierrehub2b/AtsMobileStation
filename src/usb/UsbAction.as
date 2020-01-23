package usb
{
	public class UsbAction
	{
		private var args:Array = new Array();		
		public function UsbAction(args:Array)
		{
			this.args = args;
		}
		
		public function get getArgs():Array {
			return this.args;
		}
	}
}