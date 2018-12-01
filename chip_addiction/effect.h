dutyenve_table:
	dw	0
	dw	dutyenve_001
	dw	dutyenve_002
dutyenve_lp_table:
	dw	0
	dw	dutyenve_lp_001
	dw	dutyenve_lp_002

dutyenve_001:
	db	$07,$07,$07
dutyenve_lp_001:
	db	$0b,$0b,$0b,$0b,$07,$07,$07,$07
	db	$ff
dutyenve_002:
	db	$07
dutyenve_lp_002:
	db	$0b,$0b,$0b,$0b,$0b,$07,$07,$07
	db	$07,$07,$07,$07,$ff

softenve_table:
	dw	softenve_000
	dw	softenve_001
	dw	softenve_002
	dw	softenve_003
	dw	softenve_004
	dw	softenve_005
	dw	softenve_006
softenve_lp_table:
	dw	softenve_lp_000
	dw	softenve_lp_001
	dw	softenve_lp_002
	dw	softenve_lp_003
	dw	softenve_lp_004
	dw	softenve_lp_005
	dw	softenve_lp_006

softenve_000:
	db	$07,$08,$09,$0a,$0a,$08,$08,$08
	db	$07,$07
softenve_lp_000:
	db	$06,$ff
softenve_001:
	db	$05,$05,$05,$05,$06,$06,$07,$07
	db	$07,$07,$07,$06,$06,$06,$06,$05
	db	$05,$05,$04,$04,$04,$04,$02
softenve_lp_001:
	db	$00,$ff
softenve_002:
	db	$08,$09,$09,$09,$08,$05,$05,$04
	db	$02,$02,$02,$01,$01,$01,$01
softenve_lp_002:
	db	$04,$ff
softenve_003:
	db	$0d,$08,$05,$04,$06,$01,$02,$01
softenve_lp_003:
	db	$04,$ff
softenve_004:
	db	$0e,$07,$02
softenve_lp_004:
	db	$00,$ff
softenve_005:
	db	$0e,$0e,$0e,$0c,$0c,$09,$09,$07
	db	$05,$04,$03,$02,$01,$01
softenve_lp_005:
	db	$00,$ff
softenve_006:
	db	$0c,$0c,$08,$08,$08,$04,$04,$00
softenve_lp_006:
	db	$02,$ff

pitchenve_table:
pitchenve_lp_table:


arpeggio_table:
arpeggio_lp_table:


lfo_data:
fds_data_table:
fds_effect_select:
fds_4088_data:


n106_channel:
	db	1
n106_wave_init:
n106_wave_table:


dpcm_data:


