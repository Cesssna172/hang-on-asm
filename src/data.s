.section .rdata
class_name: .asciz "HangOnAssemblyWindow"
window_title: .asciz "HANG-ON / Arcade Reconstruction / x64 Assembly"
error_text: .asciz "Windows could not initialize the game window or framebuffer."
selftest_argument: .asciz "--self-test"
decimal_format: .asciz "%d"
pause_label: .asciz "PAUSED"
arcade_km: .asciz "KM"
arcade_checkpoint: .asciz "CHECK POINT"
arcade_check: .asciz "CHECK"
arcade_resume: .asciz "P OR ENTER TO RESUME"
arcade_goal: .asciz "GOAL!"
arcade_finish: .asciz "CONGRATULATIONS!"
arcade_restart: .asciz "PUSH START BUTTON"
arcade_over: .asciz "GAME OVER"
arcade_name: .asciz "ENTER YOUR NAME"

.balign 4
curve_table:
.long 0,0,0,0,35,90,145,170,170,110,0,-75,-145,-165,-90,0,0,45,135,170,100,0,0,0,115,170,160,130,0,0,-65,0,0
.long 0,-30,-90,-145,-150,-90,0,70,145,165,100,0,-60,-140,-155,-70,0,80,150,170,120,30,0,-80,-150,-130,-40,50,120,70,0,0,0
.long 0,0,25,65,115,160,170,130,70,0,-60,-120,-160,-150,-85,0,0,0,55,110,165,145,80,0,-50,-110,-160,-100,-40,0,0,0,0
.long 0,-50,-120,-160,-170,-125,-45,35,105,155,165,110,30,-45,-110,-155,-175,-145,-90,0,60,130,165,160,100,30,-50,-130,-160,-100,-40,0,0
.long 0,0,0,0,50,110,150,160,120,70,0,-60,-135,-170,-150,-75,0,0,60,140,175,160,90,0,-75,-145,-170,-120,-50,0,0,0,0
mountain_table:
.byte 14,18,23,30,39,48,55,49,43,38,29,24,20,18,21,28
.byte 34,42,38,32,25,20,14,12,16,23,29,25,22,16,13,11
# sky, verge, asphalt A/B, edge A/B
arcade_palettes:
.long 0x0000f7,0x00d694,0x636363,0x526363,0xf7f7f7,0xb50000
.long 0x8494f7,0x00f794,0x737373,0x7b7b7b,0xf7f7f7,0xb50000
.long 0xf7a500,0xe7d694,0x8c8473,0x94948c,0xf7f7f7,0xb50000
.long 0x000000,0x000084,0xa5a5e7,0xadb5f7,0xf7f700,0xb50000
.long 0xf7c694,0x00d694,0x737373,0x7b7b7b,0xf7f7f7,0xb50000

.section .data
.balign 8
window_class:
    .long 80, 3
    .quad window_proc
    .long 0, 0
    .quad 0, 0, 0, 0, 0, class_name, 0
initial_rect: .long 0,0,960,720
best_score: .long 1000000
initials: .asciz "ASM"
entry_index: .long 0
score_rank: .long -1
record_scores: .long 1000000,900000,800000,700000,600000,500000,400000
record_names: .asciz "KAN", "YU.", "OHE", "ISH", "NAG", "KAJ", "INO"
bitmap_info:
    .long 40,WIDTH,-HEIGHT
    .short 1,32
    .long 0,WIDTH*HEIGHT*4,0,0,0,0
wave_format:
    .short 1,1
    .long 22050,44100
    .short 2,16,0

.section .bss
.balign 16
instance: .space 8
window: .space 8
memory_dc: .space 8
pixels: .space 8
bitmap: .space 8
old_bitmap: .space 8
font_small: .space 8
font_medium: .space 8
font_large: .space 8
active_palette: .space 8
wave_handle: .space 8
message: .space 48
paint_struct: .space 80
client_rect: .space 16
draw_width: .space 4
draw_height: .space 4
keys: .space 256
state: .space 4
resume_state: .space 4
speed: .space 4
player_x: .space 4
lean: .space 4
distance: .space 4
score: .space 4
stage: .space 4
time_left: .space 4
countdown: .space 4
crash_ticks: .space 4
checkpoint_ticks: .space 4
curve: .space 4
animation: .space 4
elapsed_ticks: .space 4
random_seed: .space 4
sprite_lean: .space 4
muted: .space 4
audio_ready: .space 4
audio_phase: .space 4
number_buffer: .space 32
traffic: .space 160
.balign 16
wave_headers: .space 144
wave_buffers: .space 6144

timer_fraction: .space 4
wobble_ticks: .space 4
current_pose: .space 4
ending_ticks: .space 4

road_horizon: .space 4
