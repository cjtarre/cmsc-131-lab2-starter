;
; sort.asm - qsort_asm, a recursive quicksort callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now it does nothing, which makes
; the benchmark print "NOT SORTED" and "Match: NO". Your job is to replace
; that with the sort described below.
;
; The contract, from bench.c:
;
;       int n                     [ebp+12]
;       int *arr                  [ebp+8]
;
; Sort n 32-bit signed integers in place, ascending. This is the C-facing
; routine. It must obey cdecl (prologue, args at [ebp+8]+, return in eax,
; preserve ebx/esi/edi/ebp, clean arguments after every call it makes). The
; manual lets you use any convention you document for the internal recursive
; routine, but the outer one is fixed.
;
; Requirements from the manual:
;
;   * Recursive. An iterative sort with an explicit stack array does not
;     satisfy the activity.
;   * Lomuto partition with the last element as pivot (the manual's scheme).
;   * No calls into the C standard library.
;   * Clean the arguments off the stack after each call. The next pop
;     otherwise loads an argument into a register you promised to
;     preserve, and the outer call's array base is gone.
;
; The manual's pseudocode:
;
;   qsort(arr, lo, hi):
;       if lo >= hi: return
;       p = partition(arr, lo, hi)
;       qsort(arr, lo, p - 1)
;       qsort(arr, p + 1, hi)
;
;   partition(arr, lo, hi):
;       pivot = arr[hi]
;       i = lo - 1
;       for j = lo to hi - 1:
;           if arr[j] <= pivot:
;               i = i + 1
;               swap arr[i], arr[j]
;       swap arr[i + 1], arr[hi]
;       return i + 1
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _qsort_asm qsort_asm
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif


;
; Stack-frame offsets and local storage sizes.
;

; qsort_asm arguments
QSORT_ARR       equ 8
QSORT_N         equ 12

; qsort_recursive arguments and local storage
REC_ARR         equ 8
REC_LO          equ 12
REC_HI          equ 16
REC_PIVOT       equ -4
REC_LOCALS      equ 4

; partition arguments and local storage
PART_ARR        equ 8
PART_LO         equ 12
PART_HI         equ 16
PART_I          equ -4
PART_PIVOT      equ -8
PART_J          equ -12
PART_TEMP       equ -16
PART_LOCALS     equ 16

; Three cdecl arguments, four bytes each.
ARG_BYTES       equ 12


segment .text
        global  _qsort_asm

_qsort_asm:
        enter   0,0

        ; Handle the base case and set up the initial range.

        mov     ecx, [ebp+QSORT_N]   ; ECX: n
        cmp     ecx, 1
        jle     .done                ; n <= 1: nothing to sort

        dec     ecx                  ; ECX: hi = n - 1

        ; Start recursive quicksort with range [0, n - 1].
        push    ecx                  ; hi
        push    dword 0              ; lo = 0
        push    dword [ebp+QSORT_ARR]; arr
        call    qsort_recursive
        add     esp, ARG_BYTES       ; clean up three 4-byte arguments

.done:
        xor     eax, eax             ; qsort_asm is void; EAX is unused
        leave
        ret


qsort_recursive:
        enter   REC_LOCALS,0

        ; Base case: a range with 0 or 1 element is already sorted.

        mov     eax, [ebp+REC_LO]    ; EAX: lo
        cmp     eax, [ebp+REC_HI]    ; compare lo and hi
        jge     .done                ; lo >= hi: range is already sorted

        ; Partition the range and get the pivot's final index in EAX.

        push    dword [ebp+REC_HI]   ; hi
        push    dword [ebp+REC_LO]   ; lo
        push    dword [ebp+REC_ARR]  ; arr
        call    partition
        add     esp, ARG_BYTES       ; clean up three arguments

        mov     [ebp+REC_PIVOT], eax ; save p across recursive calls

        ;
        ; Recursively sort the left range: lo .. p - 1.
        ;

        mov     ecx, eax
        dec     ecx                  ; ECX: p - 1

        push    ecx                  ; hi = p - 1
        push    dword [ebp+REC_LO]   ; lo
        push    dword [ebp+REC_ARR]  ; arr
        call    qsort_recursive
        add     esp, ARG_BYTES       ; clean up three arguments

        ;
        ; Recursively sort the right range: p + 1 .. hi.
        ;

        mov     eax, [ebp+REC_PIVOT]
        inc     eax                  ; EAX: p + 1

        push    dword [ebp+REC_HI]   ; hi
        push    eax                  ; lo = p + 1
        push    dword [ebp+REC_ARR]  ; arr
        call    qsort_recursive
        add     esp, ARG_BYTES       ; clean up three arguments

.done:
        leave
        ret


partition:
        enter   PART_LOCALS,0

        ;
        ; Lomuto partition locals:
        ; PART_I     = i
        ; PART_PIVOT = pivot
        ; PART_J     = j
        ; PART_TEMP  = temporary swap value
        ;

        ; Use the last element of the range as the pivot.
        mov     eax, [ebp+PART_HI]      ; EAX: hi
        mov     ecx, [ebp+PART_ARR]     ; ECX: arr
        mov     edx, [ecx+eax*4]        ; EDX: arr[hi]
        mov     [ebp+PART_PIVOT], edx   ; pivot = arr[hi]

        ; i tracks the end of the left partition.
        mov     eax, [ebp+PART_LO]      ; EAX: lo
        dec     eax
        mov     [ebp+PART_I], eax       ; i = lo - 1

        ; j scans the range from lo through hi - 1.
        mov     eax, [ebp+PART_LO]
        mov     [ebp+PART_J], eax       ; j = lo

.loop:
        mov     eax, [ebp+PART_J]       ; EAX: j
        cmp     eax, [ebp+PART_HI]      ; stop when j reaches hi
        jge     .after_loop

        mov     ecx, [ebp+PART_ARR]     ; ECX: arr
        mov     edx, [ecx+eax*4]        ; EDX: arr[j]
        cmp     edx, [ebp+PART_PIVOT]   ; compare arr[j] with pivot
        jg      .next                   ; signed: skip if arr[j] > pivot

        ;
        ; arr[j] belongs on the <= pivot side.
        ; Advance i and swap arr[i] with arr[j].
        ;

        inc     dword [ebp+PART_I]      ; i = i + 1

        mov     eax, [ebp+PART_I]       ; EAX: i
        mov     edx, [ecx+eax*4]        ; EDX: arr[i]
        mov     [ebp+PART_TEMP], edx    ; save old arr[i]

        mov     edx, [ebp+PART_J]       ; EDX: j
        mov     edx, [ecx+edx*4]        ; EDX: arr[j]
        mov     [ecx+eax*4], edx        ; arr[i] = arr[j]

        mov     eax, [ebp+PART_J]       ; EAX: j
        mov     edx, [ebp+PART_TEMP]    ; EDX: old arr[i]
        mov     [ecx+eax*4], edx        ; arr[j] = old arr[i]

.next:
        inc     dword [ebp+PART_J]      ; j = j + 1
        jmp     .loop

.after_loop:
        ;
        ; Put the pivot into its final sorted position at i + 1.
        ;

        mov     eax, [ebp+PART_I]
        inc     eax                     ; EAX: p = i + 1

        mov     ecx, [ebp+PART_ARR]     ; ECX: arr
        mov     edx, [ecx+eax*4]        ; EDX: arr[p]
        mov     [ebp+PART_TEMP], edx    ; save old arr[p]

        mov     edx, [ebp+PART_HI]      ; EDX: hi
        mov     edx, [ecx+edx*4]        ; EDX: pivot at arr[hi]
        mov     [ecx+eax*4], edx        ; arr[p] = pivot

        mov     edx, [ebp+PART_HI]      ; EDX: hi
        mov     eax, [ebp+PART_TEMP]    ; EAX: old arr[p]
        mov     [ecx+edx*4], eax        ; arr[hi] = old arr[p]

        ; Return the pivot's final index in EAX.
        mov     eax, [ebp+PART_I]
        inc     eax                     ; EAX: p = i + 1

        leave
        ret