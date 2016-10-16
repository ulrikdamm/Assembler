//
//  GameboyAssemblerTests.swift
//  GameboyAssemblerTests
//
//  Created by Ulrik Damm on 09/09/2016.
//  Copyright © 2016 Ufd.dk. All rights reserved.
//

import XCTest
@testable import Assembler

class GameboyInstructionSetTests : XCTestCase {
	let instructionSet = GameboyInstructionSet()
	
	func assert(_ code : String, _ output : [Opcode]) {
		let ins : Instruction
		
		do {
			let state = State(source: code)
			guard let i = try AssemblyParser.getInstruction(state)?.value else {
				XCTFail("Couldn't compile: \(code)"); return
			}
			ins = i
		} catch let error as State.ParseError {
			XCTFail("Couldn't compile: \(error.localizedDescription)"); return
		} catch let error {
			XCTFail("Couldn't compile: \(error)"); return
		}
		
		let result : [Opcode]
		
		do {
			result = try instructionSet.assembleInstruction(instruction: ins)
		} catch let error {
			XCTFail("Error assembling instruction: \(error)")
			return
		}
		
		XCTAssertEqual(result, output, "Incorrect output: \(result)")
	}
	
	func assertFails(_ code : String) {
		let ins : Instruction
		
		do {
			let state = State(source: code)
			guard let i = try AssemblyParser.getInstruction(state)?.value else {
				XCTFail("Couldn't compile: \(code)"); return
			}
			ins = i
		} catch let error as State.ParseError {
			XCTFail("Couldn't compile: \(error.localizedDescription)"); return
		} catch let error {
			XCTFail("Couldn't compile: \(error)"); return
		}
		
		do {
			let _ = try instructionSet.assembleInstruction(instruction: ins)
			XCTFail()
		} catch is ErrorMessage {
			return
		} catch let error {
			XCTFail("Unexpected error: \(error)")
		}
	}
	
	func assert(_ code : String, _ output : [UInt8]) {
		assert(code, output.map { .byte($0) })
	}
}

class GameboyLoadTests : GameboyInstructionSetTests {
	func test_ld_b_d8()		{ assert("ld b, 0xff",			[0x06, 0xff]) }
	func test_ld_c_d8()		{ assert("ld c, 0xff",			[0x0e, 0xff]) }
	func test_ld_d_d8()		{ assert("ld d, 0xff",			[0x16, 0xff]) }
	func test_ld_e_d8()		{ assert("ld e, 0xff",			[0x1e, 0xff]) }
	func test_ld_h_d8()		{ assert("ld h, 0xff",			[0x26, 0xff]) }
	func test_ld_l_d8()		{ assert("ld l, 0xff",			[0x2e, 0xff]) }
	
	func test_ld_hl_l()		{ assert("ld [hl], l",			[0x75]) }
	func test_ld_hl_ff()	{ assert("ld [hl], 0xff",		[0x36, 0xff]) }
	
	func test_ld_a_a()		{ assert("ld a, a",				[0x7f]) }
	func test_ld_a_bc()		{ assert("ld a, [bc]",			[0x0a]) }
	func test_ld_a_hl8()	{ assert("ld a, [hl]",			[0x7e]) }
	func test_ld_a_1234()	{ assert("ld a, [0x1234]",		[0xfa, 0x34, 0x12]) }
	func test_ld_1234_a()	{ assert("ld [0x1234], a",		[0xea, 0x34, 0x12]) }
	func test_ld_a_ff()		{ assert("ld a, 0xff",			[0x3e, 0xff]) }
	
	// Regression tests
	func test_ld_a_const()	{ assert("ld a, [testconst]",	[.byte(0xfa), .expression(.constant("testconst"), .uint16)]) }
	func test_ld_a_const2()	{ assert("ld a, [testconst+1]",	[.byte(0xfa), .expression(.binaryExpr(.constant("testconst"), "+", .value(1)), .uint16)]) }
	func test_ld_a_const3()	{ assert("ld a, (testval+1)",	[.byte(0x3e), .expression(.binaryExpr(.constant("testval"), "+", .value(1)), .uint8)]) }
	func test_ld_a_overflw(){ assertFails("ld a, 0x1234") }
	
