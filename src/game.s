# Fixed 60 Hz simulation. World positions and speeds use integer units.
reset_game:
    FRAME
    xor eax, eax
    mov [rip+speed], eax
    mov [rip+player_x], eax
    mov [rip+lean], eax
    mov [rip+distance], eax
    mov [rip+score], eax
    mov [rip+crash_ticks], eax
    mov [rip+checkpoint_ticks], eax
    mov [rip+curve], eax
    mov [rip+elapsed_ticks], eax
    mov [rip+timer_fraction], eax
    mov [rip+wobble_ticks], eax
    mov [rip+ending_ticks], eax
    mov [rip+entry_index], eax
    mov DWORD PTR [rip+stage], 1
    mov DWORD PTR [rip+time_left], 75000
    mov DWORD PTR [rip+countdown], 180
    mov DWORD PTR [rip+state], STATE_COUNTDOWN
    mov DWORD PTR [rip+random_seed], 0x46b18a2f
    lea rdi, [rip+traffic]
    xor ebx, ebx
.Lreset_traffic:
    mov eax, ebx
    imul eax, 2300
    add eax, 4500
    mov [rdi], eax
    call random_next
    xor edx, edx
    mov ecx, 1200
    div ecx
    sub edx, 600
    mov [rdi+4], edx
    call random_next
    and eax, 31
    add eax, 180
    mov [rdi+8], eax
    mov [rdi+12], ebx
    add rdi, 16
    inc ebx
    cmp ebx, 10
    jb .Lreset_traffic
    RETURN

random_next:
    mov eax, [rip+random_seed]
    imul eax, eax, 1664525
    add eax, 1013904223
    mov [rip+random_seed], eax
    shr eax, 1
    ret

handle_key:
    FRAME
    cmp DWORD PTR [rip+state], STATE_SCORES
    je .Lname_input
    cmp ecx, 0x1b
    je .Lescape
    cmp ecx, 'M'
    je .Lmute
    cmp ecx, 'R'
    je .Lrestart
    cmp ecx, 0x0d
    je .Lenter
    cmp ecx, 'P'
    je .Lpause
    RETURN
.Lmute:
    xor DWORD PTR [rip+muted], 1
    RETURN
.Lescape:
    cmp DWORD PTR [rip+state], STATE_TITLE
    je .Lclose_window
    mov DWORD PTR [rip+state], STATE_TITLE
    mov DWORD PTR [rip+speed], 160
    mov DWORD PTR [rip+player_x], 0
    mov DWORD PTR [rip+crash_ticks], 0
    RETURN
.Lclose_window:
    mov rcx, [rip+window]
    call DestroyWindow
    RETURN
.Lenter:
    cmp DWORD PTR [rip+state], STATE_PAUSE
    je .Lunpause
    cmp DWORD PTR [rip+state], STATE_RACE
    je .Lpause
    cmp DWORD PTR [rip+state], STATE_COUNTDOWN
    je .Lpause
.Lrestart:
    call reset_game
    RETURN
.Lpause:
    mov eax, [rip+state]
    cmp eax, STATE_PAUSE
    je .Lunpause
    cmp eax, STATE_RACE
    je .Lset_pause
    cmp eax, STATE_COUNTDOWN
    jne .Lkey_return
.Lset_pause:
    mov [rip+resume_state], eax
    mov DWORD PTR [rip+state], STATE_PAUSE
.Lkey_return:
    RETURN
.Lunpause:
    mov eax, [rip+resume_state]
    mov [rip+state], eax
    RETURN

.Lname_input:
    cmp ecx, 13
    je .Lsave_name
    cmp ecx, 27
    je .Lsave_name
    cmp DWORD PTR [rip+score_rank], 0
    jl .Lname_done
    mov eax, [rip+entry_index]
    cmp ecx, 0x25
    je .Lprevious_initial
    cmp ecx, 0x27
    je .Lnext_initial
    lea rdx, [rip+initials]
    cmp ecx, 0x26
    je .Linitial_up
    cmp ecx, 0x28
    je .Linitial_down
    cmp ecx, 'A'
    jb .Lname_done
    cmp ecx, 'Z'
    ja .Lname_done
    mov [rdx+rax], cl
    jmp .Lnext_initial
