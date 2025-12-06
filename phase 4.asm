org 0x100

ROAD_X0        equ  70
ROAD_W         equ  180
LANE_W         equ  (ROAD_W/3)
DIV1_X         equ  (ROAD_X0 + LANE_W)
DIV2_X         equ  (ROAD_X0 + 2*LANE_W)
DIV_W          equ  1
COLOR_GRASS1   equ  2
COLOR_GRASS2   equ  10
COLOR_ROAD     equ  8
COLOR_LINE     equ  15
TRANSPARENT    equ  255
CAR_W          equ  12
CAR_H          equ  16
BLUE_CAR_Y_INIT equ (200 - CAR_H - 10)
BLUE_CAR_X     equ  (ROAD_X0 + LANE_W + ((LANE_W - CAR_W)/2))
RED_CAR_Y      equ  10
RED_CAR_X      equ  (ROAD_X0 + 2*LANE_W + ((LANE_W - CAR_W)/2))

MAX_RED_CARS   equ  5
CAR_SPEED      equ  6
SPAWN_DELAY    equ  30

FRAMES_PER_SECOND equ 40

COIN_W         equ  6
COIN_H         equ  6
COIN_SPEED     equ  3
COIN_SPAWN_DELAY equ 60

CAR_MOVE_STEP  equ  5

BUFFER_SEG     equ  0x7000

FUEL_CAN_W     equ  8
FUEL_CAN_H     equ  8
FUEL_CAN_SPEED equ  3
FUEL_CAN_SPAWN_DELAY equ 80
MAX_FUEL       equ  100
FUEL_INCREASE  equ  10

start:
    mov ax, 0013h
    int 10h
    mov ax, 0A000h
    mov es, ax
    push cs
    pop ds
    
    call ShowIntroScreen
    call GetPlayerDetails
    call ShowInstructionScreen
    
    call InitRedCars
    
    mov byte [blue_lane], 1
    call UpdateBlueCarX
    
    mov byte [fuel], 100
    mov word [fuel_counter], 0
    mov byte [game_over], 0
    
    mov byte [coin_active], 0
    mov byte [coin_count], 0
    mov word [coin_spawn_counter], 0
    mov byte [last_coin_lane], 0xFF
    
    mov byte [fuelcan_active], 0
    mov word [fuelcan_spawn_counter], 0
    mov byte [last_fuelcan_lane], 0xFF
    
    mov word [blue_car_y], BLUE_CAR_Y_INIT
    mov byte [should_exit], 0
    mov byte [game_state], 1
    
    call DrawScene
    
.animate:
    mov ax, BUFFER_SEG
    mov es, ax
    
    call DrawScene
    call MoveRedCars
    call DrawRedCars
    call MoveCoin
    call DrawCoin
    call MoveFuelCan
    call DrawFuelCan
    call CheckCoinCollection
    call CheckFuelCanCollection
    
    call CheckCollision
    cmp byte [game_over], 1
    jne .continue_game
    jmp .show_lose
    
.continue_game:
    call HandleBlueCarInput
    
    cmp byte [should_exit], 1
    je near .exit
    
    push word car_blue
    push word CAR_H
    push word CAR_W
    push word [blue_car_x]
    push word [blue_car_y]
    call DrawSpriteTP
    
    call CopyBufferToScreen
    
    mov ax, 0A000h
    mov es, ax
    
    call DisplayFuel
    call DisplayCoins
    
    inc word [spawn_counter]
    mov ax, [spawn_counter]
    cmp ax, SPAWN_DELAY
    jl .no_spawn
    mov word [spawn_counter], 0
    call SpawnRedCar
.no_spawn:
    
    inc word [coin_spawn_counter]
    mov ax, [coin_spawn_counter]
    cmp ax, COIN_SPAWN_DELAY
    jl .no_coin_spawn
    mov word [coin_spawn_counter], 0
    call SpawnCoin
.no_coin_spawn:
    
    inc word [fuelcan_spawn_counter]
    mov ax, [fuelcan_spawn_counter]
    cmp ax, FUEL_CAN_SPAWN_DELAY
    jl .no_fuelcan_spawn
    mov word [fuelcan_spawn_counter], 0
    call SpawnFuelCan
.no_fuelcan_spawn:
    
    inc word [fuel_counter]
    mov ax, [fuel_counter]
    cmp ax, 5
    jl .no_fuel_decrease
    
    mov word [fuel_counter], 0
    cmp byte [fuel], 0
    je .show_lose
    dec byte [fuel]
    
