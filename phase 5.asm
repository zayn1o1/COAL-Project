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
spark_x dw 0
spark_y dw 0


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
    call DisplayLoseMessage   ; "YOU LOSE!"
    call LongDelay            ; short pause
    call ShowEndScreen
    cmp byte [should_exit], 1
    je .exit
    jmp start

    
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
    mov dl, 9
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
    mov dl, 9
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

DrawSpark:
    push ax
    push bx
    push cx
    push dx
    push di

    ; ES must already be BUFFER_SEG

    ; DI = spark_y * 320 + spark_x (center pixel)
    mov ax, [spark_y]
    mov bx, 320
    mul bx
    add ax, [spark_x]
    mov di, ax

    ; ---------------- Frame 1: small cross ----------------
    mov al, 14                ; bright yellow

    mov [es:di],     al       ; center
    mov [es:di-1],   al
    mov [es:di+1],   al
    mov [es:di-320], al
    mov [es:di+320], al

    call CopyBufferToScreen
    call SmallDelay           ; short pause

    ; --------------- Frame 2: bigger ring -----------------
    mov al, 14

    mov [es:di-2],   al
    mov [es:di+2],   al
    mov [es:di-640], al
    mov [es:di+640], al

    mov [es:di-321], al
    mov [es:di-319], al
    mov [es:di+321], al
    mov [es:di+319], al

    call CopyBufferToScreen
    call SmallDelay

    ; --------------- Frame 3: outer sparks (fade) ---------
    mov al, 15                ; slightly different color

    mov [es:di-641], al
    mov [es:di+641], al
    mov [es:di-639], al
    mov [es:di+639], al

    call CopyBufferToScreen
    call SmallDelay

    pop di
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
    
    ; collision detected
    mov byte [game_over], 1

    ; center of blue car for spark
    mov ax, [blue_car_x]
    add ax, CAR_W/2
    mov [spark_x], ax

    mov ax, [blue_car_y]
    add ax, CAR_H/2
    mov [spark_y], ax

    ; show 3-frame spark animation
    call DrawSpark

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
    pop b