	func test_ld_bc8_a()	{ assert("ld [bc], a",			[0x02]) }
	func test_ld_hl8_a()	{ assert("ld [hl], a",			[0x77]) }
	
	func test_ld_a_ch()		{ assert("ld a, [0xff00 + c]",	[0xf2]) }
	func test_ld_ch_a()		{ assert("ld [0xff00 + c], a",	[0xe2]) }
	
	func test_ld_a_hlm()	{ assert("ld a, [hl-]",			[0x3a]) }
	func test_ld_hlm_a()	{ assert("ld [hl-], a",			[0x32]) }
	func test_ld_a_hlp()	{ assert("ld a, [hl+]",			[0x2a]) }
	func test_ld_hlp_a()	{ assert("ld [hl+], a",			[0x22]) }
	
	func test_ldh_nh_a()	{ assert("ld [0xff00+0xff], a",	[0xe0, 0xff]) }
	func test_ldh_a_nh()	{ assert("ld a, [0xff00+0xff]",	[0xf0, 0xff]) }
	
	func test_ld_bc_nn()	{ assert("ld bc, 0x1234",		[0x01, 0x34, 0x12]) }
	func test_ld_de_nn()	{ assert("ld de, 0x1234",		[0x11, 0x34, 0x12]) }
	func test_ld_hl_nn()	{ assert("ld hl, 0x1234",		[0x21, 0x34, 0x12]) }
	func test_ld_sp_nn()	{ assert("ld sp, 0x1234",		[0x31, 0x34, 0x12]) }
	
	func test_ld_sp_hl()	{ assert("ld sp, hl",			[0xf9]) }
	func test_ld_hl_spn1()	{ assert("ld hl, sp + 20",		[0xf8, 0x14]) }
	func test_ld_hl_spn2()	{ assert("ld hl, sp - 20",		[0xf8, 0xec]) }
	func test_ld_nn_sp()	{ assert("ld 0x1234, sp",		[0x08, 0x34, 0x12]) }
}

class GameboyStackTests : GameboyInstructionSetTests {
	func test_push_af()		{ assert("push af",				[0xf5]) }
	func test_push_bc()		{ assert("push bc",				[0xc5]) }
	func test_push_de()		{ assert("push de",				[0xd5]) }
	func test_push_hl()		{ assert("push hl",				[0xe5]) }
	
	func test_pop_af()		{ assert("pop af",				[0xf1]) }
	func test_pop_bc()		{ assert("pop bc",				[0xc1]) }
	func test_pop_de()		{ assert("pop de",				[0xd1]) }
	func test_pop_hl()		{ assert("pop hl",				[0xe1]) }
}

class GameboyArithmeticTests : GameboyInstructionSetTests {
	func test_add_a_a()		{ assert("add a, a",			[0x87]) }
	func test_add_a_b()		{ assert("add a, b",			[0x80]) }
	func test_add_a_c()		{ assert("add a, c",			[0x81]) }
	func test_add_a_d()		{ assert("add a, d",			[0x82]) }
	func test_add_a_e()		{ assert("add a, e",			[0x83]) }
	func test_add_a_h()		{ assert("add a, h",			[0x84]) }
	func test_add_a_l()		{ assert("add a, l",			[0x85]) }
	func test_add_a_hl()	{ assert("add a, [hl]",			[0x86]) }
	func test_add_a_n()		{ assert("add a, 0xff",			[0xc6, 0xff]) }
	
