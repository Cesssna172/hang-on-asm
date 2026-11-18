# Native 320 x 224 arcade layout. Every pixel and glyph is drawn in assembly.
draw_rect:
    FRAME
    mov eax, DWORD PTR [rbp+48]
    test ecx, ecx
    jns .Lrx
    add r8d, ecx
    xor ecx, ecx
.Lrx:
    test edx, edx
    jns .Lry
    add r9d, edx
    xor edx, edx
.Lry:
    mov r10d, WIDTH
    sub r10d, ecx
    cmp r8d, r10d
    cmovg r8d, r10d
    mov r10d, HEIGHT
    sub r10d, edx
    cmp r9d, r10d
    cmovg r9d, r10d
    test r8d, r8d
    jle .Lrect_end
    test r9d, r9d
    jle .Lrect_end
    imul edx, WIDTH
    add edx, ecx
    mov rdi, [rip+pixels]
    lea rdi, [rdi+rdx*4]
    mov ebx, r8d
    mov esi, WIDTH
    sub esi, ebx
    shl esi, 2
.Lrect_line:
    mov ecx, ebx
    rep stosd
    add rdi, rsi
    dec r9d
    jnz .Lrect_line
.Lrect_end:
    RETURN

# x, y, embedded sprite, destination width, destination height on stack.
# Nearest-neighbour arbitrary-size scaling replaces integer sprite scaling.
draw_bitmap:
    FRAME
    mov ebx, ecx
    mov esi, edx
    mov rdi, r8
    mov r12d, r9d
    mov r13d, [rbp+48]
    test r12d, r12d
    jle .Lbitmap_end
    test r13d, r13d
    jle .Lbitmap_end
    xor r14d, r14d
.Lbitmap_row:
    lea eax, [rsi+r14]
    cmp eax, HEIGHT
    jae .Lbitmap_next_row
    imul eax, WIDTH
    mov [rbp-64], eax
    mov eax, r14d
    imul eax, [rdi+4]
    xor edx, edx
    div r13d
    imul eax, [rdi]
    lea r10, [rdi+rax*4+8]
    xor r15d, r15d
.Lbitmap_pixel:
    lea ecx, [rbx+r15]
    cmp ecx, WIDTH
    jae .Lbitmap_next_pixel
    mov eax, r15d
    imul eax, [rdi]
    xor edx, edx
    div r12d
    mov eax, [r10+rax*4]
    test eax, 0xff000000
    jnz .Lbitmap_next_pixel
    add ecx, [rbp-64]
    mov r11, [rip+pixels]
    mov [r11+rcx*4], eax
.Lbitmap_next_pixel:
    inc r15d
    cmp r15d, r12d
    jb .Lbitmap_pixel
.Lbitmap_next_row:
    inc r14d
    cmp r14d, r13d
    jb .Lbitmap_row
.Lbitmap_end:
    RETURN

copy_screen:
    push rsi
    push rdi
    lea rsi, [rcx+8]
    mov rdi, [rip+pixels]
    mov ecx, WIDTH*HEIGHT
    rep movsd
    pop rdi
    pop rsi
    ret

# x, y, ASCII pointer, RGB; glyph scale on stack (1 or 2).
draw_text:
    FRAME
    mov ebx, ecx
    mov esi, edx
    mov rdi, r8
    mov [rbp-64], r9d
    mov r12d, [rbp+48]
    mov [rbp-68], r12d
    cmp r12d, 3
    jne .Lfont_scale
    mov r12d, 1
    mov DWORD PTR [rbp-68], 2
.Lfont_scale:
.Lglyph:
    movzx eax, BYTE PTR [rdi]
    inc rdi
    test eax, eax
    jz .Ltext_end
    and eax, 127
    imul eax, 7
    lea r13, [rip+pixel_font]
    add r13, rax
    xor r14d, r14d
.Lglyph_row:
    xor r15d, r15d
.Lglyph_bit:
    movzx eax, BYTE PTR [r13+r14]
    mov ecx, 7
    sub ecx, r15d
    bt eax, ecx
    jnc .Lglyph_next_bit
    mov ecx, r15d
    imul ecx, r12d
    add ecx, ebx
    mov edx, r14d
    imul edx, [rbp-68]
    add edx, esi
    mov r8d, r12d
    mov r9d, [rbp-68]
    mov eax, [rbp-64]
    mov [rsp+32], eax
    call draw_rect