.Linitial_up:
    inc BYTE PTR [rdx+rax]
    cmp BYTE PTR [rdx+rax], 'Z'
    jbe .Lname_done
    mov BYTE PTR [rdx+rax], 'A'
    jmp .Lname_done
.Linitial_down:
    dec BYTE PTR [rdx+rax]
    cmp BYTE PTR [rdx+rax], 'A'
    jae .Lname_done
    mov BYTE PTR [rdx+rax], 'Z'
    jmp .Lname_done
.Lprevious_initial:
    dec eax
    jns .Lset_initial
    mov eax, 2
    jmp .Lset_initial
.Lnext_initial:
    inc eax
    cmp eax, 3
    jb .Lset_initial
    xor eax, eax
.Lset_initial:
    mov [rip+entry_index], eax
.Lname_done:
    RETURN
.Lsave_name:
    mov eax, [rip+score_rank]
    test eax, eax
    js .Lname_saved
    lea rdx, [rip+record_names]
    mov ecx, [rip+initials]
    mov [rdx+rax*4], ecx
.Lname_saved:
    mov eax, [rip+score]
    cmp eax, [rip+best_score]
    jle .Lsaved_best
    mov [rip+best_score], eax
.Lsaved_best:
    mov DWORD PTR [rip+state], STATE_TITLE
    mov DWORD PTR [rip+distance], 0
    mov DWORD PTR [rip+speed], 160
    RETURN

update_game:
    FRAME
    mov eax, [rip+state]
    cmp eax, STATE_PAUSE
    je .Lupdate_return
    cmp eax, STATE_FINISH
    jae .Lending_update
    inc DWORD PTR [rip+animation]
    cmp eax, STATE_TITLE
    je .Lattract
    cmp eax, STATE_COUNTDOWN
    jne .Lracing
    dec DWORD PTR [rip+countdown]
    jnz .Lupdate_return
    mov DWORD PTR [rip+state], STATE_RACE
    jmp .Lupdate_return
.Lracing:
    mov eax, [rip+timer_fraction]
    add eax, 1000
    xor edx, edx
    mov ecx, 60
    div ecx
    mov [rip+timer_fraction], edx
    sub [rip+time_left], eax
    inc DWORD PTR [rip+elapsed_ticks]
    cmp DWORD PTR [rip+time_left], 0
    jg .Ltime_ok
    mov DWORD PTR [rip+time_left], 0
    mov DWORD PTR [rip+state], STATE_OVER
    jmp .Lupdate_return
.Ltime_ok:
    cmp DWORD PTR [rip+wobble_ticks], 0
    je .Lwobble_done
    dec DWORD PTR [rip+wobble_ticks]
.Lwobble_done:
    cmp DWORD PTR [rip+checkpoint_ticks], 0
    je .Lcheckpoint_tick_done
    dec DWORD PTR [rip+checkpoint_ticks]
.Lcheckpoint_tick_done:
    cmp DWORD PTR [rip+crash_ticks], 0
    je .Ldrive
    dec DWORD PTR [rip+crash_ticks]
    mov eax, [rip+player_x]
    imul eax, 15
    cdq
    mov ecx, 16
    idiv ecx
    mov [rip+player_x], eax
    mov DWORD PTR [rip+lean], 0
    jmp .Lmove
.Ldrive:
    mov eax, [rip+speed]
    lea rbx, [rip+keys]
    cmp BYTE PTR [rbx+0x28], 0
    jne .Lbraking
    cmp BYTE PTR [rbx+'S'], 0
    jne .Lbraking
    cmp BYTE PTR [rbx+0x20], 0
    jne .Lbraking
    cmp BYTE PTR [rbx+0x26], 0
    jne .Laccelerating
    cmp BYTE PTR [rbx+'W'], 0
    jne .Laccelerating
    sub eax, 2
    jmp .Lspeed_bounds
.Lbraking:
    sub eax, 5
    jmp .Lspeed_bounds
.Laccelerating:
    inc eax
.Lspeed_bounds:
    xor ecx, ecx
    cmp eax, ecx
    cmovl eax, ecx
    mov ecx, 280
    cmp eax, ecx
    cmovg eax, ecx
    mov [rip+speed], eax
    xor r12d, r12d
    cmp BYTE PTR [rbx+0x25], 0
    jne .Lsteer_left
    cmp BYTE PTR [rbx+'A'], 0
    je .Lcheck_right
.Lsteer_left:
    dec r12d