	func test_adc_a_a()		{ assert("adc a, a",			[0x8f]) }
	func test_adc_a_b()		{ assert("adc a, b",			[0x88]) }
	func test_adc_a_c()		{ assert("adc a, c",			[0x89]) }
	func test_adc_a_d()		{ assert("adc a, d",			[0x8a]) }
	func test_adc_a_e()		{ assert("adc a, e",			[0x8b]) }
	func test_adc_a_h()		{ assert("adc a, h",			[0x8c]) }
	func test_adc_a_l()		{ assert("adc a, l",			[0x8d]) }
	func test_adc_a_hl()	{ assert("adc a, [hl]",			[0x8e]) }
	func test_adc_a_n()		{ assert("adc a, 0xff",			[0xce, 0xff]) }
	
	func test_sub_a_a()		{ assert("sub a, a",			[0x97]) }
	func test_sub_a_b()		{ assert("sub a, b",			[0x90]) }
	func test_sub_a_c()		{ assert("sub a, c",			[0x91]) }
	func test_sub_a_d()		{ assert("sub a, d",			[0x92]) }
	func test_sub_a_e()		{ assert("sub a, e",			[0x93]) }
	func test_sub_a_h()		{ assert("sub a, h",			[0x94]) }
	func test_sub_a_l()		{ assert("sub a, l",			[0x95]) }
	func test_sub_a_hl()	{ assert("sub a, [hl]",			[0x96]) }
	func test_sub_a_n()		{ assert("sub a, 0xff",			[0xd6, 0xff]) }
	
	func test_sbc_a_a()		{ assert("sbc a, a",			[0x9f]) }
	func test_sbc_a_b()		{ assert("sbc a, b",			[0x98]) }
	func test_sbc_a_c()		{ assert("sbc a, c",			[0x99]) }
	func test_sbc_a_d()		{ assert("sbc a, d",			[0x9a]) }
	func test_sbc_a_e()		{ assert("sbc a, e",			[0x9b]) }
	func test_sbc_a_h()		{ assert("sbc a, h",			[0x9c]) }
	func test_sbc_a_l()		{ assert("sbc a, l",			[0x9d]) }
	func test_sbc_a_hl()	{ assert("sbc a, [hl]",			[0x9e]) }
	func test_sbc_a_n()		{ assert("sbc a, 0xff",			[0xde, 0xff]) }
}

class GameboyLogicOperationTests : GameboyInstructionSetTests {
	func test_and_a()		{ assert("and a",				[0xa7]) }
	func test_and_b()		{ assert("and b",				[0xa0]) }
	func test_and_c()		{ assert("and c",				[0xa1]) }
	func test_and_d()		{ assert("and d",				[0xa2]) }
	func test_and_e()		{ assert("and e",				[0xa3]) }
	func test_and_h()		{ assert("and h",				[0xa4]) }
	func test_and_l()		{ assert("and l",				[0xa5]) }
	func test_and_hl()		{ assert("and [hl]",			[0xa6]) }
	func test_and_ff()		{ assert("and 0xff",			[0xe6, 0xff]) }
	
	func test_or_a()		{ assert("or a",				[0xb7]) }
	func test_or_b()		{ assert("or b",				[0xb0]) }
	func test_or_c()		{ assert("or c",				[0xb1]) }
	func test_or_d()		{ assert("or d",				[0xb2]) }
	func test_or_e()		{ assert("or e",				[0xb3]) }
	func test_or_h()		{ assert("or h",				[0xb4]) }
	func test_or_l()		{ assert("or l",				[0xb5]) }
	func test_or_hl()		{ assert("or [hl]",				[0xb6]) }
	func test_or_ff()		{ assert("or 0xff",				[0xf6, 0xff]) }
	
	func test_xor_a()		{ assert("xor a",				[0xaf]) }
	func test_xor_b()		{ assert("xor b",				[0xa8]) }
	func test_xor_c()		{ assert("xor c",				[0xa9]) }
	func test_xor_d()		{ assert("xor d",				[0xaa]) }
	func test_xor_e()		{ assert("xor e",				[0xab]) }
	func test_xor_h()		{ assert("xor h",				[0xac]) }
	func test_xor_l()		{ assert("xor l",				[0xad]) }
	func test_xor_hl()		{ assert("xor [hl]",			[0xae]) }
	func test_xor_ff()		{ assert("xor 0xff",			[0xee, 0xff]) }
	
