# Gameboy Assembler

Small assembler for Gameboy assembly programs written in Swift.  
Assembly syntax mostly follows other assemblers, but is probably not compatible.  
Takes an assembly file as input, produces a binary, which can be executed in a Gameboy emulator.  
Is fairly feature complete, supports all of the instruction set. Still missing some nice-to-have features, see the todo below.

## Example program

Here is a small example Gameboy program, which displays a smiley sprite on screen:

```assembly
# Simple smiley
# Displays a smiley sprite in the upper left corner of the screen

bg_tile_map = 0x9800
bg_tile_data = 0x9000

[org(0x4000)] graphics: db 0x00, 0x24, 0x24, 0x00, 0x81, 0x7e, 0x00, 0x00
[org(0x100)] start: nop; jp main
[org(0x134)] game_title: db "SMILEY"

[org(0x150)] main:
	# Set LCDC (bit 7: operation on, bit 0: bg and win on)
	ld hl, 0xff40
	ld (hl), (1 | (1 << 7))

	# Set first bg tile
	ld h, (bg_tile_map >> 8)
	ld l, (bg_tile_map & 0xff)
	ld (hl), 1

	# Set the tile data
	ld h, (bg_tile_data >> 8)
	ld l, ((bg_tile_data & 0xff) + 16)
	ld b, 8
	ld de, 0x4000
	loop:
		ld a, (de)
		inc de
		ld (hl+), a
		ld (hl+), a
		dec b
		jp nz, loop

	# Set bg palette data
	ld hl, 0xff47
	ld (hl), 0xe4
	
	end: jp end

[org(0x7fff)] pad: db 0x00
```

This is how it looks:

![Smiley example screenshot](https://d17oy1vhnax1f7.cloudfront.net/items/2t2s3q1J3E3Y2Z3e2p1D/smiley.png?v=dff06f03)

## Usage

The project comes with a CLI application which you can invoke with `input/file.asm -o output/file.gb`.  
It also contains a dynamic framework which you can import into a macOS or iOS app.

## Project status

Version 1.0 of the project has been released, and contains all core features for the assembler! See below for which features are implemented, and which are still to come.

### Implemented features

✅ Assembly parsing  
✅ Code generation  
✅ Linking  
✅ All of the Gameboy instruction set  
✅ Error reporting with line numbers  
✅ Command line interface  
✅ Constant defines  
✅ Build-time expressions  
✅ Strings

### Todo

➡️ Imports and file modules  
➡️ Using labels as expression values (e.g. in the smiley program, being able to say `ld de, graphics`)  
➡️ Programs doesn't boot in all emulators (like OpenEmu)  

### Wish list

💟 More awesome example programs    
💟 Disentanglement of code (the parsing module should be more generic for example)    
💟 Sprite importer (manually entering pixel hex codes suck. Maybe a way of defining sprites in ASCII art?)  
💟 Graphical code editor  

## Contributing

Right now it's still a personal project, and I might not be accepting pull requests for new features. Bug fixes and more tests are welcome though.

If you find a bug or a missing feature, feel free to submit an issue.