.no_fuel_decrease:
    
    call Delay
    call ToggleGrassPattern
    
    jmp .animate

.show_lose:
    mov ax, 0A000h
    mov es, ax
    call ShowEndScreen         ; NEW end screen
    cmp byte [should_exit], 1
    je .exit
    jmp start                  ; restart from main flow
    
.exit:
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

ShowIntroScreen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax

    ; clear background
    mov bx, 0
.clear_loop:
    imul di, bx, 320
    mov al, bl
    shr al, 3
    add al, 1
    mov cx, 320
    rep stosb
    inc bx
    cmp bx, 200
    jl .clear_loop

    mov cx, 3
.title_anim:
    push cx

    ; ========= TITLE =========
    mov dh, 5
    mov dl, 9              ; moved left, more centered
    call SetCursor
    mov si, game_title
    mov bl, 14
    call PrintColorString

    ; ========= STRIP =========
    mov dh, 7
    mov dl, 0              ; from left edge
    call SetCursor
    mov si, title_line      ; make this long (e.g. 40 '=')
    mov bl, 11
    call PrintColorString

    ; ===== Developer label ===
    mov dh, 10
    mov dl, 12
    call SetCursor
    mov si, dev_label
    mov bl, 11
    call PrintColorString

    mov dh, 11
    mov dl, 11
    call SetCursor
    mov si, dev_name1
    mov bl, 15
    call PrintColorString

    mov dh, 12
    mov dl, 11
    call SetCursor
    mov si, dev_name2
    mov bl, 15
    call PrintColorString

    ; ===== Roll numbers ======
    mov dh, 14
    mov dl, 12
    call SetCursor
    mov si, roll_label
    mov bl, 11
    call PrintColorString

    mov dh, 15
    mov dl, 11
    call SetCursor
    mov si, roll_num1
    mov bl, 14
    call PrintColorString

    mov dh, 16
    mov dl, 11
    call SetCursor
    mov si, roll_num2
    mov bl, 15
    call PrintColorString

    ; ===== Press any key =====
    mov dh, 22
    mov dl, 8
    call SetCursor
    mov si, press_key_intro
    mov bl, 10
    call PrintColorString

    call SmallDelay

    pop cx
    dec cx
    cmp cx, 0
    jne .title_anim

    xor ah, ah
    int 16h

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

GetPlayerDetails:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax
    
    xor di, di
    mov al, 0
    mov cx, 32000
    rep stosw
    
    mov dh, 3
    mov dl, 10
    call SetCursor
    mov si, player_details_title
    mov bl, 14
    call PrintColorString
    
    mov dh, 8
    mov dl, 5
    call SetCursor
    mov si, enter_name_prompt
    mov bl, 15
    call PrintColorString
    
    mov dh, 8
    mov dl, 20
    call SetCursor
    mov di, player_name
    mov cx, 20
    call InputString
    
    mov dh, 12
    mov dl, 5
    call SetCursor
    mov si, enter_roll_prompt
    mov bl, 15
    call PrintColorString
    
    mov dh, 12
    mov dl, 20
    call SetCursor
    mov di, player_roll
    mov cx, 15
    call InputString
    
    mov dh, 16
    mov dl, 8
    call SetCursor
    mov si, details_saved
    mov bl, 10
    call PrintColorString
    
    call LongDelay
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

InputString:
    push ax
    push bx
    push cx
    push dx
    
    xor bx, bx
    
.input_loop:
    xor ah, ah
    int 16h
    
    cmp al, 13
    je .input_done
    
    cmp al, 8
    je .handle_backspace
    
    cmp al, 32
    jl .input_loop
    
    cmp bx, cx
    jge .input_loop
    
    mov [di+bx], al
    inc bx
    
    mov ah, 0Eh
    mov bh, 0
    int 10h
    
    jmp .input_loop
    
.handle_backspace:
    cmp bx, 0
    je .input_loop
    
    dec bx
    mov byte [di+bx], 0
    
    mov ah, 0Eh
    mov al, 8
    int 10h
    mov al, ' '
    int 10h
    mov al, 8
    int 10h
    
    jmp .input_loop
    
.input_done:
    mov byte [di+bx], 0
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret

