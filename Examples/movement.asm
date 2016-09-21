# Hello world + movement
# Displays HELLO WORLD at the top of the screen, and there's a character you can move around on the screen with the directional pad

bg_tile_map = 0x9800
alphabet_start_addr = 0x8000 + (0x41 * 16)

lcdc = 0xff40
lcdc_operation_bit = (1 << 7)
lcdc_win_tilemap_bit = (1 << 6) # 0 = 9800 - 9bff, 1 = 9c00 - 9ffff
lcdc_win_on_bit = (1 << 5)
lcdc_bgwin_tiledata_bit = (1 << 4) # 0 = 8800 - 97ff, 1 = 8000 - 8fff
lcdc_bg_tilemap_bit = (1 << 3) # 0 = 9800 - 9bff, 1 = 9c00 - 9fff
lcdc_sprite_size_bit = (1 << 2) #0 = 8*8, 1 = 8*16
lcdc_sprite_on_bit = (1 << 1)
lcdc_bgwin_on_bit = (1 << 0)
ly = 0xff44
dma = 0xff46
bgwin_palette = 0xff47
obj1_palette = 0xff48
obj2_palette = 0xff49
interrupt_enable = 0xffff
ie_time = (1 << 2)
ie_lcdc = (1 << 1)
ie_vblank = (1 << 0)

[org(0x4000)] message: db "HELLO WORLD"
[org(0x4041)]
letter_a: db 0x00, 0x18, 0x24, 0x24, 0x3c, 0x24, 0x24, 0x24
letter_b: db 0x00, 0x38, 0x24, 0x24, 0x24, 0x38, 0x24, 0x38
letter_c: db 0x00, 0x18, 0x24, 0x20, 0x20, 0x20, 0x24, 0x18
letter_d: db 0x00, 0x38, 0x24, 0x24, 0x24, 0x24, 0x24, 0x38
letter_e: db 0x00, 0x3c, 0x20, 0x20, 0x20, 0x38, 0x20, 0x3c
letter_f: db 0x00, 0x3c, 0x20, 0x20, 0x20, 0x38, 0x20, 0x20
letter_g: db 0x00, 0x18, 0x24, 0x20, 0x20, 0x2c, 0x24, 0x1c
letter_h: db 0x00, 0x24, 0x24, 0x24, 0x24, 0x3c, 0x24, 0x24
letter_i: db 0x00, 0x1c, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1c
letter_j: db 0x00, 0x0e, 0x04, 0x04, 0x04, 0x04, 0x24, 0x18
letter_k: db 0x00, 0x24, 0x24, 0x28, 0x30, 0x30, 0x28, 0x24
letter_l: db 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3c
letter_m: db 0x00, 0x22, 0x36, 0x2a, 0x22, 0x22, 0x22, 0x22
letter_n: db 0x00, 0x22, 0x32, 0x32, 0x2a, 0x26, 0x26, 0x22
letter_o: db 0x00, 0x18, 0x24, 0x24, 0x24, 0x24, 0x24, 0x18
letter_p: db 0x00, 0x38, 0x24, 0x24, 0x38, 0x30, 0x30, 0x30
letter_q: db 0x00, 0x38, 0x24, 0x24, 0x24, 0x24, 0x2c, 0x1e
letter_r: db 0x00, 0x38, 0x24, 0x24, 0x38, 0x24, 0x24, 0x24
letter_s: db 0x00, 0x18, 0x24, 0x20, 0x18, 0x04, 0x24, 0x18
letter_t: db 0x00, 0x3e, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08
letter_u: db 0x00, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x18
letter_v: db 0x00, 0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x08
letter_w: db 0x00, 0x52, 0x52, 0x52, 0x52, 0x52, 0x52, 0x2c
letter_x: db 0x00, 0x22, 0x22, 0x14, 0x08, 0x14, 0x22, 0x22
letter_y: db 0x00, 0x22, 0x22, 0x14, 0x08, 0x08, 0x08, 0x08
letter_z: db 0x00, 0x3c, 0x04, 0x04, 0x18, 0x20, 0x20, 0x3c
sprite: db 0b0001_1000, 0b0001_1000, 0b0111_1110, 0b1011_1101, 0b1011_1101, 0b0001_1000, 0b0010_0100, 0b0110_0110

[org(0x0040)] vblank_interrupt: jp 0xff80

[org(0x100)] start: nop; jp main
[org(0x134)] game_title: db "HELLO WORLD"

