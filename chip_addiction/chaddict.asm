; 					Chip Addiction
; 					/Mic, 2005
;
;  	    http://jiggawatt.org/badc0de  |  micol972@gmail.com


; Assemble with NESASM 2.51



 .inesprg    2			; Two 16k PRG-ROM banks
 .ineschr    1			; One 8k CHR-ROM bank
 .inesmir    1			; Vertical mirroring
 .inesmap    0			; Mapper 0 (none)


STRPTRL = $10
STRPTRH = $11
fubar = $12


; Variables. Just picked a random RAM address not used by the MCK driver.
 .org $0300
 	flipflop: 	.db 0	; Used to slow down scrolling a bit
 	msg_nt: 	.db 0	; Nametable where the scrolling message is shown (0=$2000, 1=$2400)
 	msg_hi: 	.db 0	; High byte of the position in the message string (which can be >255)
 	msg_pos: 	.db 0	; Low byte -- " --
 	counter:	.db 0	; Used as a counter when both X & Y are needed for other things
 	hscroll: 	.db 0	; Horizontal scroll value
 	adrlo:		.db 0
 	adrhi:		.db 0
 	permit_read:	.db 0
 	flake_counter:	.db 0,0,0,0
 	
 	fade_ctr:	.db 0
 	fade_val:	.db 0
 	fade_dir:	.db 0
 	
 	twirl_pos:	.db 0
 	twirl_pos2:	.db 0
 	
 	scL:		.db 0
 	scH:		.db 0
 	scL2:		.db 0
 	scH2:		.db 0
 	
 	scrollX:	.db 255
 	scrollXH:	.db 0
  	
  	curr_str:	.db 0
 	counter2:	.db 0
 	counter3:	.db 0
 	
 	

 .bank 0
 .org  $8000
 
	; Sound data
	.include	"sounddrv-2.h"
	.include	"songdata.h"
	.include	"freqdata.h"
	.include	"effect.h"


	
 .bank 2
 .org $D000			


reset:
	cld
	sei
	ldx #$00
	stx $2000	; No NMI
	stx $2001	; Disable screen
	inx
waitvb:	
	lda $2002
	bpl waitvb	; Wait a few frames
	dex
	bpl waitvb
	txs		; Set up stack pointer

	jsr sound_init

	jsr setup

	jsr copy_gfx

	jsr enable_screen

	lda #255
	sta scrollX
	lda #0
	sta scrollXH
	sta curr_str
	
	lda #(szMessage%256)
	sta STRPTRL
	lda #(szMessage/256)
	sta STRPTRH
	
	
	forever:
		lda #1
		spinlock:
			bit permit_read
			beq spinlock
		lda #0
		sta permit_read
		
		wait_vb_over:
			lda $2002
	   		bmi wait_vb_over   
   
		wait_sprite0_clear:
			bit $2002
			bvs wait_sprite0_clear

		ldx twirl_pos
		lda flipflop
		eor #1
		sta flipflop
		bne noinc
		inx
		noinc:
		txa
		and #$3F
		sta twirl_pos
		sta twirl_pos2

		ldy #64

		wait_sprite0_hit:
			bit $2002
			bvc wait_sprite0_hit

		
		; This code distorts the logo
		; Timed to be 106+5/9 cycles per iteration
		;
		scroll_lines:
			ldx twirl_pos2		;4
			inx			;2
			txa			;2
			and #$3F		;2
			sta twirl_pos2		;4
			tax			;2
			lda sin_64_12,x		;4
			clc			;2
			adc #9			;2
			tax			;2 (26)

			;tya			;2
			;and #1			;2
			;ora #$1A		;2
			;tax			;2
			
			;ldx #$1B		;2
			stx $2005		;4
			lda #0			;2
			sta $2005		;4 (10)

			ldx #10			;2
			delay2:	dex 		;2
				bne delay2	;3

			txa
			;nop
			lda fubar
			adc #113
			bcc mongo
			mongo:
			sta fubar
			
			dey			;2
			bne scroll_lines	;3
		
		lda #0
		sta $2005
		sta $2005
		
		jmp forever


