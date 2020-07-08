import zipfile
import os
import shutil
import sys
import uuid
import time

zipFilePath = sys.argv[1]
appParentFolderPath = sys.argv[2]
appFolderName = sys.argv[3]
appExeName = sys.argv[4]

#----------------------------------------------------------------
#----------------------------------------------------------------

tempFolderPath = appParentFolderPath + "/" + str(uuid.uuid4())
appFolderPath = appParentFolderPath + "/" + appFolderName

#----------------------------------------------------------------
# Functions
#----------------------------------------------------------------

def deleteFolder(folder):
	try:
		shutil.rmtree(folder)
		return True
	except OSError:
		return False

#----------------------------------------------------------------
# Unzip
#----------------------------------------------------------------

os.mkdir(tempFolderPath)
with zipfile.ZipFile(zipFilePath,"r") as zip_ref:zip_ref.extractall(tempFolderPath)
os.remove(zipFilePath)

#----------------------------------------------------------------
# Replace folder
#----------------------------------------------------------------

maxTry = 20
while deleteFolder(appFolderPath) is False and maxTry > 0:
	maxTry -= 1
	time.sleep(0.5)

os.rename(tempFolderPath, appFolderPath)

#----------------------------------------------------------------
# Restart app
#----------------------------------------------------------------

os.chdir(appFolderPath)
os.system(appExeName)