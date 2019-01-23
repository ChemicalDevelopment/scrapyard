; SCRAPYARD code by Cade Brown

;;;; Header

  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

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

;; player positional metadata:
;; bits: ______DD
;; DD = orientation, 0=N,1=E,2=S,3=W
player_meta .rs 1

;; how many frames have elapsed? (NMI loops)
total_frames .rs 1

;; pointer variable for addressing 16 bit memory
ptr_lo .rs 1
ptr_hi .rs 1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;; Subroutines, functions, and most code is stored here
  .bank 0
  .org $C000

;; wait for a vblank
vblankwait:
  BIT $2002
  BPL vblankwait
  RTS


;; this spawns in the player
SpawnPlayer:

  ; load all the default sprites in
  LDX #$00
  LoadSpritesLoop:
    LDA sprites, x
    STA $0200, x
    INX
    CPX #$10
    BNE LoadSpritesLoop

  RTS


;; code to set the background to the correct stage
SetBackground:

  LoadBackgroundInformation:
    LDA $2002             ; read PPU status to reset the high/low latch
    LDA #$20
    STA $2006             ; write the high byte of $2000 address
    LDA #$00
    STA $2006             ; write the low byte of $2000 address

    LDA #LOW(background)
    STA ptr_lo       ; put the low byte of the address of background into pointer
    LDA #HIGH(background)
    STA ptr_hi       ; put the high byte of the address into pointer
    
    LDX #$00            ; start at pointer + 0
    LDY #$00
    OutsideLoop:
      
    InsideLoop:
      LDA [ptr_lo], y  ; copy one background byte from address in pointer plus Y
      STA $2007           ; this runs 256 * 4 times
      
      INY                 ; inside loop counter
      CPY #$00
      BNE InsideLoop      ; run the inside loop 256 times before continuing down
      
      INC ptr_hi      ; low byte went 0 to 256, so high byte needs to be changed now
      
      INX
      CPX #$04
      BNE OutsideLoop     ; run the outside loop 256 times before continuing down

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


  ; load in the player
  JSR SpawnPlayer

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
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
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
  BEQ TSOrientDone

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
  TSOrientE:
    LDA input
    AND #%0001
    BEQ TSOrientS
    LDA #$01
    STA player_meta
  TSOrientS:
    LDA input
    AND #%0100
    BEQ TSOrientW
    LDA #$02
    STA player_meta
  TSOrientW:
    LDA input
    AND #%0010
    BEQ TSOrientDone
    LDA #$03
    STA player_meta

  TSOrientDone:
  ; done setting orientation

  ; save thsee for next time
  LDA raw_input
  STA last_input

;; adjust player x, player y

  






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
  .incbin "level1.nam"

;; color palettes for sprites and backgrounds
palette:
  .db $22,$29,$1A,$0F, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F   ;;sprite palette
  .db $22,$1C,$15,$14, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F, $0F,$0F,$0F,$0F   ;;background palette


;; default sprite information, center of the screen facing north
sprites:
  ;   vert  tile       attr  horiz
  .db  $80,  $00, %00000000,   $80   ;sprite 0
  .db  $80,  $01, %00000000,   $88   ;sprite 1
  .db  $88,  $02, %00000000,   $80   ;sprite 2
  .db  $88,  $03, %00000000,   $88   ;sprite 3



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
  .incbin "scrapyard_SPRITE.chr"

; background graphics
  .incbin "scrapyard_BACKGROUND.chr"



