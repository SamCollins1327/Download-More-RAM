#include <windows.h>
#include <stdio.h>

// This app was devleoped using IDA reverse engineering of the msio driver 
// along with IOCTL traces from thaiphoon burner as ground truth, along 
// with the relevant specifications from JEDEC 
// see https://www.jedec.org/standards-documents/docs/spd412l-3
// and https://www.jedec.org/sites/default/files/docs/4_01_06R22.pdf

#define IOCTL_READ_PORT  0x80102050 // grabbed IOCTL codes from msio driver reversed in IDA pro
#define IOCTL_WRITE_PORT 0x80102054

#define SMBBASE     0x0B00 // reversed port addresses for asus ROG STRIX B450-F Gaming mobo - milage may vary
#define SMBHSTSTS   (SMBBASE + 0x00)
#define SMBHSTCNT   (SMBBASE + 0x02)
#define SMBHSTCMD   (SMBBASE + 0x03)
#define SMBHSTADD   (SMBBASE + 0x04)
#define SMBHSTDAT0  (SMBBASE + 0x05)

typedef struct {
    USHORT Port;
    BYTE   Value;
    BYTE   useless;
    USHORT useless2;
    BYTE   DataSize_maybe;
} IO_STRUCTURE;

// get full path to driver file 
BOOL GetDriverPath(wchar_t* pathOut, DWORD maxLen) {
    wchar_t exePath[MAX_PATH];
    if (!GetModuleFileNameW(NULL, exePath, MAX_PATH)) {
        printf("  [-] Failed to get executable path\n");
        return FALSE;
    }

    wchar_t* lastSlash = wcsrchr(exePath, L'\\');
    if (!lastSlash) {
        printf("  [-] Could not parse executable path\n");
        return FALSE;
    }
    *(lastSlash + 1) = L'\0';

    swprintf_s(pathOut, maxLen, L"%s%s", exePath, L"MsIo64.sys");
    return TRUE;
}

// checks if msio driver is already running 
BOOL IsDriverLoaded() {
    HANDLE h = CreateFileW(L"\\\\.\\MsIo",
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, NULL);

    if (h != INVALID_HANDLE_VALUE) {
        CloseHandle(h);
        return TRUE;
    }
    return FALSE;
}

// loads driver (in the case it isn't already)
BOOL LoadDriver(wchar_t* driverPath) {
    SC_HANDLE hSCM = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!hSCM) {
        printf("  [-] Failed to open SCM (error %lu) — run as Administrator\n",
            GetLastError());
        return FALSE;
    }

    SC_HANDLE hSvc = OpenServiceW(hSCM, L"MsIo", SERVICE_ALL_ACCESS);

    if (!hSvc) { // if the service doesn't exist yet
        printf("  [*] Creating driver service...\n");
        hSvc = CreateServiceW(
            hSCM,
            L"MsIo",                  
            L"MsIo",                  
            SERVICE_ALL_ACCESS,
            SERVICE_KERNEL_DRIVER,
            SERVICE_DEMAND_START,
            SERVICE_ERROR_NORMAL,
            driverPath,                   // full path to .sys
            NULL, NULL, NULL, NULL, NULL
        );

        if (!hSvc) {
            printf("  [-] Failed to create service (error %lu)\n", GetLastError());
            CloseServiceHandle(hSCM);
            return FALSE;
        }
    }

    printf("  [*] Starting driver service...\n");
    if (!StartServiceW(hSvc, 0, NULL)) {
        DWORD err = GetLastError();
        if (err == ERROR_SERVICE_ALREADY_RUNNING) {
            printf("  [+] Driver already running\n");
            CloseServiceHandle(hSvc);
            CloseServiceHandle(hSCM);
            return TRUE;
        }
        printf("  [-] Failed to start service (error %lu)\n", err);
        CloseServiceHandle(hSvc);
        CloseServiceHandle(hSCM);
        return FALSE;
    }

    printf("  [+] Driver loaded successfully\n");
    CloseServiceHandle(hSvc);
    CloseServiceHandle(hSCM);
    return TRUE;
}

