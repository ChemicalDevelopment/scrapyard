; SCRAPYARD code by Cade Brown

;;;; Header

  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Constants, things that are basically used like a macro for magic numbers

; where the sprites are stored in RAM
SPRITE_RAM = $0200

; where the x, y coordinates are stored in PPU mem
PLAYER_SPRITE_Y = SPRITE_RAM
PLAYER_SPRITE_X = SPRITE_RAM+$03

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Global variables in zero-page memory
  .rsset $0000

;; binary coded decimal converters, for storing the place values for converted things
; to get the hundreds place, use bcd_100s
; to get tens place use bcd_10s1s & 0xF0
; to get ones place use bcd_10s1s & 0x0F
bcd_bin .rs 1
bcd_100s .rs 1
bcd_10s1s .rs 1

; just a debug area
debug .rs 1

;; `input` byte, storing the current frame's: B, A, SELECT, START, UP, DOWN, LEFT, RIGHT, in that order
input .rs 1
raw_input .rs 1
last_input .rs 1

;; player health from a scale of 0-100
player_health .rs 1

; how many frames the player is stunned for (always counting down)
player_stun .rs 1

;; player positional metadata:
;; bits: ______DD
;; DD = orientation, 0=N,1=E,2=S,3=W
player_meta .rs 1

;; frame flag that tells if something happened (i.e. hitting a wall, hitting edge of world, etc)
game_flag .rs 1
;; bits: ABCDEFGH
;; H tells whether or not the player has hit an edge of the screen
;; G tells whether tells whether the player has hit an obstacle

;; x, y coordinates for the current sprite. Top left is 0, 0 
csprite_x .rs 1
csprite_y .rs 1

; what metatile do we land on? (packed integer that is an index into the SCENE_METADATA array)
csprite_metatile_idx .rs 1

;; how many frames have elapsed? (NMI loops)
total_frames .rs 1

;; pointer variable for addressing 16 bit memory
; these can be overwritten by functions
ptr_lo .rs 1
ptr_hi .rs 1

;; pointer to the memory location of the current level background
; for this to take effect, call
ptr_level_lo .rs 1
ptr_level_hi .rs 1

; metatiles definition pointer
ptr_metatiles_defs_lo .rs 1
ptr_metatiles_defs_hi .rs 1

; metatiles attribute pointer
ptr_metatiles_attr_lo .rs 1
ptr_metatiles_attr_hi .rs 1


;; temporary memory for swapping
tmp .rs 1
tmp2 .rs 1

;; arguments for any function (that can be overwritten!)
arg1 .rs 1
arg2 .rs 1

; random state machine for generating bytes
rand_state .rs 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Subroutines, functions, and most code is stored here
  .bank 0
  .org $C000

;; wait for a vblank
vblankwait:
  BIT $2002
  BPL vblankwait
  RTS


SetHUD:


  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$00
  STA $2006             ; write the low byte of $2000 address\

  LDY #$00
  HeaderLoop:
    LDA default_hud, Y
    STA $2007
    INY
    CPY #$C0
    BNE HeaderLoop

  RTS

;; code to set the background to the correct stage
;; before calling this, set the ptr_level_lo and ptr_level_hi variables
UpdateBackground:

  ;LDA #%00000000
  ;STA $2000
  LDA #%00000000
  STA $2001

  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$C0
  STA $2006             ; write the low byte of $2000 address\

  ; store in the pointer used for this function
  LDA ptr_level_lo
  STA ptr_lo
  LDA ptr_level_hi
  STA ptr_hi

  LDX #$00 ; start at pointer + 0
  OutsideLoop:

    LDY #$00
    InsideLoop1:
      STX tmp

      ; transform it into a metatile offset
      LDA [ptr_lo], Y
      ASL A
      ASL A
      TAX

      ; set top left corner
      LDA metatiles_defs, x
      STA $2007

      ; set top right corner
      INX
      LDA metatiles_defs, x
      STA $2007 
      
      LDX tmp ; restore to outside counter

      INY
      CPY #$10 ; 16 = width of the metatile array 
      BNE InsideLoop1

    ; do it over again for the bottom left and bottom right of the next row of sprites
    ; (the lower half of the metatile row, though)
    LDY #$00
    InsideLoop2:
      STX tmp

      LDA [ptr_lo], Y
      ASL A
      ASL A
      TAX

      ;; set bottom left corner
      INX
      INX
      LDA metatiles_defs, x
      STA $2007

      ;; set bottom right corner
      INX
      LDA metatiles_defs, x
      STA $2007 
      
      LDX tmp ; restore to outside counter

      INY
      CPY #$10
      BNE InsideLoop2

    LDA #$EF
    CMP ptr_lo
    BCS UpdateLoPtr

    INC ptr_hi ; catch overflow and change high register address

    UpdateLoPtr:
    LDA ptr_lo
    CLC
    ADC #$10 ; change lower pointer to increment read address
    STA ptr_lo

    INX
    CPX #$0C ; C=12 rows
    BNE OutsideLoop