.Lglyph_next_bit:
    inc r15d
    cmp r15d, 8
    jb .Lglyph_bit
    inc r14d
    cmp r14d, 7
    jb .Lglyph_row
    lea eax, [r12*8]
    add ebx, eax
    jmp .Lglyph
.Ltext_end:
    RETURN

draw_number:
    FRAME
    mov ebx, ecx
    mov esi, edx
    mov r12d, r9d
    lea rcx, [rip+number_buffer]
    lea rdx, [rip+decimal_format]
    call wsprintfA
    mov ecx, ebx
    mov edx, esi
    lea r8, [rip+number_buffer]
    mov r9d, r12d
    mov DWORD PTR [rsp+32], 1
    call draw_text
    RETURN

draw_time:
    FRAME
    mov ebx, ecx
    mov esi, edx
    mov r12d, r9d
    lea rcx, [rip+number_buffer]
    lea rdx, [rip+decimal_format]
    call wsprintfA
    mov ecx, ebx
    mov edx, esi
    lea r8, [rip+number_buffer]
    mov r9d, r12d
    mov DWORD PTR [rsp+32], 3
    call draw_text
    RETURN

draw_right_number:
    FRAME
    mov ebx, ecx
    mov esi, edx
    mov r12d, r9d
    lea rcx, [rip+number_buffer]
    lea rdx, [rip+decimal_format]
    call wsprintfA
    shl eax, 3
    mov ecx, ebx
    sub ecx, eax
    mov edx, esi
    lea r8, [rip+number_buffer]
    mov r9d, r12d
    mov DWORD PTR [rsp+32], 1
    call draw_text
    RETURN

# depth 0..96 -> road center. Quadratic bends retain a stable near camera.
road_center:
    mov r10d, ecx
    mov eax, 96
    sub eax, ecx
    imul eax, eax
    imul eax, [rip+curve]
    cdq
    mov r11d, 18432
    idiv r11d
    add eax, 160
    mov r11d, [rip+player_x]
    imul r11d, r10d
    sar r11d, 9
    sub eax, r11d
    ret

render_frame:
    FRAME
    cmp DWORD PTR [rip+state], STATE_TITLE
    je .Ltitle
    cmp DWORD PTR [rip+state], STATE_COUNTDOWN
    je .Lstart_grid
    cmp DWORD PTR [rip+state], STATE_SCORES
    je .Lname_screen
    cmp DWORD PTR [rip+state], STATE_OVER
    je .Lrecord_screen
    mov eax, [rip+stage]
    dec eax
    imul eax, 24
    lea rbx, [rip+arcade_palettes]
    add rbx, rax
    mov [rip+active_palette], rbx
    mov DWORD PTR [rip+road_horizon], 128
    cmp DWORD PTR [rip+stage], 4
    jb .Lhorizon_ready
    mov DWORD PTR [rip+road_horizon], 144
.Lhorizon_ready:
    # A small speed-dependent camera pitch increases foreground optical flow.
    mov eax, [rip+speed]
    sub eax, 160
    jle .Lcamera_ready
    xor edx, edx
    mov ecx, 20
    div ecx
    sub [rip+road_horizon], eax
.Lcamera_ready:
    mov eax, [rbx]
    mov [rsp+32], eax
    xor ecx, ecx
    xor edx, edx
    mov r8d, WIDTH
    mov r9d, HEIGHT
    call draw_rect
    call draw_background
    mov r12d, [rip+road_horizon]
.Lroad:
    mov r13d, r12d
    sub r13d, [rip+road_horizon]
    mov ecx, r13d
    call road_center
    mov r14d, eax
    lea r15d, [r13+r13+2]
    mov eax, 304000
    lea ecx, [r13+2]
    xor edx, edx
    div ecx
    add eax, [rip+distance]
    shr eax, 10
    and eax, 1
    mov [rbp-64], eax
    mov eax, [rbx+4]
    mov [rsp+32], eax
    xor ecx, ecx
    mov edx, r12d
    mov r8d, WIDTH
    mov r9d, 1
    call draw_rect
    mov ecx, r14d
    sub ecx, r15d
    mov edx, r12d
    lea r8d, [r15+r15]
    mov r9d, 1
    mov eax, [rbp-64]
    mov eax, [rbx+rax*4+8]
    mov [rsp+32], eax
    call draw_rect
    # White road edges and alternating red/white rumble strips.
    mov eax, r13d
    shr eax, 4
    add eax, 2
    mov [rbp-68], eax
    mov eax, [rbp-64]
    mov eax, [rbx+rax*4+16]
    mov [rsp+32], eax
    mov ecx, r14d
    sub ecx, r15d
    mov edx, r12d
    mov r8d, [rbp-68]
    mov r9d, 1
    call draw_rect
    mov ecx, r14d
    add ecx, r15d
    sub ecx, [rbp-68]
    mov edx, r12d
    mov r8d, [rbp-68]
    mov r9d, 1
    mov eax, [rbp-64]
    mov eax, [rbx+rax*4+16]
    mov [rsp+32], eax
    call draw_rect
    cmp DWORD PTR [rbp-64], 0
    jne .Lroad_next_row
    mov esi, -1