ShowInstructionScreen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax
    
    xor di, di
    mov al, 1
    mov cx, 32000
    rep stosw
    
    mov dh, 2
    mov dl, 3
    call SetCursor
    mov si, instructions_title
    mov bl, 14
    call PrintColorString
    
    mov dh, 5
    mov dl, 3
    call SetCursor
    mov si, inst_line1
    mov bl, 15
    call PrintColorString
    
    mov dh, 6
    mov dl, 3
    call SetCursor
    mov si, inst_line2
    mov bl, 11
    call PrintColorString
    
    mov dh, 8
    mov dl, 3
    call SetCursor
    mov si, inst_line3
    mov bl, 15
    call PrintColorString
    
    mov dh, 9
    mov dl, 3
    call SetCursor
    mov si, inst_line4
    mov bl, 11
    call PrintColorString
    
    mov dh, 11
    mov dl, 3
    call SetCursor
    mov si, inst_line5
    mov bl, 15
    call PrintColorString
    
    mov dh, 12
    mov dl, 3
    call SetCursor
    mov si, inst_line6
    mov bl, 11
    call PrintColorString
    
    mov dh, 14
    mov dl, 3
    call SetCursor
    mov si, inst_line7
    mov bl, 15
    call PrintColorString
    
    mov dh, 15
    mov dl, 3
    call SetCursor
    mov si, inst_line8
    mov bl, 11
    call PrintColorString
    
    mov dh, 17
    mov dl, 3
    call SetCursor
    mov si, inst_line9
    mov bl, 15
    call PrintColorString
    
    mov dh, 18
    mov dl, 3
    call SetCursor
    mov si, inst_line10
    mov bl, 11
    call PrintColorString
    
    mov dh, 22
    mov dl, 3
    call SetCursor
    mov si, press_key_start
    mov bl, 10
    call PrintColorString
    
    xor ah, ah
    int 16h
    
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

SetCursor:
    push ax
    push bx
    mov bh, 0
    mov ah, 02h
    int 10h
    pop bx
    pop ax
    ret

PrintColorString:
    push ax
    push bx
    push si
.print_loop:
    lodsb
    cmp al, 0
    je .print_done
    mov ah, 0Eh
    mov bh, 0
    int 10h
    jmp .print_loop
.print_done:
    pop si
    pop bx
    pop ax
    ret

SmallDelay:
    push cx
    push dx
    mov cx, 0x01
.outer:
    mov dx, 0xFFFF
.inner:
    dec dx
    jnz .inner
    loop .outer
    pop dx
    pop cx
    ret

LongDelay:
    push cx
    push dx
    mov cx, 0x05
.outer:
    mov dx, 0xFFFF
.inner:
    dec dx
    jnz .inner
    loop .outer
    pop dx
    pop cx
    ret

CopyBufferToScreen:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    
    mov ax, BUFFER_SEG
    mov ds, ax
    mov ax, 0A000h
    mov es, ax
    
    xor si, si
    xor di, di
    mov cx, 32000
    
    rep movsw
    
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret

DrawScene:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, 0
.bg_row:
    imul di, bx, 320
    
    mov dx, bx
    xor dx, [grass_toggle]
    and dx, 8
    jz .light_grass
    mov al, COLOR_GRASS1
    jmp short .set_grass
.light_grass:
    mov al, COLOR_GRASS2
.set_grass:
    mov cx, (ROAD_X0 - 2)
    rep stosb
    
    mov al, 0
    mov cx, 2
    rep stosb
    
    mov al, COLOR_ROAD
    mov cx, ROAD_W
    rep stosb
    
    mov al, 0
    mov cx, 2
    rep stosb
    
    mov dx, bx
    xor dx, [grass_toggle]
    and dx, 8
    jz .light_grass2
    mov al, COLOR_GRASS1
    jmp short .set_grass2
.light_grass2:
    mov al, COLOR_GRASS2
.set_grass2:
    mov cx, (320 - ROAD_X0 - ROAD_W - 2)
    rep stosb
    
    inc bx
    cmp bx, 200
    jl .bg_row
    
    xor si, si
    mov bx, 0
.div_loop:
    imul di, bx, 320
    mov dx, si
    and dx, 0Fh
    cmp dx, 8
    jge .skip
    mov ax, di
    add ax, DIV1_X
    mov di, ax
    mov al, COLOR_LINE
    mov cx, DIV_W
    rep stosb
    imul di, bx, 320
    add di, DIV2_X
    mov al, COLOR_LINE
    mov cx, DIV_W
    rep stosb
.skip:
    inc si
    inc bx
    cmp bx, 200
    jl .div_loop
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

Delay:
    push cx
    push dx
    mov cx, 0x02
.outer:
    mov dx, 0xFFFF
.inner:
    dec dx
    jnz .inner
    loop .outer
    pop dx
    pop cx
    ret