	func test_cp_a()		{ assert("cp a",				[0xbf]) }
	func test_cp_b()		{ assert("cp b",				[0xb8]) }
	func test_cp_c()		{ assert("cp c",				[0xb9]) }
	func test_cp_d()		{ assert("cp d",				[0xba]) }
	func test_cp_e()		{ assert("cp e",				[0xbb]) }
	func test_cp_h()		{ assert("cp h",				[0xbc]) }
	func test_cp_l()		{ assert("cp l",				[0xbd]) }
	func test_cp_hl()		{ assert("cp [hl]",				[0xbe]) }
	func test_cp_ff()		{ assert("cp 0xff",				[0xfe, 0xff]) }
	
	func test_inc_a()		{ assert("inc a",				[0x3c]) }
	func test_inc_b()		{ assert("inc b",				[0x04]) }
	func test_inc_c()		{ assert("inc c",				[0x0c]) }
	func test_inc_d()		{ assert("inc d",				[0x14]) }
	func test_inc_e()		{ assert("inc e",				[0x1c]) }
	func test_inc_h()		{ assert("inc h",				[0x24]) }
	func test_inc_l()		{ assert("inc l",				[0x2c]) }
	func test_inc_hl8()		{ assert("inc [hl]",			[0x34]) }
	
	func test_dec_a()		{ assert("dec a",				[0x3d]) }
	func test_dec_b()		{ assert("dec b",				[0x05]) }
	func test_dec_c()		{ assert("dec c",				[0x0d]) }
	func test_dec_d()		{ assert("dec d",				[0x15]) }
	func test_dec_e()		{ assert("dec e",				[0x1d]) }
	func test_dec_h()		{ assert("dec h",				[0x25]) }
	func test_dec_l()		{ assert("dec l",				[0x2d]) }
	func test_dec_hl8()		{ assert("dec [hl]",			[0x35]) }
	
	func test_add_hl_bc()	{ assert("add hl, bc",			[0x09]) }
	func test_add_hl_de()	{ assert("add hl, de",			[0x19]) }
	func test_add_hl_hl()	{ assert("add hl, hl",			[0x29]) }
	func test_add_hl_sp()	{ assert("add hl, sp",			[0x39]) }
	func test_add_sp_n()	{ assert("add sp, -20",			[0xe8, 0xec]) }
	
	func test_inc_bc()		{ assert("inc bc",				[0x03]) }
	func test_inc_de()		{ assert("inc de",				[0x13]) }
	func test_inc_hl()		{ assert("inc hl",				[0x23]) }
	func test_inc_sp()		{ assert("inc sp",				[0x33]) }
	
	func test_dec_bc()		{ assert("dec bc",				[0x0b]) }
	func test_dec_de()		{ assert("dec de",				[0x1b]) }
	func test_dec_hl()		{ assert("dec hl",				[0x2b]) }
	func test_dec_sp()		{ assert("dec sp",				[0x3b]) }
	
	func test_swap_a()		{ assert("swap a",				[0xcb, 0x37]) }
	func test_swap_b()		{ assert("swap b",				[0xcb, 0x30]) }
	func test_swap_c()		{ assert("swap c",				[0xcb, 0x31]) }
	func test_swap_d()		{ assert("swap d",				[0xcb, 0x32]) }
	func test_swap_e()		{ assert("swap e",				[0xcb, 0x33]) }
	func test_swap_h()		{ assert("swap h",				[0xcb, 0x34]) }
	func test_swap_l()		{ assert("swap l",				[0xcb, 0x35]) }
	func test_swap_hl8()	{ assert("swap [hl]",			[0xcb, 0x36]) }
}