;;
    ; copy all 64 attribute bytes (which we assume are 0 rightnow)   
    LDY #$00
    LoadAttributesLoop:
      LDA generic_attributes, Y
      STA $2007

      INY
      CPY #$40 ; 64 bytes
      BNE LoadAttributesLoop

  ;LDA #%10010000
  ;STA $2000

  LDA #%00011110
  STA $2001

  ; reset scroll
  ;LDA #$00
  ;STA $2005
  ;STA $2005


  RTS


;; random number generation
; uses rand_state
RandomNumber:
  LDA rand_state
  STA tmp

  ROL tmp
  ROL tmp
  ROL tmp

  ROR A
  
  CLC
  ADC tmp

  STA rand_state
  INC rand_state

  RTS

;; binary coded decimal converter for the A register
; so call LDA first with your argument
; then get your rests in bcd_100s and bcd_10s1s
; based on shift and add 3 algo: https://pubweb.eng.utah.edu/~nmcdonal/Tutorials/BCDTutorial/BCDConversion.html
CalcBCD:
  STA bcd_bin

  LDA #$00
  STA bcd_100s
  STA bcd_10s1s

  LDX #$00

  BCDLoop:

    LDA bcd_100s
    CMP #$05
    BCC BCDHundredsGood
    LDA bcd_100s
    CLC
    ADC #$03
    STA bcd_100s

    BCDHundredsGood:

    LDA bcd_10s1s
    AND #$F0
    CMP #$50
    BCC BCDTensGood
    LDA bcd_10s1s
    CLC
    ADC #$30
    STA bcd_10s1s

    BCDTensGood:

    LDA bcd_10s1s
    AND #$0F
    CMP #$05
    BCC BCDOnesGood
    LDA bcd_10s1s
    CLC
    ADC #$03
    STA bcd_10s1s

    BCDOnesGood:

    CLC
    ROL bcd_bin
    ROL bcd_10s1s
    ROL bcd_100s

    INX
    CPX #$08
    BNE BCDLoop

  ; reset scroll
  LDA #$00
  STA $2005
  STA $2005

  RTS

; for writing the BCD to the screen in the GUI section
WriteBCDToScreen:

  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$63
  STA $2006             ; write the low byte of $2000 address\

  LDA bcd_100s
  CLC
  ADC #$80
  STA $2007
  
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$64
  STA $2006             ; write the low byte of $2000 address\

  LDA bcd_10s1s
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$80

  STA $2007

  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$20
  STA $2006             ; write the high byte of $2000 address
  LDA #$65
  STA $2006             ; write the low byte of $2000 address\

  LDA bcd_10s1s
  AND #$0F
  CLC
  ADC #$80
  STA $2007

  ; reset scroll
  LDA #$00
  STA $2005
  STA $2005

  RTS


;; this just calculates the csprite_metatile_idx
SetMetatileIdx:
  ; we update the metatile x and y
  LDA csprite_y
  ;CLC
  ;ADC #$01
  SEC 
  SBC #$30
  ; take just the high bits
  AND #$F0
  STA csprite_metatile_idx

  LDA csprite_x
  ;AND #$0F
  LSR A
  LSR A
  LSR A
  LSR A
  EOR csprite_metatile_idx
  STA csprite_metatile_idx
  
  EndSetMetatileIdx:
  RTS


SetOrientN:
  LDA #$20
  LDY #$01
  STA SPRITE_RAM, Y
  LDA #$21
  LDY #$05
  STA SPRITE_RAM, Y
  LDA #$22
  LDY #$09
  STA SPRITE_RAM, Y
  LDA #$23
  LDY #$0D
  STA SPRITE_RAM, Y

  ; set the tile meta
  LDA #%00000000
  LDY #$02
  STA SPRITE_RAM, Y
  LDY #$06
  STA SPRITE_RAM, Y
  LDY #$0A
  STA SPRITE_RAM, Y
  LDY #$0E
  STA SPRITE_RAM, Y
  RTS