ToggleGrassPattern:
    xor word [grass_toggle], 8
    ret

InitRedCars:
    push ax
    push bx
    push di
    
    mov di, red_car_active
    mov bx, 0
.clear_loop:
    mov byte [di], 0
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .clear_loop
    
    mov word [spawn_counter], 0
    mov byte [last_lane], 0xFF
    
    mov ah, 00h
    int 1Ah
    mov [random_seed], dx
    
    pop di
    pop bx
    pop ax
    ret

SpawnRedCar:
    push ax
    push bx
    push cx
    push di
    
    mov di, red_car_active
    mov bx, 0
.find_slot:
    cmp byte [di], 0
    je .found_slot
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .find_slot
    jmp .spawn_done
    
.found_slot:
    call GetRandomLane
    mov [di+1], al
    mov word [di+2], 0
    mov byte [di], 1
    
.spawn_done:
    pop di
    pop cx
    pop bx
    pop ax
    ret

GetRandomLane:
    push bx
    push dx
    
    mov ah, 00h
    int 1Ah
    xor dx, [random_seed]
    mov [random_seed], dx
    
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    mov al, dl
    
    cmp al, [last_lane]
    jne .lane_ok
    
    inc al
    cmp al, 3
    jl .lane_ok
    xor al, al
    
.lane_ok:
    mov [last_lane], al
    
    pop dx
    pop bx
    ret

MoveRedCars:
    push ax
    push bx
    push di
    
    mov di, red_car_active
    mov bx, 0
.move_loop:
    cmp byte [di], 0
    je .next_car
    
    mov ax, [di+2]
    add ax, CAR_SPEED
    mov [di+2], ax
    
    cmp ax, 200
    jle .next_car
    
    mov byte [di], 0
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .move_loop
    
    pop di
    pop bx
    pop ax
    ret

DrawRedCars:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov di, red_car_active
    mov bx, 0
.draw_loop:
    cmp byte [di], 0
    je .next_car
    
    mov al, [di+1]
    xor ah, ah
    mov cx, LANE_W
    mul cx
    add ax, ROAD_X0
    add ax, (LANE_W - CAR_W) / 2
    mov cx, ax
    
    mov dx, [di+2]
    
    push word car_red
    push word CAR_H
    push word CAR_W
    push cx
    push dx
    call DrawSpriteTP
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .draw_loop
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CheckCollision:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov di, red_car_active
    mov bx, 0
.check_loop:
    cmp byte [di], 0
    je .next_car
    
    mov al, [di+1]
    xor ah, ah
    mov cx, LANE_W
    mul cx
    add ax, ROAD_X0
    add ax, (LANE_W - CAR_W) / 2
    mov cx, ax
    
    mov dx, [di+2]
    
    mov ax, cx
    add ax, CAR_W
    cmp ax, [blue_car_x]
    jle .next_car
    
    mov ax, [blue_car_x]
    add ax, CAR_W
    cmp cx, ax
    jge .next_car
    
    mov ax, dx
    add ax, CAR_H
    cmp ax, [blue_car_y]
    jle .next_car
    
    mov ax, [blue_car_y]
    add ax, CAR_H
    cmp dx, ax
    jge .next_car
    
    mov byte [game_over], 1
    jmp .collision_found
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .check_loop
    
.collision_found:
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

HandleBlueCarInput:
    push ax
    push bx
    
.check_all_keys:
    mov ah, 01h
    int 16h
    jz near .done
    
    xor ah, ah
    int 16h
    
    cmp al, 0
    je .check_arrow
    
    cmp byte [game_state], 1
    jne .check_all_keys
    
    cmp al, 27
    je .handle_esc
    
    jmp .check_all_keys
    
.check_arrow:
    cmp ah, 4Bh
    je .move_left
    
    cmp ah, 4Dh
    je .move_right
    
    cmp ah, 48h
    je .move_up
    
    cmp ah, 50h
    je .move_down
    
    jmp .check_all_keys
    
.move_left:
    cmp byte [blue_lane], 0
    je .check_all_keys
    
    dec byte [blue_lane]
    call UpdateBlueCarX
    jmp .check_all_keys
    
.move_right:
    cmp byte [blue_lane], 2
    je .check_all_keys
    
    inc byte [blue_lane]
    call UpdateBlueCarX
    jmp .check_all_keys

.move_up:
    mov ax, [blue_car_y]
    sub ax, CAR_MOVE_STEP
    cmp ax, 0
    jge .set_up_pos
    xor ax, ax
