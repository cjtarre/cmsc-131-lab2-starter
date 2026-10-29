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
        ; Set up the initial quicksort range.
        ; Empty and single-element arrays are already sorted.
        ;

        mov     ecx, [ebp+12]       ; ECX: n
        cmp     ecx, 1
        jle     .done               ; n <= 1: nothing to sort

        dec     ecx                 ; ECX: hi = n - 1

        ; Start recursive quicksort with range [0, n - 1].
        push    ecx                 ; hi
        push    dword 0             ; lo = 0
        push    dword [ebp+8]       ; arr
        call    qsort_recursive
        add     esp, 12             ; clean up three 4-byte arguments

.done:
        xor     eax, eax            ; qsort_asm is void; EAX is not used as a return value
        leave
        ret


qsort_recursive:
        enter   4,0                 ; [ebp-4] stores pivot index p

        ;
        ; Stop when the current range has zero or one element.
        ;

        mov     eax, [ebp+12]       ; EAX: lo
        cmp     eax, [ebp+16]       ; compare lo and hi
        jge     .done               ; lo >= hi: range is already sorted

        ;
        ; Partition the current range around arr[hi].
        ; partition returns the final pivot index p in EAX.
        ;

        push    dword [ebp+16]      ; hi
        push    dword [ebp+12]      ; lo
        push    dword [ebp+8]       ; arr
        call    partition
        add     esp, 12             ; clean up three arguments

        mov     [ebp-4], eax        ; save p across recursive calls

        ;
        ; Recursively sort the left range: lo .. p - 1.
        ;

        mov     ecx, eax
        dec     ecx                 ; ECX: p - 1

        push    ecx                 ; hi = p - 1
        push    dword [ebp+12]      ; lo
        push    dword [ebp+8]       ; arr
        call    qsort_recursive
        add     esp, 12             ; clean up three arguments

        ;
        ; Recursively sort the right range: p + 1 .. hi.
        ;

        mov     eax, [ebp-4]
        inc     eax                 ; EAX: p + 1

        push    dword [ebp+16]      ; hi
        push    eax                 ; lo = p + 1
        push    dword [ebp+8]       ; arr
        call    qsort_recursive
        add     esp, 12             ; clean up three arguments

.done:
        leave
        ret


partition:
        enter   16,0

        ;
        ; Lomuto partition locals:
        ; [ebp-4]  = i
        ; [ebp-8]  = pivot
        ; [ebp-12] = j
        ; [ebp-16] = temporary swap value
        ;

        ; Use the last element of the range as the pivot.
        mov     eax, [ebp+16]       ; EAX: hi
        mov     ecx, [ebp+8]        ; ECX: arr
        mov     edx, [ecx+eax*4]    ; EDX: arr[hi]
        mov     [ebp-8], edx        ; pivot = arr[hi]

        ; i marks the end of the <= pivot portion.
        mov     eax, [ebp+12]       ; EAX: lo
        dec     eax
        mov     [ebp-4], eax        ; i = lo - 1

        ; j scans the range from lo through hi - 1.
        mov     eax, [ebp+12]
        mov     [ebp-12], eax       ; j = lo

.loop:
        mov     eax, [ebp-12]       ; EAX: j
        cmp     eax, [ebp+16]       ; stop when j reaches hi
        jge     .after_loop

        mov     ecx, [ebp+8]        ; ECX: arr
        mov     edx, [ecx+eax*4]    ; EDX: arr[j]
        cmp     edx, [ebp-8]        ; compare arr[j] with pivot
        jg      .next               ; signed: skip if arr[j] > pivot

        ;
        ; arr[j] belongs on the <= pivot side.
        ; Advance i and swap arr[i] with arr[j].
        ;

        inc     dword [ebp-4]       ; i = i + 1

        mov     eax, [ebp-4]        ; EAX: i
        mov     edx, [ecx+eax*4]    ; EDX: arr[i]
        mov     [ebp-16], edx       ; save old arr[i]

        mov     edx, [ebp-12]       ; EDX: j
        mov     edx, [ecx+edx*4]    ; EDX: arr[j]
        mov     [ecx+eax*4], edx    ; arr[i] = arr[j]

        mov     eax, [ebp-12]       ; EAX: j
        mov     edx, [ebp-16]       ; EDX: old arr[i]
        mov     [ecx+eax*4], edx    ; arr[j] = old arr[i]

.next:
        inc     dword [ebp-12]      ; j = j + 1
        jmp     .loop

.after_loop:
        ;
        ; Put the pivot into its final sorted position at i + 1.
        ;

        mov     eax, [ebp-4]
        inc     eax                 ; EAX: p = i + 1

        mov     ecx, [ebp+8]        ; ECX: arr
        mov     edx, [ecx+eax*4]    ; EDX: arr[p]
        mov     [ebp-16], edx       ; save old arr[p]

        mov     edx, [ebp+16]       ; EDX: hi
        mov     edx, [ecx+edx*4]    ; EDX: pivot at arr[hi]
        mov     [ecx+eax*4], edx    ; arr[p] = pivot

        mov     edx, [ebp+16]       ; EDX: hi
        mov     eax, [ebp-16]       ; EAX: old arr[p]
        mov     [ecx+edx*4], eax    ; arr[hi] = old arr[p]

        ; Return the pivot's final index in EAX.
        mov     eax, [ebp-4]
        inc     eax                 ; EAX: p = i + 1

        leave
        ret