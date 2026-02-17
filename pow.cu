#include <cstdio>
#include <cuda_runtime.h>

#include "sha1.h"

#define MAX 10000000000000ULL

/**
 * Assumptions:
 * 0 <= difficulty <= 32 (Gets capped at 32)
 * Problem is always 16 bytes
 * Solution will always be 16 bytes
 */
__global__ void solve_kernel(const char *problem, uint32_t mask, char *solution, int *found) {
    uint64_t idx = blockIdx.x * blockDim.x + threadIdx.x;
    uint64_t stride = (uint64_t)blockDim.x * gridDim.x;

    uint8_t arr[48];
    uint32_t hash[5];

    memcpy(arr, problem, 16);
    memset(arr + 16, '0', 16);
    memcpy(arr + 32, problem, 16);

    volatile int *found_volatile = found;

    for (uint64_t i = idx; i < MAX && !(*found_volatile); i += stride) {
        uint64_t tmp = i;
        int iter = 16;
        while (tmp > 0) {
            arr[16 + --iter] = (tmp % 10) + '0';
            tmp /= 10;
        }

        sha1_hash(arr, 48, hash);
        if (!(hash[0] & mask)) {
            if (atomicExch(found, 1) == 0) {
                memcpy(solution, arr + 16, 16);
            }
            return;
        }
    }
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <16-char problem> <difficulty>\n", argv[0]);
        return 1;
    }

    const char *problem = argv[1];
    if (strlen(problem) != 16) {
        printf("Problem string must be exactly 16 characters.\n");
        return 1;
    }

    int difficulty = atoi(argv[2]);
    if (difficulty < 0 || difficulty > 32) {
        printf("Error: Difficulty must be between 0 and 32.\n");
        return 1;
    }

    uint32_t mask = difficulty >= 32 ? 0xFFFFFFFF : ((1U << difficulty) - 1) << (32 - difficulty);

    // Device memory
    char *d_problem, *d_solution;
    int *d_found;
    cudaMalloc(&d_problem, 16);
    cudaMemcpy(d_problem, problem, 16, cudaMemcpyHostToDevice);
    cudaMalloc(&d_solution, 16);
    cudaMalloc(&d_found, sizeof(int));
    cudaMemset(d_found, 0, sizeof(int));

    int blocks = 256;
    int threadsPerBlock = 256;

    solve_kernel<<<blocks, threadsPerBlock>>>(d_problem, mask, d_solution, d_found);

    cudaDeviceSynchronize();

    int found_host = 0;
    cudaMemcpy(&found_host, d_found, sizeof(int), cudaMemcpyDeviceToHost);

    if (found_host) {
        char solution[17] = {0};
        cudaMemcpy(solution, d_solution, 16, cudaMemcpyDeviceToHost);
        printf("%s\n", solution);
    } else {
        printf("No solution found\n");
    }

    cudaFree(d_problem);
    cudaFree(d_solution);
    cudaFree(d_found);

    return 0;
}