.set_up_pos:
    mov [blue_car_y], ax
    jmp .check_all_keys
    
.move_down:
    mov ax, [blue_car_y]
    add ax, CAR_MOVE_STEP
    
    mov bx, ax
    add bx, CAR_H
    cmp bx, 200
    jle .set_down_pos
    
    mov ax, 200
    sub ax, CAR_H
    
.set_down_pos:
    mov [blue_car_y], ax
    jmp .check_all_keys

.handle_esc:
    call ShowPauseScreen
    jmp .check_all_keys
    
.done:
    pop bx
    pop ax
    ret

ShowPauseScreen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax
    
    mov bx, 75
    mov cx, 50
.draw_border:
    push bx
    push cx
    
    imul di, bx, 320
    add di, 95
    
    cmp cx, 50
    je .draw_border_line
    cmp cx, 1
    je .draw_border_line
    jmp .draw_inner
    
.draw_border_line:
    mov al, 12
    push cx
    mov cx, 130
    rep stosb
    pop cx
    jmp .next_border
    
.draw_inner:
    mov al, 12
    stosb
    
    mov al, 7
    push cx
    mov cx, 128
    rep stosb
    pop cx
    
    mov al, 12
    stosb
    
.next_border:
    pop cx
    pop bx
    inc bx
    loop .draw_border
    
    mov dh, 10
    mov dl, 13
    call SetCursor
    
    mov si, pause_text
    mov bl, 14
    call PrintColorString
    
    mov dh, 13
    mov dl, 15
    call SetCursor
    
    mov si, options_text
    mov bl, 15
    call PrintColorString
    
.wait_response:
    xor ah, ah
    int 16h
    
    cmp al, 'y'
    je .confirm_quit
    cmp al, 'Y'
    je .confirm_quit
    
    cmp al, 'n'
    je .resume_game
    cmp al, 'N'
    je .resume_game
    
    cmp al, 27
    je .resume_game
    
    jmp .wait_response
    
.confirm_quit:
    mov byte [should_exit], 1
    jmp .pause_done
    
.resume_game:
    jmp .pause_done
    
.pause_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

UpdateBlueCarX:
    push ax
    push bx
    
    mov al, [blue_lane]
    xor ah, ah
    mov bx, LANE_W
    mul bx
    add ax, ROAD_X0
    add ax, (LANE_W - CAR_W) / 2
    mov [blue_car_x], ax
    
    pop bx
    pop ax
    ret

DisplayFuel:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov dh, 1
    mov dl, 1
    mov bh, 0
    mov ah, 02h
    int 10h
    
    mov si, fuel_text
.print_fuel_label:
    lodsb
    cmp al, 0
    je .print_value
    mov ah, 0Eh
    mov bh, 0
    mov bl, 15
    int 10h
    jmp .print_fuel_label
    
.print_value:
    mov al, [fuel]
    xor ah, ah
    
    mov bl, 100
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    mov al, ah
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    mov al, ah
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DisplayLoseMessage:
    push ax
    push bx
    push dx
    push si
    
    mov dh, 12
    mov dl, 14
    mov bh, 0
    mov ah, 02h
    int 10h
    
    mov si, lose_text
.print_lose:
    lodsb
    cmp al, 0
    je .done_lose
    mov ah, 0Eh
    mov bh, 0
    mov bl, 12
    int 10h
    jmp .print_lose
    
.done_lose:
    pop si
    pop dx
    pop bx
    pop ax
    ret

SpawnCoin:
    push ax
    push bx
    push cx
    
    cmp byte [coin_active], 1
    je .spawn_done
    
    call GetRandomCoinLane
    call IsLaneClear
    cmp al, 0
    je .spawn_done
    
    mov al, [temp_coin_lane]
    mov [coin_lane], al
    mov [last_coin_lane], al
    
    xor ah, ah
    mov bx, LANE_W
    mul bx
    add ax, ROAD_X0
    add ax, (LANE_W - COIN_W) / 2
    mov [coin_x], ax
    
    mov word [coin_y], 0
    mov byte [coin_active], 1
    
.spawn_done:
    pop cx
    pop bx
    pop ax
    ret

GetRandomCoinLane:
    push bx
    push dx
    
    mov ah, 00h
    int 1Ah
    xor dx, [random_seed]
    add dx, 7
    mov [random_seed], dx
    
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    mov al, dl
    
    cmp al, [last_coin_lane]
    jne .coin_lane_ok
    
    inc al
    cmp al, 3
    jl .coin_lane_ok
    xor al, al
    