.Lcheck_right:
    cmp BYTE PTR [rbx+0x27], 0
    jne .Lsteer_right
    cmp BYTE PTR [rbx+'D'], 0
    je .Lsteer
.Lsteer_right:
    inc r12d
.Lsteer:
    mov eax, [rip+speed]
    imul eax, r12d
    cdq
    mov ecx, 24
    idiv ecx
    add [rip+player_x], eax
    imul r12d, 12
    mov eax, [rip+lean]
    sub r12d, eax
    test r12d, r12d
    jle .Llean_round
    add r12d, 3
.Llean_round:
    sar r12d, 2
    add eax, r12d
    mov [rip+lean], eax
    # Centrifugal drift grows with speed and bend severity.
    mov eax, [rip+curve]
    imul eax, [rip+speed]
    cdq
    mov ecx, 12000
    idiv ecx
    sub [rip+player_x], eax
    mov eax, [rip+player_x]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, 1120
    jl .Lcheck_grass
    cmp DWORD PTR [rip+speed], 120
    jle .Lcheck_grass
    mov DWORD PTR [rip+crash_ticks], 180
    mov DWORD PTR [rip+speed], 0
    jmp .Lmove
.Lcheck_grass:
    cmp eax, 760
    jle .Lmove
    cmp DWORD PTR [rip+speed], 80
    jle .Loffroad_clamp
    sub DWORD PTR [rip+speed], 4
.Loffroad_clamp:
    mov eax, [rip+player_x]
    mov ecx, 1250
    cmp eax, ecx
    cmovg eax, ecx
    mov ecx, -1250
    cmp eax, ecx
    cmovl eax, ecx
    mov [rip+player_x], eax
.Lmove:
    mov eax, [rip+speed]
    imul eax, 3
    shr eax, 3
    add [rip+distance], eax
    imul eax, 10
    add [rip+score], eax
    call update_traffic
    mov eax, [rip+stage]
    imul eax, STAGE_LENGTH
    cmp [rip+distance], eax
    jl .Lroad_curve
    cmp DWORD PTR [rip+stage], 5
    je .Lfinish_race
    inc DWORD PTR [rip+stage]
    add DWORD PTR [rip+time_left], 60000
    mov DWORD PTR [rip+checkpoint_ticks], 150
    add DWORD PTR [rip+score], 10000
    jmp .Lroad_curve
.Lfinish_race:
    mov DWORD PTR [rip+state], STATE_FINISH
    mov eax, [rip+time_left]
    shr eax, 2
    add [rip+score], eax
    jmp .Lupdate_return
.Lattract:
    add DWORD PTR [rip+distance], 20
    mov eax, [rip+animation]
    shr eax, 7
    and eax, 3
    inc eax
    mov [rip+stage], eax
    call update_traffic
.Lroad_curve:
    # Distinct reconstructed stage profiles, 32 interpolated spans per stage.
    mov eax, [rip+distance]
    xor edx, edx
    mov ecx, STAGE_LENGTH
    div ecx
    mov eax, edx
    xor edx, edx
    mov ecx, STAGE_LENGTH/32
    div ecx
    mov r12d, edx
    mov esi, eax
    lea rbx, [rip+curve_table]
    mov eax, [rip+stage]
    dec eax
    imul eax, 132
    add rbx, rax
    mov ecx, [rbx+rsi*4]
    mov eax, [rbx+rsi*4+4]
    sub eax, ecx
    imul eax, r12d
    cdq
    mov ebx, STAGE_LENGTH/32
    idiv ebx
    add eax, ecx
    mov [rip+curve], eax
.Lupdate_return:
    RETURN
.Lending_update:
    inc DWORD PTR [rip+animation]
    cmp eax, STATE_SCORES
    je .Lupdate_return
    inc DWORD PTR [rip+ending_ticks]
    cmp DWORD PTR [rip+ending_ticks], 300
    jb .Lupdate_return
    call prepare_scores
    mov DWORD PTR [rip+state], STATE_SCORES
    RETURN

prepare_scores:
    FRAME
    mov DWORD PTR [rip+score_rank], -1
    lea rdi, [rip+record_scores]
    lea rsi, [rip+record_names]
    mov eax, [rip+score]
    xor ebx, ebx
.Lrank_search:
    cmp eax, [rdi+rbx*4]
    jg .Lrank_insert
    inc ebx
    cmp ebx, 7
    jb .Lrank_search
    RETURN