// unloads the driver :P 
BOOL UnloadDriver() {
    SC_HANDLE hSCM = OpenSCManagerW(NULL, NULL, SC_MANAGER_ALL_ACCESS);
    if (!hSCM) return FALSE;

    SC_HANDLE hSvc = OpenServiceW(hSCM, L"MsIo", SERVICE_ALL_ACCESS);
    if (!hSvc) {
        CloseServiceHandle(hSCM);
        return FALSE;
    }

    SERVICE_STATUS status;
    ControlService(hSvc, SERVICE_CONTROL_STOP, &status);
    DeleteService(hSvc);

    CloseServiceHandle(hSvc);
    CloseServiceHandle(hSCM);
    printf("  [+] Driver unloaded\n");
    return TRUE;
}

// write to io port 
BOOL WritePort(HANDLE hDriver, USHORT port, BYTE value) {
    IO_STRUCTURE inputBuffer = { port, value, 0, 0, 1 };
    DWORD returned;
    return DeviceIoControl(hDriver, IOCTL_WRITE_PORT,
        &inputBuffer, sizeof(inputBuffer),
        NULL, 0,
        &returned, NULL);
}

// read from io port (write with an output buffer)
BOOL ReadPort(HANDLE hDriver, USHORT port, BYTE* result) {
    IO_STRUCTURE inputBuffer = { port, 0x35, 0x01, 0, 1 };
    DWORD outBuffer = 0;
    DWORD returned;
    BOOL ok = DeviceIoControl(hDriver, IOCTL_READ_PORT,
        &inputBuffer, sizeof(inputBuffer),
        &outBuffer, sizeof(outBuffer),
        &returned, NULL);
    if (ok) *result = (BYTE)(outBuffer & 0xFF); // clips the 4 byte output buffer
    return ok;
}

// io ops aren't instant, this waits until the SPD gives a "yep im done signal"
BOOL WaitSMBusComplete(HANDLE hDriver) {
    BYTE status;
    int timeout = 100;
    while (timeout--) {
        if (!ReadPort(hDriver, SMBHSTSTS, &status))
            return FALSE;

        // errors :( 
        if (status & 0x04) { printf("  [-] SMBus DEV_ERR\n");  return FALSE; }
        if (status & 0x08) { printf("  [-] SMBus BUS_ERR\n");  return FALSE; }
        if (status & 0x10) { printf("  [-] SMBus FAILED\n");   return FALSE; }

        if (status & 0x02) // transaction complete
            return TRUE;

        WritePort(hDriver, SMBHSTSTS, 0x02);
        Sleep(1);
    }

    printf("  [-] SMBus timed out, last status = 0x%02X\n", status);
    return FALSE;
}

// the SPD is 512 bytes long, so we acces over 2 pages=
BOOL SwapPage(HANDLE hDriver, BOOL page1) {
    BYTE addr = page1 ? 0x6E : 0x6C;

    WritePort(hDriver, SMBHSTSTS, 0x1E);   // clear status
    WritePort(hDriver, SMBHSTADD, addr);   // set page device address
    WritePort(hDriver, SMBHSTCNT, 0x44);   // send byte command — no data needed

    if (!WaitSMBusComplete(hDriver)) {
        printf("  [!] Page swap failed\n");
        return FALSE;
    }

    printf("  [+] Switched to page %d\n", page1 ? 1 : 0);
    return TRUE;
}

// funciton to read a single byte
BOOL ReadSPDByte(HANDLE hDriver, BYTE slot, BYTE offset, BYTE* result) {
    BYTE addr = ((0x50 | slot) << 1) | 0x01;  // last bit is read/write 

    // 0B03 for setting byte to write to 
    WritePort(hDriver, SMBHSTCMD, offset);
    // status set
    WritePort(hDriver, SMBHSTSTS, 0x1E);
    // DIMM slot/write direction set
    WritePort(hDriver, SMBHSTADD, addr);
    // fire transaction
    WritePort(hDriver, SMBHSTCNT, 0x48);

    // wait for 0x02 from status 
    if (!WaitSMBusComplete(hDriver))
        return FALSE;

    // read result 
    if (!ReadPort(hDriver, SMBHSTDAT0, result))
        return FALSE;

    return TRUE;
}

