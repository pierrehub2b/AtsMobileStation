import psutil

PROC_NAME = "gmadbtunneld.exe"

for proc in psutil.process_iter():
    if proc.name() == PROC_NAME:
        proc.kill()