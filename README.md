# Download More RAM 
## Summary
This attack shows that windows systems with certain DIMMs allow a local attacker with admin privileges to perform arbitrary memory reads and writes into Hyper-V isolation containers, including on protected memory such as no-write code pages. This local privilege escalation could be used in various ways, including bypassing hypervisor-enforced code integrity (HVCI), disabling kernel driver signature enforcement, leaking secrets from Microsoft's credential guard, and breaking third party VBS enclaves. We provide a PoC to show how we can use this attack to patch secure kernel code integrity functions (skci.dll). Currently we are extending this capability to patch ci.dll in tandem and fully bypass windows flagship security. 

## Technical Preamble
The Download More RAM attack leverages a technique called memory aliasing. In this attack we re-write the EEPROM of an installed DIMM, called the SPD chip, to misreport it's addressing capacity to the BIOS. This causses the memory controller to believe there is twice as mutch memory installed as is physically present. Access into the misreported half of memory results in a behaviour called aliasing, whereby the "not real" addressing bit is disregarded, meaning data from the real half of memory is returned. We find that this allows an attacker to bypass all MMU and OS memory protections. By accessing the aliased half of memory, we are able to read/write to protected processes, patching them to disable key OS security measures.  

## Affected Systems
We verified this vulnerability on Windows 11 Enterprise 26H1 canary build with all security mitigations in place (secure boot enabled, HVCI enabled, credential guard enabled, test mode off). We ran our specific tesiting on a ROG Strix B450F motherboard, with a Ryzen 7 2700 CPU, and a single 8GB stick of [Corsair Vengence, ADATA XPG, G.Skill Aegis] DDR4 memory.

The specific Windows 11 build is - 28000.1

Use of any other build of Windows 11 will require the colleciton of new fingerprints for the functions patched in the attack. This can be done with a tool such as IDA pro, the hex values of the target funcitons listed in `patcher.c` must be replaced with fresh ones from the disassembley of `skci.dll` on the target system, which may be found in the System32 directory.  

## Build Instructions 
Note - we provide pre-compiled tools for ease of replicaiton. To build tools from source follow these steps. 

For `DMR_SPD_Tool`, `DMR_SPD_Tool_Headless`, `RTCore-write`, `RTCore_dump`, `RTCore_read`, `TrueSightKiller`, `TrueSigntKiller_NoDriverLoad`, and `WinPmem-custom`. These tools are provided as visual studio projects. These can be built using Visual Studio Community Edition. For each project, open the corresponding `.sln` file, navigate to the build menu and build as release.

For `helper_optimised.c`, `patcher.c`, and `sig_finder.c`. These tools can be compiled using gcc with no additional options with Mingw-w64.  

In the cases of `TrueSightKiller`, `TrueSigntKiller_NoDriverLoad`, and `WinPmem-custom`, all credit goes towards the original autheors as we make only light-medium edits. 

## Quickstart steps for reproducing the proof of concept 