// funciton to write a single byte 
BOOL WriteSPDByte(HANDLE hDriver, BYTE slot, BYTE offset, BYTE data) {
    BYTE addr = ((0x50 | slot) << 1) | 0x00;  // write bit clear

    WritePort(hDriver, SMBHSTCMD, offset);
    WritePort(hDriver, SMBHSTSTS, 0x1E);
    // write to data port (0B05) other sets are as above 
    WritePort(hDriver, SMBHSTDAT0, data);
    WritePort(hDriver, SMBHSTADD, addr);
    WritePort(hDriver, SMBHSTCNT, 0x48);

    if (!WaitSMBusComplete(hDriver))
        return FALSE;

    return TRUE;
}

// dumps the current spd page (half the full spd)
void DumpSPD(HANDLE hDriver, BYTE slot) {
    BYTE spd[256] = { 0 };

    printf("\n  [+] Dumping 256 bytes SPD from slot %d...\n", slot);

    for (int offset = 0; offset < 256; offset++) {
        if (!ReadSPDByte(hDriver, slot, (BYTE)offset, &spd[offset])) {
            printf("  [-] Read failed at offset 0x%02X\n", offset);
            return;
        }
    }

    // print in pretty format :) 
    printf("\n  [+] SPD Dump (slot %d):\n\n", slot);
    printf("         00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F\n");
    printf("         -----------------------------------------------\n");
    for (int row = 0; row < 16; row++) {
        printf("  0x%02X | ", row * 16);
        for (int col = 0; col < 16; col++) {
            printf("%02X ", spd[row * 16 + col]);
        }
        printf("\n");
    }
    printf("\n");
}