class GameboySpecialInstructionsTests : GameboyInstructionSetTests {
	func test_daa()			{ assert("daa",					[0x27]) }
	func test_cpl()			{ assert("cpl",					[0x2f]) }
	func test_ccf()			{ assert("ccf",					[0x3f]) }
	func test_scf()			{ assert("scf",					[0x37]) }
	func test_nop()			{ assert("nop",					[0x00]) }
	func test_halt()		{ assert("halt",				[0x76]) }
	func test_stop()		{ assert("stop",				[0x10, 0x00]) }
	func test_di()			{ assert("di",					[0xf3]) }
	func test_ei()			{ assert("ei",					[0xfb]) }
}

class GameboyRotateShiftTests : GameboyInstructionSetTests {
	func test_rlca()		{ assert("rlca",				[0x07]) }
	func test_rla()			{ assert("rla",					[0x17]) }
	func test_rrca()		{ assert("rrca",				[0x0f]) }
	func test_rra()			{ assert("rra",					[0x1f]) }
	
	func test_rlc_a()		{ assert("rlc a",				[0xcb, 0x07]) }
	func test_rlc_b()		{ assert("rlc b",				[0xcb, 0x00]) }
	func test_rlc_c()		{ assert("rlc c",				[0xcb, 0x01]) }
	func test_rlc_d()		{ assert("rlc d",				[0xcb, 0x02]) }
	func test_rlc_e()		{ assert("rlc e",				[0xcb, 0x03]) }
	func test_rlc_h()		{ assert("rlc h",				[0xcb, 0x04]) }
	func test_rlc_l()		{ assert("rlc l",				[0xcb, 0x05]) }
	func test_rlc_hl8()		{ assert("rlc [hl]",			[0xcb, 0x06]) }
	
	func test_rl_a()		{ assert("rl a",				[0xcb, 0x17]) }
	func test_rl_b()		{ assert("rl b",				[0xcb, 0x10]) }
	func test_rl_c()		{ assert("rl c",				[0xcb, 0x11]) }
	func test_rl_d()		{ assert("rl d",				[0xcb, 0x12]) }
	func test_rl_e()		{ assert("rl e",				[0xcb, 0x13]) }
	func test_rl_h()		{ assert("rl h",				[0xcb, 0x14]) }
	func test_rl_l()		{ assert("rl l",				[0xcb, 0x15]) }
	func test_rl_hl8()		{ assert("rl [hl]",				[0xcb, 0x16]) }
	
	func test_rrc_a()		{ assert("rrc a",				[0xcb, 0x0f]) }
	func test_rrc_b()		{ assert("rrc b",				[0xcb, 0x08]) }
	func test_rrc_c()		{ assert("rrc c",				[0xcb, 0x09]) }
	func test_rrc_d()		{ assert("rrc d",				[0xcb, 0x0a]) }
	func test_rrc_e()		{ assert("rrc e",				[0xcb, 0x0b]) }
	func test_rrc_h()		{ assert("rrc h",				[0xcb, 0x0c]) }
	func test_rrc_l()		{ assert("rrc l",				[0xcb, 0x0d]) }
	func test_rrc_hl8()		{ assert("rrc [hl]",			[0xcb, 0x0e]) }
	
	func test_rr_a()		{ assert("rr a",				[0xcb, 0x1f]) }
	func test_rr_b()		{ assert("rr b",				[0xcb, 0x18]) }
	func test_rr_c()		{ assert("rr c",				[0xcb, 0x19]) }
	func test_rr_d()		{ assert("rr d",				[0xcb, 0x1a]) }
	func test_rr_e()		{ assert("rr e",				[0xcb, 0x1b]) }
	func test_rr_h()		{ assert("rr h",				[0xcb, 0x1c]) }
	func test_rr_l()		{ assert("rr l",				[0xcb, 0x1d]) }
	func test_rr_hl8()		{ assert("rr [hl]",				[0xcb, 0x1e]) }
	
	func test_sla_a()		{ assert("sla a",				[0xcb, 0x27]) }
	func test_sla_b()		{ assert("sla b",				[0xcb, 0x20]) }
	func test_sla_c()		{ assert("sla c",				[0xcb, 0x21]) }
	func test_sla_d()		{ assert("sla d",				[0xcb, 0x22]) }
	func test_sla_e()		{ assert("sla e",				[0xcb, 0x23]) }
	func test_sla_h()		{ assert("sla h",				[0xcb, 0x24]) }
	func test_sla_l()		{ assert("sla l",				[0xcb, 0x25]) }
	func test_sla_hl8()		{ assert("sla [hl]",			[0xcb, 0x26]) }
	