SetOrientE:
  LDA #$40
  LDY #$01
  STA SPRITE_RAM, Y
  LDA #$41
  LDY #$05
  STA SPRITE_RAM, Y
  LDA #$42
  LDY #$09
  STA SPRITE_RAM, Y
  LDA #$43
  LDY #$0D
  STA SPRITE_RAM, Y

  ; set the tile meta
  LDA #%00000000
  LDY #$02
  STA SPRITE_RAM, Y
  LDY #$06
  STA SPRITE_RAM, Y
  LDY #$0A
  STA SPRITE_RAM, Y
  LDY #$0E
  STA SPRITE_RAM, Y
  RTS

SetOrientS:
  LDA #$23
  LDY #$01
  STA SPRITE_RAM, Y
  LDA #$22
  LDY #$05
  STA SPRITE_RAM, Y
  LDA #$21
  LDY #$09
  STA SPRITE_RAM, Y
  LDA #$20
  LDY #$0D
  STA SPRITE_RAM, Y

  RTS


SetOrientW:
  LDA #$43
  LDY #$01
  STA SPRITE_RAM, Y
  LDA #$42
  LDY #$05
  STA SPRITE_RAM, Y
  LDA #$41
  LDY #$09
  STA SPRITE_RAM, Y
  LDA #$40
  LDY #$0D
  STA SPRITE_RAM, Y

  RTS

;; basically to save code space there is a check move function here
;; takes 'arg1' register as argument to add to metatile idx 
;; and writes to the accumulator so you can use BNE
CheckMoveOffsetADD:
  LDA csprite_metatile_idx
  CLC
  ADC arg1
  TAY
  LDA [ptr_level_lo], y
  TAY
  LDA metatiles_attr, y
  RTS

CheckMoveOffsetSUB:
  LDA csprite_metatile_idx
  SEC
  SBC arg1
  TAY
  LDA [ptr_level_lo], y
  TAY
  LDA metatiles_attr, y
  RTS

;; this uses `csprite_y` as input and writes over it!
MoveN:
  ; trigger going up off the screen
  LDA csprite_y
  CMP #$30
  BCS MoveNFirstCheck

  LDA game_flag
  ORA #%00000001
  STA game_flag

  RTS

  MoveNFirstCheck:
  ; first check
  LDA #$00
  STA arg1
  JSR CheckMoveOffsetSUB
  BNE EndMoveN

  ; if it is zero aligned you need this trick
  LDA csprite_x
  AND #$0F
  BEQ RealMoveN

  ; first check
  LDA #$01
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveN

  RealMoveN:
  LDA csprite_y
  SEC
  SBC #%01
  STA csprite_y
  RTS

  
  EndMoveN:

  LDA game_flag
  ORA #%00000010
  STA game_flag

  RTS

;; this uses `csprite_x` as input and writes over it!
MoveE:

  ; trigger going right off the screen
  LDA csprite_x
  CMP #$E5
  BCC MoveEFirstCheck

  LDA game_flag
  ORA #%00000001
  STA game_flag

  RTS

  MoveEFirstCheck:
  ; first check
  LDA #$11
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveE

  ; if it is zero aligned you need this trick
  LDA csprite_y
  AND #$0F
  CMP #$0F
  BEQ RealMoveE

  ; first check
  LDA #$01
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveE

  RealMoveE:
  INC csprite_x
  RTS

  EndMoveE:

  LDA game_flag
  ORA #%00000010
  STA game_flag

  RTS

;; this uses `csprite_y` as input and writes over it!
MoveS:
  ; trigger going down off the screen
  LDA csprite_y
  CMP #$CF
  BCC MoveSFirstCheck

  LDA game_flag
  ORA #%00000001
  STA game_flag

  RTS

  MoveSFirstCheck:
  LDA csprite_y
  AND #$0F
  CMP #$0F
  BEQ MoveS_YD

  LDA csprite_x
  AND #$0F
  BEQ MoveS_X0


  LDA #$10
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveS

  LDA #$11
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveS
  JMP RealMoveS

  MoveS_X0:
    LDA csprite_metatile_idx
    CLC
    ADC #$10
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveS

    LDA #$10
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS
    JMP RealMoveS

  MoveS_YD:
    LDA csprite_x
    AND #$0F
    BEQ MoveS_X0_YD

    LDA csprite_metatile_idx
    CLC
    ADC #$21
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveS

    LDA #$20
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS
    JMP RealMoveS

  MoveS_X0_YD:
    LDA csprite_metatile_idx
    CLC
    ADC #$20
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveS

  RealMoveS:
  INC csprite_y
  RTS

  EndMoveS:
  LDA game_flag
  ORA #%00000010
  STA game_flag
  RTS

