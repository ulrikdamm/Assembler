// Simple smiley
// Displays a smiley sprite in the upper left corner of the screen

bg_tile_map = 0x9800
bg_tile_data = 0x9000

[org(0x4000)] graphics: db 0x00, 0x24, 0x24, 0x00, 0x81, 0x7e, 0x00, 0x00
[org(0x100)] start: nop; jp main
[org(0x134)] game_title: db "SMILEY"

[org(0x150)] main:
	# Set LCDC (bit 7: operation on, bit 0: bg and win on)
	ld h, 0xff
	ld l, 0x40
	ld (hl), (1 | (1 << 7))

	# Set first bg tile
	ld h, (bg_tile_map >> 8)
	ld l, (bg_tile_map & 0xff)
	ld (hl), 1

	# Set the tile data
	ld h, (bg_tile_data >> 8)
	ld l, ((bg_tile_data & 0xff) + 16)
	ld b, 8
	ld d, 0x40
	ld e, 0x00
	loop:
		ld a, (de)
		ld (hl), a
		inc hl
		ld (hl), a
		inc hl
		inc de
		dec b
		jp nz, loop

	# Set bg palette data
	ld h, 0xff
	ld l, 0x47
	ld (hl), 0xe4
	end: jp end

[org(0x7fff)] pad: db 0x00
