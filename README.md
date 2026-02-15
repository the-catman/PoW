# PoW

A simple Proof-of-Work solver implementation using SHA1.

## Overview

I used an [extremely fast implementation of SHA1](https://www.nayuki.io/page/fast-sha1-hash-implementation-in-x86-assembly) written by Nayuki in order to benchmark CPU vs GPU performances in solving computationally intensive tasks.

This is only for a proof of concept. I simply wanted to dip my toes into how GPU parallelization works. Modern Proof-of-Work solvers (in Bitcoin miners and such) have dedicated hardware that can hash a thousand times faster than what I'm currently doing. Additionally, SHA1 is mostly obsolete.

Problem Description:
- Problem: A random string whose length must always be 16.
- Difficulty: The amount of bits which have to be zero'd for the PoW to be solved.
- Solution: The solution string, whose length is, again, always 16. Is exclusively numeric.

When running `SHA1(problem | solution | problem)`, the resulting hash will have the first `difficulty` bits set to zero.

The challenge is to find out what `solution` is through bruteforce.

Important note: The slight overhead of launching a bunch of GPU kernels means that for smaller difficulties, it's more optimal to use the CPU solver.

## sha1.h

Contains the core SHA1 algorithm.

## pow.cpp

Has a few methods:
- `std::string solve`: Solves using a single thread on the CPU.
- `std::string solveParallel`: Solves using all available CPU threads (WARNING: WILL MAX OUT YOUR CPU).

Compile using `g++ pow.cpp -O3 -o pow`.

## pow.cu

Contains basically the same algorithm but modified to use [NVIDIA's CUDA Toolkit](https://developer.nvidia.com/cuda-toolkit). I used ChatGPT to generate it (and applied small modifications myself), since I don't really know CUDA.

Uses all available GPU cores, and is _ridiculously_ fast.

Open x64 Native Tools Command Prompt (if on Windows), compile using `nvcc pow.cu -O3 -o pow_cu`.

## Benchmarks (Intel i7-14700HX, NVIDIA RTX 4070, Windows 11)

Note that this is not a rigorous benchmark, and I simply used Measure-Comamnd in PowerShell to do it.

| Implementation |     Problem      | Difficulty | Time to Solve | 
| -------------- | ---------------- | ---------- | ------------- |
| CPU Single     | abc0123456789def |     32     |     101.8s    |
| CPU Parallel   | abc0123456789def |     32     |     11.95s    |
| GPU CUDA       | abc0123456789def |     32     |     0.764s    |

| Implementation |     Problem      | Difficulty | Time to Solve | 
| -------------- | ---------------- | ---------- | ------------- |
| CPU Single     | abc0123456789def |     20     |     0.037s    |
| CPU Parallel   | abc0123456789def |     20     |     0.078s    |
| GPU CUDA       | abc0123456789def |     20     |     0.110s    |