copy_palette:
	; Setup palette
        lda #$3F       
        sta $2006      
        lda #$00        
        sta $2006 
	ldx #$00
	ldy #$20
	set_palette:
		lda palette,X        
	        sta $2007
		inx
		dey
		bne set_palette
	
	rts
	

setup:
	lda #$0
	
	; Reset scrolling registers
	sta $2005
	sta $2005
	
	tax
	clear_ram:
	        sta $0300,X
	        sta $0400,X
	        inx
	        bne clear_ram


	
	; Clear nametable 0
	lda #$20
	sta $2006
	lda #$00
	sta $2006
	ldy #$1E			; Clear 30 rows (= 240 pixels)
	lda #$8E			; Use tile 142 (which is all black)
	clear_nt0:
		ldx #$20		; 32 tiles per row
		clear_row:
			sta $2007	; Write to VRAM, address is auto-incremented
			dex
			bne clear_row
		dey
		bne clear_nt0

	; Clear nametable 1
	lda #$24
	sta $2006
	lda #$00
	sta $2006
	ldy #$1E			; Clear 30 rows (= 240 pixels)
	lda #$8E			; Use tile 142 (which is all black)
	clear_nt1:
		ldx #$20		; 32 tiles per row
		clear_row2:
			sta $2007	; Write to VRAM, address is auto-incremented
			dex
			bne clear_row2
		dey
		bne clear_nt1


	; Clear attributetable 0
	lda #$23
	sta $2006
	lda #$C0
	sta $2006
	lda #$55
	ldx #$40
	clear_at0:
		sta $2007	; Write to VRAM, address is auto-incremented
		dex
		bne clear_at0

	; Clear attributetable 1
	lda #$27
	sta $2006
	lda #$C0
	sta $2006
	lda #$00
	ldx #$40
	clear_at1:
		sta $2007	; Write to VRAM, address is auto-incremented
		dex
		bne clear_at1

	
	jsr copy_palette
	
	lda #16
	sta fade_ctr
	lda #1
	sta fade_val
	lda #0
	sta fade_dir
	
	rts



copy_gfx:
	; Setup nametable 0
	lda #$20
	sta $2006
	lda #$00
	sta $2006
	
	
	; ..start copying from ROM..
	ldy #$00
	ldx #$00
	copy_nt_1:
		lda nametable_1,X
		sta $2007
		inx
		dey
		bne copy_nt_1
	

	lda #$8E
	ldx #64
	copy_loop:
		sta $2007
		dex
		bne copy_loop
	lda #152
	ldx #32
	copy_loop2:
		sta $2007
		dex
		bne copy_loop2
	lda #149
	ldx #32
	copy_loop3:
		sta $2007
		dex
		bne copy_loop3
		
	ldy #5
	lda #143

	set_nt_outer:
		ldx #32
		set_nt_1:
			sta $2007
			dex
			bne set_nt_1
		tax
		inx
		txa
		dey
		bne set_nt_outer
	lda #148
	ldy #13
	set_nt_outer_2:
		ldx #32
		set_nt_2:
			sta $2007
			dex
			bne set_nt_2
		dey
		bne set_nt_outer_2
	

	; Setup attributetable 0
	lda #$23
	sta $2006
	lda #$C0
	sta $2006
	ldx #$00
	ldy #$10
	copy_at:
		lda attrtable_1,X
		sta $2007	
		inx
		dey
		bne copy_at

	lda #$50
	ldx #8
	set_at:
		sta $2007
		dex
		bne set_at
		

	; Setup sprites
	ldx #0
	ldy #4
	copy_spr:
		lda sprite_data,x
		sta $400,x
		inx
		dey
		bne copy_spr
		

	; Reset VRAM pointer
	lda #$00
	sta $2006
	lda #$00
	sta $2006		

	rts
	
	
	
enable_screen:
	w_vbi_e:
		lda $2002
	        bpl w_vbi_e

	; Enable BG & sprites, don't clip BG
	lda #$1A
	sta $2001  

	; Enable NMI, select upper VROM bank for both BG & sprite patterns
	lda #$88
	sta $2000


	rts
	

