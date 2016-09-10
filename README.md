# Gameboy assembler

**work in progress**

Small assembler for Gameboy assembly programs written in Swift.  
Assembly syntax mostly follows other assemblers, but is probably not compatible.  
Takes an assembly file as input, produces a binary, which can be executed in a Gameboy emulator.

## Example program

Here is a small example Gameboy program, which displays a smily sprite on screen:

```assembly
# Simple smily
# Displays a smily sprite in the upper left corner of the screen

bg_tile_map = 0x9800
bg_tile_data = 0x9000

[org(0x4000)] graphics: db 0x00, 0x24, 0x24, 0x00, 0x81, 0x7e, 0x00, 0x00
[org(0x100)] start: nop; jp main
[org(0x134)] game_title: db "SMILY"

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
```

## Usage

The project comes with a CLI application which you can invoke with "input/file.asm -o output/file.gb".  
It also contains a dynamic framework which you can import into a macOS or iOS app.

## Project status

Implemented features:

• Assembly parsing  
• Code generation  
• Linking  
• Most of the Gameboy instruction set  
• Error reporting for the instruction assemling stage  
• Command line interface  
• Constant defines  
• Build-time expressions  

TODO:

• Error reporting for parsing stage  
• Line numbers in error reporting  
• Remaining Gameboy instructions  
• Using labels as expression values (e.g. in the smily program, being able to say `ld de, graphics`)  
• Graphical code editor  
• Programs doesn't boot in all emulators (like OpenEMU)

## Contributing

Right now it's still a personal project, and I won't be accepting pull requests for new features yet. Bug fixes and more tests are welcome though.  
If you find a bug or a missing feature, feel free to submit an issue.
