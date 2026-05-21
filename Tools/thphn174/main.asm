// Enigma Protector 4.xx and 5.XX unpacker by GIV (some parts are from LCF-AT Alternativ 1.1 script and the API fix is from SHADOW_UA script)
// January 22 2016
// giv@reversing.ro
// PRIVATE
// 3D00F000007E13B800000100 - API COMPARE AND JUMP
// 3B????????0075??B2018BC2C3 - IAT EMULATION ROUTINE 
// 8B08C601FF - OEP MARKER
// 85C00F95C08B??????????8B??8? - HWID
// 6A4068001010006800093D006A00E8??????FF - High memory allocation marker
//
// Script-Editing by LCF-AT
// ---------------------------------
// Enter ARImpRec.dll path below
// Added Screw Prevent patch
// Added Dumper
// Added Section Adder
// Added IAT Fixer (using SearchAndRebuildImports@28 of ARImpRec.dll) enter IATSTART & SIZE (last API-Entry+04 bytes / see counter) 
 
 
var intermediar
var dumpvm
var disablehighvmalloc
var counter
var sectiuneenigma
var patchedvm
var SIZE
var SIZE2
var primacautarevariabile
var bazacod
var rulat_r
 
call VARS
 
//lc
log "Enigma 4.XX and 5.XX simple HWID bypass, IAT scrambling repair, OEP find by GIV - 0.2a - private"
log "Emulated API'S fixer by PC-RET"
bc
bphwc
bpmc
 
mov rulat_r, 0
var IS_DLL
mov IS_DLL, 0
 
//Change the Arimprec.dll path below or put in unpackme directory
 
gpi CURRENTDIR
mov dir_curent, $RESULT
 
/////////////////////////////////////////////////////
//Declare options
// In case of Demo protected files you can set disablehighvmalloc to 0
//mov arimprecpath, "G:\Windows_POC\Tools\thphn174\Thaiphoon.exe"
 
// LCF-AT
mov ARIMPREC_PATH, "G:\Windows_POC\Tools\thphn174\Thaiphoon.exe"
 
mov primacautarevariabile, 0
mov patchedvm, 1 //0=Not patch the high alloc 1=patch the high alloc of the VM
mov dumpvm, 1 //Change to 0 if the OEP is not virtualized
mov disablehighvmalloc, 1 //Change to 0 if the OEP is not virtualized or in case of files protected with DEMO version
mov counter, 0 //Do not change
mov TYPE,  00101000 //  MEM_COMMIT|MEM_TOP_DOWN
mov SIZE1, 00100000 //Do not cahnge
//HWID data
mov changeid, 1 //change to 0 if you do not want a HWID change
mov old, "FCD92259AB2EBE7BCB7D46C4AACACD626752" //Your HWID
mov new, "72662259EEF6548F4C6172CDD50B2BB8AED9" //The HWID that need to be
len old
mov marime, $RESULT
 
// If you want to change the HWID use changeid=1 and patchedvm=1
/////////////////////////////////////////////////////
 
alloc 01000000
mov MYSEC,  $RESULT
mov MYSEC2, MYSEC
 
gmi eip, PATH
mov exepath, $RESULT
len exepath         // length of path+name+".exe" (full path)
sub $RESULT, 4      // length of path+name
mov basepath, exepath, $RESULT
 
gmi eip, MODULEBASE
MOV IMAGEBASE, $RESULT
 
GPA "VirtualAlloc", "kernel32.dll"
mov VirtualAlloc, $RESULT
 
GPA "GetProcAddress", "kernel32.dll"
mov GetProcAddress, $RESULT
 
cmp changeid, 1
ifeq
mov schimbarehwid, 1
else
mov schimbarehwid, 0
endif
//jmp Continuare_VALLOC
 
////////////////////////////////////////////////////////////
GPA_AGAIN:
bp GetProcAddress
run
bc eip
rtr
bc
bphwc
cmp [esi], #4D5A# ,02
ifeq
cmp esi, 70000000
ja GPA_AGAIN
mov sectiuneenigma, esi
endif
cmp [edi], #4D5A# ,02
ifeq
cmp edi, 70000000
ja GPA_AGAIN
mov sectiuneenigma, edi
endif
 
// LCF-AT Patch
///////////////////////
find sectiuneenigma, #F646038075??#
cmp $RESULT, 00
je IMPORTS_SCREW_NOT_FOUND
mov IMPORTS_SCREW, $RESULT
mov [IMPORTS_SCREW+04], 0EB, 01
eval "Prevent IMPORTS SCREW at: {IMPORTS_SCREW}"
log $RESULT, ""
///////////////////////
IMPORTS_SCREW_NOT_FOUND:
log "No IMPORTS SCREW found!"
log "Fixing of IAT could get wrong later!"
///////////////////////
 
 
NO_INT_VERSION:
findmem #85C00F95C08B??????????8B??8?#, IMAGEBASE                              
cmp $RESULT, 00
je NP_HWID_BASIC_FOUND
mov REG1, $RESULT+02
find REG1, #85C00F95C08B??????????8B??8?#
mov REG2, $RESULT+02
gci REG1, COMMAND
mov REG1_COM, $RESULT
gci REG2, COMMAND
mov REG2_COM, $RESULT
log ""
log "Possible used RegSheme found!"
log ""
eval "Address: {REG1} - {REG1_COM}"
log $RESULT, ""
eval "Address: {REG2} - {REG2_COM}"
log $RESULT, ""
log ""
///////////////////////
NP_HWID_BASIC_FOUND:
findmem #89431?83C31C4E75??5F5E5BC3#, IMAGEBASE                              
cmp $RESULT, 00
jne FOUND_API_TABLE
je NO_MJ_FOUND
pause
pause
ret
///////////////////////
FOUND_API_TABLE:
mov IAT_TABLE_1, $RESULT
mov [IAT_TABLE_1+02], 14, 01
findmem #33D2????????????74??????????????74??????????????74#, IMAGEBASE
cmp $RESULT, 00
je NO_MJ_FOUND
mov MJ, $RESULT
mov [MJ], #33D2B801000000C3#
log ""
eval "MJ found and patched at: {MJ}"
log $RESULT, ""
///////////////////////
NO_MJ_FOUND:
findmem #8D047F8B55FC8B4DF0894C820447FF4DD0#, IMAGEBASE
cmp $RESULT, 00
je NO_QUCIK_RD_FOUND
mov QUICK, $RESULT
///////////////////////
NO_QUCIK_RD_FOUND:
mov [REG1-02], FE, 01
mov [REG2-02], FE, 01
log "HWID EASY BYPASS was patched!"
/////////////////////////////////////////////////////////////
Continuare_VALLOC:
 
bphws VirtualAlloc
//bp VirtualAlloc
 
cmp disablehighvmalloc, 0
ifeq
jmp continuarefaradezactivaremv
endif
 
alloc 01000000
mov zonaalocata, $RESULT
 
bpgoto VirtualAlloc, Verificare
Urmatorul:
inc counter 
cmp counter, 500
ifeq
jmp continuarefaradezactivaremv
endif
RUN:
erun
pause
 
////////////////////////////
Verificare:
 
findmem #5356575583C4F4890C248BF885FF0F95C085D20F95C132C1740A#, bazacod 
mov integritate, $RESULT
cmp integritate, 0
ifa
log "Integrity check patched"
log integritate, ""
asm integritate, "xor eax,eax"
asm integritate+2, "ret"
endif
 
findmem #68584D56#, bazacod
var vm_gasit
cmp $RESULT, 0
ifa
mov vm_gasit, $RESULT
log "VMWare run restriction patched"
log $RESULT, ""
//fill vm_gasit, 4, 90
repl vm_gasit, #68584D56#, #5F564947#, 4
endif
findmem #68584D56#, vm_gasit+5
cmp $RESULT, 0
ifa
mov vm_gasit, $RESULT
log $RESULT, ""
//fill vm_gasit, 4, 90
repl vm_gasit, #68584D56#, #5F564947#, 4
endif
 
cmp primacautarevariabile, 0
ifeq
inc primacautarevariabile
findmem #8B08C601FF#, IMAGEBASE
mov oep_in_ecx, $RESULT
cmp oep_in_ecx, 0
ifeq
log "Search pattern for MOV ECX,DWORD PTR DS:[EAX] not found"
pause
ret
endif
bphws oep_in_ecx, "x"
bpgoto oep_in_ecx, procesare_OEP //18.02.2016
log "OEP JUMP:"
log oep_in_ecx,""
findmem #3D00F000007E13B800000100#, IMAGEBASE
cmp $RESULT, 0
ifeq
log "Search pattern for CMP EAX,F000 not found"
pause
ret
endif
mov iatscrambling, $RESULT-15
log ""
log "IAT SCRAMBLING:"
log iatscrambling, ""
//bphws oep_in_ecx, "x"
//bpgoto oep_in_ecx, procesare_OEP
bphws iatscrambling, "x"
bpgoto iatscrambling, IAT_REDIRECTION
 