;; this uses `csprite_y` as input and writes over it!
MoveW:
  ; trigger going left off the screen
  LDA csprite_x
  CMP #$0C
  BCS MoveWFirstCheck

  LDA game_flag
  ORA #%00000001
  STA game_flag

  RTS

  MoveWFirstCheck:

  LDA csprite_y
  AND #$0F
  CMP #$0F
  BEQ MoveW_SpecialPxY ; 0 pixel special case

  LDA csprite_x
  AND #$0F
  BEQ MoveW_SpecialPxX ; side pixel special case

  LDA #$10
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveW

  LDA #$00
  STA arg1
  JSR CheckMoveOffsetADD
  BNE EndMoveW

  JMP RealMoveW

  MoveW_SpecialPxY:
    LDA csprite_x
    AND #$0F
    BEQ MoveW_SpecialPxXSpecialPxY ; side pixel special case

    LDA #$11
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveW

    ; custom check
    ;LDA csprite_metatile_idx
    ;SEC
    ;ADC #$10
    ;TAY
    ;LDA [ptr_level_lo], y
    ;BNE EndMoveW

    JMP RealMoveW

  MoveW_SpecialPxX:
    LDA csprite_metatile_idx
    CLC
    ADC #$10
    SEC
    SBC #$01
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveW

    LDA #$01
    STA arg1
    JSR CheckMoveOffsetSUB
    BNE EndMoveW

    JMP RealMoveW

  MoveW_SpecialPxXSpecialPxY:
    LDA csprite_metatile_idx
    CLC
    ADC #$10
    SEC
    SBC #$01
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveW

    LDA csprite_metatile_idx
    CLC
    ADC #$10
    TAY
    LDA [ptr_level_lo], y
    TAY
    LDA metatiles_attr, y
    BNE EndMoveW

    JMP RealMoveW

  RealMoveW:
    LDA csprite_x
    SEC
    SBC #%01
    STA csprite_x
    RTS

  EndMoveW:
    LDA game_flag
    ORA #%00000010
    STA game_flag
    RTS



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; This is the starting point for the code either on startup or when the 'RESET' button is hit
RESET:
  SEI        ; disable IRQs
  CLD        ; disable decimal mode
  LDX #$40
  STX $4017  ; disable APU frame IRQ
  LDX #$FF
  TXS        ; Set up stack
  INX        ; now X = 0
  STX $2000  ; disable NMI
  STX $2001  ; disable rendering
  STX $4010  ; disable DMC IRQs


; wait for a vblank
  JSR vblankwait

;; Clear all the main memory
clrmem:
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
  BNE clrmem

; wait a second time, and now the PPU should be ready for loading
  JSR vblankwait


;; prepare the PPU to load in all the graphics data
PreparePPU:
  LDA $2002 ; read the status, and this prepares the PPU to read HIGH, then LOW byte of a 16 bit address
  LDA #$3F
  STA $2006 ; write the high byte of $3F00 address (palette)
  LDA #$00
  STA $2006 ; write the low byte of $3F00 address (palette)


;; load in both palettes (sprite then background). They are in the memory sequentially
LoadPalettes:

  LDX #$00
  LoadPalettesLoop:
    LDA palette, x
    STA $2007 ; this address writes data to the PPU
    INX
    CPX #$20 ; the data is 4 sprite palettes and 4 background palettes, 
             ; each with 4 colors (1 byte per color), so 2 * 4 * 4 = 32 = $20 total bytes to copy
    BNE LoadPalettesLoop

InitializePointers:
  ; initialize pointers
  LDA #LOW(metatiles_defs)
  STA ptr_metatiles_defs_lo
  LDA #HIGH(metatiles_defs)
  STA ptr_metatiles_defs_hi

  LDA #LOW(metatiles_attr)
  STA ptr_metatiles_attr_lo
  LDA #HIGH(metatiles_attr)
  STA ptr_metatiles_attr_hi