.Llane:
    mov eax, r15d
    xor edx, edx
    mov ecx, 3
    div ecx
    imul eax, esi
    lea ecx, [r14+rax]
    mov edx, r12d
    mov r8d, r13d
    shr r8d, 6
    inc r8d
    mov r9d, 1
    mov DWORD PTR [rsp+32], 0xf7f7f7
    call draw_rect
    add esi, 2
    cmp esi, 1
    je .Llane
.Lroad_next_row:
    inc r12d
    cmp r12d, HEIGHT
    jb .Lroad
    call draw_scenery
    call draw_speed_streaks
    call draw_gantry
    call draw_traffic
    call draw_player
    call draw_hud
    call draw_overlay
    RETURN
.Ltitle:
    lea rcx, [rip+art_title]
    call copy_screen
    BOX 20, 30, 292, 109, 0
    mov eax, [rip+animation]
    imul eax, 6
    mov ecx, 320
    sub ecx, eax
    xor edx, edx
    cmp ecx, edx
    cmovl ecx, edx
    add ecx, 24
    mov edx, 32
    lea r8, [rip+art_logo]
    mov r9d, 282
    mov DWORD PTR [rsp+32], 105
    call draw_bitmap
    # Animated insert-coin/start legend over the original logo artwork.
    mov eax, [rip+animation]
    test eax, 32
    jz .Ltitle_done
    BOX 99, 93, 108, 12, 0
.Ltitle_done:
    LABEL 88, 174, arcade_restart, 0xf7f700, font_small
    RETURN
.Lstart_grid:
    lea rcx, [rip+art_start]
    call copy_screen
    BOX 0, 12, 320, 40, 0x0000f7
    call draw_hud
    # Start lights change red -> amber -> green with the three-second count.
    mov eax, [rip+countdown]
    xor edx, edx
    mov ecx, 60
    div ecx
    mov r12d, eax
    mov r8d, eax
    inc r8d
    mov ecx, 155
    mov edx, 102
    mov r9d, 0xf7f700
    call draw_number
    cmp r12d, 0
    jne .Lgrid_done
    BOX 44, 121, 6, 7, 0x00f700
    BOX 59, 121, 6, 7, 0x00f700
    BOX 260, 121, 6, 7, 0x00f700
    BOX 275, 121, 6, 7, 0x00f700
.Lgrid_done:
    RETURN
.Lrecord_screen:
    lea rcx, [rip+art_over]
    call copy_screen
    call draw_hud
    RETURN
.Lname_screen:
    lea rcx, [rip+art_scores]
    call copy_screen
    BOX 128, 31, 60, 9, 0x7363a4
    BOX 199, 31, 26, 9, 0x7363a4
    mov ecx, 184
    mov edx, 32
    mov r8d, [rip+best_score]
    mov r9d, 0xf76300
    call draw_right_number
    LABEL 200, 32, record_names, 0xf7f700, font_small
    xor r12d, r12d
.Lscore_row:
    mov eax, r12d
    shl eax, 4
    add eax, 56
    mov r13d, eax
    mov ecx, 120
    mov edx, r13d
    mov r8d, 66
    mov r9d, 9
    mov DWORD PTR [rsp+32], 0x7363a4
    call draw_rect
    mov ecx, 199
    mov edx, r13d
    mov r8d, 26
    mov r9d, 9
    mov DWORD PTR [rsp+32], 0x7363a4
    call draw_rect
    lea rax, [rip+record_scores]
    mov r8d, [rax+r12*4]
    mov ecx, 184
    mov edx, r13d
    mov r9d, 0xf7f7f7
    call draw_right_number
    lea rax, [rip+record_names]
    lea r8, [rax+r12*4]
    cmp r12d, [rip+score_rank]
    jne .Lscore_name
    lea r8, [rip+initials]