endif
 
mov bpesp, [esp]
cmp [esp+4], 0
jne RUN
cmp [esp+8], SIZE1
je A1
cmp [esp+C], TYPE
jne RUN
mov [esp+C], 1000  //  MEM_COMMIT
mov SIZE2, [esp+08]
///////////////////////
A1:
bphwc eip
rtr
esti
//bphws eip
cmp [eip], #5D# ,01
ifeq
bp eip
endif
mov eax, MYSEC
mov eax, MYSEC
log ""
log "Allocated memory zone:"
log eax, ""
cmp SIZE2, 0
je A2
add MYSEC, SIZE2
mov SIZE2, 0
bphwc bpesp-6
erun
pause
///////////////////////
A2:
add MYSEC, SIZE1
//bphwc eip
bc eip
bphws bpesp-6, "x"
erun
jmp VASTOP
 
//HWID 15.01.2016
rularehwid:
gstr eax
cmp $RESULT, 0
ifeq
esto
endif
cmp $RESULT, old
ifeq
log $RESULT, ""
mov [eax], new
log "HWID found and patched"
endif
jmp RUN1
 
///////////////////////////14.01.2016
RUN1:
ERUN
///////////////////////
VASTOP:
cmp [esp], 0
jne RUN1
cmp [esp+4], SIZE1
je A11
cmp [esp+08], TYPE
jne RUN1
mov [esp+08], 1000  //  MEM_COMMIT
mov SIZE2, [esp+04]
mov patchedvm, 1
///////////////////////
bphws iatscrambling, "x"
bpgoto iatscrambling, IAT_REDIRECTION
///////////////////////
A11:
bphwc eip
//bphws eip+06
bp eip+06
erun
log eax,""
cmp patchedvm, 1
ifeq
cmp schimbarehwid, 1
ifeq
inc patchedvm
mov primulbytemv, MYSEC
bphws primulbytemv, "x"
bpgoto primulbytemv, rularehwid
endif
endif
//bphwc eip
bc eip
//bphws bpesp-6, "x"
bp bpesp-6
mov eax, MYSEC
cmp SIZE2, 0
je A22
add MYSEC, SIZE2
mov SIZE2, 0
//bphws bpesp-6, "x"
bp bpesp-6
erun
///////////////////////
A22:
add MYSEC, SIZE1
erun
jmp VASTOP
///////////////////////
////////////////////////////
continuarefaradezactivaremv:
cmp disablehighvmalloc, 0
ifeq
erun
rtr
esti
endif
bc
bphwc
 
ASK_DIALOG0:
MSGYN "Cancel CRC check (first time press NO)?=YES / NO = Go to HWID dialog"
cmp $RESULT, 0
je ASK_DIALOG2
 
CRC:
mov marker, IMAGEBASE
//CRC fix
CRC_FIX:
findmem #83??FF8B????85??7C??4?#, IMAGEBASE
cmp $RESULT, 0
ifeq
je ASK_DIALOG1
endif
mov CRC_PLACE, $RESULT
find CRC_PLACE, #7C#
mov CRC_JUMP, $RESULT
 
mov patchpoint1va, CRC_JUMP
GCI patchpoint1va, COMMAND
mov opcode1, $RESULT
repl CRC_JUMP, #7C#, #EB#, 1
log "CRC PLACE PATCHED:"
log CRC_JUMP, ""
mov marker, CRC_PLACE
 
GCI CRC_JUMP, DESTINATION
find $RESULT, #C3#
mov bp_ret_crc, $RESULT
bphws bp_ret_crc
run
bphwc bp_ret_crc
//eval "{opcode1}"
//asm CRC_JUMP, $RESULT
fill patchpoint1va, 1, 7C
inc marker
//jmp CRC_FIX
 
ASK_DIALOG1:
MSGYN "Cancel API redirection?=YES / NO = Go to OEP"
cmp $RESULT, 0
je oep
 
OEP_FIND:
findmem #8B08C601FF#, IMAGEBASE
cmp $RESULT, 0
ifeq
log "Search pattern for MOV ECX,DWORD PTR DS:[EAX] not found"
pause
ret
endif
mov oep_marker, $RESULT
log ""
log "OEP marker in ECX"
log ""
log oep_marker,""
bphws oep_marker
bpgoto oep_marker, procesare_OEP
 
ASK_DIALOG2:
MSGYN "Is HWID used?=YES / NO = Go to IAT redirection"
cmp $RESULT, 0
je IAT_REDIRECTION
jne HWID_PATCH
 
 
HWID_PATCH:
mov imagebase_HWID, IMAGEBASE
mov hwid_count, 1
//mov marker, imagebase_HWID
mov marker, IMAGEBASE
 
HWID_FIX:
findmem #85C00F95C08B??????????8B??8?#, marker
cmp $RESULT, 0
ifeq
je IAT_REDIRECTION
endif
mov HWID_PLACE, $RESULT
bphws HWID_PLACE
bpgoto HWID_PLACE, HWID_FIX_EXEC
eval "The HWID {hwid_count} is at: {HWID_PLACE}"
log $RESULT, ""
mov marker, HWID_PLACE+1
inc hwid_count
cmp hwid_count, 2
ja IAT_REDIRECTION
jmp HWID_FIX
 
 
IAT_REDIRECTION:
bphwc bpesp-6
bphwc VirtualAlloc
bc
bphwc iatscrambling
mov patchpoint1va, iatscrambling
GCI patchpoint1va, COMMAND
mov opcode1, $RESULT
//bphws iatscrambling
//run
 
IAT_REDIRECTION_SPLIT:
bphwc iatscrambling
asm eip, "inc al"
esti
GCI eip, DESTINATION
find $RESULT, #C3#
mov bp_ret_iat, $RESULT
bphws bp_ret_iat, "x"
erun
bphwc bp_ret_iat
eval "{opcode1}"
asm patchpoint1va, $RESULT
 
bphwc
cmp changeid, 0
ifeq
jmp C_01
endif
bphws primulbytemv, "x"
bpgoto primulbytemv, rularehwid
 
C_01:
bphws oep_in_ecx, "x"
bpgoto oep_in_ecx, procesare_OEP
 
jmp oep
 
oep:
//findmem #8B08C601FF#, IMAGEBASE
//cmp $RESULT, 0
//ifeq
//log "Search pattern for MOV ECX,DWORD PTR DS:[EAX] not found"
//pause
//ret
//endif
//bphwc VirtualAlloc
//mov primulbp, $RESULT
bphws oep_in_ecx, "x"
run
bphwc oep_in_ecx
jmp procesare_OEP
 
procesare_OEP:
bphwc oep_in_ecx //18.02.2016
//bc
//bphwc
//dbh
esti
mov saltoep, ecx
bphws saltoep, "x"
erun
bphwc saltoep
esti
jmp sfarsit
 
 
sfarsit:
bphwc
bc
bpmc
 
cmp disablehighvmalloc, 1
ifeq
//dm VM_address, vm_size, fisier
mov eax, MYSEC2
mov edi, eax
sub edi, IMAGEBASE
MOV SPLICESRVA, edi
mov ecx, MYSEC
sub ecx, eax
eval "{eax} VA - {edi} RVA.mem"
mov filelc, $RESULT
mov fisier, filelc
dm eax,ecx, filelc
//msg "Now dump file / Add section use right RVA / Validate file & Fix file with Lord-PE! \r\n\r\nSmall part from one script of LCF-AT"
endif
 
cmt eip, "<----------This is the entry point - GIV"
//lc
log "****************************************************************************************"
log "Made in 2016"
log "giv@reversing.ro"
log ""
log "Current directory:"
log dir_curent, ""
log ""
log "Imagebase of the module:"
log ""
log IMAGEBASE, ""
log ""
log "This is the OEP VA:"
log ""
log eip, ""
log ""
log "This is the OEP RVA:"
mov OEP, eip
sub OEP, IMAGEBASE
log ""
log OEP, ""
log ""
eval "The VM have been dumped in file: {filelc}"
mov mesaj, $RESULT
log mesaj, ""
cmp [eip], #83EC04#, 03
log ""
ifeq
msgyn "The file semms to be multiple packed. The second layer seems to be Themida. Dump the file?"
cmp $RESULT, 1
ifeq
dpe "c:\unpacked.exe", eip 
msg "The dumped file is c:\unpacked.exe"
endif
endif
//MSGYN "Search and fix VM API's?=YES/NO=End script"
log "This part was done by by PC-RET"
//cmp $RESULT, 1
//je VM_API_FIX
jmp VM_API_FIX
////////////////////
finalizare:
 