; set the level to A1
  LDA #LOW(level_A1)
  STA ptr_level_lo
  LDA #HIGH(level_A1)
  STA ptr_level_hi

  JSR SetHUD

  JSR UpdateBackground




;; Initialize everything about the game state
InitializeState:
  ; enable NMI, sprites from Pattern 0, background from Pattern 1
  LDA #%10010000
  STA $2000

  ; enable sprites, enable background
  LDA #%00011110
  STA $2001

  ; now initialize player coordinates, defaulting to the middle of the screen
  LDA #$72
  STA PLAYER_SPRITE_Y

  LDA #$80
  STA PLAYER_SPRITE_X

  JSR SetOrientN


  LDA #100
  STA player_health


  ; all the rest of these set to 0
  LDA #$00

  STA player_meta
  STA player_stun

  STA csprite_metatile_idx

  STA input
  STA raw_input
  STA last_input
  STA total_frames


  LDA #00
  JSR CalcBCD
  JSR WriteBCDToScreen



;; now actually set up things


;; now wait for NMI to kick in
Forever:
  JMP Forever


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; NMI - this is the main loop that is called every frame. Input/graphics handled here
NMI:

;; copy sprites
  LDA #LOW(SPRITE_RAM)
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #HIGH(SPRITE_RAM)
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer


  LDA #$00
  STA game_flag

;; Here is where the controllers are read, and the input is stored in 'input'
ReadInput:
  ; this code basically "latches" down the controller inputs.
  ; without this, the inputs are garbled
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  LDX #$00
  STX raw_input
  
  ReadButtonLoop:
    ASL raw_input
    LDA $4016 ; read from the controller into A
    AND #%01
    ORA raw_input
    STA raw_input

    INX
    CPX #$08 ; loop and read 8 buttons
    BNE ReadButtonLoop

  ; make a copy that we can edit (reject opposite presses and convert diagnoal presses)
  LDA raw_input
  STA input

  ; if nothing has changed, just keep the same orientation (this is to help deal with temporarily holding another direction in)
  LDA last_input
  CMP raw_input
  BNE SanitizeInput

  ; if nothing has changed, jump ahead
  JMP TSOrientDone  

  SanitizeInput:
    LDA input
    AND #%00001111    ; If A & (A - 1) is nonzero, A has more than one bit set
    BEQ NoDiagnonals
    SEC
    SBC #%01
    AND input
    BEQ NoDiagnonals
        ; Use the new directions
        LDA #$FF
        SEC
        SBC last_input
        AND input
        STA input
    NoDiagnonals:
  ;; input is sanitized

  ;; try to set the orientation bits
  TSOrientN:
    LDA input
    AND #%1000
    BEQ TSOrientE
    LDA #$00
    STA player_meta
    ; set specific tiles
    JSR SetOrientN
  TSOrientE:
    LDA input
    AND #%0001
    BEQ TSOrientS
    LDA #$01
    STA player_meta
    ; set specific tiles
    JSR SetOrientE

  TSOrientS:
    LDA input
    AND #%0100
    BEQ TSOrientW
    LDA #$02
    STA player_meta

    ; set specific tiles
    JSR SetOrientS
    ; set the tile meta
    LDA #%11000000
    LDY #$02
    STA SPRITE_RAM, Y
    LDY #$06
    STA SPRITE_RAM, Y
    LDY #$0A
    STA SPRITE_RAM, Y
    LDY #$0E
    STA SPRITE_RAM, Y
  TSOrientW:
    LDA input
    AND #%0010
    BEQ TSOrientDone

    LDA #$03
    STA player_meta
    ; set specific tiles
    JSR SetOrientW

    ; set the tile meta
    LDA #%11000000
    LDY #$02
    STA SPRITE_RAM, Y
    LDY #$06
    STA SPRITE_RAM, Y
    LDY #$0A
    STA SPRITE_RAM, Y
    LDY #$0E
    STA SPRITE_RAM, Y


  TSOrientDone:
  ; done setting orientation

  ; save thsee for next time
  LDA raw_input
  STA last_input

