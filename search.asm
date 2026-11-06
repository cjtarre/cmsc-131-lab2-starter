;
; search.asm - bsearch_asm, a recursive binary search callable from C.
;
; This is your starting point: it assembles and links as-is, so the build
; works before you write any code. Right now it always returns 0, which
; makes the benchmark report a match at index 0 for any key. Your job is to
; replace that with the search described below.
;
; The contract, from bench.c:
;
;       int key                    [ebp+16]
;       int n                      [ebp+12]
;       int *arr                   [ebp+8]
;
; Return the index of key in the sorted array, or -1 if it is absent.
; Preserve ebx/esi/edi/ebp, return in eax, and obey cdecl for the outer
; routine (the internal recursive one may use any convention you document).
;
; Requirements from the manual:
;
;   * Recursive.
;   * Compute the midpoint as lo + (hi - lo) / 2, never (lo + hi) / 2.
;     The sum can overflow 32 bits on large arrays. The difference cannot.
;     This exact bug lived in the Java standard library for nine years.
;   * An absent key returns -1.
;   * An empty array and a single-element array must behave.
;   * No calls into the C standard library.
;
; The manual's pseudocode:
;
;   bsearch(arr, lo, hi, key):
;       if lo > hi: return -1
;       mid = lo + (hi - lo) / 2
;       if arr[mid] == key: return mid
;       if arr[mid] < key:  return bsearch(arr, mid + 1, hi, key)
;       else:               return bsearch(arr, lo, mid - 1, key)
;

;element size in bytes
%define INT_SIZE          4

; stack offsets for caller _bsearch_asm
%define ARG_ARR_CALLER    ebp + 8
%define ARG_N_CALLER      ebp + 12
%define ARG_KEY_CALLER    ebp + 16

; stack offsets for bsearch_recurse
%define ARG_ARR           ebp + 8
%define ARG_LO            ebp + 12
%define ARG_HI            ebp + 16
%define ARG_KEY           ebp + 20

; for 4 args since 4*4
%define BSEARCH_ARGS_SIZE 16

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _bsearch_asm bsearch_asm
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _bsearch_asm
_bsearch_asm:
        enter   0,0

        ;solve for hi
        mov     ecx, [ARG_N_CALLER]     ;load n to ecx
        dec     ecx                     ;hi=n-1
        
        ; load other arguments then push arguments first before calling the function
        push    dword [ARG_KEY_CALLER]  ;key
        push    ecx                     ; hi
        push    dword 0                 ;lo
        push    dword [ARG_ARR_CALLER]  ;arr

        call    bsearch_recurse
        add     esp, BSEARCH_ARGS_SIZE  ;discard args



        leave
        ret

bsearch_recurse:
        enter   0,0

        mov     ecx, [ARG_LO]           ;load lo to exc
        mov     edx, [ARG_HI]           ;load hi to edx

        ;return -1 if lo > hi
        cmp     ecx, edx
        jg      .absent


        ; compute hi - lo
        mov     eax, edx                ;copy edx to eax so eax is hi
        sub     eax, ecx                ; eax = hi - lo

        ; compute (hi-lo)/2 by signed div
        cdq                             ; sign extend
        mov     ecx, 2
        idiv    ecx                     ; eax = (hi-lo)/2

        ; compute m/index = lo+(hi-lo)/2
        add     eax, [ARG_LO]           ; eax = mid index = lo + (hi-lo)/2 


        mov     ecx, [ARG_ARR]          ;load arr to ecx
        ; ecx= arr[mid], mid here is just index so to get the address
        ; mem add = base address or arr + index x element size in bytes
        mov     ecx, [ecx+ eax*INT_SIZE]   
        
        ;compare to key  if same then return mid, if less than search to right
        cmp     ecx, [ARG_KEY]           
        je      .done
        jl      .search_right

        ;else search to the left
        lea     ecx, [eax-1]            ;ecx = mid index - 1

        ;push arguments from right to left
        push    dword [ARG_KEY]         ;key
        push    ecx                     ; hi=mid - 1
        push    dword [ARG_LO]          ;lo
        push    dword [ARG_ARR]         ;arr
        call    bsearch_recurse 
        add     esp, BSEARCH_ARGS_SIZE  ; removes the arguments 
        jmp     .done                   


.absent:
        mov     eax, -1
        jmp     .done


.search_right:
        inc     eax                     ; incr index so mid + 1
        ;push arguments right to left
        push    dword [ARG_KEY]         ;key
        push    dword [ARG_HI]          ; hi
        push    eax                     ; lo = mid+1
        push    dword [ARG_ARR]         ;arr
        call    bsearch_recurse
        add     esp, BSEARCH_ARGS_SIZE  ;clear args
        jmp     .done



.done:
        leave
        ret