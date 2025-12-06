[org 0x0100]

jmp start

; player car position
red_car_row: db 20
red_car_col: db 39  ; center lane (lane_cols: 19, 39, 59)

; obstacle cars storage (each car: active(1 byte), row(1 byte), col(1 byte))
blue_cars: times 30 db 0

; coins storage
coins: times 30 db 0

; fuel pickups storage
fuel_items: times 15 db 0

; timing counters
scroll_counter: dw 0
spawn_counter: dw 0
coin_counter: dw 0
fuel_counter: dw 0

; fuel bar settings
fuel_level: db 100
fuel_bar_row: db 1
fuel_bar_col: db 12

; lane column positions (3 lanes with equal width, centered for 3-char cars)
lane_cols: db 19, 39, 59

; constants for spacing and frequency
RED_CAR_HEIGHT equ 5
OBSTACLE_GAP_EXTRA equ 7
MIN_OBSTACLE_INTERVAL equ RED_CAR_HEIGHT + OBSTACLE_GAP_EXTRA ; 12 rows between obstacle spawns
MIN_COIN_INTERVAL equ 18
MIN_FUEL_INTERVAL equ 45

SPAWN_WEIGHT_CAR  equ 60 ; percent weight
SPAWN_WEIGHT_COIN equ 30
SPAWN_WEIGHT_FUEL equ 10

; vertical gaps to avoid overlap between types
GAP_COIN_TO_CAR equ 6
GAP_FUEL_TO_CAR equ 8
GAP_ITEM_BETWEEN equ 4

; game state flags
game_started: db 0
game_paused: db 0
should_exit: db 0
old_keyboard_isr: dd 0
old_timer_isr: dd 0
music_active: db 0
music_tempo: dw 4
music_tick_counter: dw 0
music_note_index: dw 0
music_len: dw 8
event_beep_ticks: dw 0
event_divisor: dw 0
tmr_hooked: db 0
lane_cooldown: db 0

; keyboard scan codes
KEY_LEFT equ 0x4B
KEY_RIGHT equ 0x4D
KEY_UP equ 0x48
KEY_DOWN equ 0x50
KEY_ESC equ 0x01
KEY_Y equ 0x15
KEY_N equ 0x31

coin_total: dw 0
end_cause: db 0
kb_hooked: db 0
pre_screen_state: db 0
crash_msg_shown: db 0
player_name: times 20 db 0
player_roll: times 12 db 0
s_main_press: db "Press any key to continue to play",0

s_start_title: db "BLAZE RUSH",0
s_start_devlabel: db "Developer name:",0
s_start_dev1: db "Mutahir Shahzad",0
s_start_dev2: db "",0
s_start_rolllabel: db "Roll No:",0
s_start_roll1: db "24L-0580",0
s_start_roll2: db "",0
s_start_press: db "Press any key to continue",0

s_instr_title: db "INSTRUCTIONS",0
s_instr_l1: db "* Use Left Arrow  to move the car to the left lane.",0
s_instr_l2: db "* Use Right Arrow  to move the car to the right lane.",0
s_instr_l3: db "* Fuel decreases continuously during gameplay.",0
s_instr_l4: db "  - The game ends when fuel reaches zero.",0
s_instr_l5: db "* Collect Coins to increase your score.",0
s_instr_l6: db "* Press ESC during the game to open the Exit Confirmation Box.",0
s_instr_l7: db "  - Press Y to quit the game.",0
s_instr_l8: db "  - Press N to continue playing.",0
s_instr_l9: db "* Avoid crashing into other cars (collision ends game next phase).",0
s_instr_l10: db "* After the game ends, an Ending Screen will appear showing:",0
s_instr_l11: db "  - Player Name",0
s_instr_l12: db "  - Roll Number",0
s_instr_l13: db "  - Total Coins Collected",0
s_instr_l14: db "  - Press ESC to exit and Press Space to back to the Main Screen",0
s_instr_l15: db "  - Press ESC to exit (with confirmation)",0
s_instr_press: db "Press any key to continue...",0
s_end_instr: db "press esc to exit and press space to go back to the main screen",0

clrscr:
    push es
    push ax
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    cld
    rep stosw
    
    pop di
    pop cx
    pop ax
    pop es
    ret

draw_borders:
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    
    mov ax, 0xb800
    mov es, ax
    
    xor bx, bx
    
border_loop:
    cmp bx, 25
    jge border_done
    
    mov ax, bx
    mov cx, 80
    mul cx
    shl ax, 1
    mov di, ax
    
    ; left green plain border
    mov cx, 10
    mov ax, 0x2220
left_plain:
    stosw
    loop left_plain
    
    ; skip to right border start column
    add di, 120
    
    ; right green plain border
    mov cx, 10
    mov ax, 0x2220
right_plain:
    stosw
    loop right_plain
    
    inc bx
    jmp border_loop
    
border_done:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_road:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    xor bx, bx
    
road_loop:
    cmp bx, 25
    jge road_done
    
    mov ax, bx
    mov cx, 80
    mul cx
    add ax, 10
    shl ax, 1
    mov di, ax
    
    mov cx, 60
    mov ax, 0x7020
road_chars:
    stosw
    loop road_chars
    
    inc bx
    jmp road_loop
    
road_done:
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_lanes:
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    xor bx, bx
    
lane_row_loop:
    cmp bx, 25
    jge lanes_done
    
    mov ax, bx
    xor dx, dx
    mov cx, 10
    div cx
    
    cmp dx, 5
    jge skip_lane_row
    
    ; draw first lane divider at column 29 (between lane 1 and 2)
    mov ax, bx
    mov cx, 80
    mul cx
    add ax, 29
    shl ax, 1
    mov di, ax
    mov ax, 0x0FDB
    stosw
    stosw
    
    ; draw second lane divider at column 49 (between lane 2 and 3)
    mov ax, bx
    mov cx, 80
    mul cx
    add ax, 49
    shl ax, 1
    mov di, ax
    mov ax, 0x0FDB
    stosw
    stosw
    
skip_lane_row:
    inc bx
    jmp lane_row_loop
    
lanes_done:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_instructions:
    push es
    push ax
    push bx
    push si
    mov ax, 0xb800
    mov es, ax
    call clrscr
    mov bh, 0x0F
    mov al, 4
    mov si, s_instr_title
    call draw_centered_line
    mov al, 6
    mov si, s_instr_l1
    call draw_centered_line
    mov al, 7
    mov si, s_instr_l2
    call draw_centered_line
    mov al, 9
    mov si, s_instr_l3
    call draw_centered_line
    mov al, 10
    mov si, s_instr_l4
    call draw_centered_line
    mov al, 12
    mov si, s_instr_l5
    call draw_centered_line
    mov al, 14
    mov si, s_instr_l6
    call draw_centered_line
    mov al, 15
    mov si, s_instr_l7
    call draw_centered_line
    mov al, 16
    mov si, s_instr_l8
    call draw_centered_line
    mov al, 18
    mov si, s_instr_l9
    call draw_centered_line
    mov al, 20
    mov si, s_instr_l10
    call draw_centered_line
    mov al, 21
    mov si, s_instr_l11
    call draw_centered_line
    mov al, 22
    mov si, s_instr_l12
    call draw_centered_line
    mov al, 23
    mov si, s_instr_l13
    call draw_centered_line
    mov al, 24
    mov si, s_instr_l14
    call draw_centered_line
    mov al, 25
    mov si, s_instr_l15
    call draw_centered_line
    mov al, 27
    mov si, s_instr_press
    call draw_centered_line
    pop si
    pop bx
    pop ax
    pop es
    ret

draw_main_menu:
    push es
    push ax
    push bx
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    call get_random_lane
    mov si, lane_cols
    xor ah, ah
    add si, ax
    mov dl, [si]
    mov al, 5
    mov ah, dl
    call draw_blue_car_at
    mov bh, 0x7F
    mov al, 18
    mov si, s_main_press
    call draw_centered_line
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

strlen:
    push si
    xor cx, cx
strlen_loop:
    lodsb
    cmp al, 0
    je strlen_done
    inc cx
    jmp strlen_loop
strlen_done:
    pop si
    ret

draw_centered_line:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov dh, al         ; row
    mov dl, bh         ; capture attribute before BX changes
    push si
    call strlen
    pop si
    mov bx, 80
    sub bx, cx
    shr bx, 1
    mov al, dh
    xor ah, ah
    mov ch, 80         ; use CH as 80 to avoid clobbering DL
    mul ch
    add ax, bx
    shl ax, 1
    mov di, ax
