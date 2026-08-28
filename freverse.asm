; =============================================================================
; Program: Freverse
; Author:  Mateusz Gnat
; Date:    16.05. 2025
; Purpose: Reverses the contents of a file by mapping it to memory and swapping
;          bytes in 8-byte blocks, handling any remaining bytes sequentially.
; =============================================================================

global _start

section .data               ; Defines constants used throughout the program
    ; Assigns system call numbers for code readability
    sys_open        equ 2
    sys_close       equ 3
    sys_stat        equ 4
    sys_mmap        equ 9
    sys_munmap      equ 11
    sys_exit        equ 60

    ; Constants for handling and validating the input file
    O_RDWR          equ 2   ; Flag: opens the file with read/write access
    ARGC_EXPECTED   equ 2   ; Expected number of program arguments
    MIN_SIZE        equ 2   ; Minimum file size suitable for reversing
    MODE_MASK       equ 0F000h ; Mask for file type
    CORR_FILE_TYPE  equ 08000h ; Type number for expected 'regular' file

    ; Constants for sys_stat call. Returned data is stored 'below' rdi
    ; in the red zone ([rdi - 128]). The following constants refer to byte offsets
    NAME_OFFSET     equ 16  ; Offset of file name address from rsp
    RED_ZONE        equ 128 ; Size of the 'red zone' subtracted from rsp
    MODE_OFFSET     equ 104 ; Offset of file type 'below' rsp
    SIZE_OFFSET     equ 80  ; Offset of file size 'below' rsp

    ; Constants for memory mapping and loops
    PROT_RW         equ 3   ; Flag: memory can be read and written
    MAP_SHARED      equ 1   ; Flag: shared mapping, writes update the file
    BLOCK_SIZE      equ 8   ; Size of the byte block to reverse

    ; Constants for program exit
    EXIT_SUCCESS    equ 0   ; Successful execution
    EXIT_FAILURE    equ 1   ; Exit code in case of error

section .text
    ; Checks whether the program was called with correct arguments
_start:
    ; Checks the argument number
    mov     rbx, [rsp]          ; Loads the number of program arguments into rbx
    cmp     rbx, ARGC_EXPECTED  ; Compares with expected number of arguments (2)
    jne     .fail_exit

    ; Prepare registers for sys_stat call
    mov     rdi, [rsp + NAME_OFFSET] ; Put file name from stack into rdi
    lea     rsi, [rsp - RED_ZONE]    ; Result buffer in the 'red zone' below rsp
    mov     rax, sys_stat            ; System call number
    syscall
    test    rax, rax                 ; Set flags based on success
    js      .fail_exit               ; If rax < 0, exit with code 1

    ; Check the file type
    mov     eax, [rsp - MODE_OFFSET] ; Load file type info from 'red zone'
    and     eax, MODE_MASK           ; Mask file type bits (0xF000)
    cmp     eax, CORR_FILE_TYPE      ; Check for correct file type (0x8000)
    jne     .fail_exit               ; Invalid argument (e.g., directory)

    ; Check file size
    mov     r12, [rsp - SIZE_OFFSET] ; File size from 'red zone' into r12
    cmp     r12, MIN_SIZE            ; Ensure file is larger than 2 bytes
    jb      .success_exit            ; If not, exit successfully (code 0)

    ; Open the file
    mov     rdi, [rsp + NAME_OFFSET] ; File name into rdi
    mov     rsi, O_RDWR              ; Open file with read/write access
    mov     rax, sys_open            ; System call number
    syscall
    test    rax, rax                 ; Check if open succeeded
    js      .fail_exit               ; If not, exit with code 1
    mov     r13, rax                 ; Store file descriptor in r13

    ; Prepare registers for sys_mmap call
    xor     rdi, rdi        ; Starting address 0 (kernel chooses)
    mov     rsi, r12        ; Mapping size = file size
    mov     rdx, PROT_RW    ; Allow read/write access
    mov     r10, MAP_SHARED ; Shared mapping, updates file
    mov     r8, r13         ; File descriptor
    xor     r9, r9          ; Offset 0 for whole file
    mov     rax, sys_mmap   ; System call number
    syscall
    test    rax, rax        ; Check if mmap succeeded
    js      .fail_close_exit; If not, close file and exit (code 1)

    ; Set up loop iterators
    mov     r8, rax     ; Store mapped address in r8
    xor     rcx, rcx    ; Iterator starting at index 0
    mov     rdx, r12    ; rdx = end index (file size)
    dec     rdx         ; Adjust to last byte index (size - 1)

    ; Loop: reverses 8-byte blocks using bswap and swaps them
.rev_loop_qword:
    ; Checks if a full 8-byte block can still be reversed
        mov r9, rcx                 ; r9 = iterator index rcx
        add r9, 2 * BLOCK_SIZE - 1  ; r9 = rcx + rdx offset
        cmp r9, rdx                 ; Check if loop can run
        ja  .rev_bits               ; If rcx near rdx, reverse remaining bytes

        ; Reverse bytes in 8-byte blocks
        mov     rax, [r8 + rcx]                 ; rax = 8 bytes from map + rcx
        mov     rbx, [r8 + rdx - BLOCK_SIZE + 1]; rbx = 8 bytes from map + rdx - 7
        bswap   rax                             ; Reverse bytes in rax
        bswap   rbx                             ; Reverse bytes in rbx
        mov     [r8 + rcx], rbx                 ; Store rbx at map + rcx
        mov     [r8 + rdx - BLOCK_SIZE + 1], rax; Store rax at map + rdx
        add     rcx, BLOCK_SIZE                 ; Move rcx forward by 8 bytes
        sub     rdx, BLOCK_SIZE                 ; Move rdx backward by 8 bytes
        jmp     .rev_loop_qword                 ; Loop again

        ; Loop to reverse remaining 1–15 bytes between rcx and rdx
    .rev_bits:
        cmp     rcx, rdx            ; Compare rcx and rdx
        jae     .success_close_exit ; If rcx >= rdx, file content is reversed
        mov     al, [r8 + rcx]      ; al = byte at map + rcx
        mov     bl, [r8 + rdx]      ; bl = byte at map + rdx
        mov     [r8 + rcx], bl      ; Store bl at map + rcx
        mov     [r8 + rdx], al      ; Store al at map + rdx
        inc     rcx                 ; Increment rcx
        dec     rdx                 ; Decrement rdx
        jmp     .rev_bits           ; Repeat

    .success_close_exit:
        mov     rax, sys_munmap     ; Unmap memory region
        mov     rdi, r8             ; Start address of mapping
        mov     rsi, r12            ; Size of mapping
        syscall
        test    rax, rax            ; Check if unmap succeeded
        js      .fail_close_exit    ; If not, close file and exit

        mov     rdi, r13            ; File descriptor
        mov     rax, sys_close      ; Close file
        syscall
        test    rax, rax            ; Check if close succeeded
        js      .fail_exit          ; If not, exit with code 1

    .success_exit:
        mov     rax, sys_exit       ; System call number
        mov     rdi, EXIT_SUCCESS   ; Exit code 0
        syscall

    .fail_close_exit:
        mov     rdi, r13            ; File descriptor
        mov     rax, sys_close      ; Close file
        syscall                     ; No check, program ends anyway

    .fail_exit:
        mov     rax, sys_exit       ; System call number
        mov     rdi, EXIT_FAILURE   ; Exit code 1
        syscall

