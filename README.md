# AtsMobileStation
PC and Mac OS application to start and install mobile drivers used by ATS test framework

## Process to install and configure a physical device on AtsMobileStation
### prerequisites 
- Have an Xcode downloaded and **installed**
- the device **must be in WIFI and don't have a pin code**

### 1/ Set the Development team ID and retrieve the devices list
- Open AtsMobileStation and plug a physical device
- In the "Connected devices" section, click on Apple logo
- In the textbox, put your Development team ID
- Click on "Export device list" and save the output file to your computer

### Push informations to Apple Developer Website
- Go and login to your apple dev account (https://developper.apple.com)
- Go to "Certificates, ID's and profiles" -> "Devices" and add new devices by pushing "+" button
- In "Register Multiple Devices", upload the file generated previously and save

### Setup provisionning profile into Xcode
- Open Xcode and go to "Preferences" (Click on Xcode code in the left top corner)
- In "Accounts", add a new account using "+" button in the bottom left corner
- Select "Apple ID" in the dropdown list and enter your Apple Developer credentials in the next window
- Save and quit xCode

### Test if driver working effectively
- Go to AtsMobileStation
- unplug and plug your device
- your driver should start (by seeing the green check image, and show you an Ip adress and port)

**You can now go to your editeur and begenning use your pysical device into it.**