.coin_lane_ok:
    mov [temp_coin_lane], al
    
    pop dx
    pop bx
    ret

IsLaneClear:
    push bx
    push cx
    push di
    
    mov al, [temp_coin_lane]
    mov cl, al
    
    mov di, red_car_active
    mov bx, 0
.check_loop:
    cmp byte [di], 0
    je .next_car
    
    mov al, [di+1]
    cmp al, cl
    jne .next_car
    
    mov ax, [di+2]
    cmp ax, 30
    jge .next_car
    
    mov al, 0
    jmp .check_done
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .check_loop
    
    mov al, 1
    
.check_done:
    pop di
    pop cx
    pop bx
    ret

MoveCoin:
    push ax
    
    cmp byte [coin_active], 0
    je .move_done
    
    mov ax, [coin_y]
    add ax, COIN_SPEED
    mov [coin_y], ax
    
    cmp ax, 200
    jle .move_done
    
    mov byte [coin_active], 0
    
.move_done:
    pop ax
    ret

DrawCoin:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [coin_active], 0
    je .draw_done
    
    push word coin_sprite
    push word COIN_H
    push word COIN_W
    push word [coin_x]
    push word [coin_y]
    call DrawSpriteTP
    
.draw_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CheckCoinCollection:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [coin_active], 0
    je .no_collection
    
    mov cx, [coin_x]
    mov dx, [coin_y]
    
    mov ax, cx
    add ax, COIN_W
    cmp ax, [blue_car_x]
    jle .no_collection
    
    mov ax, [blue_car_x]
    add ax, CAR_W
    cmp cx, ax
    jge .no_collection
    
    mov ax, dx
    add ax, COIN_H
    cmp ax, [blue_car_y]
    jle .no_collection
    
    mov ax, [blue_car_y]
    add ax, CAR_H
    cmp dx, ax
    jge .no_collection
    
    mov byte [coin_active], 0
    inc byte [coin_count]
    
.no_collection:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DisplayCoins:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov dh, 2
    mov dl, 1
    mov bh, 0
    mov ah, 02h
    int 10h
    
    mov si, coins_text
.print_coins_label:
    lodsb
    cmp al, 0
    je .print_value
    mov ah, 0Eh
    mov bh, 0
    mov bl, 14
    int 10h
    jmp .print_coins_label
    
.print_value:
    mov al, [coin_count]
    xor ah, ah
    
    mov bl, 100
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    mov al, ah
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    mov al, ah
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

SpawnFuelCan:
    push ax
    push bx
    push cx
    
    cmp byte [fuelcan_active], 1
    je .spawn_done
    
    call GetRandomFuelCanLane
    call IsLaneClearForFuelCan
    cmp al, 0
    je .spawn_done
    
    mov al, [temp_fuelcan_lane]
    mov [fuelcan_lane], al
    mov [last_fuelcan_lane], al
    
    xor ah, ah
    mov bx, LANE_W
    mul bx
    add ax, ROAD_X0
    add ax, (LANE_W - FUEL_CAN_W) / 2
    mov [fuelcan_x], ax
    
    mov word [fuelcan_y], 0
    mov byte [fuelcan_active], 1
    
.spawn_done:
    pop cx
    pop bx
    pop ax
    ret

GetRandomFuelCanLane:
    push bx
    push dx
    
    mov ah, 00h
    int 1Ah
    xor dx, [random_seed]
    add dx, 13
    mov [random_seed], dx
    
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    mov al, dl
    
    cmp al, [last_fuelcan_lane]
    jne .fuelcan_lane_ok
    
    inc al
    cmp al, 3
    jl .fuelcan_lane_ok
    xor al, al
    
.fuelcan_lane_ok:
    mov [temp_fuelcan_lane], al
    
    pop dx
    pop bx
    ret

IsLaneClearForFuelCan:
    push bx
    push cx
    push di
    
    mov al, [temp_fuelcan_lane]
    mov cl, al
    
    mov di, red_car_active
    mov bx, 0
.check_loop:
    cmp byte [di], 0
    je .next_car
    
    mov al, [di+1]
    cmp al, cl
    jne .next_car
    
    mov ax, [di+2]
    cmp ax, 30
    jge .next_car
    
    mov al, 0
    jmp .check_done
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .check_loop
    
    mov al, 1
    
.check_done:
    pop di
    pop cx
    pop bx
    ret

