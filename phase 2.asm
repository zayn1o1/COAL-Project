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
BLUE_CAR_Y     equ  (200 - CAR_H - 10)
BLUE_CAR_X     equ  (ROAD_X0 + LANE_W + ((LANE_W - CAR_W)/2))
RED_CAR_Y      equ  10
RED_CAR_X      equ  (ROAD_X0 + 2*LANE_W + ((LANE_W - CAR_W)/2))

MAX_RED_CARS   equ  5
CAR_SPEED      equ  3
SPAWN_DELAY    equ  40

FRAMES_PER_SECOND equ 20

; ==== NEW CODE START (COIN SYSTEM) ====
COIN_W         equ  6
COIN_H         equ  6
COIN_SPEED     equ  3
COIN_SPAWN_DELAY equ 60       ; 3 seconds
; ==== NEW CODE END ====

start:
    mov ax, 0013h
    int 10h
    mov ax, 0A000h
    mov es, ax
    push cs
    pop ds
    
    ; Initialize red car system
    call InitRedCars
    
    ; Initialize blue car to middle lane (lane 1)
    mov byte [blue_lane], 1
    call UpdateBlueCarX
    
    ; Initialize fuel system
    mov byte [fuel], 100
    mov word [fuel_counter], 0
    mov byte [game_over], 0
    
    ; ==== NEW CODE START (COIN SYSTEM) ====
    ; Initialize coin system
    mov byte [coin_active], 0
    mov byte [coin_count], 0
    mov word [coin_spawn_counter], 0
    mov byte [last_coin_lane], 0xFF
    ; ==== NEW CODE END ====
    
    call DrawScene
    
    ; Wait for initial keypress
    xor ah, ah
    int 16h
    cmp al, 32           ; Spacebar?
    jne .not_space
    jmp .animate
.not_space:
    jmp .exit
    
.animate:
    call DrawScene
    
    ; Display fuel
    call DisplayFuel
    
    ; ==== NEW CODE START (COIN SYSTEM) ====
    ; Display coin count
    call DisplayCoins
    ; ==== NEW CODE END ====
    
    ; Move and draw red cars
    call MoveRedCars
    call DrawRedCars
    
    ; ==== NEW CODE START (COIN SYSTEM) ====
    ; Move and draw coin
    call MoveCoin
    call DrawCoin
    
    ; Check coin collection
    call CheckCoinCollection
    ; ==== NEW CODE END ====
    
    ; Check collision with blue car
    call CheckCollision
    cmp byte [game_over], 1
    jne .continue_game
    jmp .show_lose
    
.continue_game:
    
    ; Handle blue car movement input
    call HandleBlueCarInput
    
    ; Draw blue car at current position
    push word car_blue
    push word CAR_H
    push word CAR_W
    push word [blue_car_x]
    push word BLUE_CAR_Y
    call DrawSpriteTP
    
    ; Handle red car spawning
    inc word [spawn_counter]
    mov ax, [spawn_counter]
    cmp ax, SPAWN_DELAY
    jl .no_spawn
    mov word [spawn_counter], 0
    call SpawnRedCar
.no_spawn:
    
    ; ==== NEW CODE START (COIN SYSTEM) ====
    ; Handle coin spawning
    inc word [coin_spawn_counter]
    mov ax, [coin_spawn_counter]
    cmp ax, COIN_SPAWN_DELAY
    jl .no_coin_spawn
    mov word [coin_spawn_counter], 0
    call SpawnCoin
.no_coin_spawn:
    ; ==== NEW CODE END ====
    
    ; Update fuel timer (decrease every second)
    inc word [fuel_counter]
    mov ax, [fuel_counter]
    cmp ax, FRAMES_PER_SECOND
    jl .no_fuel_decrease
    
    ; Reset counter and decrease fuel
    mov word [fuel_counter], 0
    cmp byte [fuel], 0
    je .show_win
    dec byte [fuel]
    
.no_fuel_decrease:
    
    call Delay
    call ToggleGrassPattern
    
    ; Check for ESC only
    mov ah, 01h
    int 16h
    jz .animate
    
    xor ah, ah
    int 16h
    cmp al, 27
    jne .animate
    jmp .exit

.show_win:
    ; Player won! (fuel reached 0)
    call DrawScene
    call DisplayWinMessage
    
    ; Wait for keypress
    xor ah, ah
    int 16h
    jmp .exit

.show_lose:
    ; Player lost! (collision)
    call DrawScene
    call DisplayLoseMessage
    
    ; Wait for keypress
    xor ah, ah
    int 16h
    jmp .exit
    
.exit:
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