draw_centered_loop:
    lodsb
    cmp al, 0
    je draw_centered_done
    mov ah, dl         ; use captured attribute
    stosw
    jmp draw_centered_loop
draw_centered_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

get_random:
    push dx
    push cx
    
    mov ah, 0x00
    int 0x1A
    mov ax, dx
    
    pop cx
    pop dx
    ret

get_random_lane:
    call get_random
    xor dx, dx
    mov cx, 3
    div cx
    mov al, dl
    ret

random_spawn:
    push ax
    push bx
    push cx
    push dx
    push si
    
    call get_random
    xor dx, dx
    mov cx, 100
    div cx
    mov al, dl          ; 0..99

    mov bl, SPAWN_WEIGHT_CAR
    cmp al, bl
    jl do_spawn_car
    sub al, bl
    mov bl, SPAWN_WEIGHT_COIN
    cmp al, bl
    jl do_spawn_coin
    jmp do_spawn_fuel

do_spawn_car:
    cmp word [spawn_counter], MIN_OBSTACLE_INTERVAL
    jl spawn_done_rs
    call spawn_blue_car
    mov word [spawn_counter], 0
    jmp spawn_done_rs

do_spawn_coin:
    cmp word [coin_counter], MIN_COIN_INTERVAL
    jl spawn_done_rs
    call spawn_coin
    mov word [coin_counter], 0
    jmp spawn_done_rs

do_spawn_fuel:
    cmp word [fuel_counter], MIN_FUEL_INTERVAL
    jl spawn_done_rs
    call spawn_fuel
    mov word [fuel_counter], 0

spawn_done_rs:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

spawn_blue_car:
    push ax
    push bx
    push cx
    
    mov bx, blue_cars
    mov cx, 10
    
find_slot:
    cmp byte [bx], 0
    je found_slot
    add bx, 3
    loop find_slot
    jmp spawn_done
    
found_slot:
    ; global spacing: avoid spawning any car if a recent one exists
    push si
    push cx
    mov si, blue_cars
    mov cx, 10
global_blue_spacing_loop:
    cmp byte [si], 0
    je next_global_spacing
    mov al, [si+1]          ; existing car row from top
    cmp al, MIN_OBSTACLE_INTERVAL
    jl abort_spawn_car_pre  ; too close vertically to last car
next_global_spacing:
    add si, 3
    loop global_blue_spacing_loop
    pop cx
    pop si

    mov byte [bx], 1
    mov byte [bx+1], 0  ; start at row 0 (top of screen)

    ; choose a lane randomly, ensure gap from existing items
    call get_random_lane
    mov di, 3              ; attempts for up to 3 lanes
try_lane_car:
    mov si, lane_cols
    xor ah, ah
    add si, ax
    mov dl, [si]          ; candidate column

    ; check gap against existing blue cars in this lane
    push bx
    push cx
    mov si, blue_cars
    mov cx, 10
check_gap_bvb:
    cmp byte [si], 0
    je next_gap_bvb2
    mov al, [si+2]
    cmp al, dl
    jne next_gap_bvb2
    mov al, [si+1]
    cmp al, MIN_OBSTACLE_INTERVAL
    jl lane_car_fail
next_gap_bvb2:
    add si, 3
    loop check_gap_bvb

    ; check gap against coins in this lane
    mov si, coins
    mov cx, 10
check_gap_bvc2:
    cmp byte [si], 0
    je next_gap_bvc2
    mov al, [si+2]
    cmp al, dl
    jne next_gap_bvc2
    mov al, [si+1]
    cmp al, GAP_ITEM_BETWEEN
    jl lane_car_fail
next_gap_bvc2:
    add si, 3
    loop check_gap_bvc2

    ; check gap against fuel in this lane
    mov si, fuel_items
    mov cx, 5
check_gap_bvf2:
    cmp byte [si], 0
    je next_gap_bvf2
    mov al, [si+2]
    cmp al, dl
    jne next_gap_bvf2
    mov al, [si+1]
    cmp al, GAP_ITEM_BETWEEN
    jl lane_car_fail
next_gap_bvf2:
    add si, 3
    loop check_gap_bvf2

    ; lane is clear, assign column
    pop cx
    pop bx
    mov byte [bx+2], dl
    jmp spawn_done

lane_car_fail:
    pop cx
    pop bx
    ; try next lane
    inc ax
    cmp ax, 3
    jl lane_car_idx_ok
    xor ax, ax
lane_car_idx_ok:
    dec di
    jnz try_lane_car
    ; no lane clear, release slot
    mov byte [bx], 0
    jmp spawn_done

abort_spawn_car_pre:
    pop cx
    pop si
    jmp spawn_done
    
spawn_done:
    pop cx
    pop bx
    pop ax
    ret

spawn_coin:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, coins
    mov cx, 10
    
find_coin_slot:
    cmp byte [bx], 0
    je found_coin_slot
    add bx, 3
    loop find_coin_slot
    jmp spawn_coin_done
    
found_coin_slot:
    mov byte [bx], 1
    mov byte [bx+1], 0
    
    ; choose lane randomly and ensure gap from blue cars and fuel
    call get_random_lane
    mov di, 3
try_lane_coin:
    mov si, lane_cols
    xor ah, ah
    add si, ax
    mov dl, [si]
    
    ; avoid red car lane
    mov al, [red_car_col]
    cmp dl, al
    je lane_coin_fail

    ; ensure gap from any blue car in same lane
    push cx
    push si
    mov si, blue_cars
    mov cx, 10
coin_vs_blue_loop2:
    cmp byte [si], 0
    je next_cvb2
    mov al, [si+2]
    cmp al, dl
    jne next_cvb2
    mov al, [si+1]
    cmp al, GAP_COIN_TO_CAR
    jl lane_coin_fail_pop
next_cvb2:
    add si, 3
    loop coin_vs_blue_loop2

    ; ensure gap from any fuel in same lane
    mov si, fuel_items
    mov cx, 5
coin_vs_fuel_loop2:
    cmp byte [si], 0
    je next_cvf2
    mov al, [si+2]
    cmp al, dl
    jne next_cvf2
    mov al, [si+1]
    cmp al, GAP_ITEM_BETWEEN
    jl lane_coin_fail_pop
next_cvf2:
    add si, 3
    loop coin_vs_fuel_loop2

    pop si
    pop cx
    mov byte [bx+2], dl
    jmp spawn_coin_done

lane_coin_fail_pop:
    pop si
    pop cx
lane_coin_fail:
    inc ax
    cmp ax, 3
    jl lane_coin_idx_ok
    xor ax, ax
lane_coin_idx_ok:
    dec di
    jnz try_lane_coin
    mov byte [bx], 0
    
spawn_coin_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

spawn_fuel:
    push ax
    push bx
    push cx
    push dx
    
    mov bx, fuel_items
    mov cx, 5
    
find_fuel_slot:
    cmp byte [bx], 0
    je found_fuel_slot
    add bx, 3
    loop find_fuel_slot
    jmp spawn_fuel_done
    
found_fuel_slot:
    mov byte [bx], 1
    mov byte [bx+1], 0
    
    ; choose lane randomly and ensure gap from blue cars and coins
    call get_random_lane
    mov di, 3
try_lane_fuel:
    mov si, lane_cols
    xor ah, ah
    add si, ax
    mov dl, [si]
    
    ; avoid red car lane
    mov al, [red_car_col]
    cmp dl, al
    je lane_fuel_fail

    ; ensure gap from any blue car in same lane
    push cx
    push si
    mov si, blue_cars
    mov cx, 10
fuel_vs_blue_loop3:
    cmp byte [si], 0
    je next_fvb3
    mov al, [si+2]
    cmp al, dl
    jne next_fvb3
    mov al, [si+1]
    cmp al, GAP_FUEL_TO_CAR
    jl lane_fuel_fail_pop
next_fvb3:
    add si, 3
    loop fuel_vs_blue_loop3

    ; ensure gap from any coin in same lane
    mov si, coins
    mov cx, 10
fuel_vs_coin_loop3:
    cmp byte [si], 0
    je next_fvc3
    mov al, [si+2]
    cmp al, dl
    jne next_fvc3
    mov al, [si+1]
    cmp al, GAP_ITEM_BETWEEN
    jl lane_fuel_fail_pop
next_fvc3:
    add si, 3
    loop fuel_vs_coin_loop3

    pop si
    pop cx
    mov byte [bx+2], dl
    
