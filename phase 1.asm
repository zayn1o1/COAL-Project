org 0x100

ROAD_X0        equ  70
ROAD_W         equ  180
LANE_W         equ  (ROAD_W/3)
DIV1_X         equ  (ROAD_X0 + LANE_W)
DIV2_X         equ  (ROAD_X0 + 2*LANE_W)
DIV_W          equ  1

COLOR_GRASS    equ  2
COLOR_ROAD     equ  8
COLOR_LINE     equ  15
TRANSPARENT    equ  255

CAR_W          equ  12
CAR_H          equ  16

BLUE_CAR_Y     equ  (200 - CAR_H - 10)
BLUE_CAR_X     equ  (ROAD_X0 + LANE_W + ((LANE_W - CAR_W)/2))

RED_CAR_Y      equ  10
RED_CAR_X      equ  (ROAD_X0 + 2*LANE_W + ((LANE_W - CAR_W)/2))

start:
    mov ax, 0013h
    int 10h
    mov ax, 0A000h
    mov es, ax
    push cs
    pop ds

    mov bx, 0
.bg_row:
    imul di, bx, 320
    mov al, 2
    mov cx, ROAD_X0
    rep stosb

    mov al, 8
    mov cx, ROAD_W
    rep stosb

    mov al, 2
    mov cx, (320 - ROAD_X0 - ROAD_W)
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

    push word car_blue
    push word CAR_H
    push word CAR_W
    push word BLUE_CAR_X
    push word BLUE_CAR_Y
    call DrawSpriteTP

    push word car_red
    push word CAR_H
    push word CAR_W
    push word RED_CAR_X
    push word RED_CAR_Y
    call DrawSpriteTP

    xor ah, ah
    int 16h
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

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

car_blue:
    db 8,8,8,9,9,9,9,9,9,8,8,8
    db 8,8,8,9,9,9,9,9,9,8,8,8
    db 8,8,8,9,9,9,9,9,9,8,8,8
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,7,7,7,7,7,7,7,7,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 0,9,9,9,9,9,9,9,9,9,9,0
    db 8,8,8,9,9,9,9,9,9,8,8,8
    db 8,8,8,9,9,9,9,9,9,8,8,8
    db 8,8,8,9,9,9,9,9,9,8,8,8

car_red:
    db 8,8,8,4,4,4,4,4,4,8,8,8
    db 8,8,8,4,4,4,4,4,4,8,8,8
    db 8,8,8,4,4,4,4,4,4,8,8,8
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,7,7,7,7,7,7,7,7,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 0,4,4,4,4,4,4,4,4,4,4,0
    db 8,8,8,4,4,4,4,4,4,8,8,8
    db 8,8,8,4,4,4,4,4,4,8,8,8
    db 8,8,8,4,4,4,4,4,4,8,8,8