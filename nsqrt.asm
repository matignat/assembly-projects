; =======================================================================
; Program: Square Root Finder
; Author:  Mateusz Gnat
; Date:    15.06.2025
; Purpose: Finds the integer square root Q of a given non-negative 2n-bit
;          integer X (up to 256000 bits)such that Q^2 ≤ X < (Q+1)^2.
;          Uses an optimized bitwise method operating on qwords.
; =======================================================================

global nsqrt

section .text

nsqrt:
    ;Callee-saved register handling
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     rax, rdx
    shr     rax, 6              ;rax = n/64 - number of 64-bit words in Q

    ;Prepares the place for building Q by setting it to 0
.setQ_loop:
    mov     qword [rdi + rax * 8 - 8], 0 ;Q[rax - 8] = 0
    dec     rax                 ;Decrement the word index
    cmp     rax, 0              ;Check if all words are cleared
    jne     .setQ_loop          ;If Q not 0, iterate

    mov     r11, rdx
    shr     r11, 6              ;r11 = n/64 = number of 64-bit words in Q

    mov     r8, 1               ;r8 = j = 1 (main iterator)

    ;Main loop for building the result number qword by qword
.main_loop:
    mov     r9, rdx
    sub     r9, r8
    mov     r10, r9
    dec     r10                 ;r10 = n - j - 1 used for computing the target qword

    inc     r9                  ;r9 = n - j + 1
    mov     rcx, r9             ;rcx = r9

    shr     r9, 6               ;r9 = shift qword from Q to compute T
    and     rcx, 63             ;rcx = bit shift from Q

    mov     r12, rdx
    shr     r12, 5
    dec     r12                 ;r12 = 2n / 64 - 1 set to last qword from T

    mov     r13, r10            ;r13 = n - j - 1
    and     r10, 63             ;T word offset relative to original Q
    shr     r13, 6              ;Original Q word index relative to T

    cmp     rdx, r8             ;Compare n with j (edge case)
    je      .findTloop          ;Skip setting bit 4^0 in T (Out of range)

    bts     [rdi + r13 * 8], r10;Set bit r10 in Q (4^n-j in T)

    ; Builds T by shifting Q words according to the algorithm
.findTloop:                     ;Find T qword
    sub     r12, r9             ;Subtract Q offset from iterator
    xor     rax, rax            ;rax - clear for building T
    xor     rbx, rbx            ;Helper for X and T qwords

    cmp     r12, r11            ;Compares r12 without offset to number of qwords in Q
    jg      .compare            ;Greater = empty qword
    je      .UpLim              ;Equal = most significant qword of Q

    cmp     r12, 0              ;Compares iterator to offset
    jl      .XabeqT             ;If lower remaining qwords = 0 so X >= T
    je      .LowLim             ;If equal = first Q qword
                                ;Jump here if the T qword is entirely based on Q
    mov     rax, [rdi + r12 * 8];Corresponding qword from Q
    mov     rbx, [rdi + r12 * 8 - 8];Previous qword from Q
    shld    rax, rbx, cl        ;Shift and merge with previous word bits
    jmp     .compare            ;T qword ready to be compared with X

    ;Handling the least significant Q word case
.LowLim:
    mov     rax, [rdi]          ;rax = Q[0]
    shl     rax, cl             ;Fill with 0 from the right side

    cmp     rdx, r8             ;Compare n with j
    jne     .compare

    inc     rax                 ;If j = n add bit 1
    jmp     .compare

    ;Handling the most significant Q word case
.UpLim:
    mov     rbx, [rdi + r12 * 8 - 8];Upper Q qword (r11 is a qword number)
    shld    rax, rbx, cl        ;rax = 0 Shift by rcx bits from Q

    ;Compares T with X
.compare:
    add     r12, r9             ;Add offset to iterator
    mov     rbx, [rsi + r12 * 8];rbx = qword from X

    cmp     rbx, rax            ;compare X with T
    ja      .XabeqT             ;If X greater jump to X >= T
    jb      .XbelowT            ;If T greater jump to X < T

    dec     r12                 ;If equal decrement
    cmp     r12, -1             ;Check if all qwords were tested
    jne     .findTloop          ;If not, continue

    ;X above or equal T case
.XabeqT:
    xor     r14, r14            ;Readies r14 = offset = 0
    mov     r12, r9             ;Iterator on first significant qword
    mov     rax, [rdi]          ;rax = Q[0] first significant qword handling
    shl     rax, cl             ;Shift left by rcx

    sub     r12, r9             ;r12 = iterator - offset
    shr     rdx, 5              ;2n / 64 = X qwords

    jmp     .sub                ;Subtract the first prepared word

.loop:
    sub     r12, r9             ;Subtract Q qword offset
    xor     rax, rax            ;Prepares for T build

    cmp     r12, r11            ;Compare iterator - shift Q qwords
    jg      .sub                ;Empty qword = substract
    je      .UpLimit            ;If equal = highest Q qword

    mov     rax, [rdi + r12 * 8];Corresponding qword from Q
    mov     rbx, [rdi + r12 * 8 - 8];Previous qword from Q
    shld    rax, rbx, cl        ;Shift left, filling rax with bits from previous Q qword
    jmp     .sub

.UpLimit:
    mov     rbx, [rdi + r11 * 8 - 8] ;Last qword (r11 = number of qwords in Q)
    shld    rax, rbx, cl      ;Shift left, filling rax with bits from rbx

    ;Subtracting T from X
.sub:
    add     r12, r9           ;Add offset to iterator to get X index

    bt      r14, 0            ;Check if there was a carry and set cf
    sbb     [rsi + r12*8], rax ;Subtract with borrow if needed
    setc    r14b              ;Set new carry

    inc     r12               ;Increment iterator -> next qword
    cmp     r12, rdx          ;Compare iterator with number of qwords in X
    jne     .loop             ;If not done, continue loop

    shl     rdx, 5            ;Restore original value of n
    mov     rbx, rdx
    sub     rbx, r8           ;rbx = n - j, bit to set in Q
    mov     rax, rbx
    shr     rbx, 6            ;Word index to set the bit in Q
    and     rax, 63           ;Bit index within the qword
    bts     [rdi + rbx * 8], rax ;Set the bit in Q

    ;X below T case
.XbelowT:
    cmp     r8, rdx             ;Checks if j > n
    je      .end                ;If not end

    inc     r8                  ;Increment j
    btr     [rdi + r13 * 8], r10;Clear the test bit set in Q

    jmp     .main_loop          ;Next iteration

.end:
    pop     r14                 ;Restore callee-saved registers
    pop     r13
    pop     r12
    pop     rbx

    ret