.Lscore_name:
    mov ecx, 200
    mov edx, r13d
    mov r9d, 0xf7f700
    mov DWORD PTR [rsp+32], 1
    call draw_text
    inc r12d
    cmp r12d, 7
    jb .Lscore_row
    cmp DWORD PTR [rip+score_rank], 0
    jl .Lscore_read_only
    LABEL 80, 174, arcade_name, 0xf7f700, font_small
    mov ecx, [rip+entry_index]
    shl ecx, 3
    add ecx, 200
    mov edx, [rip+score_rank]
    shl edx, 4
    add edx, 64
    mov r8d, 6
    mov r9d, 1
    mov DWORD PTR [rsp+32], 0xf7f700
    call draw_rect
    RETURN
.Lscore_read_only:
    LABEL 80, 174, arcade_restart, 0xf7f700, font_small
    RETURN

draw_background:
    FRAME
    mov eax, [rip+stage]
    dec eax
    lea rdx, [rip+background_frames]
    mov r8, [rdx+rax*8]
    mov ecx, [rip+curve]
    sar ecx, 4
    mov r9d, 320
    mov eax, [r8+4]
    mov edx, [rip+road_horizon]
    sub edx, eax
    mov [rsp+32], eax
    call draw_bitmap
    RETURN

draw_speed_streaks:
    FRAME
    cmp DWORD PTR [rip+speed], 170
    jle .Lstreaks_done
    mov eax, [rip+state]
    cmp eax, STATE_RACE
    je .Lstreaks_begin
    cmp eax, STATE_PAUSE
    jne .Lstreaks_done
.Lstreaks_begin:
    mov r15d, 0x38e7ad
    cmp DWORD PTR [rip+stage], 3
    jne .Lstreaks_night
    mov r15d, 0xffe7b5
.Lstreaks_night:
    cmp DWORD PTR [rip+stage], 4
    jne .Lstreaks_loop_start
    mov r15d, 0x7373ce
.Lstreaks_loop_start:
    xor ebx, ebx
.Lstreak:
    mov eax, [rip+distance]
    shr eax, 5
    imul edx, ebx, 29
    add eax, edx
    and eax, 127
    imul eax, eax
    shr eax, 7
    add eax, 16
    mov r12d, eax
    mov ecx, HEIGHT
    sub ecx, [rip+road_horizon]
    cmp eax, ecx
    jae .Lstreak_next
    mov ecx, eax
    call road_center
    mov r13d, eax
    lea edx, [r12+r12+8]
    mov eax, ebx
    and eax, 3
    imul eax, 7
    add edx, eax
    test ebx, 1
    jnz .Lstreak_right
    sub r13d, edx
    jmp .Lstreak_position
.Lstreak_right:
    add r13d, edx
.Lstreak_position:
    mov r14d, [rip+road_horizon]
    add r14d, r12d
    mov eax, [rip+speed]
    sub eax, 160
    shr eax, 5
    mov edx, r12d
    shr edx, 4
    add eax, edx
    shr eax, 1
    inc eax
    mov [rbp-64], eax
    mov ecx, r13d
    mov edx, r14d
    mov r8d, 1
    mov r9d, eax
    mov [rsp+32], r15d
    call draw_rect
    mov eax, 2
    test ebx, 1
    jnz .Lstreak_offset
    neg eax
.Lstreak_offset:
    lea ecx, [r13+rax]
    mov edx, r14d
    add edx, [rbp-64]
    mov r8d, 1
    mov r9d, [rbp-64]
    mov [rsp+32], r15d
    call draw_rect
.Lstreak_next:
    inc ebx
    cmp ebx, 8
    jb .Lstreak
.Lstreaks_done:
    RETURN

draw_scenery:
    FRAME
    mov ebx, 12
