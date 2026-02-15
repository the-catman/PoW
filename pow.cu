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
__global__ void solve_kernel(const char *problem, uint64_t max, uint32_t mask, char *solution, int *found) {
    uint64_t i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= max || *found) return;

    char arr[48];
    memcpy(arr, problem, 16);
    memset(arr + 16, '0', 16);
    memcpy(arr + 32, problem, 16);

    uint64_t tmp = i;
    int iter = 16;
    while (tmp > 0 && iter > 0) {
        arr[16 + --iter] = (tmp % 10) + '0';
        tmp /= 10;
    }

    uint32_t hash[5];
    sha1_hash(reinterpret_cast<uint8_t*>(arr), 48, hash);

    if (!(hash[0] & mask)) {
        if (atomicExch(found, 1) == 0) {  // 0 = false, 1 = true
            memcpy(solution, arr + 16, 16);
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

    int threadsPerBlock = 256;
	/** Still trying to figure out what the ideal block size is. */
    int blocks = 1 << (difficulty <= 8 ? 8 : difficulty - 7); // 2 ** max(difficulty - 7, 8)
	// -7 is because threadsPerBlock = 2 ** 8.

    solve_kernel<<<blocks, threadsPerBlock>>>(d_problem, MAX, mask, d_solution, d_found);
    cudaDeviceSynchronize();

    char solution[17] = {0};
    cudaMemcpy(solution, d_solution, 16, cudaMemcpyDeviceToHost);

    printf("%s\n", solution);

    cudaFree(d_problem);
    cudaFree(d_solution);
    cudaFree(d_found);

    return 0;
}