[org(0x150)] main:
  ld sp, 0xfffe
  di
  
  call stopLCD
  
  # Clear 8000 - 8fff
  xor a
  ld hl, 0x8001
  ld de, 0x1fff
  call fill_bytes
  
  # Clear c000 - cfff
  xor a
  ld hl, 0xc000
  ld de, 0x1000
  call fill_bytes
  
  ld a, 40
  ld hl, 0xc000
  ld [hl+], a
  ld [hl+], a
  ld a, 91
  ld [hl+], a
  ld a, 0
  ld [hl+], a
  
  # Copy DMA routine to high RAM
  ld hl, 0xff80
  ld bc, perform_dma
  ld de, (perform_dma_end - perform_dma)
  call copy_bytes
  
  ld hl, alphabet_start_addr
  ld de, 26 * (8 * 8)
  ld bc, 0x4041
  call copy_bytes_twice

  ld hl, bg_tile_map
  ld bc, 0x4000
  ld de, 11
  call copy_bytes

  # Set bg palette data
  ld a, 0xe4
  ld [bgwin_palette], a
  ld [obj1_palette], a
  ld [obj2_palette], a
  
  call startLCD
  
  ld a, (ie_vblank)
  ld [interrupt_enable], a
  ei
  
  ld d, 0
  main_loop:
    halt
    nop
    
    dec d
    # jr nz, main_loop
    call read_input
    jr main_loop

read_input:
  ld a, 0x20
  ld [0xff00], a
  ld a, [0xff00]
  ld a, [0xff00]
  cpl
  and 0x0f
  swap a
  ld b, a
  ld a, 0x10
  ld [0xff00], a
  ld a, [0xff00]
  ld a, [0xff00]
  cpl
  and 0x0f
  or b
  ld b, a
  
  check_down:
    bit 7, b
    jr z, check_up
    ld a, [0xc000]
    inc a
    ld [0xc000], a
    jr check_left
  check_up:
    bit 6, b
    jr z, check_left
    ld a, [0xc000]
    dec a
    ld [0xc000], a
  
  check_left:
    bit 4, b
    jr z, check_right
    ld a, [0xc001]
    inc a
    ld [0xc001], a
    jr check_end
  check_right:
    bit 5, b
    jr z, check_end
    ld a, [0xc001]
    dec a
    ld [0xc001], a
  check_end:
    ret

perform_dma:
  push af

  ld a, 0xc0
  ld [dma], a
  ld a, 0x28
  perform_dma_wait:
    dec a
    jr nz, perform_dma_wait
  pop af
  reti
perform_dma_end:
  
incsprite:
  ld a, [0x8000]
  inc a
  ld [0x8000], a
  ret

# Wait until it's safe to update the screen and then disable LCD operation
stopLCD:
  ld a, [ly]
  cp 145
  jp nc, stopLCD
  xor a
  ld [lcdc], a
  ret

startLCD:
  ld a, (lcdc_bgwin_on_bit | lcdc_operation_bit | lcdc_bgwin_tiledata_bit | lcdc_sprite_on_bit)
  ld [lcdc], a
  ret

# a: byte to fill with
# de: number of bytes
# hl: destination address
fill_bytes:
  inc e
  inc d
  jp fill_bytes_loop
  
  fill_bytes_copy:
    ld [hl+], a

  fill_bytes_loop:
    dec e
    jp nz, fill_bytes_copy
    dec d
    jp nz, fill_bytes_copy
    ret

# de: number of bytes
# bc: start address
# hl: destination address
copy_bytes:
  inc e
  inc d
  jp copy_bytes_loop
  
  copy_bytes_copy:
    ld a, [bc]
    ld [hl+], a
    inc bc

  copy_bytes_loop:
    dec e
    jp nz, copy_bytes_copy
    dec d
    jp nz, copy_bytes_copy
    ret

# de: number of bytes
# bc: start address
# hl: destination address
copy_bytes_twice:
  inc e
  inc d
  jp copy_bytes_twice_loop
  
  copy_bytes_twice_copy:
    ld a, [bc]
    ld [hl+], a
    ld [hl+], a
    inc bc

  copy_bytes_twice_loop:
    dec e
    jp nz, copy_bytes_twice_copy
    dec d
    jp nz, copy_bytes_twice_copy
    ret

# to_a_1:
#   ld a, (bg_tile_map)
#   inc a
#   ld (bg_tile_map), a
#   ret
#
# to_a_2:
#   ld a, (bg_tile_map + 1)
#   inc a
#   ld (bg_tile_map + 1), a
#   ret

[org(0x7fff)] pad: db 0x00