	func test_sra_a()		{ assert("sra a",				[0xcb, 0x2f]) }
	func test_sra_b()		{ assert("sra b",				[0xcb, 0x28]) }
	func test_sra_c()		{ assert("sra c",				[0xcb, 0x29]) }
	func test_sra_d()		{ assert("sra d",				[0xcb, 0x2a]) }
	func test_sra_e()		{ assert("sra e",				[0xcb, 0x2b]) }
	func test_sra_h()		{ assert("sra h",				[0xcb, 0x2c]) }
	func test_sra_l()		{ assert("sra l",				[0xcb, 0x2d]) }
	func test_sra_hl8()		{ assert("sra [hl]",			[0xcb, 0x2e]) }
	
	func test_srl_a()		{ assert("srl a",				[0xcb, 0x3f]) }
	func test_srl_b()		{ assert("srl b",				[0xcb, 0x38]) }
	func test_srl_c()		{ assert("srl c",				[0xcb, 0x39]) }
	func test_srl_d()		{ assert("srl d",				[0xcb, 0x3a]) }
	func test_srl_e()		{ assert("srl e",				[0xcb, 0x3b]) }
	func test_srl_h()		{ assert("srl h",				[0xcb, 0x3c]) }
	func test_srl_l()		{ assert("srl l",				[0xcb, 0x3d]) }
	func test_srl_hl8()		{ assert("srl [hl]",			[0xcb, 0x3e]) }
}

class GameboyBitOperationsTests : GameboyInstructionSetTests {
	func test_bit_1_a()		{ assert("bit 2, a",			[0xcb, 0x57]) }
	func test_bit_1_b()		{ assert("bit 2, b",			[0xcb, 0x50]) }
	func test_bit_1_c()		{ assert("bit 2, c",			[0xcb, 0x51]) }
	func test_bit_1_d()		{ assert("bit 2, d",			[0xcb, 0x52]) }
	func test_bit_1_e()		{ assert("bit 2, e",			[0xcb, 0x53]) }
	func test_bit_1_h()		{ assert("bit 2, h",			[0xcb, 0x54]) }
	func test_bit_1_l()		{ assert("bit 2, l",			[0xcb, 0x55]) }
	func test_bit_1_hl8()	{ assert("bit 2, [hl]",			[0xcb, 0x56]) }
	
	func test_set_1_a()		{ assert("set 2, a",			[0xcb, 0xd7]) }
	func test_set_1_b()		{ assert("set 2, b",			[0xcb, 0xd0]) }
	func test_set_1_c()		{ assert("set 2, c",			[0xcb, 0xd1]) }
	func test_set_1_d()		{ assert("set 2, d",			[0xcb, 0xd2]) }
	func test_set_1_e()		{ assert("set 2, e",			[0xcb, 0xd3]) }
	func test_set_1_h()		{ assert("set 2, h",			[0xcb, 0xd4]) }
	func test_set_1_l()		{ assert("set 2, l",			[0xcb, 0xd5]) }
	func test_set_1_hl8()	{ assert("set 2, [hl]",			[0xcb, 0xd6]) }
	
	func test_res_1_a()		{ assert("res 2, a",			[0xcb, 0x97]) }
	func test_res_1_b()		{ assert("res 2, b",			[0xcb, 0x90]) }
	func test_res_1_c()		{ assert("res 2, c",			[0xcb, 0x91]) }
	func test_res_1_d()		{ assert("res 2, d",			[0xcb, 0x92]) }
	func test_res_1_e()		{ assert("res 2, e",			[0xcb, 0x93]) }
	func test_res_1_h()		{ assert("res 2, h",			[0xcb, 0x94]) }
	func test_res_1_l()		{ assert("res 2, l",			[0xcb, 0x95]) }
	func test_res_1_hl8()	{ assert("res 2, [hl]",			[0xcb, 0x96]) }
}