spawn_fuel_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

update_positions:
    push ax
    push bx
    push cx
    
    mov bx, blue_cars
    mov cx, 3
    
update_cars_loop:
    cmp byte [bx], 0
    je next_car
    
    inc byte [bx+1]
    
    cmp byte [bx+1], 25
    jl next_car
    
    mov byte [bx], 0
    
next_car:
    add bx, 3
    loop update_cars_loop
    
    mov bx, coins
    mov cx, 10
    
update_coins_loop:
    cmp byte [bx], 0
    je next_coin
    
    inc byte [bx+1]
    
    cmp byte [bx+1], 25
    jl next_coin
    
    mov byte [bx], 0
    
next_coin:
    add bx, 3
    loop update_coins_loop
    
    mov bx, fuel_items
    mov cx, 5
    
update_fuel_loop:
    cmp byte [bx], 0
    je next_fuel
    
    inc byte [bx+1]
    
    cmp byte [bx+1], 25
    jl next_fuel
    
    mov byte [bx], 0
    
next_fuel:
    add bx, 3
    loop update_fuel_loop
    
    pop cx
    pop bx
    pop ax
    ret

draw_all_blue_cars:
    push ax
    push bx
    push cx
    
    mov bx, blue_cars
    mov cx, 10
    
draw_cars_loop:
    cmp byte [bx], 0
    je skip_draw_car
    
    mov al, [bx+1]
    mov ah, [bx+2]
    call draw_blue_car_at
    
skip_draw_car:
    add bx, 3
    loop draw_cars_loop
    
    pop cx
    pop bx
    pop ax
    ret

draw_blue_car_at:
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov cl, al  ; row
    mov ch, ah  ; col
    
    ; check if car is off screen
    cmp cl, 25
    jg car_skip_all
    cmp cl, 0
    jl car_skip_all
    
    mov ax, 0xb800
    mov es, ax
    
    ; use constant blue color for all positions (no fade)
    mov dh, 0x01  ; foreground blue on black
    
draw_body:
    ; draw car body row by row (rows 0-3 of car)
    mov dl, 0
draw_blue_body_loop:
    cmp dl, 4
    jge draw_blue_wheels
    
    ; check if row is on screen
    mov al, cl
    add al, dl
    cmp al, 25
    jge draw_blue_wheels
    cmp al, 0
    jl next_blue_row
    
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, ch
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; draw 3 characters wide with constant color
    mov al, 0xDB  ; character
    mov ah, dh    ; color attribute
    stosw
    stosw
    stosw
    
next_blue_row:
    inc dl
    jmp draw_blue_body_loop
    
draw_blue_wheels:
    ; draw front wheels on row 0 (top of car body)
    mov al, cl
    add al, 0
    cmp al, 25
    jge draw_back_wheels
    cmp al, 0
    jl draw_back_wheels
    
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, ch
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; left front wheel (black, always visible)
    mov ax, 0x00DB
    stosw
    ; middle stays colored (constant body color)
    mov al, 0xDB
    mov ah, dh
    stosw
    ; right front wheel (black, always visible)
    mov ax, 0x00DB
    stosw
    
draw_back_wheels:
    ; draw back wheels on row 4 (bottom of car)
    mov al, cl
    add al, 4
    cmp al, 25
    jge car_skip_all
    cmp al, 0
    jl car_skip_all
    
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, ch
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; left back wheel (black, aligned same as front)
    mov ax, 0x00DB
    stosw
    ; middle body color (so back wheels frame the body)
    mov al, 0xDB
    mov ah, dh
    stosw
    ; right back wheel (black, aligned same as front)
    mov ax, 0x00DB
    stosw
    
car_skip_all:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret

check_coin_car_overlap:
    push bx
    push cx
    push dx
    
    mov dl, al
    mov dh, ah
    
    mov al, [red_car_row]
    mov ah, [red_car_col]
    
    cmp dl, al
    jl check_blue_cars
    mov bl, al
    add bl, 4
    cmp dl, bl
    jg check_blue_cars
    
    cmp dh, ah
    jl check_blue_cars
    mov bl, ah
    add bl, 2
    cmp dh, bl
    jg check_blue_cars
    
    mov al, 1
    jmp overlap_done
    
check_blue_cars:
    mov bx, blue_cars
    mov cx, 3
    
check_blue_loop:
    cmp byte [bx], 0
    je next_blue_check
    
    mov al, [bx+1]
    
    cmp dl, al
    jl next_blue_check
    mov si, ax
    add al, 4
    cmp dl, al
    jg next_blue_check
    
    mov al, [bx+2]
    cmp dh, al
    jl next_blue_check
    add al, 2
    cmp dh, al
    jg next_blue_check
    
    mov al, 1
    jmp overlap_done
    
next_blue_check:
    add bx, 3
    loop check_blue_loop
    
    mov al, 0
    
overlap_done:
    pop dx
    pop cx
    pop bx
    ret

draw_all_coins:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    mov bx, coins
    mov cx, 10
    
draw_coins_loop:
    cmp byte [bx], 0
    je skip_draw_coin
    
    mov al, [bx+1]
    cmp al, 24
    jge skip_draw_coin
    
    mov ah, [bx+2]
    push bx
    push cx
    call check_coin_car_overlap
    pop cx
    pop bx
    
    cmp al, 1
    je skip_draw_coin
    
    mov al, [bx+1]
    xor ah, ah
    push cx
    mov cl, 80
    mul cl
    pop cx
    
    mov dl, [bx+2]
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov di, ax
    
    mov ax, 0x7E4F
    stosw
    
skip_draw_coin:
    add bx, 3
    loop draw_coins_loop
    
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_fuel_bar:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    mov al, [fuel_bar_row]
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, [fuel_bar_col]
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    mov ax, 0x0F46
    stosw
    mov ax, 0x0F55
    stosw
    mov ax, 0x0F45
    stosw
    mov ax, 0x0F4C
    stosw
    mov ax, 0x0F3A
    stosw
    
    mov cl, [fuel_level]
    xor ch, ch
    
    mov ax, cx
    mov bl, 5
    div bl
    mov bl, al
    
    mov cx, 20
    
draw_fuel_chars:
    cmp cx, 0
    je fuel_bar_done
    
    mov al, 20
    sub al, cl
    cmp al, bl
    jl draw_filled
    
    mov ax, 0x70DB
    stosw
    jmp next_fuel_char
    
draw_filled:
    mov al, [fuel_level]
    cmp al, 50
    jg draw_green_fuel
    cmp al, 30
    jg draw_yellow_fuel
    
    mov ax, 0x4CDB
    stosw
    jmp next_fuel_char
    
draw_yellow_fuel:
    mov ax, 0x6EDB
    stosw
    jmp next_fuel_char
    
draw_green_fuel:
    mov ax, 0x2ADB
    stosw
    
next_fuel_char:
    dec cx
    jmp draw_fuel_chars
    
fuel_bar_done:
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_all_fuel:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    mov bx, fuel_items
    mov cx, 5
    
draw_fuel_loop:
    cmp byte [bx], 0
    je skip_draw_fuel
    
    mov al, [bx+1]
    cmp al, 24
    jge skip_draw_fuel
    
    mov ah, [bx+2]
    push bx
    push cx
    call check_coin_car_overlap
    pop cx
    pop bx
    
    cmp al, 1
    je skip_draw_fuel
    
    mov al, [bx+1]
    xor ah, ah
    push cx
    mov cl, 80
    mul cl
    pop cx
    
    mov dl, [bx+2]
    xor dh, dh
    add ax, dx
    shl ax, 1
    mov di, ax
    
    mov ax, 0x7C46
    stosw
    
skip_draw_fuel:
    add bx, 3
    loop draw_fuel_loop
    
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_red_car:
    push es
    push ax
    push bx
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    mov cl, [red_car_row]
    
    ; draw solid red rectangle body (rows 0-3)
    mov ch, 0
draw_red_body_loop:
    cmp ch, 4
    jge draw_red_wheels
    
    mov al, cl
    add al, ch
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, [red_car_col]
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; draw 3 characters wide
    mov ax, 0x44DB
    stosw
    stosw
    stosw
    
    inc ch
    jmp draw_red_body_loop
    
