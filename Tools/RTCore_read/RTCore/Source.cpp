#include "Native.h"
#include "RTCore.h"
#include <iostream>
#include <map>


std::map<ULONG, ULONG> KernelDirectoryTableBase =
{
    { 7601, 0x187000 },
    { 9200, 0x187000 },
    { 9600, 0x1A7000 },
    { 10240, 0x1AB000 },
    { 10586, 0x1AB000 },
    { 14393, 0x1AB000 },
    { 15063, 0x1AB000 },
    { 16299, 0x1AB000 },
    { 17134, 0x1AD000 },
    { 17763, 0x1AD000 },
    { 18362, 0x1AD000 },
    { 18363, 0x1AD000 },
    { 19041, 0x1AD000 },
    { 19042, 0x1AD000 },
    { 19043, 0x1AD000 },
    { 19044, 0x1AD000 },
    { 19045, 0x1AD000 },
    { 22621, 0x1AE000 },
    { 22449, 0x1AE000 },
    { 22000, 0x1AE000 }
};


int main_test(CRTCore* rtcore, uintptr_t address, size_t length)
{
    if (rtcore->Load())
    {
        printf("Yay Loaded\n");

        BYTE* myBuffer = new BYTE[length]{ 0 }; // dynamically allocate buffer
        if (rtcore->ReadPhysical((PVOID)address, myBuffer, length))
        {
            for (size_t i = 0; i < length; i++) {
                printf("%02X ", myBuffer[i]);

                // New line every 16 bytes
                if ((i + 1) % 16 == 0)
                    printf("\n");
            }
            printf("\n");
        }
        else
        {
            printf("ReadPhysical failed!\n");
        }

        delete[] myBuffer;
        rtcore->Unload();
    }
    else
    {
        printf("Failed DriverLoad\n");
    }

    system("pause");
    return 0;
}

int main(int argc, char* argv[])
{
    SetConsoleTitleW(L"RTCore Test");

    if (argc != 3)
    {
        printf("Usage: %s <address in hex> <length in decimal>\n", argv[0]);
        return 1;
    }

    // Convert command line arguments
    uintptr_t address = strtoull(argv[1], nullptr, 16); // hex address
    size_t length = strtoull(argv[2], nullptr, 10);     // decimal length

    CRTCore rtcore;
    return main_test(&rtcore, address, length);
}