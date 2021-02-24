import os
import sys

zipFilePath = sys.argv[1]
appFolderPath = sys.argv[2]
appName = sys.argv[3]

#----------------------------------------------------------------
#----------------------------------------------------------------

os.system("killall AtsMobileStation")

os.system("xattr -r -d com.apple.quarantine " + zipFilePath)

#----------------------------------------------------------------
# Unzip
#----------------------------------------------------------------

os.system("unzip -o " + zipFilePath + " -d " + appFolderPath)

#----------------------------------------------------------------
# Restart app
#----------------------------------------------------------------

os.system("open " + appFolderPath + "/" + appName)