draw_red_wheels:
    ; draw front wheels on row 0 (top of car body)
    mov al, cl
    add al, 0
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, [red_car_col]
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; left front wheel (black)
    mov ax, 0x00DB
    stosw
    ; middle stays red (body)
    mov ax, 0x44DB
    stosw
    ; right front wheel (black)
    mov ax, 0x00DB
    stosw
    
    ; draw back wheels on row 4 (bottom of car)
    mov al, cl
    add al, 4
    xor ah, ah
    mov bl, 80
    mul bl
    mov bl, [red_car_col]
    xor bh, bh
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; left back wheel (black)
    mov ax, 0x00DB
    stosw
    ; middle stays red (body)
    mov ax, 0x44DB
    stosw
    ; right back wheel (black)
    mov ax, 0x00DB
    stosw
    
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

; move car left - moves to left lane
move_left:
    push ax
    push bx
    
    mov al, [red_car_col]
    mov bl, [lane_cols]      ; leftmost lane
    cmp al, bl
    je move_left_done        ; already in leftmost lane
    
    ; find current lane and move to left lane
    mov bl, [lane_cols + 1]  ; middle lane
    cmp al, bl
    je move_to_left_lane     ; currently in middle, move to left
    
    mov bl, [lane_cols + 2]  ; right lane
    cmp al, bl
    je move_to_middle_lane   ; currently in right, move to middle
    
    jmp move_left_done       ; not in any lane, don't move
    
move_to_left_lane:
    mov al, [lane_cols]
    push ax
    push bx
    push cx
    push dx
    mov bx, blue_cars
    mov cx, 10
ml_check_loop:
    cmp byte [bx], 0
    je ml_next
    mov dl, [bx+2]
    cmp dl, al
    jne ml_next
    mov dl, [bx+1]
    mov dh, [red_car_row]
    mov si, dx
    mov al, dl
    add al, 4
    cmp dh, al
    jg ml_next
    mov dx, si
    mov al, dh
    add al, 4
    cmp dl, al
    jg ml_next
    mov byte [end_cause], 3
    call draw_spark_current
    pop dx
    pop cx
    pop bx
    pop ax
    jmp move_left_done
ml_next:
    add bx, 3
    loop ml_check_loop
    pop dx
    pop cx
    pop bx
    pop ax
    mov [red_car_col], al
    jmp move_left_done
    
move_to_middle_lane:
    mov al, [lane_cols + 1]
    push ax
    push bx
    push cx
    push dx
    mov bx, blue_cars
    mov cx, 10
mm_check_loop:
    cmp byte [bx], 0
    je mm_next
    mov dl, [bx+2]
    cmp dl, al
    jne mm_next
    mov dl, [bx+1]
    mov dh, [red_car_row]
    mov si, dx
    mov al, dl
    add al, 4
    cmp dh, al
    jg mm_next
    mov dx, si
    mov al, dh
    add al, 4
    cmp dl, al
    jg mm_next
    mov byte [end_cause], 3
    call draw_spark_current
    pop dx
    pop cx
    pop bx
    pop ax
    jmp move_left_done
mm_next:
    add bx, 3
    loop mm_check_loop
    pop dx
    pop cx
    pop bx
    pop ax
    mov [red_car_col], al
    
move_left_done:
    pop bx
    pop ax
    ret

; move car right - moves to right lane
move_right:
    push ax
    push bx
    
    mov al, [red_car_col]
    mov bl, [lane_cols + 2]  ; rightmost lane
    cmp al, bl
    je move_right_done       ; already in rightmost lane
    
    ; find current lane and move to right lane
    mov bl, [lane_cols]      ; left lane
    cmp al, bl
    je move_to_middle_from_left ; currently in left, move to middle
    
    mov bl, [lane_cols + 1]  ; middle lane
    cmp al, bl
    je move_to_right_lane    ; currently in middle, move to right
    
    jmp move_right_done      ; not in any lane, don't move
    
move_to_middle_from_left:
    mov al, [lane_cols + 1]
    push ax
    push bx
    push cx
    push dx
    mov bx, blue_cars
    mov cx, 10
mml_check_loop:
    cmp byte [bx], 0
    je mml_next
    mov dl, [bx+2]
    cmp dl, al
    jne mml_next
    mov dl, [bx+1]
    mov dh, [red_car_row]
    mov si, dx
    mov al, dl
    add al, 4
    cmp dh, al
    jg mml_next
    mov dx, si
    mov al, dh
    add al, 4
    cmp dl, al
    jg mml_next
    mov byte [end_cause], 3
    call draw_spark_current
    pop dx
    pop cx
    pop bx
    pop ax
    jmp move_right_done
mml_next:
    add bx, 3
    loop mml_check_loop
    pop dx
    pop cx
    pop bx
    pop ax
    mov [red_car_col], al
    jmp move_right_done
    
move_to_right_lane:
    mov al, [lane_cols + 2]
    push ax
    push bx
    push cx
    push dx
    mov bx, blue_cars
    mov cx, 10
mrl_check_loop:
    cmp byte [bx], 0
    je mrl_next
    mov dl, [bx+2]
    cmp dl, al
    jne mrl_next
    mov dl, [bx+1]
    mov dh, [red_car_row]
    mov si, dx
    mov al, dl
    add al, 4
    cmp dh, al
    jg mrl_next
    mov dx, si
    mov al, dh
    add al, 4
    cmp dl, al
    jg mrl_next
    mov byte [end_cause], 3
    call draw_spark_current
    pop dx
    pop cx
    pop bx
    pop ax
    jmp move_right_done
mrl_next:
    add bx, 3
    loop mrl_check_loop
    pop dx
    pop cx
    pop bx
    pop ax
    mov [red_car_col], al
    
move_right_done:
    pop bx
    pop ax
    ret

; move car up
move_up:
    push ax
    
    mov al, [red_car_row]
    cmp al, 0
    jle move_up_done
    
    dec byte [red_car_row]
    
move_up_done:
    pop ax
    ret

; move car down - one block at a time
move_down:
    push ax
    
    mov al, [red_car_row]
    ; car is 5 rows tall (0-4), so max row is 20 (25-5=20)
    cmp al, 20
    jge move_down_done
    
    inc byte [red_car_row]
    
move_down_done:
    pop ax
    ret

; draw pause menu with confirmation screen
draw_pause_menu:
    push es
    push ax
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    ; draw box background
    mov di, (10 * 80 + 25) * 2
    mov cx, 30
    mov ax, 0x7020
draw_pause_line1:
    stosw
    loop draw_pause_line1
    
    mov di, (11 * 80 + 25) * 2
    mov cx, 30
draw_pause_line2:
    stosw
    loop draw_pause_line2
    
    mov di, (12 * 80 + 25) * 2
    mov cx, 30
draw_pause_line3:
    stosw
    loop draw_pause_line3
    
    mov di, (13 * 80 + 25) * 2
    mov cx, 30
draw_pause_line4:
    stosw
    loop draw_pause_line4
    
    ; draw message "Do you want to quit?"
    mov di, (11 * 80 + 28) * 2
    
    mov ax, 0x7044  ; D
    stosw
    mov ax, 0x706F  ; o
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x7079  ; y
    stosw
    mov ax, 0x706F  ; o
    stosw
    mov ax, 0x7075  ; u
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x7077  ; w
    stosw
    mov ax, 0x7061  ; a
    stosw
    mov ax, 0x706E  ; n
    stosw
    mov ax, 0x7074  ; t
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x7074  ; t
    stosw
    mov ax, 0x706F  ; o
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x7071  ; q
    stosw
    mov ax, 0x7075  ; u
    stosw
    mov ax, 0x7069  ; i
    stosw
    mov ax, 0x7074  ; t
    stosw
    mov ax, 0x703F  ; ?
    stosw
    
    ; draw options
    mov di, (12 * 80 + 32) * 2
    mov ax, 0x7059  ; Y
    stosw
    mov ax, 0x7065  ; e
    stosw
    mov ax, 0x7073  ; s
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x702D  ; -
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x7059  ; Y
    stosw
    
    mov ax, 0x7020  ; space
    stosw
    stosw
    stosw
    
    mov ax, 0x704E  ; N
    stosw
    mov ax, 0x706F  ; o
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x702D  ; -
    stosw
    mov ax, 0x7020  ; space
    stosw
    mov ax, 0x704E  ; N
    stosw
    
    pop di
    pop cx
    pop ax
    pop es
    ret

draw_confirm_box_pre:
    push es
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    ; framed confirmation box: rows 9..13, cols 20..59
    ; top border
    mov di, (9 * 80 + 20) * 2
    mov ax, 0x1F2B ; '+'
    stosw
    mov cx, 38
    mov ax, 0x1F2D ; '-'
