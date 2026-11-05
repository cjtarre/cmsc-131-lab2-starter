;
; util.asm - gcd_asm and sum_range_asm, both recursive, callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now gcd_asm returns 0 and
; sum_range_asm returns 0, so the benchmark's --gcd and --reentrancy demos
; fail. Your job is to replace both.
;
; The contracts, from bench.c:
;
;       int b                       [ebp+12]
;       int a                       [ebp+8]
;       int gcd_asm(int a, int b)   returns the greatest common divisor
;
;       int hi                      [ebp+12]
;       int lo                      [ebp+8]
;       int sum_range_asm(lo, hi)   returns the sum of lo..hi inclusive
;
; Both are C-facing and must obey cdecl: prologue, args at [ebp+8]+, return
; in eax, preserve ebx/esi/edi/ebp, clean arguments after every call.
;
; gcd_asm also sets the global `gcd_depth` to the recursion depth of its
; most recent call. The depth is the number of gcd calls on the stack at
; the deepest point, the first call counted as 1. gcd(1071, 462) makes
; four calls, so it reaches 4. bench.c declares the global extern and
; prints it after --gcd:
;
;       int gcd_depth               (in .bss, exported, one int)
;
; The manual's requirements:
;
;   * Both recursive (Euclid's algorithm for gcd).
;   * sum_range_asm must be reentrant. It has to stay correct when a second
;     call begins before the first has finished. That means no .data or
;     .bss storage that changes during execution. Everything lives on the
;     stack and in registers. The static gcd_depth global is gcd's, not
;     sum_range's, and it is diagnostic rather than part of a result.
;   * sum_range_asm calls the C function bench_callback(void) once each
;     time C calls it, which is how bench makes one call overlap another.
;     The recursive calls must not call it again. bench counts the calls.
;     Declare it extern and call it with cdecl. It is not in the manual's
;     pseudocode, but it is what the reentrancy demo runs on.
;   * No calls into the C standard library.
;
; Euclid:
;
;   gcd(a, b):
;       if b == 0: return a
;       return gcd(b, a % b)
;
; sum_range, written so that nothing lives outside the stack:
;
;   sum_range(lo, hi):
;       if lo > hi: return 0
;       return lo + sum_range(lo + 1, hi)
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _gcd_asm gcd_asm
  %define _sum_range_asm sum_range_asm
  %define _gcd_depth gcd_depth
  %define _bench_callback bench_callback
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .bss
        global  _gcd_depth
_gcd_depth      resd    1

segment .text
        global  _gcd_asm
        extern  _bench_callback
_gcd_asm:
        enter   0,0

        inc     dword [_gcd_depth]       ; increment counter on entry
        mov     ecx, [ebp+12]           ; ECX: int b
        mov     eax, [ebp+8]            ; EAX: int a

        cmp     eax, 0                  ; edge case gcd(0, b)
        je      .return_b

        cmp     ecx, 0                  ; if (b==0):
        je      .gcd_end                ;       return a (EAX already has a)

        xor     edx, edx                ; clear edx for div
        div     ecx                     ; edx:eax / ecx -> EDX holds (a % b)
                                        
        push    edx                     ; push a % b    as next b
        push    ecx                     ; push b        as next a

        call    _gcd_asm                ; recursive call
        add     esp, 8                  ; clean up two arguments
        jmp     .gcd_end                ; continue to end

.return_b:
        mov     eax, ecx                ; EAX: int b

.gcd_end:
        leave
        ret

        global  _sum_range_asm
_sum_range_asm:
        enter   0,0
        call    _bench_callback    ; once per call from C, never inside the recursion
        push    dword [ebp+12]     ; hi
        push    dword [ebp+8]      ; lo
        call    sum_inner
        add     esp, 8             ; clean up 2 args
        leave
        ret

; internal: sum_inner(lo, hi), same stack layout as cdecl, so it's easy to reason about
sum_inner:
        enter   0,0
        mov     eax, [ebp+8]       ; lo
        cmp     eax, [ebp+12]      ; signed compare against hi
        jg      .base

        mov     ecx, eax           ; ecx = lo
        inc     ecx                ; ecx = lo + 1
        push    dword [ebp+12]     ; hi (pushed first, right to left)
        push    ecx                ; lo + 1
        call    sum_inner
        add     esp, 8             ; clean up 2 args
        add     eax, [ebp+8]       ; result += lo (reloaded from frame)
        leave
        ret

.base:
        xor     eax, eax           ; return 0
        leave
        ret