class GameboyJumpTests : GameboyInstructionSetTests {
	func test_jp_nn()		{ assert("jp 0x1234",			[0xc3, 0x34, 0x12]) }
	func test_jp_nz_nn()	{ assert("jp nz, 0x1234",		[0xc2, 0x34, 0x12]) }
	func test_jp_z_nn()		{ assert("jp z, 0x1234",		[0xca, 0x34, 0x12]) }
	func test_jp_nc_nn()	{ assert("jp nc, 0x1234",		[0xd2, 0x34, 0x12]) }
	func test_jp_c_nn()		{ assert("jp c, 0x1234",		[0xda, 0x34, 0x12]) }
	func test_jp_hl()		{ assert("jp hl",				[0xe9]) }
	
	func test_call_nn()		{ assert("call 0x1234",			[0xcd, 0x34, 0x12]) }
	func test_call_nz_nn()	{ assert("call nz, 0x1234",		[0xc4, 0x34, 0x12]) }
	func test_call_z_nn()	{ assert("call z, 0x1234",		[0xcc, 0x34, 0x12]) }
	func test_call_nc_nn()	{ assert("call nc, 0x1234",		[0xd4, 0x34, 0x12]) }
	func test_call_c_nn()	{ assert("call c, 0x1234",		[0xdc, 0x34, 0x12]) }
	
	func test_rst_00()		{ assert("rst 0x00",			[0xc7]) }
	func test_rst_08()		{ assert("rst 0x08",			[0xcf]) }
	func test_rst_10()		{ assert("rst 0x10",			[0xd7]) }
	func test_rst_18()		{ assert("rst 0x18",			[0xdf]) }
	func test_rst_20()		{ assert("rst 0x20",			[0xe7]) }
	func test_rst_28()		{ assert("rst 0x28",			[0xef]) }
	func test_rst_30()		{ assert("rst 0x30",			[0xf7]) }
	func test_rst_38()		{ assert("rst 0x38",			[0xff]) }
	
	func test_ret()			{ assert("ret",					[0xc9]) }
	func test_ret_nz()		{ assert("ret nz",				[0xc0]) }
	func test_ret_z()		{ assert("ret z",				[0xc8]) }
	func test_ret_nc()		{ assert("ret nc",				[0xd0]) }
	func test_ret_c()		{ assert("ret c",				[0xd8]) }
	func test_reti()		{ assert("reti",				[0xd9]) }
	
	func test_jr_n()		{ assert("jr 5",				[0x18, 0x05]) }
	func test_jr_n_neg()	{ assert("jr -5",				[0x18, 0xfb]) }
	func test_jr_z_n_neg()	{ assert("jr z, -5",			[0x28, 0xfb]) }
	func test_jr_nz_n_neg()	{ assert("jr nz, -5",			[0x20, 0xfb]) }
	func test_jr_c_n_neg()	{ assert("jr c, -5",			[0x38, 0xfb]) }
	func test_jr_nc_n_neg()	{ assert("jr nc, -5",			[0x30, 0xfb]) }
}

class GameboyExpressionOpcodeTests : GameboyInstructionSetTests {
	func test_label_ref()	{
		assert("ld hl, label", [.byte(0x21), .expression(.constant("label"), .uint16)])
	}
	
	func test_label_ref_relative()	{
		assert("jr label", [.byte(0x18), .expression(.constant("label"), .int8relative)])
	}
	
	func test_expression_16()	{
		let result = Expression.binaryExpr(.constant("label"), "+", .value(1))
		assert("ld hl, label + 1", [.byte(0x21), .expression(result, .uint16)])
	}
	
	func test_expression_8() {
		let result = Expression.binaryExpr(.constant("label1"), "-", .constant("label2"))
		assert("ld a, label1 - label2", [.byte(0x3e), .expression(result, .uint8)])
	}
}