dcbp_top_fill:
    stosw
    loop dcbp_top_fill
    mov ax, 0x1F2B ; '+'
    stosw
    ; inner background rows with side borders
    mov di, (10 * 80 + 20) * 2
    mov ax, 0x1F7C ; '|'
    stosw
    mov cx, 38
    mov ax, 0x7020 ; grey background space
dcbp_inner1:
    stosw
    loop dcbp_inner1
    mov ax, 0x1F7C ; '|'
    stosw
    mov di, (11 * 80 + 20) * 2
    mov ax, 0x1F7C ; '|'
    stosw
    mov cx, 38
    mov ax, 0x7020
dcbp_inner2:
    stosw
    loop dcbp_inner2
    mov ax, 0x1F7C ; '|'
    stosw
    ; bottom border
    mov di, (12 * 80 + 20) * 2
    mov ax, 0x1F2B ; '+'
    stosw
    mov cx, 38
    mov ax, 0x1F2D ; '-'
dcbp_bot_fill:
    stosw
    loop dcbp_bot_fill
    mov ax, 0x1F2B ; '+'
    stosw
    ; message and options in white on grey
    mov di, (10 * 80 + 22) * 2
    mov ax, 0x0F44 ; D
    stosw
    mov ax, 0x0F6F ; o
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F79 ; y
    stosw
    mov ax, 0x0F6F ; o
    stosw
    mov ax, 0x0F75 ; u
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F77 ; w
    stosw
    mov ax, 0x0F61 ; a
    stosw
    mov ax, 0x0F6E ; n
    stosw
    mov ax, 0x0F74 ; t
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F74 ; t
    stosw
    mov ax, 0x0F6F ; o
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F71 ; q
    stosw
    mov ax, 0x0F75 ; u
    stosw
    mov ax, 0x0F69 ; i
    stosw
    mov ax, 0x0F74 ; t
    stosw
    mov ax, 0x0F3F ; ?
    stosw
    ; options line
    mov di, (11 * 80 + 26) * 2
    mov ax, 0x0F59 ; Y
    stosw
    mov ax, 0x0F3D ; '='
    stosw
    mov ax, 0x0F59 ; Y
    stosw
	mov ax, 0x0F65  ; e
    stosw
    mov ax, 0x0F73  ; s
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F4E ; N
    stosw
    mov ax, 0x0F3D ; '='
    stosw
    mov ax, 0x0F4E ; N
    stosw
	mov ax, 0x0F6F  ; o
    stosw
    ; wait key
    mov ah, 0
    int 0x16
    pop di
    pop cx
    pop es
    ret

erase_confirm_box_area_black:
    push es
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    ; clear rows 9..12, cols 20..59 with black spaces
    mov di, (9 * 80 + 20) * 2
    mov cx, 40
    mov ax, 0x0720
ecbab_line0:
    stosw
    loop ecbab_line0
    mov di, (10 * 80 + 20) * 2
    mov cx, 40
ecbab_line1:
    stosw
    loop ecbab_line1
    mov di, (11 * 80 + 20) * 2
    mov cx, 40
ecbab_line2:
    stosw
    loop ecbab_line2
    mov di, (12 * 80 + 20) * 2
    mov cx, 40
ecbab_line3:
    stosw
    loop ecbab_line3
    pop di
    pop cx
    pop es
    ret

; keyboard interrupt handler
keyboard_isr:
    push ax
    push bx
    
    in al, 0x60
    
    ; check if key release (bit 7 set)
    test al, 0x80
    jnz keyboard_done
    mov word [event_beep_ticks], 0
    
    ; check if game started
    cmp byte [game_started], 0
    je start_game_check
    
    ; check if game paused
    cmp byte [game_paused], 1
    je paused_keys
    
    ; normal game keys
    cmp al, KEY_LEFT
    je handle_left
    cmp al, KEY_RIGHT
    je handle_right
    cmp al, KEY_UP
    je handle_up
    cmp al, KEY_DOWN
    je handle_down
    cmp al, KEY_ESC
    je handle_esc
    jmp keyboard_done
    
start_game_check:
    ; any key starts the game
    mov byte [game_started], 1
    jmp keyboard_done
    
handle_left:
    cmp byte [lane_cooldown], 0
    jne keyboard_done
    call move_left
    mov byte [lane_cooldown], 4
    jmp keyboard_done
    
handle_right:
    cmp byte [lane_cooldown], 0
    jne keyboard_done
    call move_right
    mov byte [lane_cooldown], 4
    jmp keyboard_done
    
handle_up:
    call move_up
    jmp keyboard_done
    
handle_down:
    call move_down
    jmp keyboard_done
    
handle_esc:
    xor byte [game_paused], 1
    jmp keyboard_done
    
paused_keys:
    ; only Y, N, and ESC work during pause
    cmp al, KEY_Y
    je handle_quit
    cmp al, KEY_N
    je handle_resume
    cmp al, KEY_ESC
    je handle_resume
    jmp keyboard_done
    
handle_quit:
    mov byte [game_paused], 0
    mov byte [end_cause], 1
    jmp keyboard_done
    
handle_resume:
    ; resume smoothly - just unpause
    mov byte [game_paused], 0
    jmp keyboard_done
    
keyboard_done:
    mov al, 0x20
    out 0x20, al
    
    pop bx
    pop ax
    iret

; setup keyboard interrupt
setup_keyboard:
    push ax
    push es
    
    xor ax, ax
    mov es, ax
    
    mov ax, [es:9*4]
    mov [old_keyboard_isr], ax
    mov ax, [es:9*4+2]
    mov [old_keyboard_isr+2], ax
    
    cli
    mov word [es:9*4], keyboard_isr
    mov [es:9*4+2], cs
    sti
    mov byte [kb_hooked], 1
    
    pop es
    pop ax
    ret

setup_timer:
    push ax
    push es
    xor ax, ax
    mov es, ax
    mov ax, [es:8*4]
    mov [old_timer_isr], ax
    mov ax, [es:8*4+2]
    mov [old_timer_isr+2], ax
    cli
    mov word [es:8*4], timer_isr
    mov [es:8*4+2], cs
    sti
    mov byte [tmr_hooked], 1
    pop es
    pop ax
    ret

restore_timer:
    push ax
    push es
    xor ax, ax
    mov es, ax
    cli
    mov ax, [old_timer_isr]
    mov [es:8*4], ax
    mov ax, [old_timer_isr+2]
    mov [es:8*4+2], ax
    sti
    mov byte [tmr_hooked], 0
    pop es
    pop ax
    ret

music_start:
    mov byte [music_active], 1
    ret

music_stop:
    mov byte [music_active], 0
    in al, 0x61
    and al, 0xFC
    out 0x61, al
    ret

sound_coin:
    mov word [event_divisor], 1136
    mov word [event_beep_ticks], 2
    ret

sound_fuel:
    mov word [event_divisor], 1136
    mov word [event_beep_ticks], 2
    ret

sound_crash:
    mov word [event_divisor], 3180
    mov word [event_beep_ticks], 30
    ret

timer_isr:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    push cs
    pop ds
    cmp byte [music_active], 1
    jne ti_silence
    mov ax, [music_tempo]
    inc word [music_tick_counter]
    cmp [music_tick_counter], ax
    jl ti_select
    mov word [music_tick_counter], 0
    inc word [music_note_index]
    mov bx, [music_len]
    cmp [music_note_index], bx
    jl ti_select
    xor bx, bx
    mov [music_note_index], bx
ti_select:
    cmp word [event_beep_ticks], 0
    jg ti_event_now
    mov bx, [music_note_index]
    shl bx, 1
    mov si, music_notes
    add si, bx
    mov ax, [si]
    jmp ti_set_now
ti_event_now:
    mov ax, [event_divisor]
    dec word [event_beep_ticks]
ti_set_now:
    mov dx, ax
    mov al, 0xB6
    out 0x43, al
    mov al, dl
    out 0x42, al
    mov al, dh
    out 0x42, al
    in al, 0x61
    or al, 3
    out 0x61, al
    jmp ti_chain
ti_silence:
    in al, 0x61
    and al, 0xFC
    out 0x61, al
ti_chain:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    jmp far [old_timer_isr]

; restore keyboard interrupt
restore_keyboard:
    push ax
    push es
    
    xor ax, ax
    mov es, ax
    
    cli
    mov ax, [old_keyboard_isr]
    mov [es:9*4], ax
    mov ax, [old_keyboard_isr+2]
    mov [es:9*4+2], ax
    sti
    
    pop es
    pop ax
    ret

