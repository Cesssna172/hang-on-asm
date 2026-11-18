.intel_syntax noprefix
# Windows x64. All game, graphics and audio code is assembly.
.equ WIDTH, 320
.equ HEIGHT, 224
.equ FRAME_MS, 16
.equ STAGE_LENGTH, 360000
.equ STATE_TITLE, 0
.equ STATE_COUNTDOWN, 1
.equ STATE_RACE, 2
.equ STATE_PAUSE, 3
.equ STATE_FINISH, 4
.equ STATE_OVER, 5
.equ STATE_SCORES, 6

# Preserve every nonvolatile general-purpose register and provide aligned
# outgoing argument space. Locals occupy rbp-64 through rbp-112.
.macro FRAME
    push rbp
    mov rbp, rsp
    sub rsp, 256
    mov [rbp-8], rbx
    mov [rbp-16], rsi
    mov [rbp-24], rdi
    mov [rbp-32], r12
    mov [rbp-40], r13
    mov [rbp-48], r14
    mov [rbp-56], r15
.endm
.macro RETURN
    mov rbx, [rbp-8]
    mov rsi, [rbp-16]
    mov rdi, [rbp-24]
    mov r12, [rbp-32]
    mov r13, [rbp-40]
    mov r14, [rbp-48]
    mov r15, [rbp-56]
    mov rsp, rbp
    pop rbp
    ret
.endm
.macro BOX x, y, w, h, color
    mov ecx, \x
    mov edx, \y
    mov r8d, \w
    mov r9d, \h
    mov DWORD PTR [rsp+32], \color
    call draw_rect
.endm
.macro LABEL x, y, string, color, font
    mov ecx, \x
    mov edx, \y
    lea r8, [rip+\string]
    mov r9d, \color
    mov rax, [rip+\font]
    mov [rsp+32], rax
    call draw_text
.endm

.section .text
.global start
start:
    FRAME
    call GetCommandLineA
    mov rcx, rax
    call is_self_test
    test eax, eax
    jz .Lnormal_start
    call self_test
    mov ecx, eax
    call ExitProcess
.Lnormal_start:
    xor ecx, ecx
    call GetModuleHandleA
    mov [rip+instance], rax
    mov [rip+window_class+24], rax
    xor ecx, ecx
    mov edx, 32512
    call LoadCursorA
    mov [rip+window_class+40], rax
    lea rcx, [rip+window_class]
    call RegisterClassExA
    test eax, eax
    jz .Lfatal
    # Calculate the outer rectangle for a 960 x 600 client area.
    lea rcx, [rip+initial_rect]
    mov edx, 0x00cf0000
    xor r8d, r8d
    call AdjustWindowRect
    xor ecx, ecx
    lea rdx, [rip+class_name]
    lea r8, [rip+window_title]
    mov r9d, 0x00cf0000
    mov DWORD PTR [rsp+32], 0x80000000
    mov DWORD PTR [rsp+40], 0x80000000
    mov eax, [rip+initial_rect+8]
    sub eax, [rip+initial_rect]
    mov [rsp+48], eax
    mov eax, [rip+initial_rect+12]
    sub eax, [rip+initial_rect+4]
    mov [rsp+56], eax
    mov QWORD PTR [rsp+64], 0
    mov QWORD PTR [rsp+72], 0
    mov rax, [rip+instance]
    mov [rsp+80], rax
    mov QWORD PTR [rsp+88], 0
    call CreateWindowExA
    test rax, rax
    jz .Lfatal
    mov [rip+window], rax
    xor ecx, ecx
    call CreateCompatibleDC
    mov [rip+memory_dc], rax
    mov rcx, rax
    lea rdx, [rip+bitmap_info]
    xor r8d, r8d
    lea r9, [rip+pixels]
    mov QWORD PTR [rsp+32], 0
    mov DWORD PTR [rsp+40], 0
    call CreateDIBSection
    test rax, rax
    jz .Lfatal
    mov [rip+bitmap], rax
    mov rcx, [rip+memory_dc]
    mov rdx, rax
    call SelectObject
    mov [rip+old_bitmap], rax
    mov QWORD PTR [rip+font_small], 1
    mov QWORD PTR [rip+font_medium], 1
    mov QWORD PTR [rip+font_large], 2
    call audio_init
    call reset_game
    mov DWORD PTR [rip+state], STATE_TITLE
    mov DWORD PTR [rip+speed], 160
    mov rcx, [rip+window]
    mov edx, 5
    call ShowWindow
    mov ecx, 1
    call timeBeginPeriod
    call GetTickCount64
    imul rax, 60
    mov r12, rax
.Lmain_loop:
    lea rcx, [rip+message]
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    mov DWORD PTR [rsp+32], 1
    call PeekMessageA
    test eax, eax
    jz .Lclock
    cmp DWORD PTR [rip+message+8], 0x12
    je .Lexit
    lea rcx, [rip+message]
    call TranslateMessage
    lea rcx, [rip+message]
    call DispatchMessageA
    jmp .Lmain_loop
.Lclock:
    call GetTickCount64
    imul rax, 60
    mov r13, rax
    sub rax, r12
    cmp rax, 1000
    jb .Lidle
    # At most five fixed updates after a stall. Drop the excess backlog.
    cmp rax, 5000
    jbe .Lcatch_up
    lea r12, [r13-5000]