// LCF-AT
////////////////////
ASK_FOR_IAT_DATAS:
ask "Enter the IAT Start VA address!"
cmp $RESULT, -1
je ASK_FOR_IAT_DATAS
cmp $RESULT, 00
je ASK_FOR_IAT_DATAS
mov IATSTART, $RESULT
mov IATRVA, $RESULT
eval "IATSTART  VA: {IATRVA}"
log $RESULT, ""
gmi IATRVA, MODULEBASE
sub IATRVA, $RESULT
eval "IATSTART RVA: {IATRVA}"
log $RESULT, ""
////////////////////
ASK_FOR_IAT_LENGHT:
ask "Enter the IAT size from start till end!"
cmp $RESULT, -1
je ASK_FOR_IAT_LENGHT
cmp $RESULT, 00
je ASK_FOR_IAT_LENGHT
mov IATSIZE, $RESULT
eval "IATSIZE     : {IATSIZE}"
log $RESULT, ""
mov IATEND, IATSTART
add IATEND, IATSIZE
call DUMPER
call FIXER
cmp disablehighvmalloc, 01
jne NO_SECTION_ADDING
call ADDER
////////////////////
NO_SECTION_ADDING:
 
jmp Recuperare_cod
ret
 
HWID_FIX_EXEC:
bc
exec
mov al,1
ende
bphwc iatscrambling
call IAT_REDIRECTION
ret
 
 
VM_API_FIX:
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///////////////////////Enigma Protector 4.xx VM API Fixer///////////////////////
//////////////////////////////////by PC-RET/////////////////////////////////////
////////////////////////////////////////////////////////////v0.5.1 public///////
////////////////////////////////////////////////////////////////////////////////
 
 
log ""
log "Enigma Protector 4.xx VM API Fixer - Public Version"
log "------------------------------------------------------------"
bc
bphwc
bpmc
mov notfixed, 0
mov fixed, 0
pusha
gmi eip, MODULEBASE
mov MODULEBASE, $RESULT
mov eax, $RESULT
mov edi, eax
add eax, 3C
mov eax, edi+[eax]
mov SECTIONS, [eax+06], 02
mov esi, eax+0F8
mov edi, 28
mov ebp, SECTIONS
mov ecx, edi
mul edi, SECTIONS
add edi, esi
sub edi, 28
mov LASTSECTION, [edi+0C]
add LASTSECTION, MODULEBASE
sub edi, 28
mov ENIGMASECTION, [edi+0C]
add ENIGMASECTION, MODULEBASE
cmp [ENIGMASECTION], #4D5A# ,02
je ENIGMASECTION_FOUND
cmp [LASTSECTION], #4D5A# ,02
je ENIGMASECTION_FOUND_LAST
ENIGMAENTER:
ask "Please enter ENIGMA section address:"
cmp $RESULT, 0
je canceled
mov ENIGMASECTION, $RESULT
cmp [ENIGMASECTION], #4D5A# ,02
jne ENIGMASUSPICIOUS
jmp start
ENIGMASUSPICIOUS:
eval "The entered VA doesn't seems like ENIGMA section address.\r\n\r\nTry again?"
msgyn $RESULT
cmp $RESULT, 01
je ENIGMAENTER
ENIGMASECTION_FOUND_LAST:
mov ENIGMASECTION, LASTSECTION
ENIGMASECTION_FOUND:
popa
start:
eval "Do you want the script to automatically search for VM'ed imports and fix them?"
msgyn $RESULT
cmp $RESULT, 01
je auto
manual:
ask "Please enter IAT start:"
cmp $RESULT, 0
je canceled
mov IATStart, $RESULT
ask "Please enter IAT end:"
cmp $RESULT, 0
je canceled
mov IATEnd, $RESULT
mov IATSize,IATEnd
sub IATSize,IATStart
 
log "------------------IAT data------------------"
log "IAT start address:"
log IATStart,""
log "IAT end address:"
log IATEnd,""
log "IAT size:"
log IATSize,""
log " "
log "--------------------------------------------"
 
 
gmemi ENIGMASECTION, MEMORYSIZE
mov ENIGMASIZE, $RESULT
gpi MAINBASE
mov filebase, $RESULT
gmi filebase, CODEBASE
mov CODESECTION, $RESULT
gmi filebase, CODESIZE
mov CODESIZE, $RESULT
alloc 2000
mov VMAPILOGGER, $RESULT
alloc 1000
mov vmapialloc, $RESULT
mov [vmapialloc], #60BBAAAAAAAABEBBBBBBBBBFCCCCCCCC03F33BDE0F8711000000833B000F850E00000083C304E9E7FFFFFFE91D000000908B1381FA0070530072E881FA00907C0077E0891F89570483C708EBD66190#
mov [vmapialloc+2], IATStart
mov [vmapialloc+7], IATSize
mov [vmapialloc+C], VMAPILOGGER
mov [vmapialloc+35], ENIGMASECTION
mov [vmapialloc+3D], ENIGMASECTION
add [vmapialloc+3D], ENIGMASIZE
mov OEP, eip
mov eip, vmapialloc
bp vmapialloc+4E
run
jmp vmpapialloc_set
auto:
gmemi ENIGMASECTION, MEMORYSIZE
mov ENIGMASIZE, $RESULT
gpi MAINBASE
mov filebase, $RESULT
gmi filebase, CODEBASE
mov CODESECTION, $RESULT
gmi filebase, CODESIZE
mov CODESIZE, $RESULT
alloc 2000
mov VMAPILOGGER, $RESULT
alloc 1000
mov vmapialloc, $RESULT
mov [vmapialloc], #60BB00104000BE00400E00BF0000320503F383EE013BDE0F841100000066813BFF250F840C00000043E9E7FFFFFFE930000000908B5302FF7302E820BD4F7783F80174E48B1281FA0070E70372DA81FA0050420477D28B4B02890F89570483C708EBC5BB00104000BE00400E0003F383EE013BDE0F841100000066813BFF150F840C00000043E9E7FFFFFFE930000000908B5302FF7302E8C3BC4F7783F80174E48B1281FA0070E70372DA81FA0050420477D28B4B02890F89570483C708EBC56190#
mov [vmapialloc+2], CODESECTION
mov [vmapialloc+7], CODESIZE
mov [vmapialloc+C], VMAPILOGGER
mov [vmapialloc+64], CODESECTION
mov [vmapialloc+69], CODESIZE
mov [vmapialloc+48], ENIGMASECTION
mov [vmapialloc+50], ENIGMASECTION
add [vmapialloc+50], ENIGMASIZE
mov [vmapialloc+A5], ENIGMASECTION
mov [vmapialloc+AD], ENIGMASECTION
add [vmapialloc+AD], ENIGMASIZE
GPA "IsBadCodePtr", "kernel32.dll"
mov  IsBadCodePtr, $RESULT
eval "call {IsBadCodePtr}"
asm vmapialloc+3A, $RESULT
eval "call {IsBadCodePtr}"
asm vmapialloc+97, $RESULT
mov OEP, eip
mov eip, vmapialloc
bp vmapialloc+C1
run
vmpapialloc_set:
mov eip, OEP
mov esp_addr, esp
pusha
alloc 1000
mov searchalloc, $RESULT
mov [searchalloc], #60B800000000B900000000BE0000000003C883E9013BC10F840F0000008038E90F840800000040E9E9FFFFFF90908B500103D083C20581FA0000000072E83BD177E49090803A6875DD39720175D86190#
mov [searchalloc+2], ENIGMASECTION
mov [searchalloc+38], ENIGMASECTION
mov [searchalloc+7], ENIGMASIZE
looplogger:
mov origapiaddr, [VMAPILOGGER]
mov vmedlocation, [VMAPILOGGER+4]
cmp origapiaddr, 0
je end
gmemi [origapiaddr], MEMORYBASE
cmp $RESULT, ENIGMASECTION
jne next4bytes
mov eip, vmedlocation
loopsti:
find eip, #68????????#
cmp $RESULT, 0
jne foundpointer_push
findmovpointer:
find eip, #C70424#
cmp $RESULT, 0
jne foundpointer_mov
do_sti:
sti
jmp loopsti
foundpointer_push:
cmp $RESULT, eip
jne findmovpointer
jmp endsearch
foundpointer_mov:
cmp $RESULT, eip
jne do_sti
jmp endsearch
endsearch:
cmp [eip], #68#, 1
je push_type
cmp [eip], #C70424#, 3
je mov_type
push_type:
mov searchpointer, [eip+1], 4
jmp startsearch
mov_type:
mov searchpointer, [eip+3], 4
startsearch:
mov [searchalloc+C], searchpointer
mov bakeip, eip
mov eip, searchalloc
bp searchalloc+2C
bp searchalloc+4E
run
bc
cmp eip,searchalloc+2C
je next4bytes1
cmp eip,searchalloc+4E
je foundpointer
jmp end
foundpointer:
mov addr_result, eax
and addr_result, f0
cmp addr_result, 0
jne normal
mov addr_result, eax
alloc 100
mov alloc1, $RESULT
mov [alloc1], addr_result
rev [alloc1]
mov addr_result, $RESULT
eval #0{addr_result}#
mov addr_result, $RESULT
mov addr_result_bak, $RESULT
free alloc1
jmp after_notnormal
normal:
mov addr_result, eax
mov addr_result_bak, eax
after_notnormal:
sti
mov searchaddr_start, ENIGMASECTION
searchres:
find searchaddr_start, addr_result
cmp $RESULT, 0
je next4bytes1
mov addr_result, $RESULT
 