delay:
    push cx
    push dx
    mov cx, 0x0130
delay_loop:
    mov dx, 0x0200
delay_inner:
    dec dx
    jnz delay_inner
    loop delay_loop
    pop dx
    pop cx
    ret

; draw start screen
draw_start_screen:
    push es
    push ax
    push bx
    push cx
    push si
    push di
    mov ax, 0xb800
    mov es, ax
    call clrscr
    mov bh, 0x0F
    mov al, 7
    mov si, s_start_title
    call draw_centered_line
    mov al, 9
    mov si, s_start_devlabel
    call draw_centered_line
    mov al, 10
    mov si, s_start_dev1
    call draw_centered_line
    mov al, 11
    mov si, s_start_dev2
    call draw_centered_line
    mov al, 13
    mov si, s_start_rolllabel
    call draw_centered_line
    mov al, 14
    mov si, s_start_roll1
    call draw_centered_line
    mov al, 15
    mov si, s_start_roll2
    call draw_centered_line
    mov al, 18
    mov si, s_start_press
    call draw_centered_line
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop es
    ret

input_text:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    mov si, dx
read_loop_it:
    mov ah, 0
    int 0x16
    cmp al, 13
    je input_done_it
    cmp al, 27
    jne store_char_it
    call draw_confirm_box_pre
    cmp al, 'Y'
    je game_exit
    cmp al, 'y'
    je game_exit
    call erase_confirm_box_area_black
    jmp read_loop_it
store_char_it:
    mov [si], al
    inc si
    mov ah, 0x0F
    stosw
    jmp read_loop_it
input_done_it:
    mov byte [si], 0
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

input_player_details:
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    call clrscr
    
    ; draw title
    mov bh, 0x0F
    mov al, 5
    mov si, s_start_devlabel
    call draw_centered_line
    
    ; draw input boxes
    ; name box at row 8, col 22, width 36
    mov di, (8 * 80 + 22) * 2
    mov cx, 36
    mov ax, 0x7020
draw_name_box:
    stosw
    loop draw_name_box
    ; roll box at row 12, col 22, width 36
    mov di, (12 * 80 + 22) * 2
    mov cx, 36
    mov ax, 0x7020
draw_roll_box:
    stosw
    loop draw_roll_box

    ; labels
    mov di, (7 * 80 + 22) * 2
	mov ax, 0x0F45 ;E 
	stosw
	mov ax, 0x0F6E ; n 
	stosw
	mov ax, 0x0F74 ; t 
	stosw
	mov ax, 0x0F65; e 
	stosw
	mov ax, 0x0F72; r 
	stosw
	mov ax, 0x0F20 ; space 
	stosw
    mov ax, 0x0F4E ; N
    stosw
    mov ax, 0x0F61 ; a
    stosw
    mov ax, 0x0F6D ; m
    stosw
    mov ax, 0x0F65 ; e
    stosw
	mov ax, 0x0F3A ; :
	stosw
    mov di, (11 * 80 + 22) * 2
	mov ax, 0x0F45 ;E 
	stosw
	mov ax, 0x0F6E ; n 
	stosw
	mov ax, 0x0F74 ; t 
	stosw
	mov ax, 0x0F65; e 
	stosw
	mov ax, 0x0F72; r 
	stosw
	mov ax, 0x0F20 ; space 
	stosw
    mov ax, 0x0F52 ; R
    stosw
    mov ax, 0x0F6F ; o
    stosw
    mov ax, 0x0F6C ; l
    stosw
    mov ax, 0x0F6C ; l
    stosw
	mov ax, 0x0F20 ; space
	stosw
	mov ax, 0x0F4E ; N 
	stosw
	mov ax, 0x0F6F ; o
    stosw
	mov ax, 0x0F3A ; :
	stosw
	
    ; input into boxes
    mov di, (8 * 80 + 22) * 2
    mov dx, player_name
    call input_text
    mov di, (12 * 80 + 22) * 2
    mov dx, player_roll
    call input_text

    pop di
    pop cx
    pop ax
    pop es
    ret

; wait for game start - static screen until any key pressed
wait_for_start:
    cmp byte [game_started], 0
    je wait_for_start
    ret

wait_for_key_intro:
    mov ah, 0
    int 0x16
    cmp al, 27
    jne wki_done
    call draw_confirm_box_pre
    cmp al, 'Y'
    je game_exit
    cmp al, 'y'
    je game_exit
    cmp al, 'N'
    je wki_redraw
    cmp al, 'n'
    je wki_redraw
    jmp wait_for_key_intro
wki_redraw:
    cmp byte [pre_screen_state], 1
    jne wki_redraw_instr
    call draw_start_screen
    jmp wait_for_key_intro
wki_redraw_instr:
    cmp byte [pre_screen_state], 2
    jne wki_redraw_main
    call draw_instructions
    jmp wait_for_key_intro
wki_redraw_main:
    cmp byte [pre_screen_state], 3
    jne wait_for_key_intro
    call clrscr
    call draw_borders
    call draw_road
    call draw_lanes
    call draw_main_menu
    jmp wait_for_key_intro
wki_done:
    ret

; check collision with blue cars
check_collision:
    push bx
    push cx
    push dx
    
    mov bx, blue_cars
    mov cx, 10
    
check_collision_loop:
    cmp byte [bx], 0
    je next_collision_check
    
    ; get blue car position
    mov dl, [bx+1]  ; blue car row
    mov dh, [bx+2]  ; blue car col
    
    ; get red car position
    mov al, [red_car_row]
    mov ah, [red_car_col]
    
    ; check row overlap: red rows [al, al+4], blue rows [dl, dl+4]
    ; overlap if: al <= dl+4 AND dl <= al+4
    push ax
    mov al, dl
    add al, 4
    cmp byte [red_car_row], al
    pop ax
    jg next_collision_check  ; red car is below blue car
    
    push ax
    mov al, [red_car_row]
    add al, 4
    cmp dl, al
    pop ax
    jg next_collision_check  ; blue car is below red car
    
    ; rows overlap, check column overlap
    ; red cols [ah, ah+2], blue cols [dh, dh+2]
    push ax
    mov al, dh
    add al, 2
    cmp byte [red_car_col], al
    pop ax
    jg next_collision_check  ; red car is to the right of blue car
    
    push ax
    mov al, [red_car_col]
    add al, 2
    cmp dh, al
    pop ax
    jg next_collision_check  ; blue car is to the right of red car
    
    ; collision detected
    mov al, 1
    jmp collision_done
    
next_collision_check:
    add bx, 3
    loop check_collision_loop
    
    ; no collision
    mov al, 0
    
collision_done:
    pop dx
    pop cx
    pop bx
    ret

; check and collect coins
check_coin_collection:
    push ax
    push bx
    push cx
    push dx
    
    mov al, [red_car_row]
    mov ah, [red_car_col]
    
    mov bx, coins
    mov cx, 10
    
check_coin_loop:
    cmp byte [bx], 0
    je next_coin_check
    
    mov dl, [bx+1]
    mov dh, [bx+2]
    
    ; check if coin is within car bounds
    cmp dl, al
    jl next_coin_check
    mov si, ax
    mov al, [red_car_row]
    add al, 4
    cmp dl, al
    jg next_coin_check
    mov ax, si
    
    cmp dh, ah
    jl next_coin_check
    mov al, [red_car_col]
    add al, 2
    cmp dh, al
    jg next_coin_check
    
    mov byte [bx], 0
    mov ax, [coin_total]
    inc ax
    mov [coin_total], ax
    call sound_coin
    
next_coin_check:
    mov al, [red_car_row]
    add bx, 3
    loop check_coin_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; check and collect fuel
check_fuel_collection:
    push ax
    push bx
    push cx
    push dx
    
    mov al, [red_car_row]
    mov ah, [red_car_col]
    
    mov bx, fuel_items
    mov cx, 5
    
check_fuel_loop:
    cmp byte [bx], 0
    je next_fuel_check
    
    mov dl, [bx+1]
    mov dh, [bx+2]
    
    ; check if fuel is within car bounds
    cmp dl, al
    jl next_fuel_check
    mov si, ax
    mov al, [red_car_row]
    add al, 4
    cmp dl, al
    jg next_fuel_check
    mov ax, si
    
    cmp dh, ah
    jl next_fuel_check
    mov al, [red_car_col]
    add al, 2
    cmp dh, al
    jg next_fuel_check
    
    ; collect fuel
    mov byte [bx], 0
    mov al, [fuel_level]
    add al, 20
    cmp al, 100
    jle fuel_not_max
    mov al, 100
