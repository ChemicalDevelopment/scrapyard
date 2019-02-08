;;;; SCRAPYARD code
; by Cade Brown
; NES game


;; header
.segment "HEADER"

INES_MAPPER = 0 ; 0 = NROM
INES_MIRROR = 1 ; 0 = horizontal mirroring, 1 = vertical mirroring
INES_SRAM   = 0 ; 1 = battery backed SRAM at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID
.byte $02 ; 16k PRG chunk count
.byte $01 ; 8k CHR chunk count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0 ; padding

;;;; more variables

PPUCTRL = $2000
PPUMASK = $2001
PPUSTATUS = $2002
PPUSCROLL = $2005
PPUADDR = $2006
PPUDATA = $2007

CONTROLLER_1 = $4016
CONTROLLER_2 = $4017

PLAYER_SPRITE = oam+0

NPC_SPRITESTART = PLAYER_SPRITE + 4*4

OFFSET_Y = $00
OFFSET_TILE = $01
OFFSET_ATTR = $02
OFFSET_X = $03

;;;; macros

.macro SET_CSPRITE addr

    LDA #>(addr)
    STA ptr_csprite_hi
    LDA #<(addr)
    STA ptr_csprite_lo

.endmacro

; load sprite Y into A
.macro L_SPR_Y
    LDY #OFFSET_Y
    LDA (ptr_csprite_lo), Y
.endmacro

; load sprite tile into A
.macro L_SPR_TILE
    LDY #OFFSET_TILE
    LDA (ptr_csprite_lo), Y
.endmacro

; load sprite attr into A
.macro L_SPR_ATTR
    LDY #OFFSET_ATTR
    LDA (ptr_csprite_lo), Y
.endmacro

; load sprite Y into A
.macro L_SPR_X
    LDY #OFFSET_X
    LDA (ptr_csprite_lo), Y
.endmacro



; store A into sprite Y
.macro S_SPR_Y
    LDY #OFFSET_Y
    STA (ptr_csprite_lo), Y
.endmacro

; store A into sprite tile
.macro S_SPR_TILE
    LDY #OFFSET_TILE
    STA (ptr_csprite_lo), Y
.endmacro

; store A into sprite attr
.macro S_SPR_ATTR
    LDY #OFFSET_ATTR
    STA (ptr_csprite_lo), Y
.endmacro

; store A into sprite X
.macro S_SPR_X
    LDY #OFFSET_X
    STA (ptr_csprite_lo), Y
.endmacro


;; special addresses to start running code on
; interrupts
.segment "VECTORS"
.word NMI
.word RESET
.word IRQ

;; CHR (graphics) data
.segment "TILES"
.incbin "art/scrapyard_SPRITE.chr"
.incbin "art/scrapyard_BACKGROUND.chr"


;; 0x0000 address space
; this is where most variables should go
.segment "ZEROPAGE"

; input handling
input: .res 1
raw_input: .res 1
last_input: .res 1

; what background are we in
background_idx: .res 1

debug: .res 1
; total frames
total_frames: .res 1

; player information
player_health: .res 1 ; health from 0-100
player_stun: .res 1 ; frames left on stun effect
;player_meta: .res 1 ; bit-packed meta:
;; bits: ______DD
; DD=orientation, 0=N,1=E,2=S,3=W

; game global 'dirty' flag
game_flag: .res 1
;; bits: ABCDEFGH
; G=player hit obstacle
; H=player hit edge of screen

; a packed byte showing where on the 16x12 metatile grid the current sprite is
; YYYYXXXX
csprite_metatile: .res 1

; csprite pointer, for calling functions to operate on arbitrary sprites
ptr_csprite_lo: .res 1 ; <- this is the offset into the sprite oam array
ptr_csprite_hi: .res 1 ; <- this should always be #>(oam)

; pointer variable for holding 16 bit ram address
ptr_lo: .res 1
ptr_hi: .res 1

; pointer variable for holding address in ROM for current level (screen layout)
ptr_level_lo: .res 1
ptr_level_hi: .res 1

; random state machine for generating bytes
rand_state: .res 1

tmp1: .res 1
tmp2: .res 1

; bcd numbers, 100s holds the hundreds digit
bcd_100s: .res 1
; backed, leftmost 4 bits are 10s digit, and rightmost 4 bits are the 1s digit
bcd_10s1s: .res 1

NPC1_state: .res 1


;; this is the area sent to the PPU containing the sprites
; each sprite takes up 4 bytes:
; Y pos, sprite index, attributes, X pos
.segment "OAM"
oam: .res 256


;; all the source code
.segment "CODE"

;; utility functions
.include "mathutil.asm"
.include "spriteutil.asm"
.include "backgroundutil.asm"

