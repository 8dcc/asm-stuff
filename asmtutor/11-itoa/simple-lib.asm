; -------------------------------------------------------------------------
; https://github.com/r4v10l1/asm-stuff
; This file contains some functions that will be used by another file when
; including. Keep in mind that the file might change depending on the
; current directory.
; -------------------------------------------------------------------------

; int slen(char*)
; Calculates length of string
slen:
    push    ebx                 ; We wil use ebx to store the pointer to the first character of out string
    mov     ebx,eax             ; eax contains the target string, move to ebx
slen_nextchar:
    cmp     byte[eax],0         ; Check end of string
    jz      slen_finished       ; Was end of string, go to finished
    inc     eax                 ; Else, next char
    jmp     slen_nextchar
slen_finished:
    sub     eax,ebx             ; eax points to the last position of the str, subtract the first pos to get len
    pop     ebx                 ; We don't need ebx anymore, pop from stack
    ret                         ; Return function

; void sprint(char*)
; Prints a string using the write syscall (4)
sprint:
    push    edx                 ; We push with reverse order to pop in the good one (it's not like it matters here but idk)
    push    ecx
    push    ebx
    push    eax                 ; Will be on top of the stack. eax is the char* we are going to use
    
    call    slen                ; We call slen to get the length of the str (needed for edx).
                                ; Returned value will be stored in eax but we have the original char* in stack

    mov     edx,eax             ; Move length to edx
    pop     eax                 ; pop the original eax (char*) from stack

    mov     ecx,eax             ; Move the char* to ecx
    mov     eax,4               ; Write
    mov     ebx,1               ; STDOUT
    int     0x80                ; Call kernel

    pop     ebx                 ; pop values back in reverse order from when we pushed
    pop     ecx
    pop     edx
    ret                         ; Return the function, eax was not pop'ed so it will be 4 (sys_write)

; void println(char*)
; Prints a string using the sprint function + '\n'
println:
    call    sprint

    push    eax                 ; Push current eax to stack to preserve it
    mov     eax, 0xA            ; Move '\n' to eax because we want to append it
    push    eax                 ; Push eax ('\n') to stack so we can get the address
    mov     eax, esp            ; esp points to the item on top of the stack ('\n'), so we move it to eax to use as function argument for sprint
    call    sprint              ; Print newline
    pop     eax                 ; Remove newline from stack
    pop     eax                 ; Get original eax from stack
    ret

; void iprint(int i)
; Prints i (eax) as string. I will use a different method than the one on asmtutor
iprint:
    push    eax                 ; Save eax register
    push    ebx                 ; Save ebx for calling sys_write
    push    ecx                 ; Save ecx for calling sys_write
    push    edx                 ; For remainders using idiv
    push    ebp                 ; Save ebp register
    mov     ebp, esp            ; Save stack position (after pushing)

    dec     esp                 ; We will be subtracting 1 to esp each char (in this case '\0'). See comment on iprint_nextdigit
    mov     [esp], byte 0       ; Add the terminating '\0'
    mov     esi, 10             ; Divisor. TODO: save esi on the stack?

iprint_nextdigit:
    dec     esp                 ; Decrement the stack pointer by 1, allocating the next byte.

    mov     edx, 0              ; Clear reminder from last division.
    idiv    esi                 ; (eax / 10) Result is saved in eax, and remainder to edx. Would be:
                                ;   edx = eax % 10;
                                ;   eax /= 10;
    add     edx, '0'            ; Digit (remainder) to char
    mov     [esp], dl           ; We can't just push the digit because each stack item is 4 bytes, and sys_write expects an array of
                                ; 1 byte chars. We don't use "byte [esp]" because it would give a type mismatch error. We don't mov
                                ; edx, because we would be moving a word (4 bytes), and because we are only decreasing esp 1 byte,
                                ; we would be overwriting the first 3 bytes of our previous word. We instead use dl, which is the
                                ; lower half of dx, which is the lower half of edx, moving the lowest byte of edx into esp.

    cmp     eax, 0              ; We compare eax with 0 to check if we are done dividing (we printed all the digits)
    jnz     iprint_nextdigit    ; Jump back if not zero

; End of iprint_nextdigit
    mov     edx, ebp            ; Move ebp to edx to store the str len when calling sys_write
    sub     edx, esp            ; Sub old esp to current one, to get string length. We subtract the new pos from the old one because
                                ; the top of the stack is on a lower position in memory.
    
    mov     ecx, esp            ; Save stack pointer to ecx. Stack would be:
                                ;   [ '4', '2, '0', '\0', ebp, edx, eax, ... ]
    mov     ebx, 1              ; stdout
    mov     eax, 4              ; sys_write
    int     0x80

    mov     esp, ebp            ; Restore stack position (to after we pushed so we can pop):
                                ;   [ '4', '2, '0', '\0', ebp, edx, eax, ...]
                                ; (top)                    ^             (bottom)

    pop     ebp                 ; Pop ebp register
    pop     edx                 ; Pop edx register
    pop     ecx                 ; Pop ecx register
    pop     ebx                 ; Pop ebx register
    pop     eax                 ; Pop registers after restoring esp
    ret

; void quit()
; Calls sys_exit (1)
quit:
    mov     eax,1               ; sys_exit
    mov     ebx,0               ; Return 0
    int     0x80                ; Call kernel (exit)
    ret                         ; Return should not be necesary but whatever