fuel_not_max:
    mov [fuel_level], al
    call sound_fuel
    
next_fuel_check:
    mov al, [red_car_row]
    add bx, 3
    loop check_fuel_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

game_loop:
    cmp byte [end_cause], 0
    je gl_continue
    cmp byte [end_cause], 3
    jne game_over
    cmp byte [crash_msg_shown], 1
    je game_over
    call draw_spark_current
    call draw_end_message_box
    mov byte [crash_msg_shown], 1
    jmp game_over
gl_continue:
    
    ; check if should exit
    cmp byte [should_exit], 1
    je game_exit
    
    ; check if game has started (static until key pressed)
    cmp byte [game_started], 0
    je game_loop
    
    ; check if paused
    cmp byte [game_paused], 1
    je handle_pause
    
    call check_collision
    cmp al, 1
    jne no_collision
    mov byte [end_cause], 3
    call sound_crash
    call draw_spark_current
    call draw_end_message_box
    jmp game_over
no_collision:
    
    ; check coin collection
    call check_coin_collection
    
    ; check fuel collection
    call check_fuel_collection
    
    ; consume fuel
    inc word [scroll_counter]
    cmp word [scroll_counter], 3
    jl skip_fuel_decrease
    mov word [scroll_counter], 0
    
    cmp byte [fuel_level], 0
    jne skip_end_on_fuel
    mov byte [end_cause], 2
    call draw_fuel_end_message_box
    jmp game_over
skip_end_on_fuel:
    dec byte [fuel_level]
    
skip_fuel_decrease:
    
    ; update spawn timers and spawn randomly by weights
    inc word [spawn_counter]
    inc word [coin_counter]
    inc word [fuel_counter]
    call random_spawn
    
    call update_positions
    ; cooldown: only allow one lane move every few frames
    cmp byte [lane_cooldown], 0
    je gl_skip_cool
    dec byte [lane_cooldown]
gl_skip_cool:
    
    ; redraw game
    call draw_road
    call draw_lanes
    call draw_all_blue_cars
    call draw_all_coins
    call draw_all_fuel
    call draw_red_car
    call draw_fuel_bar
    call draw_score
    
    call delay
    
    jmp game_loop

handle_pause:
    call draw_pause_menu
    
pause_wait:
    cmp byte [should_exit], 1
    je game_exit
    cmp byte [game_paused], 0
    jne pause_wait
    
    ; redraw game to remove pause menu
    call draw_road
    call draw_lanes
    call draw_all_blue_cars
    call draw_all_coins
    call draw_all_fuel
    call draw_red_car
    call draw_fuel_bar
    call draw_score
    
    jmp game_loop

game_over:
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    cmp byte [kb_hooked], 1
    jne go_no_unhook
    call restore_keyboard
    mov byte [kb_hooked], 0
go_no_unhook:
    cmp byte [tmr_hooked], 1
    jne go_no_tmr
    call music_stop
    call restore_timer
go_no_tmr:
    mov ax, 0xb800
    mov es, ax
    call clrscr
    mov di, (1 * 80 + 0) * 2
    mov ax, 0x0F45
    stosw
    mov ax, 0x0F4E
    stosw
    mov ax, 0x0F44
    stosw
    mov di, (3 * 80 + 0) * 2
    mov ax, 0x0F43
    stosw
    mov ax, 0x0F61
    stosw
    mov ax, 0x0F75
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F3A
    stosw
    mov di, (4 * 80 + 0) * 2
    mov al, [end_cause]
    cmp al, 1
    je cause_quit
    cmp al, 2
    je cause_fuel
    cmp al, 3
    je cause_crash
    jmp after_cause
cause_quit:
	mov ax, 0x0F55
	stosw
	mov ax, 0x0F73 
	stosw
	mov ax, 0x0F65 
	stosw
	mov ax, 0x0F72 
	stosw
	mov ax, 0x0F20 ; space 
	stosw
    mov ax, 0x0F51 ; Q
    stosw
    mov ax, 0x0F75 ; u
    stosw
    mov ax, 0x0F69 ; i
    stosw
    mov ax, 0x0F74 ; t
    stosw
    jmp after_cause
cause_fuel:
    mov ax, 0x0F46 ; F
    stosw
    mov ax, 0x0F75 ; u
    stosw
    mov ax, 0x0F65 ; e
    stosw
    mov ax, 0x0F6C ; l
    stosw
	mov ax, 0x0F20 ; space 
	stosw
	mov ax, 0x0F65 
	stosw
	mov ax, 0x0F6E 
	stosw
	mov ax, 0x0F64 
	stosw
    jmp after_cause
cause_crash:
	mov ax, 0x0F43
	stosw
	mov ax, 0x0F61
	stosw
	mov ax, 0x0F72
	stosw
	mov ax, 0x0F20 ; space 
	stosw
    mov ax, 0x0F43 ; C
    stosw
    mov ax, 0x0F72 ; r
    stosw
    mov ax, 0x0F61 ; a
    stosw
    mov ax, 0x0F73 ; s
    stosw
    mov ax, 0x0F68 ; h
    stosw
after_cause:
    mov di, (6 * 80 + 0) * 2
    mov ax, 0x0F4E
    stosw
    mov ax, 0x0F61
    stosw
    mov ax, 0x0F6D
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F3A
    stosw
    mov di, (7 * 80 + 0) * 2
    mov si, player_name
    mov cx, 20
print_name_loop:
    mov al, [si]
    cmp al, 0
    je print_name_done
    mov ah, 0x0F
    stosw
    inc si
    loop print_name_loop
print_name_done:
    mov di, (8 * 80 + 0) * 2
    mov ax, 0x0F52
    stosw
    mov ax, 0x0F6F
    stosw
    mov ax, 0x0F6C
    stosw
    mov ax, 0x0F6C
    stosw
	mov ax, 0x0F20 ; space 
	stosw
	mov ax, 0x0F4E 
	stosw
	mov ax, 0x0F6F 
	stosw
    mov ax, 0x0F3A
    stosw
    mov di, (9 * 80 + 0) * 2
    mov si, player_roll
    mov cx, 12
print_roll_loop:
    mov al, [si]
    cmp al, 0
    je print_roll_done
    mov ah, 0x0F
    stosw
    inc si
    loop print_roll_loop
print_roll_done:
    mov di, (10 * 80 + 0) * 2
    mov ax, 0x0F43
    stosw
    mov ax, 0x0F6F
    stosw
    mov ax, 0x0F69
    stosw
    mov ax, 0x0F6E
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F3A
    stosw
    mov di, (11 * 80 + 0) * 2
    mov ax, [coin_total]
    mov bx, 10
    xor cx, cx
conv_loop:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    cmp ax, 0
    jne conv_loop
print_digits:
    pop dx
    mov ah, 0x0F
    mov al, dl
    stosw
    loop print_digits
    mov di, (13 * 80 + 0) * 2
    mov si, s_end_instr
    mov ah, 0x0F
print_end_instr:
    mov al, [si]
    cmp al, 0
    je end_wait
    stosw
    inc si
    jmp print_end_instr
end_wait:
    mov ah, 0
    int 0x16
    mov word [event_beep_ticks], 0
    cmp al, 27
    jne end_check_keys
    call draw_confirm_box_pre
    cmp al, 'Y'
    je game_exit
    cmp al, 'y'
    je game_exit
    call erase_confirm_box_area_black
    jmp end_wait
end_check_keys:
    cmp al, 13
    jne ew_check_space
    call music_stop
    jmp restart_main
ew_check_space:
    cmp al, ' '
    jne end_wait
    call music_stop
    jmp restart_main
restart_main:
    mov byte [end_cause], 0
    mov byte [game_started], 0
    mov byte [crash_msg_shown], 0
    mov byte [lane_cooldown], 0
    xor ax, ax
    mov [coin_total], ax
    mov byte [fuel_level], 100
    mov si, coins
    mov cx, 10
clr_coins:
    mov byte [si], 0
    add si, 3
    loop clr_coins
    mov si, blue_cars
    mov cx, 10
clr_cars:
    mov byte [si], 0
    add si, 3
    loop clr_cars
    mov si, fuel_items
    mov cx, 5
clr_fuels:
    mov byte [si], 0
    add si, 3
    loop clr_fuels
    jmp start