gmi [addr_result-4], MODULEBASE
mov mdbase, $RESULT
cmp mdbase, 0
je cont_s
cmp mdbase, [addr_result-8]
jne cont_s
jmp stop_search
 
cont_s:
mov searchaddr_start, addr_result
add searchaddr_start, 4
mov addr_result, addr_result_bak
jmp searchres
 
stop_search:
mov [origapiaddr], [addr_result-4]
gn [addr_result-4]
mov apiname, $RESULT_2
add fixed, 1
eval "[INFO]: Fixed at {origapiaddr} - {apiname}"
log $RESULT, ""
mov eip, bakeip
jmp next4bytes
next4bytes:
mov searchpointer, 0
mov addr_result, 0
add VMAPILOGGER, 8
jmp looplogger
next4bytes1:
mov eip, bakeip
add notfixed, 1
eval "[ERROR]: NOT fixed at {origapiaddr}"
log $RESULT, ""
add VMAPILOGGER, 8
mov searchpointer, 0
mov addr_result, 0
jmp looplogger
end:
mov eip, bakeip
free searchalloc
free VMAPILOGGER
free vmapialloc
mov esp, esp_addr
popa
mov eip, OEP
cmp fixed, 0
je nofixed
log " "
log "------------------UIF data------------------"
GPI PROCESSID
MOV PID, $RESULT
log "Process ID:"
log PID,""
log "Code section address:"
log CODESECTION,""
mov codesecend, CODESECTION
add codesecend, CODESIZE
log "Code section end:"
log codesecend,""
log " "
log PID,""
log CODESECTION,""
log codesecend,""
log " "
log "--------------------------------------------"
eval "Job completed.\r\n--------------------------\r\nFixed: {fixed}\r\nNOT fixed: {notfixed}\r\n--------------------------\r\nCheck log for more details."
jmp DONE1
nofixed:
eval "Job completed.\r\nNothing has been fixed."
DONE1:
msg $RESULT
 
Recuperare_cod:
cmp rulat_r, 0
ja Sfarsit
MSGYN "Do you want to recover virtualized OEP?"
cmp $RESULT, 0
ifeq
mov rulat_r, 1
jmp finalizare
//jmp Sfarsit
endif
 
GMI eip, CODEBASE
mov bazacod, $RESULT
GMI eip, CODESIZE
mov marimecod, $RESULT
 
VAR INTRARE
//ask "Enter the EIP of the stolen OEP"
mov INTRARE, eip
//mov INTRARE, 0041F372
 
 
BPHWS INTRARE
erun
bphwc INTRARE
 
ask "Enter compiler type: 1 for Delphi 2 for Visual Basic 3 for C++"
var sFile
mov tipcompilator, $RESULT
cmp $RESULT,1 
ifeq
jmp Delphi
endif
cmp $RESULT,2 
ifeq
jmp vb6
endif
cmp $RESULT,3
ifeq
jmp C_plus
endif
 
//Target compiler select
mov delphi, 1
mov vb6, 0
mov cpp, 0
/////////////////
 
 
cmp delphi, 1
ifeq
jmp Delphi
endif
 
cmp vb6, 1
ifeq
jmp vb6
endif
 
cmp cpp, 1
ifeq
jmp C_plus
endif
 
 
Delphi:
eval "Recovered_OEP_Delphi.txt"
mov sFile, $RESULT
wrt sFile, " "
wrta sFile, "PUSH EBP"
wrta sFile, "MOV EBP, ESP"
wrta sFile, "ADD ESP, -10"
 
log "PUSH EBP"
log "MOV EBP, ESP"
log "ADD ESP, -10"
 
BREAK:
 
bc
bphwc
bpmc
 
BPRM bazacod, marimecod
erun
cmp eip, INTRARE
ifeq
jmp BREAK
endif
cmp eip, bazacod+marimecod
ifa
jmp BREAK
endif
cmp eax, 01000000
ifa
jmp DWORD
endif
cmp [eip], #FF25#, 2
ifeq
jmp BREAK
endif
mov valoareeax, eax
eval "MOV EAX, 00{valoareeax}"
LOG $RESULT, ""
wrta sFile, $RESULT
eval "MOV ECX, 00{ecx}"
log $RESULT, ""
wrta sFile, $RESULT
eval "MOV EDX, 00{edx}"
log $RESULT, ""
wrta sFile, $RESULT
mov pozitie, eip
eval "CALL 0{pozitie}"
log $RESULT, ""
wrta sFile, $RESULT
 
GASIRE_RET:
bpmc
cmp [eip], #FF25#, 2
ifeq
jmp BREAK
endif
find eip, #C3#, 5
mov adresagasitaret, $RESULT
cmp adresagasitaret, 0
ifa
bp adresagasitaret
erun
bc adresagasitaret
esti
gci eip, COMMAND 
mov stringoep, $RESULT
scmpi stringoep, "PUSH 0x0", 4
cmp $RESULT, 0
ifa
jmp Comanda_gci
endif
esti
jmp Comanda_gci
endif
 
 
find eip, #5?C?#, 1500
mov adresagasitaret, $RESULT
cmp adresagasitaret, 0
ifa
mov diferenta, adresagasitaret-eip
cmp diferenta, 35
ifb
cmp [adresagasitaret], #5BC3#, 2
ifeq
bpmc 
bp adresagasitaret
erun
esti
esti
jmp Comanda_gci
endif
cmp [adresagasitaret], #5DC2#, 2
ifeq
bpmc 
bp adresagasitaret
erun
esti
esti
jmp Comanda_gci
endif
msg "Diferenta prea mica"
endif
mov adresacomparare, adresagasitaret
add adresacomparare, 1
cmp [adresacomparare], #C3#,1
ifneq
mov start, eip
add start, 35
find start,#E8????????C3#
bp $RESULT
erun
bc
find eip, #5?C?#
bp $RESULT
erun
bc
esti
esti
jmp Comanda_gci
//msg "Pauza C3"
endif
bp adresagasitaret
erun
bc adresagasitaret
esti
esti
jmp Comanda_gci
endif
 
find eip, #5?5?5?5?C3#,500
bpmc
mov adresagasitaret, $RESULT
cmp adresagasitaret, 0
ifa
bp adresagasitaret
erun
bc adresagasitaret
esti
esti
jmp Comanda_gci
endif
 
cmp adresagasitaret, 0
 
Continuare_ret:
bpmc
ifa
bp adresagasitaret
bpmc
erun
endif
bc adresagasitaret
esti
esti
Comanda_gci:
GCI eip, COMMAND
mov comanda, $RESULT
scmpi comanda, "PUSH 0x0", 4
ifneq
jmp GASIRE_RET
endif
jmp BREAK
 
DWORD:
/////////
bc
bphwc
/////////
mov gasire, eax
rev gasire
mov gasire, $RESULT
///////////////////
eval "{gasire}"
mov gasire, $RESULT
//////////////////
len gasire
cmp $RESULT, 7
ifeq
eval "0{gasire}"
mov gasire, $RESULT
jmp ansamblare_gasire
endif
len gasire
cmp $RESULT, 6
ifeq
eval "00{gasire}"
mov gasire, $RESULT
endif
//log gasire, ""
ansamblare_gasire:
eval "#{gasire}#"
mov gasire, $RESULT
findmem gasire, bazacod
mov adresa_p, $RESULT
cmp adresa_p, 0
ifeq
GCI eip, COMMAND
mov comanda, $RESULT
scmpi comanda, "MOV EDX", 7
ifeq
find eip, #58C3#
bp $RESULT+1
bpmc
bphwc
erun
bc
esti
esti
jmp Comanda_gci
endif
msg "Pointer negasit"
pause
endif
ifa
eval "MOV EAX, DWORD PTR[{adresa_p}]"
log $RESULT, ""
wrta sFile, $RESULT
cmp ecx, 401000
ifa
eval "MOV ECX, 00{ecx}"
log $RESULT, ""
wrta sFile, $RESULT
endif
cmp edx, 401000
ifa
eval "MOV EDX, 00{edx}"
log $RESULT, ""
wrta sFile, $RESULT
endif
mov pozitie, eip
eval "CALL 0{pozitie}"
log $RESULT, ""
wrta sFile, $RESULT
jmp GASIRE_RET
 
vb6:
eval "Recovered_OEP_VB6.txt"
mov sFile, $RESULT
wrt sFile, " "
findmem #5642??21#, bazacod
mov variabilapush, $RESULT
cmp variabilapush,0
ifeq
msg "Pattern not found for push value - VB6"
jmp Sfarsit
endif
eval "PUSH 00{variabilapush}"
LOG $RESULT, ""
wrta sFile, $RESULT
asm eip, $RESULT
mov variabilacall, eip-6
eval "CALL 00{variabilacall}"
LOG $RESULT, ""
wrta sFile, $RESULT
asm eip+5, $RESULT
jmp Sfarsit
 