.Lscenery_object:
    mov eax, [rip+distance]
    xor edx, edx
    mov ecx, 2600
    div ecx
    mov eax, ebx
    imul eax, 2600
    sub eax, edx
    add eax, 3200
    mov ecx, eax
    mov eax, 304000
    xor edx, edx
    div ecx
    mov r12d, eax
    cmp eax, 95
    ja .Lnext_scenery
    mov ecx, eax
    call road_center
    mov r13d, eax
    lea r14d, [r12+r12+12]
    mov r15d, r12d
    imul r15d, 8
    xor edx, edx
    mov eax, r15d
    mov ecx, 7
    div ecx
    mov r15d, eax
    cmp DWORD PTR [rip+stage], 3
    je .Lcactus
    cmp DWORD PTR [rip+stage], 4
    je .Llamp
    test ebx, 2
    jnz .Lbillboard
    mov ecx, r13d
    sub ecx, r14d
    sub ecx, r15d
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    lea r8, [rip+art_tree]
    mov eax, r15d
    imul eax, 42
    xor edx, edx
    mov ecx, 137
    div ecx
    mov r9d, eax
    mov ecx, r13d
    sub ecx, r14d
    sub ecx, r9d
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    mov [rsp+32], r15d
    call draw_bitmap
    # The other verge receives houses and signs, rather than duplicate trees.
    lea ecx, [r13+r14]
    mov edx, [rip+road_horizon]
    add edx, r12d
    mov eax, r12d
    shr eax, 1
    sub edx, eax
    mov [rsp+32], eax
    lea r8, [rip+art_house]
    mov r9d, r12d
    call draw_bitmap
    jmp .Lnext_scenery
.Lbillboard:
    lea ecx, [r13+r14]
    mov edx, [rip+road_horizon]
    add edx, r12d
    mov eax, r12d
    shr eax, 2
    sub edx, eax
    mov [rsp+32], eax
    lea r8, [rip+art_sign]
    mov r9d, r12d
    call draw_bitmap
    jmp .Lnext_scenery
.Lcactus:
    mov ecx, r13d
    sub ecx, r14d
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    mov r8d, 3
    mov r9d, r15d
    mov DWORD PTR [rsp+32], 0x008c21
    call draw_rect
    mov ecx, r13d
    sub ecx, r14d
    sub ecx, 4
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    mov eax, r15d
    shr eax, 1
    add edx, eax
    mov r8d, 12
    mov r9d, 3
    mov DWORD PTR [rsp+32], 0x00b521
    call draw_rect
    jmp .Lnext_scenery
.Llamp:
    lea ecx, [r13+r14]
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    mov r8d, 2
    mov r9d, r15d
    mov DWORD PTR [rsp+32], 0x949494
    call draw_rect
    lea ecx, [r13+r14-6]
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r15d
    mov r8d, 8
    mov r9d, 2
    mov DWORD PTR [rsp+32], 0xf7f7b5
    call draw_rect
.Lnext_scenery:
    dec ebx
    jnz .Lscenery_object
    RETURN

draw_traffic:
    FRAME
    mov DWORD PTR [rbp-64], 0
    mov DWORD PTR [rbp-68], 10
.Lpick_rider:
    mov r12d, -1
    mov r13d, -1
    xor ebx, ebx
    lea rdi, [rip+traffic]
.Lfind_rider:
    bt DWORD PTR [rbp-64], ebx
    jc .Lfind_next
    mov eax, [rdi]
    sub eax, [rip+distance]
    cmp eax, -100
    jl .Lfind_next
    cmp eax, 30000
    jg .Lfind_next
    cmp eax, r13d
    jle .Lfind_next
    mov r13d, eax
    mov r12d, ebx
.Lfind_next:
    add rdi, 16
    inc ebx
    cmp ebx, 10
    jb .Lfind_rider
    cmp r12d, -1
    je .Lriders_done
    bts DWORD PTR [rbp-64], r12d
    add r13d, 3200
    mov eax, 304000
    xor edx, edx
    div r13d
    mov r14d, eax
    mov ecx, eax
    call road_center
    mov ebx, eax
    lea rdi, [rip+traffic]
    mov eax, r12d
    shl eax, 4
    add rdi, rax
    mov eax, [rdi+4]
    imul eax, r14d
    sar eax, 9
    add ebx, eax
    mov eax, r12d
    xor edx, edx
    mov ecx, 3
    div ecx
    imul edx, 7
    mov eax, [rip+curve]
    cdq
    mov ecx, 55
    idiv ecx
    mov ecx, 2
    cmp eax, ecx
    cmovg eax, ecx
    mov ecx, -2
    cmp eax, ecx
    cmovl eax, ecx
    add eax, 3
    # Palette chosen independently from pose (id mod 3).
    mov esi, eax
    mov eax, r12d
    xor edx, edx
    mov ecx, 3
    div ecx
    imul edx, 7
    add edx, esi
    lea rax, [rip+rival_frames]
    mov r8, [rax+rdx*8]
    mov eax, r14d
    imul eax, 4
    xor edx, edx
    mov ecx, 5
    div ecx
    add eax, 4
    mov r15d, eax
    mov ecx, ebx
    mov edx, r15d
    shr edx, 1
    sub ecx, edx
    mov edx, [rip+road_horizon]
    add edx, r14d
    sub edx, r15d
    mov r9d, r15d
    mov [rsp+32], r15d
    call draw_bitmap
    dec DWORD PTR [rbp-68]
    jnz .Lpick_rider
