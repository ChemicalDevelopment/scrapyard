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

; current background/screen of meta tiles
SCENE_METADATA = $0400

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Global variables in zero-page memory
  .rsset $0000

;; `input` byte, storing the current frame's: B, A, SELECT, START, UP, DOWN, LEFT, RIGHT, in that order
input .rs 1
raw_input .rs 1
last_input .rs 1

;; x, y coordinates in pixels. Top left is 0, 0 
player_x .rs 1
player_y .rs 1

; what metatile do we land on?
player_metatile_x .rs 1
player_metatile_y .rs 1

; for indexing into SCENE_METADATA
player_metatile_idx .rs 1

;; player positional metadata:
;; bits: ______DD
;; DD = orientation, 0=N,1=E,2=S,3=W
player_meta .rs 1

;; how many frames have elapsed? (NMI loops)
total_frames .rs 1

;; pointer variable for addressing 16 bit memory
ptr_lo .rs 1
ptr_hi .rs 1

ptr2_lo .rs 1
ptr2_hi .rs 1

; pointer to SCENE_METADATA
ptr_SCENE_METADATA_lo .rs 1
ptr_SCENE_METADATA_hi .rs 1

;; temporary memory for swapping
tmp .rs 1
tmp2 .rs 1

;; variable to count how many reads used
reads_used .rs 1


;; section that stores screen data
  .rsset SCENE_METADATA

scene_data .rs 240


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Subroutines, functions, and most code is stored here
  .bank 0
  .org $C000

;; wait for a vblank
vblankwait:
  BIT $2002
  BPL vblankwait
  RTS