; DrawScene - draws background with patchy grass, road, and dividers
DrawScene:
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov bx, 0
.bg_row:
    imul di, bx, 320
    
    ; -------- LEFT GRASS (patchy) --------
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
    
    ; -------- LEFT BORDER (black) --------
    mov al, 0
    mov cx, 2
    rep stosb
    
    ; -------- ROAD --------
    mov al, COLOR_ROAD
    mov cx, ROAD_W
    rep stosb
    
    ; -------- RIGHT BORDER (black) --------
    mov al, 0
    mov cx, 2
    rep stosb
    
    ; -------- RIGHT GRASS (patchy) --------
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
    
    ; Draw lane dividers
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

; Delay - simple delay loop
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

; ToggleGrassPattern - flips grass animation state
ToggleGrassPattern:
    xor word [grass_toggle], 8
    ret

; InitRedCars - initialize red car system
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

; SpawnRedCar - spawn a new red car at top of screen
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

; GetRandomLane - returns random lane (0-2) in AL, avoiding last_lane
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

; MoveRedCars - move all active red cars downward
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

; DrawRedCars - draw all active red cars
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

; CheckCollision - check if any red car collides with blue car
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
    
    ; Check X overlap
    mov ax, cx
    add ax, CAR_W
    cmp ax, [blue_car_x]
    jle .next_car
    
    mov ax, [blue_car_x]
    add ax, CAR_W
    cmp cx, ax
    jge .next_car
    
    ; Check Y overlap
    mov ax, dx
    add ax, CAR_H
    cmp ax, BLUE_CAR_Y
    jle .next_car
    
    mov ax, BLUE_CAR_Y
    add ax, CAR_H
    cmp dx, ax
    jge .next_car
    
    ; Collision detected! Set game over flag
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


; HandleBlueCarInput - handle ARROW keys for instant response
HandleBlueCarInput:
    push ax
    push bx
    
.check_all_keys:
    mov ah, 01h
    int 16h
    jz .done
    
    xor ah, ah
    int 16h
    
    ; Check if extended key (arrows return AL=0, scan code in AH)
    cmp al, 0
    jne .check_all_keys      ; Not an arrow key, skip
    
    ; Check AH for arrow key scan codes
    cmp ah, 4Bh              ; Left arrow scan code
    je .move_left
    
    cmp ah, 4Dh              ; Right arrow scan code
    je .move_right
    
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
    
.done:
    pop bx
    pop ax
    ret

; UpdateBlueCarX - calculate and update blue car X position based on current lane
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

; DisplayFuel - draw fuel text on left grass area
DisplayFuel:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Draw "Fuel:" at position (1, 1)
    mov dh, 1
    mov dl, 1
    mov bh, 0
    mov ah, 02h
    int 10h
    
    ; Print "Fuel: "
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
    ; Convert fuel value to ASCII and print
    mov al, [fuel]
    xor ah, ah
    
    ; Print hundreds digit
    mov bl, 100
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    ; Print tens digit
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
    
    ; Print ones digit
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

; DisplayWinMessage - show "YOU WON!" centered
DisplayWinMessage:
    push ax
    push bx
    push dx
    push si
    
    mov dh, 12
    mov dl, 15
    mov bh, 0
    mov ah, 02h
    int 10h
    
    mov si, win_text
.print_win:
    lodsb
    cmp al, 0
    je .done_win
    mov ah, 0Eh
    mov bh, 0
    mov bl, 14
    int 10h
    jmp .print_win
    
.done_win:
    pop si
    pop dx
    pop bx
    pop ax
    ret

; DisplayLoseMessage - show "YOU LOSE!" centered
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

; ==== NEW CODE START (COIN SYSTEM) ====

; SpawnCoin - spawn a coin at random lane
SpawnCoin:
    push ax
    push bx
    push cx
    
    ; Check if coin already active
    cmp byte [coin_active], 1
    je .spawn_done
    
    ; Get random lane (avoiding last coin lane)
    call GetRandomCoinLane
    
    ; Check if lane has red car near top (Y < 30)
    call IsLaneClear
    cmp al, 0
    je .spawn_done          ; Lane not clear, skip spawn
    
    ; Spawn the coin
    mov al, [temp_coin_lane]
    mov [coin_lane], al
    mov [last_coin_lane], al
    
    ; Calculate X position
    xor ah, ah
    mov bx, LANE_W
    mul bx
    add ax, ROAD_X0
    add ax, (LANE_W - COIN_W) / 2
    mov [coin_x], ax
    
    ; Set Y to top
    mov word [coin_y], 0
    
    ; Activate coin
    mov byte [coin_active], 1
    
.spawn_done:
    pop cx
    pop bx
    pop ax
    ret