.Lriders_done:
    RETURN

draw_gantry:
    FRAME
    mov DWORD PTR [rbp-64], 0
    mov eax, [rip+distance]
    cmp eax, 3200
    ja .Lcheckpoint_gantry
    xor edx, edx
    mov ecx, 60
    div ecx
    lea r12d, [rax+96]
    jmp .Lproject_gantry
.Lcheckpoint_gantry:
    mov DWORD PTR [rbp-64], 1
    mov eax, [rip+stage]
    imul eax, STAGE_LENGTH
    sub eax, [rip+distance]
    cmp eax, 7500
    ja .Lgantry_done
    add eax, 3200
    mov ecx, eax
    mov eax, 304000
    xor edx, edx
    div ecx
    mov r12d, eax
.Lproject_gantry:
    mov ecx, r12d
    cmp ecx, 96
    jbe .Lgantry_center
    mov ecx, 96
.Lgantry_center:
    call road_center
    mov ebx, eax
    mov eax, r12d
    imul eax, 248
    xor edx, edx
    mov ecx, 96
    div ecx
    mov r13d, eax
    mov eax, r12d
    imul eax, 153
    xor edx, edx
    div ecx
    mov r14d, eax
    mov ecx, ebx
    mov edx, r13d
    shr edx, 1
    sub ecx, edx
    mov edx, [rip+road_horizon]
    add edx, r12d
    sub edx, r14d
    mov [rbp-68], edx
    lea r8, [rip+art_gate]
    mov r9d, r13d
    mov [rsp+32], r14d
    call draw_bitmap
    cmp DWORD PTR [rbp-64], 0
    je .Lgantry_done
    cmp r12d, 60
    jb .Lgantry_done
    lea ecx, [rbx-22]
    mov edx, [rbp-68]
    add edx, 2
    mov r8d, 48
    mov r9d, 12
    mov DWORD PTR [rsp+32], 0xf70000
    call draw_rect
    lea ecx, [rbx-20]
    mov edx, [rbp-68]
    add edx, 5
    lea r8, [rip+arcade_check]
    cmp DWORD PTR [rip+stage], 5
    jne .Lgantry_label
    lea r8, [rip+arcade_goal]
.Lgantry_label:
    mov r9d, 0xf7f700
    mov DWORD PTR [rsp+32], 1
    call draw_text
    RETURN
.Lgantry_done:
    RETURN

draw_player:
    FRAME
    cmp DWORD PTR [rip+crash_ticks], 0
    jne .Lcrash_animation
    mov eax, [rip+lean]
    cdq
    mov ecx, 4
    idiv ecx
    add eax, 3
    mov ecx, 0
    cmp eax, ecx
    cmovl eax, ecx
    mov ecx, 6
    cmp eax, ecx
    cmovg eax, ecx
    mov [rip+current_pose], eax
    lea rdx, [rip+bike_frames]
    mov r8, [rdx+rax*8]
    mov ecx, 120
    cmp DWORD PTR [rip+wobble_ticks], 0
    je .Lno_wobble
    mov eax, [rip+animation]
    and eax, 4
    sub eax, 2
    add ecx, eax
.Lno_wobble:
    mov edx, 144
    # Speed-dependent two-pixel suspension/rear-wheel vibration.
    mov eax, [rip+distance]
    shr eax, 7
    and eax, 1
    sub edx, eax
    mov r9d, 80
    mov DWORD PTR [rsp+32], 80
    call draw_bitmap
    RETURN