MoveFuelCan:
    push ax
    
    cmp byte [fuelcan_active], 0
    je .move_done
    
    mov ax, [fuelcan_y]
    add ax, FUEL_CAN_SPEED
    mov [fuelcan_y], ax
    
    cmp ax, 200
    jle .move_done
    
    mov byte [fuelcan_active], 0
    
.move_done:
    pop ax
    ret

DrawFuelCan:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [fuelcan_active], 0
    je .draw_done
    
    push word fuelcan_sprite
    push word FUEL_CAN_H
    push word FUEL_CAN_W
    push word [fuelcan_x]
    push word [fuelcan_y]
    call DrawSpriteTP
    
.draw_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

CheckFuelCanCollection:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [fuelcan_active], 0
    je .no_collection
    
    mov cx, [fuelcan_x]
    mov dx, [fuelcan_y]
    
    mov ax, cx
    add ax, FUEL_CAN_W
    cmp ax, [blue_car_x]
    jle .no_collection
    
    mov ax, [blue_car_x]
    add ax, CAR_W
    cmp cx, ax
    jge .no_collection
    
    mov ax, dx
    add ax, FUEL_CAN_H
    cmp ax, [blue_car_y]
    jle .no_collection
    
    mov ax, [blue_car_y]
    add ax, CAR_H
    cmp dx, ax
    jge .no_collection
    
    mov byte [fuelcan_active], 0
    
    mov al, [fuel]
    add al, FUEL_INCREASE
    cmp al, MAX_FUEL
    jle .set_fuel
    mov al, MAX_FUEL
.set_fuel:
    mov [fuel], al
    
.no_collection:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

DrawSpriteTP:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    mov bx, [bp+4]
    mov dx, [bp+10]
    mov si, [bp+12]
    
    imul di, bx, 320
    add di, [bp+6]
    
.row:
    mov cx, [bp+8]
.col:
    lodsb
    cmp al, TRANSPARENT
    je  .skip_px
    stosb
    jmp short .next_px
.skip_px:
    inc di
.next_px:
    loop .col
    
    mov ax, 320
    sub ax, [bp+8]
    add di, ax
    dec dx
    jnz .row
    
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10

; =====================
; NEW: END SCREEN
; =====================
ShowEndScreen:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es
    
    mov ax, 0A000h
    mov es, ax

    ; Clear screen
    xor di, di
    mov al, 1
    mov cx, 32000
    rep stosw

    ; Title
    mov dh, 3
    mov dl, 3
    call SetCursor
    mov si, end_title
    mov bl, 14
    call PrintColorString

    ; Player name
    mov dh, 7
    mov dl, 3
    call SetCursor
    mov si, end_name_label
    mov bl, 15
    call PrintColorString

    mov si, player_name
    mov bl, 11
    call PrintColorString

    ; Roll #
    mov dh, 9
    mov dl, 3
    call SetCursor
    mov si, end_roll_label
    mov bl, 15
    call PrintColorString

    mov si, player_roll
    mov bl, 11
    call PrintColorString

    ; Coins
    mov dh, 11
    mov dl, 3
    call SetCursor
    mov si, end_coins_label
    mov bl, 15
    call PrintColorString

    ; (3-digit coin printing stays same)
    mov al, [coin_count]
    xor ah, ah
    mov bl, 100
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax

    mov al, ah
    xor ah, ah
    mov bl, 10
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax

    mov al, ah
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h

    ; ================================
    ; LEFT-ALIGNED instructions
    ; ================================

    mov dh, 15
    mov dl, 3          ; LEFT ALIGNED
    call SetCursor
    mov si, end_instr1 ; "Press ENTER to return..."
    mov bl, 10
    call PrintColorString

    mov dh, 17
    mov dl, 3          ; LEFT ALIGNED
    call SetCursor
    mov si, end_instr2 ; "Press ESC to exit..."
    mov bl, 11
    call PrintColorString

    ; ================================
.se_wait:
    xor ah, ah
    int 16h

    cmp al, 13
    je .se_enter

    cmp al, 27
    je .se_esc

    jmp .se_wait

.se_esc:
    call ShowPauseScreen
    cmp byte [should_exit], 1
    je .se_done
    jmp .se_wait

.se_enter:
    mov byte [should_exit], 0
    jmp .se_done

.se_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

grass_toggle dw 0
red_car_active:
    times MAX_RED_CARS db 0, 0, 0, 0
