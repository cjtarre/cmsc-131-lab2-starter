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

segment .text
        global  _qsort_asm
_qsort_asm:
        enter   0,0

        ;
        ; TODO: sort.
        ;
        ; Remember the array elements are four bytes, so index with a *4
        ; scale. The first thing to handle is the empty and single-element
        ; arrays: n <= 1 sorts itself.
        ;

        mov     ecx, [ebp+12]       ; ECX: n
        cmp     ecx, 1
        jle     .done               ; n <= 1 is already sorted

        dec     ecx                 ; ECX: hi = n - 1

        push    ecx                 ; hi
        push    dword 0             ; lo = 0
        push    dword [ebp+8]       ; arr
        call    qsort_recursive
        add     esp, 12             ; clean up three arguments

.done:
        xor     eax, eax
        leave
        ret


qsort_recursive:
        enter   0,0

        mov     eax, [ebp+12]       ; EAX: lo
        cmp     eax, [ebp+16]       ; compare lo and hi
        jge     .done               ; lo >= hi: nothing to sort

        ;
        ; TODO: partition current range, then recursively sort
        ;       lo..p-1 and p+1..hi.
        ;

.done:
        leave
        ret
