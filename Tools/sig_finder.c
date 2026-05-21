#define _FILE_OFFSET_BITS 64   // Must come before any includes for large files
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#define CHUNK_SIZE (1024 * 1024ULL)
#define ONE_MB     (1024 * 1024ULL)
#define MAX_STEPS  100

unsigned char ucDataBlock[168] = {
	// Offset 0x00000008 to 0x000000AF
	0x48, 0x83, 0xEC, 0x38, 0x41, 0xB9, 0x10, 0x00, 0x00, 0x00, 0x4C, 0x8B,
	0xDA, 0x45, 0x3B, 0xC1, 0x0F, 0x82, 0x8B, 0x00, 0x00, 0x00, 0x4C, 0x8B,
	0x15, 0x4B, 0x18, 0x06, 0x00, 0x4D, 0x85, 0xD2, 0x74, 0x7F, 0x81, 0xE9,
	0x03, 0x80, 0x00, 0x00, 0x74, 0x3A, 0x83, 0xE9, 0x01, 0x74, 0x2B, 0x83,
	0xE9, 0x08, 0x74, 0x1C, 0x83, 0xE9, 0x01, 0x74, 0x0D, 0x83, 0xF9, 0x01,
	0x75, 0x63, 0x8D, 0x41, 0x5F, 0x8D, 0x51, 0x67, 0xEB, 0x26, 0xB8, 0x50,
	0x00, 0x00, 0x00, 0x8D, 0x50, 0x08, 0xEB, 0x1C, 0xB8, 0x40, 0x00, 0x00,
	0x00, 0x8D, 0x50, 0x08, 0xEB, 0x12, 0xB8, 0x30, 0x00, 0x00, 0x00, 0x8D,
	0x50, 0x08, 0xEB, 0x08, 0xB8, 0x20, 0x00, 0x00, 0x00, 0x8D, 0x50, 0x08,
	0x42, 0x8B, 0x0C, 0x10, 0x85, 0xC9, 0x74, 0x2D, 0x4A, 0x8B, 0x14, 0x12,
	0x48, 0x8D, 0x05, 0xA9, 0x0D, 0x01, 0x00, 0x44, 0x8B, 0xC1, 0x4C, 0x89,
	0x4C, 0x24, 0x28, 0x49, 0xC1, 0xE8, 0x04, 0x49, 0x8B, 0xCB, 0x48, 0x89,
	0x44, 0x24, 0x20, 0x48, 0xFF, 0x15, 0x66, 0xC9, 0xFC, 0xFF, 0x0F, 0x1F,
	0x44, 0x00, 0x00, 0xEB, 0x02, 0x33, 0xC0, 0x48, 0x83, 0xC4, 0x38, 0xC3
};



const size_t ucDataBlockLen = sizeof(ucDataBlock);

static void find_all_signatures(const unsigned char *buf, size_t bufLen,
                                const unsigned char *sig, size_t sigLen,
                                uint64_t baseOffset, uint64_t **results, size_t *count, size_t *capacity) {
    if (bufLen < sigLen) return;
    for (size_t i = 0; i <= bufLen - sigLen; i++) {
        size_t j = 0;
        while (j < sigLen && buf[i + j] == sig[j]) j++;
        if (j == sigLen) {
            if (*count >= *capacity) {
                *capacity *= 2;
                *results = realloc(*results, (*capacity) * sizeof(uint64_t));
                if (!*results) {
                    fprintf(stderr, "Memory allocation failed\n");
                    exit(1);
                }
            }
            (*results)[(*count)++] = baseOffset + i;
        }
    }
}


static size_t count_zeros(FILE *f, uint64_t offset, size_t len) {
    if (fseeko(f, (off_t)offset, SEEK_SET) != 0) {
        perror("fseeko");
        return 0;
    }

    unsigned char buf[CHUNK_SIZE];
    size_t remaining = len, totalZeros = 0;

    while (remaining > 0) {
        size_t toRead = remaining > CHUNK_SIZE ? CHUNK_SIZE : remaining;
        size_t bytes = fread(buf, 1, toRead, f);
        if (bytes == 0) break;

        for (size_t i = 0; i < bytes; i++)
            if (buf[i] == 0x00)
                totalZeros++;

        remaining -= bytes;
    }

    return totalZeros;
}


int main(int argc, char *argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("fopen"); return 1; }

    unsigned char *buffer = malloc(CHUNK_SIZE + ucDataBlockLen);
    if (!buffer) { fprintf(stderr, "malloc failed\n"); fclose(f); return 1; }

    uint64_t *offsets = malloc(16 * sizeof(uint64_t));
    size_t offsetCount = 0, offsetCap = 16;
    if (!offsets) { fprintf(stderr, "malloc failed\n"); free(buffer); fclose(f); return 1; }

    uint64_t totalRead = 0;
    size_t bytesRead;

    while ((bytesRead = fread(buffer, 1, CHUNK_SIZE, f)) > 0) {
        find_all_signatures(buffer, bytesRead, ucDataBlock, ucDataBlockLen,
                            totalRead, &offsets, &offsetCount, &offsetCap);
        totalRead += bytesRead;
    }

    if (offsetCount == 0) {
        printf("Signature not found.\n");
        free(buffer); free(offsets); fclose(f);
        return 0;
    }

    printf("Found %zu signatures:\n", offsetCount);
    for (size_t i = 0; i < offsetCount; i++)
        printf("  [%zu] 0x%011llX\n", i + 1, (unsigned long long)offsets[i]);
    printf("\n");

    for (size_t idx = 0; idx < offsetCount; idx++) {
        uint64_t foundOffset = offsets[idx];
        uint64_t mbBase = foundOffset & 0xFFFFF00000ULL;

        printf("=== Signature #%zu @ 0x%011llX ===\n", idx + 1, (unsigned long long)foundOffset);
        printf("Starting MB boundary: 0x%011llX\n\n", (unsigned long long)mbBase);

        printf("Scanning backward up to %d MB:\n", MAX_STEPS);
        printf("Region A: 0x00000000-0x00000200 (512 bytes)\n");
        printf("Region B: 0x00007E2B-0x0000D800 (%zu bytes)\n\n",
               (size_t)(0x0000D800ULL - 0x00007E2BULL));

        for (int i = 0; i < MAX_STEPS; i++) {
            uint64_t curMB = mbBase - (ONE_MB * i);
            uint64_t regionA_start = curMB + 0x00000000ULL;
            uint64_t regionB_start = curMB + 0x00007E2BULL;
            size_t regionA_len = 0x00000200ULL;
            size_t regionB_len = (size_t)(0x0000D800ULL - 0x00007E2BULL);

            size_t zerosA = count_zeros(f, regionA_start, regionA_len);
            size_t zerosB = count_zeros(f, regionB_start, regionB_len);

            printf("MB @ 0x%011llX | A: %5zu/%zu | B: %5zu/%zu",
                   (unsigned long long)curMB,
                   zerosA, regionA_len,
                   zerosB, regionB_len);

            if (zerosA == regionA_len && zerosB == regionB_len) {
                double mbPos = (double)curMB / (double)ONE_MB;
                double distMB = ceil((double)(mbBase - curMB) / (double)ONE_MB);
                printf("  <-- Found empty MB @ %.0f MB (%.0f MB before signature)", mbPos, distMB);
            }
            printf("\n");
        }

        printf("\n");
    }

    free(buffer);
    free(offsets);
    fclose(f);
    return 0;
}