spawn_counter dw 0
last_lane db 0xFF
random_seed dw 0
blue_lane db 1
blue_car_x dw BLUE_CAR_X
fuel db 100
fuel_counter dw 0
game_over db 0
game_state db 0
fuel_text db 'Fuel: ', 0
lose_text db 'YOU LOSE!', 0
coin_active db 0
coin_lane db 0
coin_x dw 0
coin_y dw 0
coin_count db 0
coin_spawn_counter dw 0
last_coin_lane db 0xFF
temp_coin_lane db 0
coins_text db 'Coins: ', 0
blue_car_y dw BLUE_CAR_Y_INIT
should_exit db 0
pause_text db 'Do you want to quit?', 0
options_text db 'Y - Yes  N - No', 0

fuelcan_active db 0
fuelcan_lane db 0
fuelcan_x dw 0
fuelcan_y dw 0
fuelcan_spawn_counter dw 0
last_fuelcan_lane db 0xFF
temp_fuelcan_lane db 0

game_title db '*** HIGHWAY RACER ***', 0
title_line db '========================================', 0
dev_label db 'Developed by:', 0
dev_name1 db 'Zain Azeem', 0
dev_name2 db 'Aadil Mudasser', 0
roll_label db 'Roll Numbers:', 0
roll_num1 db '24L-0862', 0
roll_num2 db '24L-0640', 0
press_key_intro db 'Press any key to continue...', 0

player_details_title db '*** PLAYER DETAILS ***', 0
enter_name_prompt db 'Enter Name: ', 0
enter_roll_prompt db 'Enter Roll: ', 0
details_saved db 'Details saved! Loading...', 0

instructions_title db '*** GAME INSTRUCTIONS ***', 0
inst_line1 db '* CONTROLS:', 0
inst_line2 db 'Arrow Keys - Move car (Left/Right/Up/Down)', 0
inst_line3 db '* FUEL:', 0
inst_line4 db 'Decreases every second. Game ends at 0!', 0
inst_line5 db '* COLLECTIBLES:', 0
inst_line6 db 'Yellow coins for points, Red cans for fuel', 0
inst_line7 db '* OBJECTIVE:', 0
inst_line8 db 'Avoid red cars and survive as long as possible', 0
inst_line9 db '* PAUSE/QUIT:', 0
inst_line10 db 'Press ESC during game to pause/quit', 0
press_key_start db 'Press any key to start the game...', 0

end_title db '*** GAME OVER ***', 0
end_name_label db 'Player Name: ', 0
end_roll_label db 'Roll No: ', 0
end_coins_label db 'Coins Collected: ', 0
end_instr1 db 'Press ENTER to return to main screen', 0
end_instr2 db 'Press ESC to exit ', 0

player_name  times 20 db 0
player_roll  times 15 db 0


fuelcan_sprite:
    db 255,255, 12, 12, 12, 12,255,255
    db 255, 12, 12, 15, 15, 12, 12,255
    db  12, 12, 15, 15, 15, 15, 12, 12
    db  12, 12, 12, 12, 12, 12, 12, 12
    db  12, 12, 12, 12, 12, 12, 12, 12
    db  12, 12, 12, 12, 12, 12, 12, 12
    db  12, 12, 12, 12, 12, 12, 12, 12
    db 255, 12, 12, 12, 12, 12, 12,255

coin_sprite:
    db 255,255, 14, 14,255,255
    db 255, 14, 14, 14, 14,255
    db  14, 14, 14, 14, 14, 14
    db  14, 14, 14, 14, 14, 14
    db 255, 14, 14, 14, 14,255
    db 255,255, 14, 14,255,255

car_blue:
    db 0,0,0,9,9,9,9,9,9,0,0,0
    db 0,0,0,9,9,9,9,9,9,0,0,0
    db 0,0,0,9,9,9,9,9,9,0,0,0
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,7,7,7,7,7,7,7,7,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 9,9,9,9,9,9,9,9,9,9,9,9
    db 0,0,0,9,9,9,9,9,9,0,0,0
    db 0,0,0,9,9,9,9,9,9,0,0,0
    db 0,0,0,9,9,9,9,9,9,0,0,0

car_red:
    db 0,0,0,4,4,4,4,4,4,0,0,0
    db 0,0,0,4,4,4,4,4,4,0,0,0
    db 0,0,0,4,4,4,4,4,4,0,0,0
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,7,7,7,7,7,7,7,7,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4
    db 0,0,0,4,4,4,4,4,4,0,0,0
    db 0,0,0,4,4,4,4,4,4,0,0,0
    db 0,0,0,4,4,4,4,4,4,0,0,0