.Lrank_insert:
    mov [rip+score_rank], ebx
    mov ecx, 6
.Lrank_shift:
    cmp ecx, ebx
    jle .Lrank_write
    mov edx, [rdi+rcx*4-4]
    mov [rdi+rcx*4], edx
    mov edx, [rsi+rcx*4-4]
    mov [rsi+rcx*4], edx
    dec ecx
    jmp .Lrank_shift
.Lrank_write:
    mov [rdi+rbx*4], eax
    mov edx, [rip+initials]
    mov [rsi+rbx*4], edx
    cmp eax, [rip+best_score]
    jle .Lrank_done
    mov [rip+best_score], eax
.Lrank_done:
    RETURN

update_traffic:
    FRAME
    lea rdi, [rip+traffic]
    mov ebx, 10
.Ltraffic_update:
    mov eax, [rdi+8]
    imul eax, 3
    shr eax, 3
    add [rdi], eax
    mov eax, [rdi]
    sub eax, [rip+distance]
    cmp eax, -450
    jl .Lrespawn
    cmp DWORD PTR [rip+state], STATE_RACE
    jne .Lnext_traffic
    cmp DWORD PTR [rip+crash_ticks], 0
    jne .Lnext_traffic
    cmp DWORD PTR [rip+wobble_ticks], 0
    jne .Lnext_traffic
    cmp eax, -180
    jl .Lnext_traffic
    cmp eax, 220
    jg .Lnext_traffic
    mov eax, [rdi+4]
    sub eax, [rip+player_x]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, 130
    jge .Lnext_traffic
    cmp DWORD PTR [rip+speed], 30
    jle .Lnext_traffic
    mov DWORD PTR [rip+wobble_ticks], 36
    mov eax, [rip+speed]
    sub eax, 65
    xor ecx, ecx
    cmp eax, ecx
    cmovl eax, ecx
    mov [rip+speed], eax
    mov DWORD PTR [rip+speed], 28
    jmp .Lnext_traffic
.Lrespawn:
    call random_next
    xor edx, edx
    mov ecx, 16000
    div ecx
    add edx, [rip+distance]
    add edx, 8000
    mov [rdi], edx
    call random_next
    xor edx, edx
    mov ecx, 1300
    div ecx
    sub edx, 650
    mov [rdi+4], edx
.Lnext_traffic:
    add rdi, 16
    dec ebx
    jnz .Ltraffic_update
    RETURN

is_self_test:
    # Command-line substring match, no C runtime.
    lea rdx, [rip+selftest_argument]
.Lscan_arg:
    cmp BYTE PTR [rcx], 0
    je .Lno_arg
    xor r8d, r8d
.Lmatch_arg:
    mov r9b, [rdx+r8]
    test r9b, r9b
    jz .Lhas_arg
    cmp [rcx+r8], r9b
    jne .Lscan_next
    inc r8d
    jmp .Lmatch_arg
.Lscan_next:
    inc rcx
    jmp .Lscan_arg
.Lhas_arg:
    mov eax, 1
    ret
.Lno_arg:
    xor eax, eax
    ret

self_test:
    FRAME
    call reset_game
    cmp DWORD PTR [rip+stage], 1
    jne .Ltest_fail
    mov ebx, 180
.Ltest_count:
    call update_game
    dec ebx
    jnz .Ltest_count
    cmp DWORD PTR [rip+state], STATE_RACE
    jne .Ltest_fail
    mov BYTE PTR [rip+keys+0x26], 1
    mov ebx, 300