.Lcatch_up:
    call update_game
    add r12, 1000
    mov rax, r13
    sub rax, r12
    cmp rax, 1000
    jae .Lcatch_up
    call audio_pump
    call render_frame
    mov rcx, [rip+window]
    xor edx, edx
    xor r8d, r8d
    call InvalidateRect
    mov rcx, [rip+window]
    call UpdateWindow
    jmp .Lmain_loop
.Lidle:
    mov ecx, 1
    call Sleep
    jmp .Lmain_loop
.Lexit:
    call audio_shutdown
    mov ecx, 1
    call timeEndPeriod
    mov rcx, [rip+memory_dc]
    mov rdx, [rip+old_bitmap]
    call SelectObject
    mov rcx, [rip+bitmap]
    call DeleteObject
    mov rcx, [rip+memory_dc]
    call DeleteDC
    xor ecx, ecx
    call ExitProcess
.Lfatal:
    xor ecx, ecx
    lea rdx, [rip+error_text]
    lea r8, [rip+window_title]
    mov r9d, 0x10
    call MessageBoxA
    mov ecx, 1
    call ExitProcess
    RETURN

window_proc:
    FRAME
    mov r12, rcx
    mov r13d, edx
    mov r14, r8
    mov r15, r9
    cmp edx, 0x0f
    je .Lpaint
    cmp edx, 0x02
    je .Ldestroy
    cmp edx, 0x14
    je .Lerase
    cmp edx, 0x24
    je .Lmin_size
    cmp edx, 0x08
    je .Llost_focus
    cmp edx, 0x100
    je .Lkey_down
    cmp edx, 0x101
    je .Lkey_up
.Ldefault_message:
    mov rcx, r12
    mov edx, r13d
    mov r8, r14
    mov r9, r15
    call DefWindowProcA
    RETURN
.Lpaint:
    mov rcx, r12
    lea rdx, [rip+paint_struct]
    call BeginPaint
    mov rbx, rax
    mov rcx, r12
    lea rdx, [rip+client_rect]
    call GetClientRect
    cmp QWORD PTR [rip+pixels], 0
    je .Lend_paint
    # Aspect-correct letterboxing with nearest-neighbour pixel scaling.
    mov r14d, [rip+client_rect+8]
    mov r15d, [rip+client_rect+12]
    test r14d, r14d
    jz .Lend_paint
    test r15d, r15d
    jz .Lend_paint
    mov rcx, rbx
    xor edx, edx
    xor r8d, r8d
    mov r9d, r14d
    mov [rsp+32], r15d
    mov DWORD PTR [rsp+40], 0x00000042
    call PatBlt
    mov eax, r15d
    imul eax, 4
    xor edx, edx
    mov ecx, 3
    div ecx
    cmp eax, r14d
    jbe .Lwidth_from_height
    mov eax, r14d
    imul eax, 3
    xor edx, edx
    mov ecx, 4
    div ecx
    mov [rip+draw_height], eax
    mov [rip+draw_width], r14d
    jmp .Lblit
.Lwidth_from_height:
    mov [rip+draw_width], eax
    mov [rip+draw_height], r15d
.Lblit:
    mov rcx, rbx
    mov edx, 3
    call SetStretchBltMode
    mov rcx, rbx
    mov edx, r14d
    sub edx, [rip+draw_width]
    sar edx, 1
    mov r8d, r15d
    sub r8d, [rip+draw_height]
    sar r8d, 1
    mov r9d, [rip+draw_width]
    mov eax, [rip+draw_height]
    mov [rsp+32], eax
    mov rax, [rip+memory_dc]
    mov [rsp+40], rax
    mov QWORD PTR [rsp+48], 0
    mov QWORD PTR [rsp+56], 0
    mov DWORD PTR [rsp+64], WIDTH
    mov DWORD PTR [rsp+72], HEIGHT
    mov DWORD PTR [rsp+80], 0x00cc0020
    call StretchBlt
.Lend_paint:
    mov rcx, r12
    lea rdx, [rip+paint_struct]
    call EndPaint
    xor eax, eax
    RETURN
.Lmin_size:
    mov DWORD PTR [r15+24], 656
    mov DWORD PTR [r15+28], 439
    xor eax, eax
    RETURN
.Lkey_down:
    cmp r14d, 255
    ja .Lhandled
    lea rax, [rip+keys]
    cmp BYTE PTR [rax+r14], 0
    jne .Lhandled
    mov BYTE PTR [rax+r14], 1
    mov ecx, r14d
    call handle_key
    jmp .Lhandled
.Lkey_up:
    cmp r14d, 255
    ja .Lhandled
    lea rax, [rip+keys]
    mov BYTE PTR [rax+r14], 0
    jmp .Lhandled
.Llost_focus:
    lea rdi, [rip+keys]
    xor eax, eax
    mov ecx, 32
    rep stosq
    mov eax, [rip+state]
    cmp eax, STATE_RACE
    je .Lauto_pause
    cmp eax, STATE_COUNTDOWN
    jne .Lhandled
.Lauto_pause:
    mov [rip+resume_state], eax
    mov DWORD PTR [rip+state], STATE_PAUSE
.Lhandled:
    xor eax, eax
    RETURN
.Ldestroy:
    xor ecx, ecx
    call PostQuitMessage
    xor eax, eax
    RETURN
.Lerase:
    mov eax, 1
    RETURN

.include "src/game.s"
.include "src/render.s"
.include "src/audio.s"
.include "src/data.s"
.include "src/art.s"