;; adjust player x, player y
  
  LDA input
  AND #%00001111
  BEQ RenderPlayer
  ; else, we need to update positions

  ; we update the metatile x and y
  LDA PLAYER_SPRITE_Y
  STA csprite_y
  LDA PLAYER_SPRITE_X
  STA csprite_x

  JSR SetMetatileIdx
  LDA player_stun
  BNE EndUpdatePosition

  ; only move if not stunned
  UpdatePositionN:
    LDA player_meta
    AND #%11
    CMP #%00
    BNE UpdatePositionE
    ; we are facing north
    JSR MoveN
    JMP EndUpdatePosition
  UpdatePositionE:
    LDA player_meta
    AND #%11
    CMP #%01
    BNE UpdatePositionS
    ; we are facing east
    JSR MoveE
    JMP EndUpdatePosition
  UpdatePositionS:
    LDA player_meta
    AND #%11
    CMP #%10
    BNE UpdatePositionW
    ; we are facing east
    JSR MoveS
    JMP EndUpdatePosition
  UpdatePositionW:
    LDA player_meta
    AND #%11
    CMP #%11
    BNE EndUpdatePosition
    ; we are facing east
    JSR MoveW
  EndUpdatePosition:
  LDA csprite_x
  STA PLAYER_SPRITE_X
  LDA csprite_y
  STA PLAYER_SPRITE_Y
  

;; update the actual x and y of the sprites
RenderPlayer:
  LDA PLAYER_SPRITE_Y
  LDY #$00
  STA SPRITE_RAM, Y
  LDY #$04
  STA SPRITE_RAM, Y

  CLC
  ADC #$08

  LDY #$08
  STA SPRITE_RAM, Y
  LDY #$0C
  STA SPRITE_RAM, Y

  LDA PLAYER_SPRITE_X
  LDY #$03
  STA SPRITE_RAM, Y
  LDY #$0B
  STA SPRITE_RAM, Y

  CLC
  ADC #$08

  LDY #$07
  STA SPRITE_RAM, Y
  LDY #$0F
  STA SPRITE_RAM, Y


  LDA game_flag
  AND #%00000010
  BEQ CheckSetSection

  ; player has hit obstacle

  LDA player_health
  SEC
  SBC #$01
  STA player_health

  LDA PLAYER_SPRITE_X
  SEC
  SBC #$10
  STA PLAYER_SPRITE_X
  
  LDA player_stun
  CLC
  ADC #$10
  STA player_stun


CheckSetSection:
  LDA game_flag
  AND #%00000001
  BEQ FinalizeFrame

  ;; player wants to change areas
  JSR vblankwait

SetSectionN:
  LDA player_meta
  AND #%11
  CMP #%00
  BNE SetSectionE

  ; set the level to A2
  LDA #LOW(level_A2)
  STA ptr_level_lo
  LDA #HIGH(level_A2)
  STA ptr_level_hi

  LDA #$CE
  STA PLAYER_SPRITE_Y

SetSectionE:
  LDA player_meta
  AND #%11
  CMP #%01
  BNE SetSectionS

SetSectionS:
  LDA player_meta
  AND #%11
  CMP #%10
  BNE SetSectionW
  
  ; set the level to A1
  LDA #LOW(level_A1)
  STA ptr_level_lo
  LDA #HIGH(level_A1)
  STA ptr_level_hi

  LDA #$20
  STA PLAYER_SPRITE_Y

SetSectionW:
  LDA player_meta
  AND #%11
  CMP #%11
  BNE SetSectionEnd

SetSectionEnd:

  JSR UpdateBackground


;; Finalize counters, etc
FinalizeFrame:

  JSR RandomNumber

  INC total_frames
  
  LDA player_stun
  BEQ AfterUpdatePlayerStun
  LDA player_stun
  SEC
  SBC #$01
  STA player_stun

  AfterUpdatePlayerStun:
  
  ;LDA total_frames
  LDA player_health
  JSR CalcBCD
  JSR WriteBCDToScreen


  ;LDA total_frames
  ;BNE DoneFrame

  ; set the level to A2
  ;LDA #LOW(level_A2)
  ;STA ptr_level_lo
  ;LDA #HIGH(level_A2)
  ;STA ptr_level_hi

  ;JSR UpdateBackground

DoneFrame:
;; return from the interrupt, until next time NMI is called
  RTI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; data bank for graphics info and level layout
  .bank 1
  .org $E000

default_hud:
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $AA, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $AB, $00
  .db $00, $A6, $9C, $8C, $9B, $8A, $99, $A2, $8A, $9B, $8D, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $9C, $8E, $8C, $A4, $8A, $80, $A8, $00
  .db $00, $A6, $B0, $A4, $A4, $A4, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $A8, $00
  .db $00, $A6, $B1, $A4, $A4, $A4, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $A8, $00
  .db $00, $A7, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A9, $00