;; RESET button or power on state
RESET:
    SEI        ; disable IRQs
    CLD        ; disable decimal mode
    LDX #$40
    STX $4017  ; disable APU frame IRQ
    LDX #$FF
    TXS        ; Set up stack
    INX        ; now X = 0
    STX PPUCTRL  ; disable NMI
    STX PPUMASK  ; disable rendering
    STX $4010  ; disable DMC IRQs

    ; wait for a vblank
    JSR vblankwait

;; Clear all the main memory
@Clrmem:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0200, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0300, x
	INX
	BNE @Clrmem


@SetupPPU:

    JSR PPUOff
    JSR vblankwait

    ; write the address 3F00 (palette)
    LDA $2002
    LDA #$3F
    STA PPUADDR
    LDA #$00
    STA PPUADDR

    ; now write data
    LDX #$00
    @LoadPalettesLoop:
        LDA palette, x
        STA PPUDATA ; send to PPU
        INX
        CPX #$20 ; the data is 4 sprite palettes and 4 background palettes, so 2*4*4=32=$20 bytes
                
        BNE @LoadPalettesLoop

@InitState:

    ; start player off

    LDA #$00
    STA background_idx

    JSR SetBackground
    JSR SetHUD

    
    LDA #100
    STA player_health

    ; set up player
    SET_CSPRITE PLAYER_SPRITE

    LDA #$80
    S_SPR_Y

    LDA #$80
    S_SPR_X

    LDA #$20
    LDY #($01)
    STA (ptr_csprite_lo), Y
    LDA #$21
    LDY #($01+4)
    STA (ptr_csprite_lo), Y
    LDA #$22
    LDY #($01+4*2)
    STA (ptr_csprite_lo), Y
    LDA #$23
    LDY #($01+4*3)
    STA (ptr_csprite_lo), Y

    ; set NPC

    SET_CSPRITE NPC_SPRITESTART

    LDA #$60
    S_SPR_Y

    LDA #$60
    S_SPR_X

    LDA #$04
    LDY #($01)
    STA (ptr_csprite_lo), Y
    LDA #$05
    LDY #($01+4)
    STA (ptr_csprite_lo), Y
    LDA #$06
    LDY #($01+4*2)
    STA (ptr_csprite_lo), Y
    LDA #$07
    LDY #($01+4*3)
    STA (ptr_csprite_lo), Y


    JSR PPUOn


; start main loop
@Forever:

    LDA #<(oam)
    STA $2003
    LDA #>(oam)
    STA $4014
    
; update non-player-characters
@MoveNPCs:
    SET_CSPRITE NPC_SPRITESTART
    JSR UpdateCspriteMetatile
    
    JSR RandomNumber
    AND #%00000001
    CMP #%00000000
    BNE @NoStateChange

    LDA NPC1_state
    BEQ @P1
    LDA #$00
    STA NPC1_state
    JMP @NoStateChange
    @P1:
        LDA #$01
        STA NPC1_state

    @NoStateChange:
        LDA NPC1_state

        BEQ @NoNPCMovement

        JSR MoveSprite

        @NoNPCMovement:

            JSR UpdateSprite3Extra

; deal with player
@MovePlayer:
    ; read controller #1
    JSR ReadInput

    LDA #$00
    STA game_flag

    ;; load current sprite to be player
    SET_CSPRITE PLAYER_SPRITE
    JSR UpdateCspriteMetatile

    JSR SetPlayerOrient

    LDA input
    AND #$0F
    BEQ @MovePlayerDone

    JSR MoveSprite

@MovePlayerDone:

    LDA game_flag
    AND #%00000001
    BEQ @AfterBgUpdate

@BgUpdate:
    ; otherwise, go off screen

    JSR PPUOff

    JSR MoveBackground

    JSR vblankwait
    JSR PPUOn

    JMP @AfterBgUpdate

@AfterBgUpdate:

    JSR UpdateSprite3Extra

@FinalizeFrame:
    
    ; write player health
    INC player_health
    LDA player_health

    JSR CalcBCD
    LDA #$63 ; offset into the HUD
    JSR WriteBCDToHUD


    ; another frame ended
    INC total_frames
    JSR vblankwait

    JMP @Forever


NMI:
; called every frame
; TODO: music here
    RTI

IRQ:

    RTI


.segment "BSS"
nmt_update: .res 256 ; nametable update entry buffer for PPU update


.segment "RODATA"

.include "levels.asm"

palette:
  ;; background palettes
  .byte $0F,$1C,$2B,$39,  $0F,$07,$26,$34,  $0F,$09,$28,$36,  $0F,$07,$26,$34

  ;; sprite palettes
  .byte $0F,$15,$35,$15, $0F,$1B,$2A,$38, $0F,$1B,$2A,$38, $0F,$1B,$2A,$38