scroller:
	ldx #0
	stx counter
	lda scrollX
	sta scL
	lda scrollXH
	sta scH
	
	scr_loop:
		ldy counter
		lda [STRPTRL],y 
		cmp #0
		beq scr_done
		sec
		sbc #29
		sta $405,x
		
		lda scH
		cmp #0
		beq x_ok
		lda #0
		sta $407,x
		lda #8
		sta $404,x
		jmp not_visible
		x_ok:
		
		; Get Y		
		lda scL
		sta $407,x
		
		tay
		lda sin256,y
		sta $404,x

		lda #0
		sta $406,x

		not_visible:
		
		lda scL
		clc
		adc #9
		sta scL
		bcc no_carry_1
		inc scH
		no_carry_1:
		
		inc counter
		
		; Point to next sprite table entry		
		txa
		clc
		adc #4
		tax

		jmp scr_loop
		
	scr_done:
	


	lda scrollX
	sec
	sbc #1
	sta scrollX
	bcs no_carry2
	dec scrollXH
	no_carry2:
	
	lda scrollXH
	cmp #$FF
	bne no_str_change
	

	ldx curr_str
	lda strstop,x
	cmp scrollX
	bne no_str_change

	inx
	cpx #13
	bne not_maxxed
	ldx #0
	not_maxxed:
	stx curr_str
	txa
	asl a
	tax

	lda strtable,x
	sta STRPTRL
	inx
	lda strtable,x
	sta STRPTRH
	
	ldx #255
	stx scrollX
	inx
	stx scrollXH
	
	no_str_change:		
	rts
	


; NMI handler
nmi:
	; Save registers
	pha
	txa
	pha
	tya
	pha

	lda	#$0
	sta	$2003

	; DMA sprites
	lda	#$04
	sta	$4014
	
	; Call sound driver
	jsr sound_driver_start	
	
	; Fade logo color
	dec fade_ctr
	bne no_fade_update
		lda #16
		sta fade_ctr
		lda fade_val
		tay
		tax
		iny
		cpy #6
		bne fade_val_ok
			ldy #0
		fade_val_ok:
		sty fade_val
		lda fade_table,x
        	ldx #$3F       
        	stx $2006      
        	ldx #$01        
        	stx $2006
        	sta $2007
	no_fade_update:

	jsr copy_palette
	
	jsr scroller
	
	; y i a x
	lda #105
	sta $480
	lda #135
	sta $484
	lda #1
	sta $481
	sta $485
	lda #1
	sta $482
	sta $486
	lda #50
	sta $483
	lda #80
	sta $487
	
	; Reset VRAM address
      	ldx #$20       
       	stx $2006      
       	ldx #$00        
       	stx $2006
  
	lda #1
	sta permit_read

	lda #$88
	sta $2000
	
	; Restore registers	
	pla
	tay
	pla
	tax
	pla
	

irq:
	rti
	

; DATA

; Character mappings for the serif8 font
character_set:
	.incbin "serif8.set"

; 256 bytes
nametable_1:
	.incbin "chaddict2.nam"

; Attribute table data. 16 bytes (256*64 pixels = 8*2 attributes)
attrtable_1:
	.incbin "chaddict2.atr"

sprite_data:
	; Sprite 0
	.db 1,0,32,248
	.db 11,10,32,2
	.db 31,29,0,4
	

palette:
	.db 2,36,2,32		; 
	.db 2,14,32,38		; 
	.db 2,3,32,10		; 
	.db 2,3,32,9		; 

	.db 2,49,33,32		; 
	.db 2,19,35,48		; 
	.db 2,37,38,39		; 
	.db 2,53,54,55		; 

fade_table:
	.db 4,20,36,52,36,20


sin_64_12:
	.db 1,1,2,2,3,3,4,4,5,5,6,6,5,5,5,6
	.db 6,6,6,5,5,4,4,5,5,6,6,5,5,4,4,3
	.db 3,2,2,1,1,2,2,3,3,3,2,2,1,1,1,2
	.db 2,2,3,3,3,3,2,2,2,1,1,1,1,2,2,2

	
