use32
global interrupt_init
extern panic
extern interrupt
extern lowmem

%include "consts.asm"

%define IDT_SIZE 0x1000

%define PIC1 0x20
%define PIC2 0xa0
%define COMMAND 0
%define DATA    1

interrupt_init:
    ; init PIC
    call pic_init

    ; build IDT:
    %define IDT_PRESENT 0x80
    %define IDT_INT32   0x0e

    ; ENTRY(vector, offset, segment, type)
    %macro ENTRY 4
        mov eax, %2 ; offset lo
        mov [idt + ((%1) * 8) + 0], ax
        mov [idt + ((%1) * 8) + 2], word %3 ; segment
        mov [idt + ((%1) * 8) + 4], word (%4) << 8 ; type
        shr eax, 16 ; offset hi
        mov [idt + ((%1) * 8) + 6], ax
    %endmacro

    ; DISPATCH_E(vector, name) - dispatch interrupt with error code
    %macro DISPATCH_E 2
        %2:
            push dword %1
            jmp interrupt_common
    %endmacro

    ; DISPATCH_0(vector, name) - dispatch interrupt without error code
    %macro DISPATCH_0 2
        %2:
            push dword 0
            push dword %1
            jmp interrupt_common
    %endmacro

    ENTRY 0x00, divide_by_zero,             SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x01, debug,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x02, nmi,                        SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x03, breakpoint,                 SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x04, overflow,                   SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x05, bound_range_exceeded,       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x06, invalid_opcode,             SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x07, device_not_available,       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x08, double_fault,               SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x0a, invalid_tss,                SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x0b, segment_not_present,        SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x0c, stack_segment_fault,        SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x0d, general_protection_fault,   SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x0e, page_fault,                 SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x10, x87_exception,              SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x11, alignment_check,            SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x12, machine_check,              SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x13, simd_exception,             SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x14, virtualization_exception,   SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x1e, security_exception,         SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x20, irq0,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x21, irq1,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x22, irq2,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x23, irq3,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x24, irq4,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x25, irq5,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x26, irq6,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x27, irq7,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x28, irq8,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x29, irq9,                       SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2a, irq10,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2b, irq11,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2c, irq12,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2d, irq13,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2e, irq14,                      SEG_KCODE, IDT_PRESENT | IDT_INT32
    ENTRY 0x2f, irq15,                      SEG_KCODE, IDT_PRESENT | IDT_INT32

    ; load IDT
    lidt [idtr]
    ret

DISPATCH_0 0x06, invalid_opcode
DISPATCH_E 0x0d, general_protection_fault
DISPATCH_E 0x0e, page_fault

; IRQ dispatchers
; note: IRQ7 and IRQ15 handlers require special handling due to spurious
; interrupts
DISPATCH_0 0x20, irq0
DISPATCH_0 0x21, irq1
DISPATCH_0 0x22, irq2
DISPATCH_0 0x23, irq3
DISPATCH_0 0x24, irq4
DISPATCH_0 0x25, irq5
DISPATCH_0 0x26, irq6
; DISPATCH_0 0x27, irq7
DISPATCH_0 0x28, irq8
DISPATCH_0 0x29, irq9
DISPATCH_0 0x2a, irq10
DISPATCH_0 0x2b, irq11
DISPATCH_0 0x2c, irq12
DISPATCH_0 0x2d, irq13
DISPATCH_0 0x2e, irq14
; DISPATCH_0 0x2f, irq15

interrupt_common:
    push ds
    push es
    pusha
    mov ax, SEG_KDATA
    mov ds, ax
    mov es, ax
    push esp
    call interrupt
    add esp, 4
    popa
    pop es
    pop ds
    add esp, 8
    iret

pic_init:
    ; save pic masks, PIC1 in BL and PIC2 in BH
    in al, PIC2 + DATA
    mov ah, al
    in al, PIC1 + DATA
    ; reinitialise PICs
    mov al, 0x11
    out PIC1 + COMMAND, al
    out PIC2 + COMMAND, al
    ; set interrupt vector offsets for PICs
    mov al, 0x20
    out PIC1 + DATA, al
    mov al, 0x28
    out PIC2 + DATA, al
    ;
    mov al, 0x04
    out PIC1 + DATA, al
    mov al, 0x02
    out PIC2 + DATA, al

    mov al, 0x01
    out PIC1 + DATA, al
    out PIC2 + DATA, al
    ; restore saved masks
    mov ax, bx
    out PIC1 + DATA, al
    mov al, ah
    out PIC2 + DATA, al
    ret

%macro DISPATCH_PANIC 1
    push ds
    push es
    mov ax, SEG_KDATA
    mov ds, ax
    mov es, ax
    push .msg
    call panic
    cli
    hlt
    .msg db "Unhandled CPU exception: ", %1, 0
%endmacro

divide_by_zero:
    DISPATCH_PANIC "divide by zero"

debug:
    DISPATCH_PANIC "debug"

nmi:
    DISPATCH_PANIC "non-maskable interrupt"

breakpoint:
    DISPATCH_PANIC "breakpoint"

overflow:
    DISPATCH_PANIC "overflow"

bound_range_exceeded:
    DISPATCH_PANIC "bound range exceeded"

device_not_available:
    DISPATCH_PANIC "device not available"

double_fault:
    DISPATCH_PANIC "double fault"

invalid_tss:
    DISPATCH_PANIC "invalid tss"

segment_not_present:
    DISPATCH_PANIC "segment not present"

stack_segment_fault:
    DISPATCH_PANIC "stack segment fault"

x87_exception:
    DISPATCH_PANIC "x87 exception"

alignment_check:
    DISPATCH_PANIC "alignment check"

machine_check:
    DISPATCH_PANIC "machine check"

simd_exception:
    DISPATCH_PANIC "simd exception"

virtualization_exception:
    DISPATCH_PANIC "virtualization exception"

security_exception:
    DISPATCH_PANIC "security exception"

; IRQ 2 is missing - it never happens in practise

; LPT1/spurious
irq7:
    ; we need to test whether this was a genuine IRQ or spurious
    push ax
    mov al, 0x0b ; read in-service register from PIC1
    out PIC1 + COMMAND, al
    in al, PIC1 + COMMAND
    bt ax, 7
    ; if bit 7 is not set on PIC1, this was a spurious IRQ
    jnc .spurious
    ; dispatch interrupt if legit
    pop ax
    push 0      ; error code - unused
    push 0x27   ; interrupt number
    jmp interrupt_common
.spurious:
    ; ignore it otherwise
    pop ax
    iret

; ATA2/spurious
irq15:
    ; we need to test whether this was a genuine IRQ or spurious
    push ax
    mov al, 0x0b ; read in-service register from PIC2
    out PIC2 + COMMAND, al
    in al, PIC2 + COMMAND
    bt ax, 7
    ; if bit 7 is not set on PIC2, this was a spurious IRQ
    jnc .spurious
    ; dispatch interrupt if legit
    pop ax
    push 0      ; error code - unused
    push 0x2f   ; interrupt number
    jmp interrupt_common
.spurious:
    ; ignore it otherwise
    pop ax
    iret

align 4
idtr:
    dw IDT_SIZE - 1
    dd idt

section .bss
idt resb IDT_SIZE
