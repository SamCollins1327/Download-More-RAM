#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>

#define CHUNK_SIZE (64 * 1024 * 1024) // 64 MB per chunk

typedef struct {
    uint8_t *data;
    size_t size;
    uint32_t xor_value;
    volatile LONG *active_workers;
    HANDLE done_event;
} WorkerArgs;

DWORD WINAPI xor_worker(LPVOID arg) {
    WorkerArgs *args = (WorkerArgs *)arg;
    uint32_t *p = (uint32_t *)args->data;
    size_t words = args->size / sizeof(uint32_t);
    for (size_t i = 0; i < words; i++)
        p[i] ^= args->xor_value;

    if (InterlockedDecrement(args->active_workers) == 0)
        SetEvent(args->done_event);
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "Usage: %s <input_file> <output_file>\n", argv[0]);
        return 1;
    }

    const char *input_file = argv[1];
    const char *output_file = argv[2];

    FILE *infile = fopen(input_file, "rb");
    FILE *outfile = fopen(output_file, "wb");
    if (!infile || !outfile) {
        perror("File error");
        return 1;
    }

    // ✅ 64-bit stat for large files
    struct __stat64 st;
    if (_stat64(input_file, &st) != 0) {
        perror("stat failed");
        fclose(infile);
        fclose(outfile);
        return 1;
    }
    unsigned long long total_size = st.st_size;
    unsigned long long processed = 0;

    // ✅ Auto-detect CPU cores
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    int num_threads = (int)sysinfo.dwNumberOfProcessors;
    if (num_threads < 1) num_threads = 1;
    if (num_threads > 32) num_threads = 32; // sanity cap

    fprintf(stderr, "Using %d threads\n", num_threads);

    uint8_t *buffer = malloc(CHUNK_SIZE);
    if (!buffer) {
        fprintf(stderr, "Memory allocation failed\n");
        fclose(infile);
        fclose(outfile);
        return 1;
    }

    const uint32_t xor_value = 0xE39F243C;

    HANDLE done_event = CreateEvent(NULL, TRUE, FALSE, NULL);
    WorkerArgs *args = malloc(sizeof(WorkerArgs) * num_threads);

    while (!feof(infile)) {
        size_t bytes_read = fread(buffer, 1, CHUNK_SIZE, infile);
        if (bytes_read == 0)
            break;

        // Split work across threads
        size_t chunk_per_thread = bytes_read / num_threads;
        volatile LONG active = num_threads;

        ResetEvent(done_event);

        for (int i = 0; i < num_threads; i++) {
            args[i].data = buffer + (i * chunk_per_thread);
            args[i].size = (i == num_threads - 1)
                               ? (bytes_read - i * chunk_per_thread)
                               : chunk_per_thread;
            args[i].xor_value = xor_value;
            args[i].active_workers = &active;
            args[i].done_event = done_event;
            CloseHandle(CreateThread(NULL, 0, xor_worker, &args[i], 0, NULL));
        }

        // ✅ Live progress display while threads work
        while (WaitForSingleObject(done_event, 100) == WAIT_TIMEOUT) {
            double progress = ((double)processed / (double)total_size) * 100.0;
            if (progress > 100.0) progress = 100.0;
            fprintf(stderr, "\rProgress: %.2f%%", progress);
            fflush(stderr);
        }

        WaitForSingleObject(done_event, INFINITE);

        fwrite(buffer, 1, bytes_read, outfile);
        processed += bytes_read;

        double progress = ((double)processed / (double)total_size) * 100.0;
        if (progress > 100.0) progress = 100.0;
        fprintf(stderr, "\rProgress: %.2f%%", progress);
        fflush(stderr);
    }

    fprintf(stderr, "\nDecoding complete. Output saved to %s\n", output_file);

    free(buffer);
    free(args);
    CloseHandle(done_event);
    fclose(infile);
    fclose(outfile);
    return 0;
}