// checks if dimm is write protected by writing then reading some values across two blocks 
void CheckWriteProtection(HANDLE hDriver, BYTE slot) {
    printf("\n  [+] Write Protection Test (slot %d) \n\n", slot);
    printf("  [+] EXPLAINATION: This will briefly write 0xEE to bytes 0x70 and 0xA0\n");
    printf("      and restore them. BACKUP SPD FIRST!!!\n\n");
    printf("  [*] Press Enter to continue or Ctrl+C to abort...");
    getchar(); 
    printf("\n");

    printf("  [+] Testing byte 0x70 (first 128 bytes protection)...\n");

    // realistically these should be 0x00 on any normal spd 
    BYTE original_70 = 0;
    BYTE readback = 0;

    // read 
    if (!ReadSPDByte(hDriver, slot, 0x70, &original_70)) {
        printf("  [-] Failed to read byte 0x70\n");
        return;
    }
    printf("  [+] Original value at 0x70 = 0x%02X\n", original_70);

    // write 0xEE
    printf("  [+] Writing 0xEE to 0x70...\n");
    if (!WriteSPDByte(hDriver, slot, 0x70, 0xEE)) {
        printf("  [-] Write to 0x70 failed — may be write protected\n");
        goto test_a0;
    }

    // check
    Sleep(10);
    if (!ReadSPDByte(hDriver, slot, 0x70, &readback)) {
        printf("  [-] Readback of 0x70 failed\n");
        goto restore_70;
    }

    if (readback == 0xEE) {
        printf("  [+] Byte 0x70 verified = 0xEE — NOT write protected\n");
    }
    else {
        printf("  [-] Byte 0x70 readback = 0x%02X (expected 0xEE) — SPD LIKELY WRITE PROTECTED\n", readback);
    }

restore_70:
    // restore original value
    printf("  [+] Restoring 0x70 to 0x%02X...\n", original_70);
    if (!WriteSPDByte(hDriver, slot, 0x70, original_70)) {
        printf("  [-] Failed to restore byte 0x70 — check manually!\n");
    }
    else {
        Sleep(10);
        ReadSPDByte(hDriver, slot, 0x70, &readback);
        if (readback == original_70)
            printf("  [+] Byte 0x70 restored successfully\n\n");
        else
            printf("  [-] Restore verify failed, 0x70 = 0x%02X\n\n", readback);
    }

test_a0:
    printf("  [+] Testing byte 0xA0 (second 256 bytes protection)...\n");

    BYTE original_a0 = 0;

    // read
    if (!ReadSPDByte(hDriver, slot, 0xA0, &original_a0)) {
        printf("  [-] Failed to read byte 0xA0\n");
        return;
    }
    printf("  [+] Original value at 0xA0 = 0x%02X\n", original_a0);

    // write 0xEE
    printf("  [+] Writing 0xEE to 0xA0...\n");
    if (!WriteSPDByte(hDriver, slot, 0xA0, 0xEE)) {
        printf("  [-] Write to 0xA0 failed — may be write protected\n");
        return;
    }

    // check
    Sleep(10);
    if (!ReadSPDByte(hDriver, slot, 0xA0, &readback)) {
        printf("  [-] Readback of 0xA0 failed\n");
        goto restore_a0;
    }

    if (readback == 0xEE) {
        printf("  [+] Byte 0xA0 verified = 0xEE — NOT write protected\n");
    }
    else {
        printf("  [-] Byte 0xA0 readback = 0x%02X (expected 0xEE) — WRITE PROTECTED\n", readback);
    }

restore_a0:
    // restore original value
    printf("  [+] Restoring 0xA0 to 0x%02X...\n", original_a0);
    if (!WriteSPDByte(hDriver, slot, 0xA0, original_a0)) {
        printf("  [-] Failed to restore byte 0xA0 — check manually!\n");
    }
    else {
        Sleep(10);
        ReadSPDByte(hDriver, slot, 0xA0, &readback);
        if (readback == original_a0)
            printf("  [+] Byte 0xA0 restored successfully\n\n");
        else
            printf("  [-] Restore verify failed, 0xA0 = 0x%02X\n\n", readback);
    }

    printf("  === Write protection test complete ===\n\n");
}