C_plus:
bc
bphwc
bpmc
BPRM bazacod, marimecod
erun
MOV intrarecallc, eip
eval "Recovered_OEP_CPP.txt"
mov sFile, $RESULT
wrt sFile, " "
EVAL "CALL {intrarecallc}"
log $RESULT, ""
wrta sFile, $RESULT
ASM INTRARE, $RESULT
bc
bphwc
bpmc
rtr
esti
BPRM bazacod, marimecod
erun
MOV jmpc, eip
EVAL "JMP {jmpc}"
log $RESULT, ""
wrta sFile, $RESULT
ASM INTRARE+5, $RESULT
jmp Sfarsit
 
Sfarsit:
msg "Script is finished"
//endif
pause
pause
ret
canceled:
msg "Canceled by user"
pause
pause
ret
////////////////////
////////////////////
////////////////////
VARS:
var EXEFILENAME
var CURRENTDIR
var EXEFILENAME_LEN
var CURRENTDIR_LEN
var LoadLibraryA
var VirtualAlloc
var GetModuleHandleA
var GetModuleFileNameA
var GetCurrentProcessId
var OpenProcess
var malloc
var free
var ReadProcessMemory
var CloseHandle
var VirtualFree
var CreateFileA
var WriteFile
var GetFileSize
var ReadFile
var SetFilePointer
var GetCommandLineA
var CreateFileMappingA
var MapViewOfFile
var lstrcpynA
var VirtualLock
var SetEndOfFile
var VirtualUnlock
var UnmapViewOfFile
var lstrlenA
var ldiv
var PATCH_CODESEC
var BAK_EIP
var ARIMPREC_PATH
var TRY_NAMES
var SearchAndRebuildImports
var PID
var IATRVA
var IATSIZE
var REBUILD_PATCH
var MessageBoxA
var GetProcAddress
var DOT_END
var DeleteFileA
var MoveFileA
var SECHANDLE
var EXEFILENAME_SHORT  // xy.exe oder xy.dll
var OEP_RVA            // new rva ohne IB
var NEW_SEC_RVA        // rva of new section
var NEW_SECTION_NAME   // name of dumped section to add
var NEW_SECTION_PATH   // section full path
gpa "MessageBoxA",         "user32.dll"
mov  MessageBoxA,           $RESULT
gpa "MoveFileA",           "kernel32.dll"
mov  MoveFileA,             $RESULT
gpa "DeleteFileA",         "kernel32.dll"
mov  DeleteFileA,           $RESULT
gpa "GetProcAddress",      "kernel32.dll"
mov  GetProcAddress,        $RESULT
gpa "LoadLibraryA",        "kernel32.dll"
mov  LoadLibraryA,          $RESULT
gpa "VirtualAlloc",        "kernel32.dll"
mov  VirtualAlloc,          $RESULT
gpa "GetModuleHandleA",    "kernel32.dll"
mov  GetModuleHandleA,      $RESULT
gpa "GetModuleFileNameA",  "kernel32.dll"
mov  GetModuleFileNameA,    $RESULT
gpa "GetCurrentProcessId", "kernel32.dll"
mov  GetCurrentProcessId,   $RESULT
gpa "OpenProcess",         "kernel32.dll"
mov  OpenProcess,           $RESULT
gpa "ReadProcessMemory",   "kernel32.dll"
mov  ReadProcessMemory,     $RESULT
gpa "CloseHandle",         "kernel32.dll"
mov  CloseHandle,           $RESULT
gpa "VirtualFree",         "kernel32.dll"
mov  VirtualFree,           $RESULT
gpa "CreateFileA",         "kernel32.dll"
mov  CreateFileA,           $RESULT
gpa "WriteFile",           "kernel32.dll"
mov  WriteFile,             $RESULT
gpa "GetFileSize",         "kernel32.dll"
mov  GetFileSize,           $RESULT
gpa "ReadFile",            "kernel32.dll"
mov  ReadFile,              $RESULT
gpa "SetFilePointer",      "kernel32.dll"
mov  SetFilePointer,        $RESULT
gpa "GetCommandLineA",     "kernel32.dll"
mov  GetCommandLineA,       $RESULT
gpa "CreateFileMappingA",  "kernel32.dll"
mov  CreateFileMappingA,    $RESULT
gpa "MapViewOfFile",       "kernel32.dll"
mov  MapViewOfFile,         $RESULT
gpa "lstrcpynA",           "kernel32.dll"
mov  lstrcpynA,             $RESULT
gpa "VirtualLock",         "kernel32.dll"
mov  VirtualLock,           $RESULT
gpa "SetEndOfFile",        "kernel32.dll"
mov  SetEndOfFile,          $RESULT
gpa "VirtualUnlock",       "kernel32.dll"
mov  VirtualUnlock,         $RESULT
gpa "UnmapViewOfFile",     "kernel32.dll"
mov  UnmapViewOfFile,       $RESULT
gpa "lstrlenA",            "kernel32.dll"
mov  lstrlenA,              $RESULT
ret
////////////////////
DUMPER:
gpi EXEFILENAME
mov EXEFILENAME,     $RESULT
len EXEFILENAME
mov EXEFILENAME_LEN, $RESULT
gpi CURRENTDIR
mov CURRENTDIR,      $RESULT
len CURRENTDIR
mov CURRENTDIR_LEN,  $RESULT
pusha
alloc 1000
mov eax, $RESULT
mov esi, eax
mov [eax], EXEFILENAME
add eax, CURRENTDIR_LEN
mov ecx, EXEFILENAME_LEN
sub ecx, CURRENTDIR_LEN
readstr [eax], ecx
mov EXEFILENAME_SHORT, $RESULT
str EXEFILENAME_SHORT
add eax, 10
add eax, ecx
mov [eax], "msvcrt.dll"
mov edi, LoadLibraryA
exec
push eax
call edi
ende
cmp eax, 00
jne MSVCRT_LOADED
msg "Can't load msvcrt.dll!"
pause
pause
cret
ret
////////////////////
MSVCRT_LOADED:
free esi
popa
gpa "malloc", "msvcrt.dll"
mov  malloc,   $RESULT
gpa "free",   "msvcrt.dll"
mov  free,     $RESULT
gpa "ldiv",   "msvcrt.dll"
mov  ldiv,     $RESULT
////////////////////
ASK_OEP_RVA:
// ask "Enter new OEP RVA"
// cmp $RESULT, 00
// je ASK_OEP_RVA
// cmp $RESULT, -1
// je ASK_OEP_RVA
mov OEP_RVA, eip
gmi OEP_RVA, MODULEBASE
sub OEP_RVA, $RESULT
////////////////////
START_OF_PATCH:
mov BAK_EIP, eip
alloc 2000
mov PATCH_CODESEC, $RESULT
mov eip, PATCH_CODESEC+09F
alloc 1000
//new
mov NAME_FILE, $RESULT
mov [NAME_FILE], EXEFILENAME_SHORT
mov [PATCH_CODESEC],    OEP_RVA
// mov [PATCH_CODESEC+04], EXEFILENAME_SHORT
mov [PATCH_CODESEC+86], "msvcrt.dll"
mov [PATCH_CODESEC+09F], #C705AAAAAAAA000000008925AAAAAAAAA3AAAAAAAA890DAAAAAAAA8915AAAAAAAA891DAAAAAAAA892DAAAAAAAA8935AAAAAAAA893DAAAAAAAA#
mov [PATCH_CODESEC+0D8], #68AAAAAAAAE8D9BA21BB83F8000F84920400006A40680010000068004000006A00E8BDBA21BB83F8000F8476040000A3AAAAAAAA05002000008BE08BE881ED000200006A40680010000068001000006A00E88DBA21BB#
mov [PATCH_CODESEC+12E], #83F8000F8446040000A3AAAAAAAA6A40680010000068001000006A00E86CBA21BB83F8000F8425040000A3AAAAAAAA68AAAAAAAAE854BA21BB83F8000F840D0400006800100000FF35AAAAAAAA50E83ABA21BB83F8000F84F303000068AAAAAAAAE827BA21BB#
mov [PATCH_CODESEC+194], #83F8000F84E0030000A3AAAAAAAA8B483C03C88B51508915AAAAAAAA6800100000FF35AAAAAAAAFF35AAAAAAAAE8F5B921BB83F8000F84AE030000A3AAAAAAAA0305AAAAAAAA#
mov [PATCH_CODESEC+1DA], #83E8046681382E64741A6681382E4474136681382E65741B6681382E457414E97F030000C7005F44502EC74004646C6C00EB0FC7005F44502EC7400465786500EB00E89AB921BBA3AAAAAAAAFF35AAAAAAAA6A006A10E886B921BB#
mov [PATCH_CODESEC+235], #83F8000F843F030000A3AAAAAAAA33C0FF35AAAAAAAAE86BB921BB83F8000F8424030000A3AAAAAAAA8D55D852FF35AAAAAAAAFF35AAAAAAAAA1AAAAAAAA50FF35AAAAAAAAE83CB921BB83F8000F84F5020000FF35AAAAAAAAE828B921BB#
mov [PATCH_CODESEC+293], #83F8000F84E10200006A40680010000068002000006A00E80CB921BB83F8000F84C5020000A3AAAAAAAAA1AAAAAAAA8B0DAAAAAAAA518B35AAAAAAAA568BD052E883010000A1AAAAAAAA03403C8BF08B1DAAAAAAAA#
mov [PATCH_CODESEC+2E8], #895E28E805010000A1AAAAAAAA03403C8B40508B15AAAAAAAA8B35AAAAAAAA894424108954246C525056E87A0000008B25AAAAAAAA68008000006A00FF35AAAAAAAA#
mov [PATCH_CODESEC+32A], #E88CB821BB68008000006A00FF35AAAAAAAAE87AB821BB68008000006A00FF35AAAAAAAAE868B821BB68008000006A00FF35AAAAAAAAE856B821BBA1AAAAAAAA8B0DAAAAAAAA8B15AAAAAAAA8B1DAAAAAAAA8B2DAAAAAAAA8B35AAAAAAAA8B3DAAAAAAAA#
mov [PATCH_CODESEC+38E], #9090908974240CA1AAAAAAAA566A0068800000006A026A006A0368000000C050E808B821BB8BF083FEFF0F84BF0100008B54240CA1AAAAAAAA8D4C24106A0051525056E8E5B721BB83F8000F849E01000056E8D6B721BB#
mov [PATCH_CODESEC+3E5], #83F8000F848F010000B8010000005EC333D23BC20F847E01000033C9668B48148D4C08188955FC8955E433F6668B70063BD6731C8B710C8971148B710889711083C128894DE042EBDEC745FCFFFFFFFFB90010000089483C894854C3#
mov [PATCH_CODESEC+441], #9090B8010000008B4DF064890D000000005F5E5B8BE55DC3909081EC3C01000053555633ED575568800000006A03556A01680000008050E83EB721BB8BF083FEFF7512E9F40000005F5E5D33C05B81C43C010000C3#
mov [PATCH_CODESEC+496], #6A0056E81DB721BB83F8FF0F84D6000000BFBBBBBBBB8D4C24106A00518D54241C6A405256FFD785C00F84B800000066817C24144D5A7412E9AA0000005F5E5D33C05B81C43C010000C38B442450BBBBBBBBBB#
mov [PATCH_CODESEC+4E9], #6A006A005056FFD38D4C24106A00518D54245C68F80000005256FFD785C00F8470000000817C2454504500000F85620000008B8424A80000008B8C24580100003BC10F874C0000006A006A006A0056FFD38B9424A80000008B8424540100008D4C24106A0051525056FFD7#
mov [PATCH_CODESEC+554], #85C00F8421000000BD0100000056E854B621BB83F8000F840D0000005F8BC55E5D5B81C43C010000C39090#
pusha
mov eax, PATCH_CODESEC
add eax, 09F
mov ecx, PATCH_CODESEC
mov [eax+002], ecx
mov [eax+006], OEP_RVA
mov [eax+00C], ecx+04E
mov [eax+011], ecx+05A
mov [eax+017], ecx+05E
mov [eax+01D], ecx+062
mov [eax+023], ecx+066
mov [eax+029], ecx+06A
mov [eax+02F], ecx+06E
mov [eax+035], ecx+072
mov [eax+03A], ecx+086
eval "call {LoadLibraryA}"
asm eax+03E, $RESULT
eval "call {VirtualAlloc}"
asm eax+05A, $RESULT
mov [eax+069], ecx+052
eval "call {VirtualAlloc}"
asm eax+08A, $RESULT
mov [eax+099], ecx+076
eval "call {VirtualAlloc}"
asm eax+0AB, $RESULT
mov [eax+0BA], ecx+07A
// mov [eax+0BF], ecx+004
mov [eax+0BF], NAME_FILE
eval "call {GetModuleHandleA}"
asm eax+0C3, $RESULT
mov [eax+0D8], ecx+07A
eval "call {GetModuleFileNameA}"
asm eax+0DD, $RESULT
// mov [eax+0EC], ecx+004
mov [eax+0EC], NAME_FILE
eval "call {GetModuleHandleA}"
asm eax+0F0, $RESULT
mov [eax+0FF], ecx+032
mov [eax+10D], ecx+036
mov [eax+118], ecx+076
mov [eax+11E], ecx+032
eval "call {GetModuleFileNameA}"
asm eax+122, $RESULT
mov [eax+131], ecx+056
mov [eax+137], ecx+076
eval "call {GetCurrentProcessId}"
asm eax+17D, $RESULT
mov [eax+183], ecx+03A
mov [eax+189], ecx+03A
eval "call {OpenProcess}"
asm eax+191, $RESULT
mov [eax+1A0], ecx+03E
mov [eax+1A8], ecx+036
eval "call {malloc}"
asm eax+1AC, $RESULT
mov [eax+1BB], ecx+046
mov [eax+1C5], ecx+036
mov [eax+1CB], ecx+046
mov [eax+1D0], ecx+032
mov [eax+1D7], ecx+03E
eval "call {ReadProcessMemory}"
asm eax+1DB, $RESULT
mov [eax+1EB], ecx+03E
eval "call {CloseHandle}"
asm eax+1EF, $RESULT
eval "call {VirtualAlloc}"
asm eax+20B, $RESULT
mov [eax+21A], ecx+02E
mov [eax+21F], ecx+07A
mov [eax+225], ecx+036
mov [eax+22C], ecx+02E
mov [eax+23A], ecx+046
mov [eax+245], ecx
mov [eax+252], ecx+046
mov [eax+25E], ecx+046
mov [eax+264], ecx+076
mov [eax+27A], ecx+04E
mov [eax+287], ecx+052
eval "call {VirtualFree}"
asm eax+28B, $RESULT
mov [eax+299], ecx+076
eval "call {VirtualFree}"
asm eax+29D, $RESULT
mov [eax+2AB], ecx+07A
eval "call {VirtualFree}"
asm eax+2AF, $RESULT
mov [eax+2BD], ecx+02E
eval "call {VirtualFree}"
asm eax+2C1, $RESULT
mov [eax+2C7], ecx+05A
mov [eax+2CD], ecx+05E
mov [eax+2D3], ecx+062
mov [eax+2D9], ecx+066
mov [eax+2DF], ecx+06A
mov [eax+2E5], ecx+06E
mov [eax+2EB], ecx+072
mov [eax+2F7], ecx+076
eval "call {CreateFileA}"
asm eax+30F, $RESULT
mov [eax+324], ecx+046
eval "call {WriteFile}"
asm eax+332, $RESULT
eval "call {CloseHandle}"
asm eax+341, $RESULT
eval "call {CreateFileA}"
asm eax+3D9, $RESULT
eval "call {GetFileSize}"
asm eax+3FA, $RESULT
mov [eax+409], ReadFile
mov [eax+446], SetFilePointer
eval "call {CloseHandle}"
asm eax+4C3, $RESULT
popa
bp PATCH_CODESEC+38F  // success dumping
bp PATCH_CODESEC+57D  // PROBLEM
esto
bc
cmp eip, PATCH_CODESEC+38F
je DUMPING_SUCCESSFULLY
msg "Dumping failed by the script! \r\n\r\nDump the file manually! \r\n\r\nLCF-AT"
pause
pause
cret
ret
////////////////////
DUMPING_SUCCESSFULLY:
msg "Dumping was successfully by the script! \r\n\r\nLCF-AT"
mov eip, BAK_EIP
free PATCH_CODESEC
ret
////////////////////
ADDER:
alloc 2000
mov PATCH_CODESEC, $RESULT
////////////////////
ASK_SECTION_NAME:
// ask "Enter section name of dumped section with quotes"
// cmp $RESULT, 00
// je ASK_SECTION_NAME
// cmp $RESULT, -1
// je ASK_SECTION_NAME
mov $RESULT, filelc
mov NEW_SECTION_NAME, $RESULT
log NEW_SECTION_NAME, ""
////////////////////
ASK_NEW_SEC_RVA:
// ask "Enter new section RVA or nothing"
// cmp $RESULT, -1
// je ASK_NEW_SEC_RVA
mov $RESULT, SPLICESRVA
mov NEW_SEC_RVA, $RESULT
eval "{CURRENTDIR}{NEW_SECTION_NAME}"
mov NEW_SECTION_PATH, $RESULT
log NEW_SECTION_PATH, ""
mov [PATCH_CODESEC],     NEW_SEC_RVA
mov [PATCH_CODESEC+08],  NEW_SECTION_NAME
mov [PATCH_CODESEC+37],  EXEFILENAME_SHORT
mov [PATCH_CODESEC+59],  NEW_SECTION_PATH
mov [PATCH_CODESEC+216], #2E4E657753656300#
pusha
mov eax, PATCH_CODESEC
mov ecx, PATCH_CODESEC
add eax, 222
mov eip, eax
mov [eax],     #60B8AAAAAAAAA3AAAAAAAAB8AAAAAA0AA3AAAAAAAA618925AAAAAAAAA3AAAAAAAA890DAAAAAAAA8915AAAAAAAA891DAAAAAAAA892DAAAAAAAA8935AAAAAAAA893DAAAAAAAA8925AAAAAAAA6A40680010000068004000006A00E83BB921BB83F8000F84FD060000A3AAAAAAAA05002000008BE08BE881ED000200006A40680010000068001000006A00E80BB921BB83F800#
mov [eax+091], #0F84CD060000A3AAAAAAAA8BF868AAAAAAAAE8F1B821BB83F8000F84B30600006800100000FF35AAAAAAAA50E8D7B821BB83F8000F84990600000305AAAAAAAA83E8046681382E64741A6681382E4474136681382E65741B6681382E457414E96F060000C7005F44502EC74004646C6C00EB0FC7005F44502EC7400465786500EB00A1AAAAAAAA8BF8EB37E878B821BB#
mov [eax+121], #4033C980382274044140EBF72BC1890DAAAAAAAA96F3A4A1AAAAAAAA8BD8031DAAAAAAAA83EB048B3BC7035F44502E897B03FF35AAAAAAAAE80700000090E806010000905355568B742410576A0068800000006A036A006A0368000000C056E814B821BB#
mov [eax+185], #8BF8A3AAAAAAAA83FFFF7505E9CE0500006A0057E8FBB721BB83F8FF0F84BD0500006A006A006A006A046A0057A3AAAAAAAA898608010000E8D7B721BB83F8008BE885ED7505E9940500006A006A006A006A0655E8BBB721BB83F8000F847D05000055BDBBBBBBBB#
mov [eax+1ED], #8BD8FFD583F8000F846A050000891DAAAAAAAA8BC38B403C03C3A3AAAAAAAAC780D000000000000000C780D4000000000000008BC885C08D511889861001000089961C010000740583C270EB0383C26033C0899620010000668B4114C78628010000000000005F8D4C081833C0898E24010000890DAAAAAAAA83C40CC36A0068800000006A036A006A01B9AAAAAAAA#
mov [eax+27C], #680000008051E812B721BB8BD883FBFF7505E9D1040000BDBBBBBBBB6A0053FFD583F8FF0F84BE0400008BF056E8EBB621BBA3AAAAAAAA8BF88D5424146A0052565753E8D5B621BB83F8000F8497040000E8550400008B48148B501003CA8B15AAAAAAAA518B423C50E8560400008B0DAAAAAAAA#
mov [eax+2F0], #6A006A005051E89EB621BBA1AAAAAAAA8D5424146A0052565750BDBBBBBBBB83F8000F844C04000057E8FD030000E82B030000E8FF0300008BF8566800100000897710E8080400008B0DAAAAAAAA89470851E8E302000083C4108D5424186A095052E842B621BB#
mov [eax+357], #83F8000F84040400008B4424186A0089078B4C2420894F048B15AAAAAAAA52FFD568AAAAAAAAA3AAAAAAAAE8630200008B1DAAAAAAAA6A0068800000006A036A006A0368000000C053E8F4B521BB83F8FF894424147505E9B10300008B5424146A0052E8DAB521BB83F8FF0F849C0300008BD8895C241C895C24186A046800100000536A00E8B8B521BB#
mov [eax+3E1], #85C0894424107505E9760300008B4424105350E8A0B521BB8B5424108B4424148D4C24246A0051535250E889B521BB83F8000F844B0300008B4C24108B413C03C1A3AAAAAAAA8BD08B4C24188B5424105152A1AAAAAAAA6033D2668B500633C9668B48148D4C0818BF2800000003CF4A83FA0075F883E928833DAAAAAAAA00#
mov [eax+460], #74098B35AAAAAAAA89710C61E8940000008BD88B4C24105183C40C8B542414BBBBBBBBBB6A006A006A0052FFD38B4C24188B5424108D4424246A00508B44241C515250E8F1B421BB83F8000F84B30200008B4C24188B5424146A006A005152FFD38B44241450E8CEB421BB#
mov [eax+4CB], #8B5C241CC7442420010000008B4C24105351E8B7B421BB8B54241068008000006A0052E8A6B421BB8B44241450E89CB421BB909090E9890000005333C9668B481433D2668B5006565783CFFF85D28D4C08187619558D59148BEA8B3385F67406#
mov [eax+52B], #3BF773028BFE83C3284D75EE5D33F64A85D2897854761A8B51348B790C2BD789510833D2668B500683C128464A3BF272E68B5424148B59148B71082BD38951108B490C85F6740E03CE5F8948505EB8010000005BC3#
mov [eax+580], #03CA5F8948505EB8010000005BC38B25AAAAAAAA68008000006A00FF35AAAAAAAAE8F3B321BB68008000006A00FF35AAAAAAAAE8E1B321BB8B25AAAAAAAAA1AAAAAAAA8B0DAAAAAAAA8B15AAAAAAAA8B1DAAAAAAAA8B2DAAAAAAAA8B35AAAAAAAA8B3DAAAAAAAA909090#
mov [eax+5EA], #568B742408A1AAAAAAAA50E89FB321BB8B0DAAAAAAAA8B15AAAAAAAA6A006A005152E888B321BBA1AAAAAAAA50E87DB321BB8B0DAAAAAAAA51E871B321BB5EC3568B74240856E864B321BB8A4C30FF8D4430FF80F9005E7409#
mov [eax+643], #8A48FF4880F90075F740C3E89A00000085C00F8505000000E9040100005657E8C00000008BF033FFC7464CE00000E0897E30A1AAAAAAAA8B08894E288B500466897E4A89562C66897E48897E448B46148B56108B0DAAAAAAAA03C28B513C5052E898000000#
mov [eax+6A8], #89463C897E40897E388B460883C4083BC774088B4E0C03C851EB098B560C8B461003D0526800100000E86A000000894634A1AAAAAAAA83C40866FF4006B8010000005F5EC3#
mov [eax+6ED], #8B0DAAAAAAAA33C033D2668B4106668B51148D04808D04C28B15AAAAAAAA8B523C8D4410408B51543BD01BC040C38B44240450E874B221BB59C38B0DAAAAAAAA33C0668B41068D1480A1AAAAAAAA8D44D0D8C3#
mov [eax+740], #568B742408578B7C24105657E848B221BB83C40885D27407405F0FAFC65EC38BC75F5EC39090#
mov [eax+02], ecx+216
mov [eax+07], ecx+20E
mov [eax+0C], ecx+008
mov [eax+11], ecx+1E6
mov [eax+18], ecx+1DE
mov [eax+1D], ecx+1BE
mov [eax+23], ecx+1C2
mov [eax+29], ecx+1C6
mov [eax+2F], ecx+1CA
mov [eax+35], ecx+1CE
mov [eax+3B], ecx+1D2
mov [eax+41], ecx+1D6
mov [eax+47], ecx+1DE
eval "call {VirtualAlloc}"
asm eax+59, $RESULT
mov [eax+68], ecx+1DA
eval "call {VirtualAlloc}"
asm eax+89, $RESULT
mov [eax+98], ecx+20A
// mov [eax+9F], ecx+037
mov [eax+9F], NAME_FILE
eval "call {GetModuleHandleA}"
asm eax+0A3, $RESULT
mov [eax+0B8], ecx+20A
eval "call {GetModuleFileNameA}"
asm eax+0BD, $RESULT
mov [eax+0CD], ecx+20A
mov [eax+114], ecx+20A
eval "call {GetCommandLineA}"
asm eax+11C, $RESULT
mov [eax+131], ecx+21E
mov [eax+139], ecx+20A
mov [eax+141], ecx+21E
mov [eax+155], ecx+20A
eval "call {CreateFileA}"
asm eax+180, $RESULT
mov [eax+188], ecx+206
eval "call {GetFileSize}"
asm eax+199, $RESULT
mov [eax+1B3], ecx+1F2
eval "call {CreateFileMappingA}"
asm eax+1BD, $RESULT
eval "call {MapViewOfFile}"
asm eax+1D9, $RESULT
mov [eax+1E9], CloseHandle
mov [eax+1FC], ecx+1FA
mov [eax+208], ecx+1FE
mov [eax+262], ecx+202
mov [eax+278], ecx+059
eval "call {CreateFileA}"
asm eax+282, $RESULT
mov [eax+294], GetFileSize
eval "call {malloc}"
asm eax+2A9, $RESULT
mov [eax+2AF], ecx+1EA
eval "call {ReadFile}"
asm eax+2BF, $RESULT
mov [eax+2DC], ecx+1FE
mov [eax+2EC], ecx+206
eval "call {SetFilePointer}"
asm eax+2F6, $RESULT
mov [eax+2FC], ecx+206
eval "call {WriteFile}"
asm eax+30A, $RESULT
mov [eax+33A], ecx+1E6
eval "call {lstrcpynA}"
asm eax+352, $RESULT
mov [eax+371], ecx+206
mov [eax+379], ecx+20A
mov [eax+37E], ecx+1F6
mov [eax+389], ecx+20A
eval "call {CreateFileA}"
asm eax+3A0, $RESULT
eval "call {GetFileSize}"
asm eax+3BA, $RESULT
eval "call {VirtualAlloc}"
asm eax+3DC, $RESULT
eval "call {VirtualLock}"
asm eax+3F4, $RESULT
eval "call {ReadFile}"
asm eax+40B, $RESULT
mov [eax+423], ecx+1FE
mov [eax+434], ecx+1FE
mov [eax+45B], ecx
mov [eax+464], ecx
mov [eax+480], SetFilePointer
eval "call {WriteFile}"
asm eax+4A3, $RESULT
eval "call {SetEndOfFile}"
asm eax+4C6, $RESULT
eval "call {VirtualUnlock}"
asm eax+4DD, $RESULT
eval "call {VirtualFree}"
asm eax+4EE, $RESULT
eval "call {CloseHandle}"
asm eax+4F8, $RESULT
mov [eax+590], ecx+1DE
mov [eax+59D], ecx+1DA
eval "call {VirtualFree}"
asm eax+5A1, $RESULT
mov [eax+5AF], ecx+20A
eval "call {VirtualFree}"
asm eax+5B3, $RESULT
mov [eax+5BA], ecx+1DE
mov [eax+5BF], ecx+1BE
mov [eax+5C5], ecx+1C2
mov [eax+5CB], ecx+1C6
mov [eax+5D1], ecx+1CA
mov [eax+5D7], ecx+1CE
mov [eax+5DD], ecx+1D2
mov [eax+5E3], ecx+1D6
mov [eax+5F0], ecx+1FA
eval "call {UnmapViewOfFile}"
asm eax+5F5, $RESULT
mov [eax+5FC], ecx+1F6
mov [eax+602], ecx+206
eval "call {SetFilePointer}"
asm eax+60C, $RESULT
mov [eax+612], ecx+206
eval "call {SetEndOfFile}"
asm eax+617, $RESULT
mov [eax+61E], ecx+206
eval "call {CloseHandle}"
asm eax+623, $RESULT
eval "call {lstrlenA}"
asm eax+630, $RESULT
mov [eax+676], ecx+20E
mov [eax+698], ecx+1FE
mov [eax+6DA], ecx+1FE
mov [eax+6EF], ecx+1FE
mov [eax+707], ecx+1FA
eval "call {free}"
asm eax+720, $RESULT
mov [eax+729], ecx+1FE
mov [eax+737], ecx+202
eval "call {ldiv}"
asm eax+74C, $RESULT
bp eax+5E7
bp eax+764
bp PATCH_CODESEC+4A9 // SecHandle
popa
esto
cmp eip, PATCH_CODESEC+4A9
jne NO_HANDLES
bc eip
mov SECHANDLE, eax
esto
////////////////////
NO_HANDLES:
bc
cmp eip, PATCH_CODESEC+809
je SECTION_ADDED_OK
cmp eip, PATCH_CODESEC+886
je NO_SECTION_ADDED
pause
pause
cret
ret
////////////////////
NO_SECTION_ADDED:
msg "Can't add the dumped section to file! \r\n\r\nDo it manually later! \r\n\r\nLCF-AT"
pause
pause
cret
ret
////////////////////
SECTION_ADDED_OK:
fill PATCH_CODESEC, 100, 00
mov [PATCH_CODESEC], filelc
pusha
mov edi, PATCH_CODESEC
mov esi, SECHANDLE
exec
push esi
call {CloseHandle}
push edi
call {DeleteFileA}
ende
popa
msg "Section was successfully added to dumped file! \r\n\r\nPE Rebuild was successfully! \r\n\r\nLCF-AT"
log "Section was successfully added to dumped file!"
log "PE Rebuild was successfully!"
mov eip, BAK_EIP
free PATCH_CODESEC
ret
////////////////////
FIXER:
call LOAD_ARI_DLL
jmp DO_REBUILD
////////////////////
LOAD_ARI_DLL:
pusha
alloc 1000
mov TRY_NAMES, $RESULT
mov eax, TRY_NAMES
mov [TRY_NAMES], ARIMPREC_PATH
mov ecx, LoadLibraryA
log ""
log eax
log ecx
exec
push eax
call ecx
ende
log eax
cmp eax, 00
jne DLL_LOAD_SUCCESS
log ""
log "Can't load the ARImpRec.dll!"
msg "Can't load the ARImpRec.dll!"
pause
pause
cret
ret
////////////////////
DLL_LOAD_SUCCESS:
refresh eax
mov [eax+1EA7D], #496174466978#
fill TRY_NAMES, 1000, 00
mov [TRY_NAMES], "SearchAndRebuildImports@28"
mov ecx, TRY_NAMES
mov edi, GetProcAddress
log ""
log ecx
log eax
log edi
exec
push ecx
push eax
call edi
ende
log eax
cmp eax, 00
jne TRY_API_SUCCESS
log ""
log "Can't get the SearchAndRebuildImports API!"
msg "Can't get the SearchAndRebuildImports API!"
pause
pause
cret
ret
////////////////////
TRY_API_SUCCESS:
mov SearchAndRebuildImports, eax
fill TRY_NAMES, 1000, 00
free TRY_NAMES
popa
ret
////////////////////
DO_REBUILD:
alloc 2000
mov PATCH_CODESEC, $RESULT
mov BAK_EIP, eip
mov [PATCH_CODESEC], PATCH_CODESEC+1800
mov [PATCH_CODESEC+04], IATSIZE
mov [PATCH_CODESEC+08], IATRVA
mov [PATCH_CODESEC+0C], PATCH_CODESEC+1500 // Dumpname
mov [PATCH_CODESEC+1500], EXEFILENAME
pusha
mov eax, PATCH_CODESEC+1500
add eax, EXEFILENAME_LEN
mov ecx, EXEFILENAME_LEN
xor ebx, ebx
////////////////////
DOT_LOOP:
cmp ecx, 00
jne DOT_LOOP_GO
msg "Can't find the dot in filename! \r\n\r\nLCF-AT"
log "Can't find the dot in filename!"
pause
pause
cret
ret
////////////////////
DOT_LOOP_GO:
cmp [eax], 2E, 01
je DOT
dec ecx
dec eax
inc ebx
jmp DOT_LOOP
////////////////////
DOT:
len [eax]
mov edx, $RESULT
gstr eax
mov DOT_END, $RESULT
mov [eax], "_DP"
add eax, 03
mov [eax], DOT_END
popa
pusha
exec
call {GetCurrentProcessId}
ende
mov PID, eax
popa
mov [PATCH_CODESEC+10], PID
mov [PATCH_CODESEC+14], SearchAndRebuildImports
mov [PATCH_CODESEC+100], #606800000000680000000068000000006A0068000000006800000000FF3500000000FF1500000000906190#
mov [PATCH_CODESEC+102], PATCH_CODESEC+1800 // PATCH_CODESEC
mov [PATCH_CODESEC+107], PATCH_CODESEC+04
mov [PATCH_CODESEC+10C], PATCH_CODESEC+08
mov [PATCH_CODESEC+113], BAK_EIP
mov [PATCH_CODESEC+118], [PATCH_CODESEC+0C]
mov [PATCH_CODESEC+11E], PATCH_CODESEC+10
mov [PATCH_CODESEC+124], PATCH_CODESEC+14
mov eip, PATCH_CODESEC+100
bp PATCH_CODESEC+128
bp PATCH_CODESEC+12A
esto
bc eip
cmp eax, 0
je REBUILD_GOOD
pusha
alloc 1000
mov edi, $RESULT
mov [edi], "Warning!"
mov esi, PATCH_CODESEC+1800
exec
push 30
push edi
push esi
push 0
call {MessageBoxA}
ende
free edi
popa
pause
pause
cret
ret
////////////////////
REBUILD_GOOD:
run
bc eip
mov eip, BAK_EIP
pusha
mov edi, PATCH_CODESEC+1500
exec
push edi
call {DeleteFileA}
ende
cmp eax, 01
jne DELETE_FAILED
len [edi]
mov esi, $RESULT
add esi, edi
inc esi
mov [esi], EXEFILENAME
mov eax, esi
len [eax]
add eax, $RESULT
////////////////////
DOT_LOOP_GO_2:
cmp [eax], 2E, 01
je DOT_2
dec eax
jmp DOT_LOOP_GO_2
////////////////////
DOT_2:
mov [eax], "_DP_"
add eax, 04
mov [eax], DOT_END
exec
push edi
push esi
call {MoveFileA}
ende
////////////////////
DELETE_FAILED:
popa
free PATCH_CODESEC
msg "IAT was rebuild into dumped file! \r\n\r\nLCF-AT"
log "IAT was rebuild into dumped file!"
ret