1. Navigate into the `Precompiled_Tools` directory. Set the path values in `runme.bat` to the directory of the file. All the folowing steps should be run from an elevated command prompt.
2. Install primo ramdisk utility trial version and add the path to `rxprd.exe` to the PATH enviromental variable
3. Run `DMR_SPD_TOOL.exe`, you should also have `MsIo64.sys` in the same directory as the tool. Select the appropriate DIMM slot then select `alias DIMM', you can also check the write protection first with option 2.
4. Run `bcdedit /set removememory 8192`, then restart the PC. Verify you are running with aliased memory in task maanger or msinfo. 16GB should be installed with 8GB avaliable.
5. Run `runme.bat`

## Steps for reproducing the proof of concept in detail 

1. Prepare target system with SPD-writeable DIMM. In our experiments, we could verify the SPD-writeability on Corsair Vengeance DIMMs (DDR4). In the following, we assume a system with a single 8GB corsair vengeance DIMM installed
2. Rewriting the DIMM’s memory size stored in the SPD memory. Increasing the stored memory size can be achieved by increasing the DIMM’s row size stored in the SPD by one as well as the reported DIMM density, effectively “doubling” the perceived available memory. This can be achieved in multiple ways. We use a custom tool "DMR_SPD_Tool" which we have written leveraging the MsIo driver, also used by thaiphoon burner. We have only verified this tool on our own test system at time of writing. On some systems the DIMMs serial number must also be changed ot force the BIOS to re-read the SPD info on next boot, elsewise it will rely on old cached data. 
3. Reserve aliased memory to be not used by Windows. To be able to effectively use the aliased memory for the PoC, windows must be configured to only use the lower half of “available” memory. We used the (previously) secure boot compliant “removememory” parameter for this (e.g., `bcdedit /set removememory 8192`). MSFT have now made this non-secure boot compliant since Apr 14 ion response to this work. 
4. Reboot and verify modifications. After reboot, the task manager should now report that 16GB of memory are installed, but only 8GB are available.
5. Dump aliased memory region. This step requires use of a (signed & allowlisted) kernel driver for memory acquisition. For our experiment, we used the driver shipped with the WinPMem utility (v. 4.0.rc1) [2], exposing the `MmMapIoSpace` function to map physical memory. However, other acquisition drivers (or drivers with vulnerabilities) would work equally. For WinPMem, the verification of memory boundaries is performed by the userspace utility, and we customized WinPMem’s userspace utility to ignore these checks (our altered version is included in the submission). To dump the aliased memory region, run `winpmem_custom.exe -a -0 <outputfile>`.
6. Decode/decrypt dump. The aliased memory region will be encrypted with a static XOR key, due to micro architectural read/write behaviour. To decrypt the dump, we wrote a utility   `helper.exe <input> <output>`, included in the submission. This will xor all dumped memory contents with the static key of 0xE39F243C (may differ per machine as per the chipset DDR scrambler, see torubleshooting). After this step, we have successfully obtained a decrypted physical memory dump of the victim.
7. Scan for known values in memory. In our PoC, we target code in the secure kernel, and found that both the securekernel.exe and skci.dll images are easily found in memory. Additionally, their location in physical memory is consistent across reboots. Our memory scanner script is included in the submission. 
8. Preparing the write primitive. Similar to the read/dump primitive of step 5, this can be carried out with different tools. For our PoC, we leverage primo ramdisk [3], which allows us to create ramdisks in memory, including in the aliased regions. On our system allocating a 3mb FAT ramdisk 28mb from the start of the aliased region will encompass the scki.dll code pages without corrupting anything. 
9. Writing aliased memory. With the system memory aliased and primo ramdisk ready to use, the following encompasses the main body of the attack.
    - On our system skci.dll was always in the same location
    - Open ramdisk over target location
    - Take a snapshot of the ramdisk
    - Decode it
    - Patch relevant functions in the decoded copy
    - Re-encode it
    - Reupload it to the same region of memory
This delivers the chosen patches to the target. We automate these steps with the script “runme.bat”. 
10. Verifying the success of the PoC. Try and load a blocked vulnerable drive on the target system.. From there all BYOVD drivers are now unlocked again opening many avenues for attack. The script runme.bat will try and run the truesight driver attack and disbale Windows defender by default. 



## Troubleshooting
- The system does not reboot after step 3. In this case, Windows likely uses the aliased memory region (i.e., reserving aliased memory was not successful). To fix, it’s best to rewrite the DIMM’s SPD from another machine to its original size, and restart from Step 1.

- XOR key for region decoding is not 0xE39F243C: Different systems may use different keys, search `ddr data scrambler' for more. To find the right XOR key, inspect the encrypted aliased memory dump and check for large parts of repeating 4-bytes pattern; This will likely be pages which are all zero, and, thus, give away the key. The key then needs to be adjusted in helper.c, and it needs to be recompiled.

- Step 8 bluescreens the system. As primo ramdisk creates a ramdisk, a different memory layout can lead to primo ramdisk overwriting other memory/services with disk meta data, crashing the system. To identify a good starting point for overwriting, we include “recon.bat” to find candidate region starting points. 

## Attached files
Screenshots

Tools
- DMR_SPD_TOOL - custom tool to read/write DDR4 SPD data 

- DMR_SPD_TOOL_headless - custom tool to read/write DDR4 SPD data, used in one-click version of attack with no menu 

- RTCore_dump - vulnerable driver tool for dumping large memory to a file

- Primo RAMDSIK (not attached) https://www.romexsoftware.com/en-us/primo-ramdisk/

- RTCore_read - vulnerable driver tool for reading snippet of memory

- RTCore_write - vulnerable driver tool for clean patches

- Spd_check_v02_test2 - contains DDR4 SPD read/write utilities 

- thphn174 - thaiphoon burner SPD utility

- TrueSight_Polymorphs - polymorphic variants of the TrueSight driver 

- TrueSightKiller - used for disbaling AV/EDR

- TrueSightKiller_NoDriverLoad - used for disbaling AV/EDR, we decouple the driver load from the IOCTLS

- Winpmem-custom - I’ve made various changes, if you want to change the read size for different dimm sizes change code on line 441 of WinPmem-custom\src\executable\winpmem.cpp

- helper_optimised.c - to unxor memory dump, change xor_value on line 71 if the mask is different on your machine 

- OSRLOADER.exe - GUI tool for driver loading, must still disable security before bad drivers can be loaded

- patcher_index.txt

- patcher.c - patches functions found in input file and writes to output file, which functions it patches are based off its input (see how its called in .bat file). Loaded signitures are for the Dec 9th caranry build of Windows 11. 

- sig_finder.c: this will find instances of a given signature and suggest memory regions before the fingerprint where a ramdisk could be safely loaded. Loaded signiture is for the regular kernel ci.dll module. 

- winpmem_custom.exe - pre-compiled 

- CreateAndAutoLogon.ps1 - runs one-click variant of attack 

- CleanUpAutoLogOnUser.ps1 - cleans up system after one click variant of attack 

DemoVideo