// aliases/un-aliases target dimm by incrementing/decrementing density and row addressing 
void aliasDIMM(HANDLE hDriver, BYTE slot, BOOL sign) {
    BYTE densityByte = 0x00;
    BYTE addressingByte = 0x00;

    printf("  [+] Reading addressing informaiton from DIMM\n");

    if (!ReadSPDByte(hDriver, slot, 0x04, &densityByte)) {
        printf("  [+] Read failed\n");
        return;
    }
    if (!ReadSPDByte(hDriver, slot, 0x05, &addressingByte)) {
        printf("  [+] Read failed\n");
        return;
    }

    printf("  [+] SPD byte: 0x04 = 0x%02X, 0x05 = 0x%02X\n\n", densityByte, addressingByte);

    // grabbed bitmaps from SPD spec 
    const char* density = "Unknown";
    switch (densityByte & 0x0F) { // bits 3-0 are density 
    case 0x03: density = "2 Gb";  break;
    case 0x04: density = "4 Gb";  break;
    case 0x05: density = "8 Gb";  break;
    case 0x06: density = "16 Gb"; break;
    case 0x07: density = "32 Gb"; break;
    }
    
    int row_bits = 0;
    switch ((addressingByte >> 3) & 0x07) { //  bits 5-3 are row address bits
    case 0x00: row_bits = 12; break;
    case 0x01: row_bits = 13; break;
    case 0x02: row_bits = 14; break;
    case 0x03: row_bits = 15; break;
    case 0x04: row_bits = 16; break;
    case 0x05: row_bits = 17; break;
    case 0x06: row_bits = 18; break;
    }

    int col_bits = 0; //  bits 2-0 are column address bits
    switch (addressingByte & 0x07) {
    case 0x00: col_bits = 9; break;
    case 0x01: col_bits = 10; break;
    case 0x02: col_bits = 11; break;
    case 0x03: col_bits = 12; break;
    }

    printf("      [+] Density    : %s\n", density);
    printf("      [+] Row addressing bits    : %d\n", row_bits);
    printf("      [+] Column addressing bits    : %d\n", col_bits);
    printf("\n");

    BYTE newDensityByte = 0x00;
    BYTE newAddressingByte = 0x00;

    if (sign) // if we are aliasing the dimm we increment density and row addressing 
    {
        newDensityByte = ((densityByte & 0x0F) + 0x01) + (densityByte & 0xF0);
        newAddressingByte = ((((addressingByte >> 3) & 0x07) + 0x01) << 3) + (addressingByte & 0xC7);
    }
    else // otherwise we decrment it 
    {
        newDensityByte = ((densityByte & 0x0F) - 0x01) + (densityByte & 0xF0);
        newAddressingByte = ((((addressingByte >> 3) & 0x07) - 0x01) << 3) + (addressingByte & 0xC7);
    }
    
    printf("  [+] Proposed new byte 0x04 = 0x%02X, 0x05 = 0x%02X\n", newDensityByte, newAddressingByte);

    // yes I'm too lazy to put the switch in a funcion 

    switch (newDensityByte & 0x0F) { // bits 3-0 are density 
    case 0x03: density = "2 Gb";  break;
    case 0x04: density = "4 Gb";  break;
    case 0x05: density = "8 Gb";  break;
    case 0x06: density = "16 Gb"; break;
    case 0x07: density = "32 Gb"; break;
    }

    switch ((newAddressingByte >> 3) & 0x07) { //  bits 5-3 are row address bits
    case 0x00: row_bits = 12; break;
    case 0x01: row_bits = 13; break;
    case 0x02: row_bits = 14; break;
    case 0x03: row_bits = 15; break;
    case 0x04: row_bits = 16; break;
    case 0x05: row_bits = 17; break;
    case 0x06: row_bits = 18; break;
    }

    switch (newAddressingByte & 0x07) {
    case 0x00: col_bits = 9; break;
    case 0x01: col_bits = 10; break;
    case 0x02: col_bits = 11; break;
    case 0x03: col_bits = 12; break;
    }

    printf("      [+] Proposed Density    : %s\n", density);
    printf("      [+] Proposed Row addressing bits    : %d\n", row_bits);
    printf("      [+] Proposed Column addressing bits    : %d\n", col_bits);
    printf("\n");

    printf("  [*] Press Enter to continue or Ctrl+C to abort...");
    getchar();
    printf("\n");

    printf("  [+] Writing 0x%02X to 0x04...\n", newDensityByte);
    if (!WriteSPDByte(hDriver, slot, 0x04, newDensityByte)) {
        printf("  [-] Write to 0x04 failed — may be write protected\n");
        return;
    }

    printf("  [+] Writing 0x%02X to 0x05...\n", newAddressingByte);
    if (!WriteSPDByte(hDriver, slot, 0x05, newAddressingByte)) {
        printf("  [-] Write to 0x05 failed — may be write protected\n");
        return;
    }
    
    // in order fo rthe bios to recognise the new dimm we need to change some identifiers, otherwise 
    // it will used chaced spd info and not notice the new addressing. We spray change various identifiers 
    // including the serial number, all of which are on the second page (bytes 0x140 -> 0x15c) 

    SwapPage(hDriver, TRUE);

    for (BYTE offset = 0x40; offset <= 0x5C; offset++) {
        BYTE original = 0;
        BYTE readback = 0;

        // Read original
        if (!ReadSPDByte(hDriver, slot, offset, &original)) {
            printf("  [-] Failed to read byte 0x1%02X\n", offset);
            continue;
        }

        BYTE newVal = original + 0x01;

        // Write incremented value
        if (!WriteSPDByte(hDriver, slot, offset, newVal)) {
            printf("  [-] Failed to write byte 0x1%02X — may be write protected\n", offset);
            continue;
        }

        // Verify
        Sleep(10);
        if (!ReadSPDByte(hDriver, slot, offset, &readback)) {
            printf("  [-] Failed to read back byte 0x1%02X\n", offset);
            continue;
        }

        if (readback == newVal) {
            printf("  [+] Byte 0x1%02X: 0x%02X -> 0x%02X OK\n", offset, original, readback);
        }
        else {
            printf("  [!] Byte 0x1%02X: wrote 0x%02X but read back 0x%02X\n", offset, newVal, readback);
        }
    }

    SwapPage(hDriver, FALSE);


    if (sign) printf("  === Aliasing complete... good luck! ===\n\n");
    else printf("  === Un-aliasing complete... good luck! ===\n\n");
}