sin256:
	.db 196,196,197,198,198,199,200,200,201,202,202,203,204,204,205,206
	.db 206,207,207,208,209,209,210,210,211,212,212,213,213,214,214,215
	.db 215,216,216,217,217,218,218,218,219,219,220,220,220,221,221,221
	.db 221,222,222,222,222,222,223,223,223,223,223,223,223,223,223,223
	.db 223,223,223,223,223,223,223,223,223,223,223,222,222,222,222,222
	.db 221,221,221,221,220,220,220,219,219,218,218,218,217,217,216,216
	.db 215,215,214,214,213,213,212,212,211,210,210,209,209,208,207,207
	.db 206,206,205,204,204,203,202,202,201,200,200,199,198,198,197,196
	.db 196,195,194,193,193,192,191,191,190,189,189,188,187,187,186,185
	.db 185,184,184,183,182,182,181,181,180,179,179,178,178,177,177,176
	.db 176,175,175,174,174,173,173,173,172,172,171,171,171,170,170,170
	.db 170,169,169,169,169,169,168,168,168,168,168,168,168,168,168,168
	.db 168,168,168,168,168,168,168,168,168,168,168,169,169,169,169,169
	.db 170,170,170,170,171,171,171,172,172,173,173,173,174,174,175,175
	.db 176,176,177,177,178,178,179,179,180,181,181,182,182,183,184,184
	.db 185,185,186,187,187,188,189,189,190,191,191,192,193,193,194,195

szMessage: 
	.db "mic presents:   "
	.db 0
szMessage2:
	.db "2005       "
	.db 0
szMessage3:
	.db "'Chip Addiction'"
	.db 0
szMessage4:
	.db "Exclusive PAL release :P"
	.db 0
szMessage5:
	.db "40kB of NES juice"
	.db 0
szMessage6:
	.db "It's ok. It's demo for goat"
	.db 0
szMessage7:
	.db "..NES love that goat"
	.db 0
szMessage8:
	.db "Original groove by Mad Max"

	.db 0
szMessage9:
	.db "aesthetically abused in mml"

	.db 0
szMessage10:
	.db 34,"3D",34," is done with log LUTs"
	.db 0
szMessage11:
	.db "8-bit s00per precision ;)"
	.db 0
szMessage12:
	.db "Pretty slick, eh?"
	.db 0
szMessage13:
	.db "<WRAP>"
	.db 0
	
strtable:
	.dw szMessage
	.dw szMessage2
	.dw szMessage3
	.dw szMessage4
	.dw szMessage5
	.dw szMessage6
	.dw szMessage7
	.dw szMessage8
	.dw szMessage9
	.dw szMessage10
	.dw szMessage11
	.dw szMessage12
	.dw szMessage13

strstop:
	.db 126,166,100,36,85,5,36,16,4,16,34,80,160
	

; Setup interrupt vectors
 .bank 3
 .org  $fffa
	.dw   nmi
	.dw   reset
	.dw   irq



; CHR-ROM
 .bank 4
 .org $0000

	; Background image. 142 tiles
	.incbin "chaddict2.pat"
 
 
 	; Tile consisting only of color 3 (which is black in all BG palettes)
 	black_tile:
 		.db $0,$0,$0,$0
 		.db $0,$0,$0,$0
 		.db $ff,$ff,$ff,$ff
 		.db $ff,$ff,$ff,$ff
 

 	; 12 tiles
 	.incbin "gradient8.pat"
 

 .org $1000
 	sprite0_pat:
  		.db $ff,$ff,$ff,$ff
  		.db $ff,$ff,$ff,$ff
  		.db $ff,$ff,$ff,$ff
 		.db $ff,$ff,$ff,$ff

	.incbin "ball.pat"
 		
	; Monochrome font (72)
 	.incbin "adore64.pat"
	

	
  	
 	
 	
	
    