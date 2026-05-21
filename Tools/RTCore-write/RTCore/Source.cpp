#include "Native.h"
#include "RTCore.h"
#include <iostream>
#include <map>


#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <cinttypes>
#include <fstream>
#include <vector>

int main_test(CRTCore* rtcore, uintptr_t address, const char* filePath)
{
    // Open the file in binary mode
    std::ifstream inFile(filePath, std::ios::binary | std::ios::ate);
    if (!inFile)
    {
        printf("Failed to open file: %s\n", filePath);
        return 1;
    }

    // Get the file size
    std::streamsize length = inFile.tellg();
    inFile.seekg(0, std::ios::beg);

    if (length <= 0)
    {
        printf("File is empty or error reading size\n");
        return 1;
    }

    // Read file contents into buffer
    std::vector<BYTE> buffer(length);
    if (!inFile.read(reinterpret_cast<char*>(buffer.data()), length))
    {
        printf("Failed to read file contents\n");
        return 1;
    }

    if (!rtcore->Load())
    {
        printf("Failed DriverLoad\n");
        return 1;
    }

    // Write buffer to physical memory
    if (rtcore->WritePhysical((PVOID)address, buffer.data(), static_cast<size_t>(length)))
    {
        printf("Successfully wrote %lld bytes to 0x%" PRIXPTR "\n", length, address);
    }
    else
    {
        printf("WritePhysical failed!\n");
    }

    rtcore->Unload();
    system("pause");
    return 0;
}

int main(int argc, char* argv[])
{
    SetConsoleTitleW(L"RTCore Write Test");

    if (argc != 3)
    {
        printf("Usage: %s <address in hex> <file path>\n", argv[0]);
        return 1;
    }

    // Convert address argument from hex string
    uintptr_t address = strtoull(argv[1], nullptr, 16);

    CRTCore rtcore;
    return main_test(&rtcore, address, argv[2]);
}