; GetRandomCoinLane - get random lane for coin (avoiding last)
GetRandomCoinLane:
    push bx
    push dx
    
    mov ah, 00h
    int 1Ah
    xor dx, [random_seed]
    add dx, 7            ; Additional randomness
    mov [random_seed], dx
    
    mov ax, dx
    xor dx, dx
    mov bx, 3
    div bx
    mov al, dl
    
    ; Avoid last coin lane
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

; IsLaneClear - check if lane is clear of red cars near top (returns 1 if clear, 0 if blocked)
IsLaneClear:
    push bx
    push cx
    push di
    
    mov al, [temp_coin_lane]
    mov cl, al              ; CL = target lane
    
    ; Check all red cars
    mov di, red_car_active
    mov bx, 0
.check_loop:
    cmp byte [di], 0
    je .next_car
    
    ; Check if red car is in same lane
    mov al, [di+1]
    cmp al, cl
    jne .next_car
    
    ; Check if red car Y < 30
    mov ax, [di+2]
    cmp ax, 30
    jge .next_car
    
    ; Lane is blocked!
    mov al, 0
    jmp .check_done
    
.next_car:
    add di, 4
    inc bx
    cmp bx, MAX_RED_CARS
    jl .check_loop
    
    ; Lane is clear
    mov al, 1
    
.check_done:
    pop di
    pop cx
    pop bx
    ret

; MoveCoin - move coin downward
MoveCoin:
    push ax
    
    cmp byte [coin_active], 0
    je .move_done
    
    ; Move coin down
    mov ax, [coin_y]
    add ax, COIN_SPEED
    mov [coin_y], ax
    
    ; Check if off screen
    cmp ax, 200
    jle .move_done
    
    ; Deactivate coin
    mov byte [coin_active], 0
    
.move_done:
    pop ax
    ret

; DrawCoin - draw the coin if active
DrawCoin:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [coin_active], 0
    je .draw_done
    
    ; Draw coin sprite
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

; CheckCoinCollection - check if blue car collects coin
CheckCoinCollection:
    push ax
    push bx
    push cx
    push dx
    
    cmp byte [coin_active], 0
    je .no_collection
    
    ; Get coin position
    mov cx, [coin_x]
    mov dx, [coin_y]
    
    ; Check X overlap
    mov ax, cx
    add ax, COIN_W
    cmp ax, [blue_car_x]
    jle .no_collection
    
    mov ax, [blue_car_x]
    add ax, CAR_W
    cmp cx, ax
    jge .no_collection
    
    ; Check Y overlap
    mov ax, dx
    add ax, COIN_H
    cmp ax, BLUE_CAR_Y
    jle .no_collection
    
    mov ax, BLUE_CAR_Y
    add ax, CAR_H
    cmp dx, ax
    jge .no_collection
    
    ; Collision! Collect coin
    mov byte [coin_active], 0
    inc byte [coin_count]
    
.no_collection:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; DisplayCoins - draw coin count below fuel
DisplayCoins:
    push ax
    push bx
    push cx
    push dx
    push di
    
    ; Draw "Coins:" at position (2, 1)
    mov dh, 2
    mov dl, 1
    mov bh, 0
    mov ah, 02h
    int 10h
    
    ; Print "Coins: "
    mov si, coins_text
.print_coins_label:
    lodsb
    cmp al, 0
    je .print_value
    mov ah, 0Eh
    mov bh, 0
    mov bl, 14           ; Yellow color
    int 10h
    jmp .print_coins_label
    
.print_value:
    ; Convert coin count to ASCII and print
    mov al, [coin_count]
    xor ah, ah
    
    ; Print hundreds digit
    mov bl, 100
    div bl
    push ax
    add al, '0'
    mov ah, 0Eh
    mov bh, 0
    int 10h
    pop ax
    
    ; Print tens digit
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
    
    ; Print ones digit
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

; ==== NEW CODE END ====

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

; Data section
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

fuel_text db 'Fuel: ', 0
win_text db 'YOU WON!', 0
lose_text db 'YOU LOSE!', 0

; ==== NEW CODE START (COIN SYSTEM) ====
coin_active db 0
coin_lane db 0
coin_x dw 0
coin_y dw 0
coin_count db 0
coin_spawn_counter dw 0
last_coin_lane db 0xFF
temp_coin_lane db 0

coins_text db 'Coins: ', 0

; Coin sprite - 6x6 yellow circle
coin_sprite:
    db 255,255, 14, 14,255,255
    db 255, 14, 14, 14, 14,255
    db  14, 14, 14, 14, 14, 14
    db  14, 14, 14, 14, 14, 14
    db 255, 14, 14, 14, 14,255
    db 255,255, 14, 14,255,255
; ==== NEW CODE END ====

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