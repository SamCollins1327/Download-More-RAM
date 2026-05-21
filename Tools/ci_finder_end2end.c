#define _FILE_OFFSET_BITS 64   // Must come before any includes for large files
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

#define CHUNK_SIZE (1024 * 1024ULL)
#define ONE_MB     (1024 * 1024ULL)

unsigned char ucDataBlock[24] = {
	// Offset 0x00000008 to 0x0000001F
	0x48, 0x83, 0xEC, 0x28, 0xE8, 0x17, 0x00, 0x00, 0x00, 0x48, 0xF7, 0xD8,
	0x1B, 0xC0, 0x25, 0x03, 0x06, 0x00, 0xC0, 0x48, 0x83, 0xC4, 0x28, 0xC3
};


const size_t ucDataBlockLen = sizeof(ucDataBlock);

/* Finds all occurrences of the signature in a buffer */
static void find_all_signatures(const unsigned char *buf, size_t bufLen,
                                const unsigned char *sig, size_t sigLen,
                                uint64_t baseOffset,
                                uint64_t **results, size_t *count, size_t *capacity)
{
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

int main(int argc, char *argv[])
{
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        perror("fopen");
        return 1;
    }

    unsigned char *buffer = malloc(CHUNK_SIZE + ucDataBlockLen);
    if (!buffer) {
        fprintf(stderr, "malloc failed\n");
        fclose(f);
        return 1;
    }

    uint64_t *offsets = malloc(16 * sizeof(uint64_t));
    size_t offsetCount = 0, offsetCap = 16;
    if (!offsets) {
        fprintf(stderr, "malloc failed\n");
        free(buffer);
        fclose(f);
        return 1;
    }

    uint64_t totalRead = 0;
    size_t bytesRead;

    while ((bytesRead = fread(buffer, 1, CHUNK_SIZE, f)) > 0) {
        find_all_signatures(buffer,
                            bytesRead,
                            ucDataBlock,
                            ucDataBlockLen,
                            totalRead,
                            &offsets,
                            &offsetCount,
                            &offsetCap);
        totalRead += bytesRead;
    }

    if (offsetCount == 0) {
        printf("Signature not found\n");
        goto cleanup;
    }

    /* Take the FINAL signature */
    uint64_t foundOffset = offsets[offsetCount - 1];

    /* Convert to MB, subtract 3 MB, and output */
    double sigMB = (double)foundOffset / (double)ONE_MB;
    uint64_t resultMB = (uint64_t)floor(sigMB) - 2;

    printf("%llu\n", (unsigned long long)resultMB);

cleanup:
    free(buffer);
    free(offsets);
    fclose(f);
    return 0;
}