int main() {
    printf("============================================\n");
    printf("         Download More RAM SPD Tool\n");
    printf("============================================\n\n");

    printf("  [*] Warning! Developed and tested on ROG STRIX B450F, Ryzen 2000 Series, and Corsair Vengence DIMM\n\n");

    // get driver path 
    wchar_t driverPath[MAX_PATH];
    if (!GetDriverPath(driverPath, MAX_PATH)) {
        return 1;
    }

    // check if driver is already loaded, load if not
    BOOL driverWasLoaded = IsDriverLoaded();
    if (driverWasLoaded) {
        printf("  [+] Driver already loaded\n");
    }
    else {
        printf("  [*] Driver not loaded, attempting to load...\n");
        if (!LoadDriver(driverPath)) {
            printf("  [-] Failed to load driver — exiting\n");
            return 1;
        }
        Sleep(500);  // give driver time to initialise
    }

    // open driver handle
    HANDLE hDriver = CreateFileW(L"\\\\.\\MsIo",
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, NULL);

    if (hDriver == INVALID_HANDLE_VALUE) {
        printf("  [-] Failed to open driver handle (error %lu)\n", GetLastError());
        if (!driverWasLoaded) UnloadDriver();
        return 1;
    }
    printf("  [+] Driver handle opened\n\n");


    int slot = 0;
    printf("  [*] Enter DIMM slot number (0-3): ");
    scanf_s("%d", &slot);
    if (slot < 0 || slot > 3) {
        printf("[-] Invalid slot number\n");
        CloseHandle(hDriver);
        return 1;
    }
    getchar();

    printf("\n  [+] Selected slot: %d (I2C address 0x%02X)\n\n",
        slot, (0x50 | slot) << 1);

    // menu
    int choice = 0;
    printf("  [*] Select operation:\n");
    printf("       1. Dump SPD (256 bytes)\n");
    printf("       2. Check write protection\n");
    printf("       3. Alais DIMM\n");
    printf("       4. Un-alais DIMM\n\n");
    printf("  [*] Choice: ");
    scanf_s("%d", &choice);
    getchar();

    switch (choice) {
    case 1:
        printf("  [+] Reading page 0 (bytes 0-255)...\n");
        // page swap sinc ethe spd is 512 bytes 
        SwapPage(hDriver, FALSE);
        DumpSPD(hDriver, (BYTE)slot);

        printf("  [+] Reading page 1 (bytes 256-511)...\n");
        SwapPage(hDriver, TRUE);
        DumpSPD(hDriver, (BYTE)slot);

        SwapPage(hDriver, FALSE);  
        break;
    case 2:
        CheckWriteProtection(hDriver, (BYTE)slot);
        break;
    case 3:
        aliasDIMM(hDriver, (BYTE)slot, 1);
        break;
    case 4:
        aliasDIMM(hDriver, (BYTE)slot, 0);
        break;
    default:
        printf("\n  [-] Bad choice\n");
        break;
    }

    CloseHandle(hDriver);
    printf("  [+] Done.\n");
    return 0;
}