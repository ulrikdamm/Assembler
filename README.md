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
	ld [hl], (1 | (1 << 7))

	# Set first bg tile
	ld h, (bg_tile_map >> 8)
	ld l, (bg_tile_map & 0xff)
	ld [hl], 1

	# Set the tile data
	ld h, (bg_tile_data >> 8)
	ld l, ((bg_tile_data & 0xff) + 16)
	ld b, 8
	ld de, 0x4000
	loop:
		ld a, [de]
		inc de
		ld [hl+], a
		ld [hl+], a
		dec b
		jp nz, loop

	# Set bg palette data
	ld hl, 0xff47
	ld [hl], 0xe4
	end: jp end

[org(0x7fff)] pad: db 0x00

```

This is how it looks:

![Smiley example screenshot](https://d17oy1vhnax1f7.cloudfront.net/items/2t2s3q1J3E3Y2Z3e2p1D/smiley.png?v=dff06f03)

There are more examples in the examples folder:

[Smiley sprite](Examples/smiley.asm) | [Hello world](Examples/helloworld.asm) | [Directional pad movement](Examples/movement.asm)

## Usage

Quick start:

```bash
git clone git@github.com:ulrikdamm/Assembler.git
cd Assembler
swift build -c release
./.build/release/Assembler input.asm
```

You can compile the app from the Xcode project or by running `swift build` (the executable will be in .build/debug/Assembler)  
You compile source code with `Assembler input.asm`.
It also contains a dynamic framework which you can import into a macOS or iOS app.

## Project status

The assembler is stable and able to produce working binaries. See below for which features are supported and which are yet to come.

### New in version 1.2

🆕 Optional linker output showing all symbol locations (run with `--output-symbols`)  
🆕 Relative jumps (`jr`)  
🆕 Updated syntax (uses [] instead of () for direct memory access, as in `ld a, [0xff46]`)  
🆒 Example code showing gamepad input and DMA transfers  
🆗 Fixed problems with loads between a and memory that wouldn't assemble properly

### New in version 1.1

🆕 Ability to use labels in expressions (e.g. `ld a, (data_end - data)`)    
🆕 Allows empty labels (useful for the first point)  
🆕 Better command line interface, allows relative paths  
🆒 Updated examples  
🆗 Fixed loading of values between A and memory addresses (e.g. `ld a, (0xff00 + 0x44)`)

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
➡️ Smart layout of disconnected blocks in linker  
➡️ Support for variables though `ds` (define storage)

### Wish list

💟 More awesome example programs    
💟 Sprite importer (manually entering pixel hex codes suck. Maybe a way of defining sprites in ASCII art?)  
💟 Graphical code editor  

## Contributing

Right now it's still a personal project, and I might not be accepting pull requests for new features. Bug fixes and more tests are welcome though.

If you find a bug or a missing feature, feel free to submit an issue.
