# freverse – high-performance file reversal in x86-64 Assembly

## Overview
**freverse** is a Linux-based program written in **x86-64 assembly** that reverses the contents of a file.
Program reverses 8-byte blocks for efficency and handles remaining bytes sequentially.
The project demonstrates **low-level systems programming**, **efficient file handling**, and **advanced use of Linux system calls**, while handling extremely large files (over 4 GiB) without any artificial limits.

- Demonstrates **advanced memory management** for large files using `mmap`.  
- Efficiently reverses files of **any size**, including files larger than 4 GiB.  
- Uses **only Linux system calls** (`sys_read`, `sys_write`, `sys_open`, `sys_close`, `sys_stat`, `sys_fstat`, `sys_lseek`, `sys_mmap`, `sys_munmap`, `sys_msync`, `sys_exit`).  
- Robust **error handling**:  
  - Validates command-line arguments.  
  - Checks for system call failures and handles them appropriately.  
- Minimal resource usage and high performance.  
- Silent execution – does not produce any output on the terminal.  

## Usage
```bash
# Assemble and link
nasm -f elf64 freverse.asm -o freverse.o
ld freverse.o -o freverse

# Run the program
./freverse <file>

