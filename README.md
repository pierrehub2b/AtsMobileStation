# AtsMobileStation
PC and Mac OS application to start and install mobile drivers used by ATS test framework

## iOS Devices
**This procedure is useless if you're using iOS Simulators**
### Apple Developer settings
To execute automated tests on physical iPhone devices, you need to create an Apple developer account and suscribe to a developer licence

### Prerequisites 
- Have an Xcode downloaded and **installed**
- the device **must be in WIFI and don't have a pin code**

### 1/ Setup provisionning profile into Xcode
- Open Xcode and go to 'Preferences' (Click on Xcode code in the left top corner)
- In 'Accounts', add a new account using '+' button in the bottom left corner
- Select 'Apple ID' in the dropdown list and enter your Apple Developer credentials in the next window
- When you're logged, click on "Manage Certificates". If there is no certificate associated with your post (no one is enlightened), click on "+" button -> "Apple Development" and "Done"
- Save and quit xCode

### 2/ Set the Development team ID and retrieve the devices list
- Open AtsMobileStation and plug an iPhone device
- In the 'Connected devices' section, click on Apple logo
- In the textbox, put your Development team ID
- Click on 'Export device list' and save the output file to your computer

### 3/ Push informations to Apple Developer Website
- Go and login to your apple dev account (https://developer.apple.com)
- Go to 'Certificates, ID's and profiles' -> 'Devices' and add new devices by pushing '+' button
- In 'Register Multiple Devices', upload the file generated previously and save

### 4/ Test if driver working effectively
- Go to AtsMobileStation
- unplug and plug your iPhone device
- your driver should start (by seeing the green check image, and show you an Ip adress and port)

### 5/ Error handling
- If the Apple key vault ask credential recurrently: 
  - unplug the device
  - open the key vault application
  - right click on "session"
  - "**lock** the vault 'session'"
  - right click on "session"
  - "**unlock** the vault 'session'"
  - enter your Mac credentials
  - plug your device again

## Android devices
### Prerequisites
- the device **must be in WIFI and don't have a pin code** 
- Enable the **developer mode** and autorize the connexion to the linked computer

**You can now go the ATS Framework and begenning use it with your physical device.**