game_exit:
    cmp byte [kb_hooked], 1
    jne skip_restore_kb
    call restore_keyboard
    mov byte [kb_hooked], 0
skip_restore_kb:
    cmp dword [old_timer_isr], 0
    je skip_restore_timer
    call music_stop
    call restore_timer
skip_restore_timer:
    call clrscr
    mov ax, 0x4c00
    int 0x21

; main start function
start:
    call draw_start_screen
    mov byte [pre_screen_state], 1
    call wait_for_key_intro
    call input_player_details
    call draw_instructions
    mov byte [pre_screen_state], 2
    call wait_for_key_intro

    call clrscr
    call draw_borders
    call draw_road
    call draw_lanes
    call draw_main_menu
    mov byte [pre_screen_state], 3
    ; pre-game ESC confirmation handled by wait_for_key_intro
    call wait_for_key_intro
    mov byte [game_started], 1
    call setup_keyboard
    cmp byte [tmr_hooked], 1
    je st_skip_hook
    call setup_timer
st_skip_hook:
    call music_start
    call draw_road
    call draw_lanes
    jmp game_loop
lane_fuel_fail_pop:
    pop si
    pop cx
lane_fuel_fail:
    inc ax
    cmp ax, 3
    jl lane_fuel_idx_ok
    xor ax, ax
lane_fuel_idx_ok:
    dec di
    jnz try_lane_fuel
    mov byte [bx], 0

draw_spark_current:
    push es
    push ax
    push bx
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    mov bl, [red_car_row]
    mov bh, [red_car_col]
    mov di, (0 * 80 + 0) * 2
    mov al, bl
    mov cl, 80
    mul cl
    xor dx, dx
    mov dl, bh
    add ax, dx
    add ax, 81
    shl ax, 1
    mov di, ax
    mov cx, 9
spark_loop:
    mov ax, 0x7E2A
    stosw
    loop spark_loop
    pop di
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_end_message_box:
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    cmp byte [kb_hooked], 1
    jne de_no_unhook
    call restore_keyboard
    mov byte [kb_hooked], 0
de_no_unhook:
    mov di, (9 * 80 + 20) * 2
    mov ax, 0x1F2B
    stosw
    mov cx, 38
    mov ax, 0x1F2D
de_top:
    stosw
    loop de_top
    mov ax, 0x1F2B
    stosw
    mov di, (10 * 80 + 20) * 2
    mov ax, 0x1F7C
    stosw
    mov cx, 38
    mov ax, 0x7020
de_in1:
    stosw
    loop de_in1
    mov ax, 0x1F7C
    stosw
    mov di, (11 * 80 + 20) * 2
    mov ax, 0x1F7C
    stosw
    mov cx, 38
    mov ax, 0x7020
de_in2:
    stosw
    loop de_in2
    mov ax, 0x1F7C
    stosw
    mov di, (12 * 80 + 20) * 2
    mov ax, 0x1F2B
    stosw
    mov cx, 38
    mov ax, 0x1F2D
de_bot:
    stosw
    loop de_bot
    mov ax, 0x1F2B
    stosw
    mov di, (10 * 80 + 28) * 2
    mov ax, 0x0F43
    stosw
    mov ax, 0x0F72
    stosw
    mov ax, 0x0F61
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F68
    stosw
    mov ax, 0x0F21
    stosw
    mov di, (11 * 80 + 26) * 2
    mov ax, 0x0F47
    stosw
    mov ax, 0x0F61
    stosw
    mov ax, 0x0F6D
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F20
    stosw
    mov ax, 0x0F4F
    stosw
    mov ax, 0x0F76
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F72
    stosw
    mov di, (11 * 80 + 40) * 2
    mov ax, 0x0F50 ; P
    stosw
    mov ax, 0x0F72 ; r
    stosw
    mov ax, 0x0F65 ; e
    stosw
    mov ax, 0x0F73 ; s
    stosw
    mov ax, 0x0F73 ; s
    stosw
    mov ax, 0x0F20 ; space
    stosw
    mov ax, 0x0F45 ; E
    stosw
    mov ax, 0x0F6E ; n
    stosw
    mov ax, 0x0F74 ; t
    stosw
    mov ax, 0x0F65 ; e
    stosw
    mov ax, 0x0F72 ; r
    stosw
de_wait_loop:
    mov ah, 0
    int 0x16
    cmp al, 0
    je de_check_scan
    cmp al, 13
    je de_key_done
    jmp de_wait_loop
de_check_scan:
    cmp ah, 0x1C
    je de_key_done
    jmp de_wait_loop
de_key_done:
    mov byte [crash_msg_shown], 1
    pop di
    pop cx
    pop ax
    pop es
    ret

draw_score:
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    mov ax, 0xb800
    mov es, ax
    ; position row 0, col 12
    xor ax, ax
    mov cl, 80
    mul cl
    add ax, 12
    shl ax, 1
    mov di, ax
    ; print "Score: " in white on grey
    mov ax, 0x7F53 ; S
    stosw
    mov ax, 0x7F63 ; c
    stosw
    mov ax, 0x7F6F ; o
    stosw
    mov ax, 0x7F72 ; r
    stosw
    mov ax, 0x7F65 ; e
    stosw
    mov ax, 0x7F3A ; :
    stosw
    mov ax, 0x7F20 ; space
    stosw
    ; print coin_total
    mov ax, [coin_total]
    mov bx, 10
    xor cx, cx
ds_conv_loop:
    xor dx, dx
    div bx
    add dl, '0'
    push dx
    inc cx
    cmp ax, 0
    jne ds_conv_loop
ds_print_digits:
    pop dx
    mov ah, 0x7F
    mov al, dl
    stosw
    loop ds_print_digits
    ; clear trailing area
    mov cx, 3
    mov ax, 0x7F20
ds_clear_tail:
    stosw
    loop ds_clear_tail
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    ret

draw_fuel_end_message_box:
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    cmp byte [kb_hooked], 1
    jne df_no_unhook
    call restore_keyboard
    mov byte [kb_hooked], 0
df_no_unhook:
    mov di, (9 * 80 + 20) * 2
    mov ax, 0x1F2B
    stosw
    mov cx, 38
    mov ax, 0x1F2D
df_top:
    stosw
    loop df_top
    mov ax, 0x1F2B
    stosw
    mov di, (10 * 80 + 20) * 2
    mov ax, 0x1F7C
    stosw
    mov cx, 38
    mov ax, 0x7020
df_in1:
    stosw
    loop df_in1
    mov ax, 0x1F7C
    stosw
    mov di, (11 * 80 + 20) * 2
    mov ax, 0x1F7C
    stosw
    mov cx, 38
    mov ax, 0x7020
df_in2:
    stosw
    loop df_in2
    mov ax, 0x1F7C
    stosw
    mov di, (12 * 80 + 20) * 2
    mov ax, 0x1F2B
    stosw
    mov cx, 38
    mov ax, 0x1F2D
df_bot:
    stosw
    loop df_bot
    mov ax, 0x1F2B
    stosw
    mov di, (10 * 80 + 26) * 2
    mov ax, 0x0F46
    stosw
    mov ax, 0x0F75
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F6C
    stosw
    mov ax, 0x0F20
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F6E
    stosw
    mov ax, 0x0F64
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F21
    stosw
    mov di, (11 * 80 + 26) * 2
    mov ax, 0x0F47
    stosw
    mov ax, 0x0F61
    stosw
    mov ax, 0x0F6D
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F20
    stosw
    mov ax, 0x0F4F
    stosw
    mov ax, 0x0F76
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F72
    stosw
    mov di, (11 * 80 + 40) * 2
    mov ax, 0x0F50
    stosw
    mov ax, 0x0F72
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F73
    stosw
    mov ax, 0x0F20
    stosw
    mov ax, 0x0F45
    stosw
    mov ax, 0x0F6E
    stosw
    mov ax, 0x0F74
    stosw
    mov ax, 0x0F65
    stosw
    mov ax, 0x0F72
    stosw
df_wait_loop:
    mov ah, 0
    int 0x16
    cmp al, 0
    je df_check_scan
    cmp al, 13
    je df_key_done
    jmp df_wait_loop
df_check_scan:
    cmp ah, 0x1C
    je df_key_done
    jmp df_wait_loop
df_key_done:
    pop di
    pop cx
    pop ax
    pop es
    ret
music_notes:
    dw 2035, 1814, 2035, 1715, 1522, 1715, 2035, 1814
