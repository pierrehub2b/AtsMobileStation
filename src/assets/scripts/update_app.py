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
#----------------------------------------------------------------

def deleteFolder(folder):
	try:
		shutil.rmtree(folder)
		return True
	except OSError:
		return False

#----------------------------------------------------------------
#----------------------------------------------------------------

os.mkdir(tempFolderPath)
with zipfile.ZipFile(sys.argv[1],"r") as zip_ref:zip_ref.extractall(tempFolderPath)

maxTry = 10
while deleteFolder(appFolderPath) is False and maxTry > 0:
	maxTry -= 1
	time.sleep(1)

os.rename(tempFolderPath, appFolderPath)

os.chdir(appFolderPath)
os.system(appExeName)