.Ltest_accel:
    call update_game
    dec ebx
    jnz .Ltest_accel
    cmp DWORD PTR [rip+speed], 280
    jne .Ltest_fail
    mov r12d, [rip+distance]
    call update_game
    mov eax, [rip+distance]
    sub eax, r12d
    cmp eax, 105
    jne .Ltest_fail
    mov BYTE PTR [rip+keys+0x27], 1
    call update_game
    cmp DWORD PTR [rip+player_x], 0
    jle .Ltest_fail
    mov BYTE PTR [rip+keys+0x27], 0
    mov ecx, 'P'
    call handle_key
    mov r12d, [rip+distance]
    call update_game
    cmp [rip+distance], r12d
    jne .Ltest_fail
    mov ecx, 'P'
    call handle_key
    cmp DWORD PTR [rip+state], STATE_RACE
    jne .Ltest_fail
    mov BYTE PTR [rip+keys+0x28], 1
    call update_game
    cmp DWORD PTR [rip+speed], 275
    jne .Ltest_fail
    mov BYTE PTR [rip+keys+0x28], 0
    mov DWORD PTR [rip+distance], STAGE_LENGTH
    call update_game
    cmp DWORD PTR [rip+stage], 2
    jne .Ltest_fail
    cmp DWORD PTR [rip+checkpoint_ticks], 150
    jne .Ltest_fail
    mov DWORD PTR [rip+stage], 5
    mov DWORD PTR [rip+distance], 5*STAGE_LENGTH
    call update_game
    cmp DWORD PTR [rip+state], STATE_FINISH
    jne .Ltest_fail
    call reset_game
    mov DWORD PTR [rip+state], STATE_RACE
    mov DWORD PTR [rip+time_left], 1
    call update_game
    cmp DWORD PTR [rip+state], STATE_OVER
    jne .Ltest_fail
    call reset_game
    mov DWORD PTR [rip+state], STATE_RACE
    mov DWORD PTR [rip+speed], 200
    mov DWORD PTR [rip+player_x], 900
    call update_game
    cmp DWORD PTR [rip+speed], 197
    jne .Ltest_fail
    # Traffic collision at the player's world position.
    call reset_game
    mov DWORD PTR [rip+state], STATE_RACE
    mov DWORD PTR [rip+speed], 200
    mov DWORD PTR [rip+traffic], 25
    mov DWORD PTR [rip+traffic+4], 0
    call update_game
    cmp DWORD PTR [rip+wobble_ticks], 36
    jne .Ltest_fail
    # End-to-end: complete all stages through the actual update function.
    # Isolate continuous route/timer progression; traffic contact is tested above.
    call reset_game
    mov BYTE PTR [rip+keys+0x26], 1
    lea rdi, [rip+traffic]
    mov ecx, 10
.Ltest_clear_route:
    mov DWORD PTR [rdi], 10000000
    add rdi, 16
    dec ecx
    jnz .Ltest_clear_route
    mov ebx, 36000
.Ltest_full_race:
    mov BYTE PTR [rip+keys+0x25], 0
    mov BYTE PTR [rip+keys+0x27], 0
    xor r12d, r12d
    mov eax, [rip+player_x]
    sub eax, r12d
    cmp eax, 40
    jle .Ltest_auto_right
    mov BYTE PTR [rip+keys+0x25], 1
.Ltest_auto_right:
    cmp eax, -40
    jge .Ltest_auto_update
    mov BYTE PTR [rip+keys+0x27], 1
.Ltest_auto_update:
    call update_game
    cmp DWORD PTR [rip+state], STATE_FINISH
    je .Ltest_full_passed
    cmp DWORD PTR [rip+state], STATE_OVER
    je .Ltest_race_failed
    dec ebx
    jnz .Ltest_full_race
    jmp .Ltest_race_failed
.Ltest_full_passed:
    cmp DWORD PTR [rip+distance], 5*STAGE_LENGTH
    jl .Ltest_fail
    # End-screen progression and high-score initials through normal key handling.
    mov DWORD PTR [rip+score], 2000000
    mov ebx, 300
.Ltest_scores_transition:
    call update_game
    dec ebx
    jnz .Ltest_scores_transition
    cmp DWORD PTR [rip+state], STATE_SCORES
    jne .Ltest_fail
    mov ecx, 'B'
    call handle_key
    cmp BYTE PTR [rip+initials], 'B'
    jne .Ltest_fail
    mov ecx, 13
    call handle_key
    cmp DWORD PTR [rip+best_score], 2000000
    jne .Ltest_fail
    cmp DWORD PTR [rip+state], STATE_TITLE
    jne .Ltest_fail
    call reset_game
    mov DWORD PTR [rip+state], STATE_RACE
    mov DWORD PTR [rip+speed], 200
    mov DWORD PTR [rip+player_x], 1200
    call update_game
    cmp DWORD PTR [rip+crash_ticks], 180
    jne .Ltest_fail
    xor eax, eax
    RETURN
.Ltest_race_failed:
    mov eax, [rip+stage]
    add eax, 10
    RETURN
.Ltest_fail:
    mov eax, 1
    RETURN