;; code to set the background to the correct stage
SetBackground:
  ; to set a background, the first 32*30=960 bytes are the tiles, in row-major order
  ; then, there are 256 bytes


  LoadBackgroundInformation:
    LDA $2002             ; read PPU status to reset the high/low latch
    LDA #$20
    STA $2006             ; write the high byte of $2000 address
    LDA #$00
    STA $2006             ; write the low byte of $2000 address
    
    LDA #LOW(SCENE_METADATA)
    STA ptr_SCENE_METADATA_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(SCENE_METADATA)
    STA ptr_SCENE_METADATA_hi       ; put the high byte of the address into pointer

    LDA #LOW(background)
    STA ptr_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(background)
    STA ptr_hi       ; put the high byte of the address into pointer

    LDX #$00            ; start at pointer + 0
    ; also use this opportunity to write meta tile info to SCENE_METADATA array

    OutsideLoop:

      LDY #$00
      InsideLoop1:
        LDA [ptr_lo], Y
        STA tmp
        STY tmp2

        STA [ptr_SCENE_METADATA_lo], Y
        

        LDA tmp
        LDY tmp2

        STX tmp
        ASL A
        ASL A
        TAX

        LDA metatiles, x
        STA $2007

        INX
        LDA metatiles, x
        STA $2007 
        
        LDX tmp

        INY                 ; inside loop counter
        CPY #$10
        BNE InsideLoop1      ; run the inside loop 256 times before continuing down

      LDY #$00
      InsideLoop2:
        ; use local ram that it's been copied in to
        LDA [ptr_lo], Y
        STX tmp
        ASL A
        ASL A
        TAX
        INX
        INX
        LDA metatiles, x
        STA $2007

        INX
        LDA metatiles, x
        STA $2007 
        
        LDX tmp

        INY                 ; inside loop counter
        CPY #$10
        BNE InsideLoop2      ; run the inside loop 256 times before continuing down

      LDA ptr_lo
      CLC
      ADC #$10
      STA ptr_lo
      STA ptr_SCENE_METADATA_lo

      INX
      CPX #$0F
      BNE OutsideLoop

    LDA #LOW(background_attributes)
    STA ptr_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(background_attributes)
    STA ptr_hi       ; put the high byte of the address into pointer

    ; copy all 256 attribute bytes here    
    LDY #$00
    LoadAttributesLoop:
      LDA [ptr_lo], Y
      STA $2007           ; this runs 256 * 4 times

      INY                 ; inside loop counter
      CPY #$40
      BNE LoadAttributesLoop      ; run the inside loop 256 times before continuing down

    LDA #LOW(background)
    STA ptr_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(background)
    STA ptr_hi 

    LDA #LOW(metatiledefs_meta)
    STA ptr2_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(metatiledefs_meta)
    STA ptr2_hi       ; put the high byte of the address into pointer

    
    LDA #LOW(SCENE_METADATA)
    STA ptr_SCENE_METADATA_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(SCENE_METADATA)
    STA ptr_SCENE_METADATA_hi       ; put the high byte of the address into pointer

    ; copy all 240 metadaatas   
    LDY #$00
    LoadMetadataLoop:
      STY tmp
      LDA [ptr_lo], Y
      TAY
      LDA [ptr2_lo], Y
      LDY tmp
      STA [ptr_SCENE_METADATA_lo], Y

      INY                 ; inside loop counter
      CPY #$F0
      BNE LoadMetadataLoop      ; run the inside loop 256 times before continuing down
      

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


  ; set up the background tiles
  JSR SetBackground


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
  STA player_y

  LDA #$80
  STA player_x

  ; all the rest of these set to 0
  LDA #$00

  STA player_meta

  STA player_metatile_x
  STA player_metatile_y

  STA input
  STA raw_input
  STA last_input
  STA total_frames


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
    LDA #$00
    LDY #$01
    STA SPRITE_RAM, Y
    LDA #$01
    LDY #$05
    STA SPRITE_RAM, Y
    LDA #$02
    LDY #$09
    STA SPRITE_RAM, Y
    LDA #$03
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
  TSOrientE:
    LDA input
    AND #%0001
    BEQ TSOrientS
    LDA #$01
    STA player_meta
    ; set specific tiles
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

  TSOrientS:
    LDA input
    AND #%0100
    BEQ TSOrientW
    LDA #$02
    STA player_meta

    ; set specific tiles
    LDA #$03
    LDY #$01
    STA SPRITE_RAM, Y
    LDA #$02
    LDY #$05
    STA SPRITE_RAM, Y
    LDA #$01
    LDY #$09
    STA SPRITE_RAM, Y
    LDA #$00
    LDY #$0D
    STA SPRITE_RAM, Y

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
  LDA player_y
  ; divide by 16
  LSR A
  LSR A
  LSR A
  LSR A
  STA player_metatile_y
  INC player_metatile_y

  LDA player_x
  ; divide by 16
  LSR A
  LSR A
  LSR A
  LSR A
  STA player_metatile_x
  INC player_metatile_x

  UpdatePositionN:
    LDA player_meta
    AND #%11
    CMP #%00
    BNE UpdatePositionE
    ; we are facing north
    LDA player_y
    SEC
    SBC #%01
    STA player_y
    JMP RenderPlayer
  UpdatePositionE:
    LDA player_meta
    AND #%11
    CMP #%01
    BNE UpdatePositionS
    ; we are facing east

    LDA player_metatile_y
    ASl A
    ASl A
    ASl A
    ASl A
    ORA player_metatile_x

    STA player_metatile_idx
    TAY
    LDA [ptr_SCENE_METADATA_lo], Y
    
    BNE EndTryMovePlayerE

    INC player_x
    EndTryMovePlayerE:
    JMP RenderPlayer
  UpdatePositionS:
    LDA player_meta
    AND #%11
    CMP #%10
    BNE UpdatePositionW
    ; we are facing east
    INC player_y
    JMP RenderPlayer
  UpdatePositionW:
    LDA player_meta
    AND #%11
    CMP #%11
    BNE RenderPlayer
    ; we are facing east
    LDA player_x
    SEC
    SBC #%01
    STA player_x


;; update the actual x and y of the sprites
RenderPlayer:
  LDA player_y
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

  LDA player_x
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



;; Finalize counters, etc
FinalizeFrame:



  INC total_frames


;; return from the interrupt, until next time NMI is called
  RTI

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; data bank for graphics info and level layout
  .bank 1
  .org $E000

;; main level, with included attributes
background:

;; stored in metatiles, visually like below:
;; total of 15 (NOT! 16) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 15 * 16 = 240 bytes
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
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00

background_attributes:

;;; attributes are 64 bytes that tell how the metatiles behave (color palette)
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
  .db $01,$11,$21,$31, $05,$15,$25,$35, $09,$19,$29,$39, $09,$19,$29,$39

  ;; sprite palettes
  ;           default             blue              red            green
  .db $0F,$30,$26,$05, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F



;; metatile definitions
metatiledefs_TL:
metatiledefs_TR:
metatiledefs_BL:
metatiledefs_BR:

;; metadata about that sort of tile (does it block player movement, activate something, etc)
metatiledefs_meta:
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

;; storage for what metatiles there are
metatiles:
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



