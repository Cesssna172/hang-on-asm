# Triple-buffered 22050 Hz / 16-bit / mono procedural engine synthesizer.
# The program also runs when no audio output device is available.
audio_init:
    FRAME
    lea rcx, [rip+wave_handle]
    mov edx, -1
    lea r8, [rip+wave_format]
    xor r9d, r9d
    mov QWORD PTR [rsp+32], 0
    mov QWORD PTR [rsp+40], 0
    call waveOutOpen
    test eax, eax
    jnz .Laudio_unavailable
    mov DWORD PTR [rip+audio_ready], 1
    lea rdi, [rip+wave_headers]
    lea rsi, [rip+wave_buffers]
    mov ebx, 3
.Lprepare_audio:
    mov [rdi], rsi
    mov DWORD PTR [rdi+8], 2048
    mov rcx, [rip+wave_handle]
    mov rdx, rdi
    mov r8d, 48
    call waveOutPrepareHeader
    test eax, eax
    jnz .Lprepare_failed
    add rdi, 48
    add rsi, 2048
    dec ebx
    jnz .Lprepare_audio
    RETURN
.Lprepare_failed:
    call audio_shutdown
.Laudio_unavailable:
    mov DWORD PTR [rip+muted], 1
    RETURN

audio_pump:
    FRAME
    cmp DWORD PTR [rip+audio_ready], 0
    je .Laudio_pump_done
    lea rdi, [rip+wave_headers]
    mov ebx, 3
.Laudio_header:
    mov eax, [rdi+24]
    test eax, 16
    jnz .Laudio_next
    mov rsi, [rdi]
    mov eax, [rip+speed]
    shr eax, 1
    add eax, 44
    imul r12d, eax, 194783
    mov r13d, [rip+audio_phase]
    mov r14d, 1024
    mov r15d, 0
    cmp DWORD PTR [rip+muted], 0
    jne .Laudio_samples
    cmp DWORD PTR [rip+state], STATE_RACE
    jne .Laudio_samples
    mov r15d, 1
.Laudio_samples:
    add r13d, r12d
    mov eax, r13d
    shr eax, 16
    sub eax, 32768
    sar eax, 4
    # A second harmonic gives the low-resolution exhaust its rasp.
    lea edx, [r13+r13]
    shr edx, 16
    sub edx, 32768
    sar edx, 6
    add eax, edx
    imul eax, r15d
    mov WORD PTR [rsi], ax
    add rsi, 2
    dec r14d
    jnz .Laudio_samples
    mov [rip+audio_phase], r13d
    mov rcx, [rip+wave_handle]
    mov rdx, rdi
    mov r8d, 48
    call waveOutWrite
.Laudio_next:
    add rdi, 48
    dec ebx
    jnz .Laudio_header
.Laudio_pump_done:
    RETURN

audio_shutdown:
    FRAME
    cmp DWORD PTR [rip+audio_ready], 0
    je .Laudio_shutdown_done
    mov rcx, [rip+wave_handle]
    call waveOutReset
    lea rdi, [rip+wave_headers]
    mov ebx, 3
.Lunprepare_audio:
    test DWORD PTR [rdi+24], 2
    jz .Lunprepare_next
    mov rcx, [rip+wave_handle]
    mov rdx, rdi
    mov r8d, 48
    call waveOutUnprepareHeader
.Lunprepare_next:
    add rdi, 48
    dec ebx
    jnz .Lunprepare_audio
    mov rcx, [rip+wave_handle]
    call waveOutClose
    mov DWORD PTR [rip+audio_ready], 0
.Laudio_shutdown_done:
    RETURN