;; main level, with included attributes
level_A1:

;; stored in metatiles, visually like below:
;; total of 12 (NOT! 16, basically the 15 minus the GUI room) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 12 * 16 = 192 bytes
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $06, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $03, $02, $05, $05, $05, $05, $11, $00, $00, $00, $00, $00, $00
  .db $00, $00, $08, $0D, $04, $04, $04, $04, $04, $11, $00, $00, $00, $00, $00, $00
  .db $00, $00, $0B, $07, $07, $07, $07, $07, $07, $11, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

;; main level, with included attributes
level_A2:

;; stored in metatiles, visually like below:
;; total of 15 (NOT! 16) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 15 * 16 = 240 bytes
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $11, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $11, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00


generic_attributes:

;;; attributes are 64 bytes that tell how the metatiles behave (color palette)
; see here: https://wiki.nesdev.com/w/index.php/PPU_attribute_tables
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000




;; a metatile screen and attributes is 240+64=304 bytes per screen, which is down to about 30% of what the full section would be
;; this means you can fit about 3 screens / kb, which isn't awful
;; in the future I think I'll not make the attributes so big, and maybe just basic data about the whole screen (is it a 'blue' or 'red' or 'neutral' section)


;; color palettes for sprites and backgrounds
palette:
  
  ;; background palettes
  ;              blue              red            green              N/A
  .db $0F,$1C,$2B,$39,  $0F,$07,$26,$34,  $0F,$09,$28,$36,  $0F,$07,$26,$34

  ;; good blue: $0F,$1C,$2B,$39
  ;; good red: $0F,$1B,$2A,$38
  ;; good : $0F,$09,$28,$36
  ;; good : $0F,$07,$26,$34

  ;; sprite palettes
  ;           default             blue              red            green
  .db $0F,$15,$35,$15, $0F,$1B,$2A,$38, $0F,$1B,$2A,$38, $0F,$1B,$2A,$38

  ;; greenish: $0F,$1B,$2A,$38
  ;; pinkish: $05,$15,$25,$35



;; metadata about that sort of tile (does it block player movement, activate something, etc)
metatiles_attr:
; metadata byte:
; %ABCDEFGH 
; H: is considered a blocking obstacle if 1


  .db %00000000, %00000000, %00000000, %00000000    , %00000000
  .db %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000
  .db %00000000, %00000000, %00000000, %00000000

  ; blocks
  .db %00000001

  .db %00000000, %00000000, %00000000, %00000000

;; storage for the definitions of metatiles
metatiles_defs:
; each metatile is 4 bytes. They are sequentially arranged, TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHt in which background tile

  ; $00 starts here

  ; blank
  .db $00, $00, $00, $00

  ; whole block
  .db $01, $01, $01, $01

  ;; lattice patterns (starts at metatile $02)
  .db $02, $02, $02, $02 ; Solid
  .db $0B, $0C, $0B, $0C ; Road middle (up/down)
  .db $0D, $0D, $0E, $0E ; Road middle (left/right)

  ; $05 starts here
  .db $03, $03, $02, $02 ; Barrier N
  .db $02, $04, $02, $04 ; Barrier E 
  .db $02, $02, $05, $05 ; Barrier S
  .db $06, $02, $06, $02 ; Barrier W

  ; $09 starts here
  .db $03, $08, $02, $04 ; Corner NE
  .db $02, $04, $05, $0A ; Corner SE
  .db $06, $02, $09, $05 ; Corner SW
  .db $07, $03, $06, $02 ; Corner NW

  ; $0D starts here
  .db $0B, $0F, $02, $0E ; RoadLinePipe NE
  .db $0B, $0F, $02, $0E ; TODO
  .db $0B, $0F, $02, $0E ; TODO
  .db $0B, $0F, $02, $0E ; TODO

  ; $11 starts here
  .db $10, $10, $10, $10



;;;; vectors (basically function addresses)
  .org $FFFA

  ; this is the callback per frame for when the drawing stops
  .dw NMI

  ; this is the callback when the `RESET` button is hit on the unit
  .dw RESET

  ; I'm not using the IRQ interrupt
  .dw 0          

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  
;; bank for graphics information  
  .bank 2
  .org $0000

; sprite graphics
  .incbin "./art/scrapyard_SPRITE.chr"

; background graphics
  .incbin "./art/scrapyard_BACKGROUND.chr"



