LETLN		EQU		0006H

FTYPE		EQU		10F0H	; FILE TYPE
FNAME		EQU		10F1H	; FILE NAME

;
; QD File Header
;
QD_FSIZE	EQU		1104H
QD_LOAD_FROM	EQU		1106H
QD_EXEC		EQU		1108H
;
; Tape File Header
;
TAPE_FSIZE	EQU		1102H
TAPE_LOAD_FROM	EQU		1104H
TAPE_EXEC	EQU		1106H

;
; BANK
;
MRAM_ON		EQU		0E0H


;
; 9Z-502M Entry Point
;
ENT_COLD	EQU		0E801H		; Cold start
ENT_COMMAND	EQU		0E804H		; Command input
ENT_PSG_MUTE	EQU		0E007H		; Mute PSG
ENT_PAL_INIT	EQU		0E80AH		; Palette init
ENT_QD_IO	EQU		0E80DH		; QD I/O

QD_WORK_INIT	EQU		0EF7AH
QD_RD_FILE_INFO	EQU		0EF85H		; Read file information of QD

CONFIRM_OK	EQU		0F15AH		; OK(Y/N)

QD_PREPARE_RD	EQU		0EFB5H		; EFB5: リード準備 (CMD=1, PARAM=00 実行)
QD_PREPARE_WR	EQU		0F079H		; F079: ライト準備 (CMD=1, PARAM=FF 実行)

QD_ENTER_NAME	EQU		0ED16H		; OUT: 11A3-, END=0DH
QD_FIND_FILE	EQU		0F318H		; 11A3-をファイル名だとして検索。空なら最初のファイルを検索(CMD-05実行)
QD_WRITE_FILE	EQU		0F037H		; QDにファイルを書き込む

QD_ERR_COMMON	EQU		0F2BBH		; QD I/O Common error process

ES_CMD_W_SRAM	EQU		0F7E0H		; ES Command: After tape load success


ES_CMD_MAIN	EQU		0F7BEH		; ES Command Main: Save SRAM from CMT
MSG_LOADING	EQU		0EEFBH		; "Loading "
MSG_RAM_PROG	EQU		0F863H		; "Ramboard programming"
MSG_MR_QD	EQU		0EDF7H		; "Make ready QD"

;==========================================================================
; "E"コマンド解析部
	ORG	0EB34H
	JP	PATCH_1			; EB34: C390F8
;==========================================================================
;
;パッチエリア
;   F890-F9FF
;   FE40-FFEF


	ORG	0F890H
MSG_SRAM_CLR:	DB	"SRAM C", 05H, "LEAR", 05H, 0DH

PATCH_1:
	JP	Z,ES_CMD_MAIN		;EB34: CABEF7	"ʾ "	:  ES Command Main: Save SRAM from CMT
	CP	'Q'			;"EQ" コマンド = QDからSRAMに書き込み
	JP	Z,EQ_CMD_MAIN
	CP	'C'			;"EC" コマンド = SRAMクリア
	JP	NZ,ENT_COMMAND
;
; EC CMD
;  C=1R12 port addr
EC_CMD_MAIN:
	LD	(11FEH),BC		; SAVE Port Addr
	LD	DE,MSG_SRAM_CLR		; "SRAM Clear"
	RST	18H
	CALL	LETLN
	CALL	CONFIRM_OK		; "OK(Y/N)"
	LD	BC,(11FEH)		; Restore Port Addr
	IN	A,(C)			; RESET ADDR CONTER
	LD	B,9			; HEADER SIZE
	INC	C			; C=DATA WRITE PORT
	INC	C
EC_10:
	OUT	(C),B			; Header[9,8,7,6,5,4,3,2,1] = CSUM Error
	DJNZ	EC_10
	JP	ENT_COMMAND		; E804:Command input
;
; EQ CMD
;  C=1R12 port addr
EQ_CMD_MAIN:
	LD	(11FCH),BC		; SAVE Port Addr
	LD	DE,MSG_RAM_PROG		; "Ramboard programming"
	RST	18H
	CALL	LETLN
	CALL	QD_WORK_INIT
	CALL	QD_PREPARE_RD
EQ_ERR:
	JP	C,QD_ERR_COMMON		; QD I/O Common error process
	CALL	QD_ENTER_NAME
	CALL	QD_FIND_FILE
	LD	DE,MSG_LOADING
	RST	18H
EQ_CMD_10:
	CALL	QD_RD_FILE_INFO
	JR	C,EQ_ERR
	LD	A,(FTYPE)
	CP	001H			; OBJ ?
	JR	NZ,EQ_CMD_10		; Loop while no

	LD	DE,FNAME
	RST	18H
	LD	HL,(QD_LOAD_FROM)	; FROM == 0 ?
	LD	A,H
	OR	L
	JR	NZ,EQ_CMD_20		; No --> Normal OBJ
	LD	HL,(QD_EXEC)		; EXEC == 0 ?
	LD	A,H
	OR	L
EQ_CMD_20:
	JR	NZ,EQ_CMD_30
	LD	A,0FFH			; このプログラムは$1200にロード後、MRAMに切り替えて0000へ転送し実行
	LD	(113BH),A
	LD	HL,1200H		; $1200からロード
	JR	EQ_CMD_40
EQ_CMD_30:
	LD	HL,(QD_LOAD_FROM)	; FROM
EQ_CMD_40:
	LD	(1132H),HL
	LD	HL,(QD_FSIZE)
	LD	(1134H),HL
	LD	HL,0103H
	LD	(1130H),HL
	CALL	ENT_QD_IO
	JR	C,EQ_ERR
;
; テープからのロードのシミュレーション
;
	LD	HL,(QD_FSIZE)		; $1104
	LD	(TAPE_FSIZE),HL		; $1102
	LD	HL,(QD_LOAD_FROM)	; $1106
	LD	(TAPE_LOAD_FROM),HL	; $1104
	LD	HL,(QD_EXEC)		; $1108
	LD	(TAPE_EXEC),HL		; $1106

	LD	A,(113BH)
	CP	0FFH			; このプログラムは$1200にロード後、MRAMに切り替えて0000へ転送し実行?
	JR	NZ,EQ_CMD_50		; No

; 転送ルーチンをスタートアドレスとする
	LD	HL,(TAPE_FSIZE)		; 本体サイズ
	LD	(1200H-2),HL		; $1200の直前にサイズを置く
	LD	DE,1200H-2
	LD	(TAPE_LOAD_FROM),DE
	INC	HL
	INC	HL
	LD	(TAPE_FSIZE),HL		; サイズのデータ分だけ増やす
	LD	HL,EQ_XFER
	LD	(TAPE_EXEC),HL		; 転送ルーチンをスタートアドレスとする。

EQ_CMD_50:
	LD	BC,(11FCH)		; Restore Port Addr
	JP	ES_CMD_W_SRAM		; ES Command: After tape load success

; 以下、MRAMに切り替えて0000へ転送し実行するスタブ

EQ_XFER:
	OUT	(MRAM_ON),A		; MONITOR=RAM
	LD	HL,1200H
	LD	DE,0000H
	LD	BC,(1200H-2)
	LDIR
	LD	BC,0300H
	JP	0000H

;==========================================================================

	END