.Lcrash_animation:
    # Airborne bike -> explosion -> fallen rider -> recovery.
    mov eax, [rip+crash_ticks]
    cmp eax, 135
    jb .Lexplosion
    mov eax, 180
    sub eax, [rip+crash_ticks]
    shr eax, 3
    and eax, 3
    lea rdx, [rip+tumble_frames]
    mov r8, [rdx+rax*8]
    mov ecx, 112
    mov edx, 135
    mov r9d, 90
    mov DWORD PTR [rsp+32], 76
    call draw_bitmap
    jmp .Lrider_on_road
.Lexplosion:
    cmp eax, 65
    jb .Lrider_on_road
    mov eax, 135
    sub eax, [rip+crash_ticks]
    xor edx, edx
    mov ecx, 12
    div ecx
    cmp eax, 5
    jbe .Lfire_index
    mov eax, 5
.Lfire_index:
    mov [rip+current_pose], eax
    lea rdx, [rip+fire_frames]
    mov r8, [rdx+rax*8]
    mov r9d, [r8]
    mov ecx, 160
    mov eax, r9d
    shr eax, 1
    sub ecx, eax
    mov eax, [r8+4]
    mov edx, 207
    sub edx, eax
    mov [rsp+32], eax
    call draw_bitmap
.Lrider_on_road:
    mov ecx, 202
    mov edx, 198
    lea r8, [rip+art_fallen]
    mov r9d, 49
    mov DWORD PTR [rsp+32], 23
    call draw_bitmap
    RETURN

draw_hud:
    FRAME
    mov r12d, 0x0000f7
    cmp DWORD PTR [rip+state], STATE_COUNTDOWN
    je .Lhud_background
    mov eax, [rip+stage]
    dec eax
    imul eax, 24
    lea rdx, [rip+arcade_palettes]
    mov r12d, [rdx+rax]
    cmp DWORD PTR [rip+state], STATE_OVER
    jne .Lhud_background
    mov r12d, 0x949494
.Lhud_background:
    BOX 64, 14, 64, 10, r12d
    BOX 240, 14, 64, 10, r12d
    BOX 72, 32, 8, 9, r12d
    BOX 144, 32, 24, 16, r12d
    BOX 248, 32, 24, 9, r12d
    xor ecx, ecx
    xor edx, edx
    lea r8, [rip+art_hud]
    mov r9d, 320
    mov DWORD PTR [rsp+32], 50
    call draw_bitmap
    mov ecx, 64
    mov edx, 16
    mov r8d, [rip+best_score]
    mov r9d, 0xf76300
    call draw_number
    mov ecx, 304
    mov edx, 16
    mov r8d, [rip+score]
    mov r9d, 0x00f700
    call draw_right_number
    mov ecx, 72
    mov edx, 33
    mov r8d, [rip+stage]
    mov r9d, 0xf7f7f7
    call draw_number
    mov eax, [rip+time_left]
    add eax, 999
    xor edx, edx
    mov ecx, 1000
    div ecx
    mov r8d, eax
    mov ecx, 145
    mov edx, 33
    mov r9d, 0xf7f700
    call draw_time
    mov ecx, 272
    mov edx, 33
    mov r8d, [rip+speed]
    mov r9d, 0xf7f7f7
    call draw_right_number
    LABEL 273, 33, arcade_km, 0xf7f700, font_small
    RETURN

draw_overlay:
    FRAME
    mov eax, [rip+state]
    cmp eax, STATE_PAUSE
    je .Lpause_overlay
    cmp eax, STATE_FINISH
    je .Lgoal
    cmp eax, STATE_OVER
    je .Lgame_over
    cmp DWORD PTR [rip+checkpoint_ticks], 0
    je .Loverlay_end
    LABEL 81, 70, arcade_checkpoint, 0xf7f700, font_small
.Loverlay_end:
    RETURN
.Lpause_overlay:
    LABEL 120, 80, pause_label, 0xf7f700, font_small
    LABEL 72, 96, arcade_resume, 0xf7f7f7, font_small
    RETURN
.Lgoal:
    LABEL 132, 69, arcade_goal, 0xf7f700, font_small
    LABEL 72, 86, arcade_finish, 0xf7f7f7, font_small
    LABEL 64, 103, arcade_restart, 0x00f700, font_small
    RETURN
.Lgame_over:
    LABEL 124, 70, arcade_over, 0xf70000, font_small
    LABEL 72, 88, arcade_restart, 0xf7f700, font_small
    RETURN

