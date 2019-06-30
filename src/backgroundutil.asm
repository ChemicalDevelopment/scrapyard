
;; all functions in here assume ptr_level_lo and ptr_level_hi are set correctly to the lo and hi bytes of the level address, in levels.asm

PPUOff:
    LDA #$00
    STA PPUCTRL
    STA PPUMASK
    RTS

; turn the PPU rendering functions on
PPUOn:
    LDA #%10010000
    STA PPUCTRL
    LDA #%00011110
    STA PPUMASK
    RTS

; resets x/y offset
ResetScroll:
    LDA #$00
    STA $2005
    STA $2005
    RTS


;; sets the top part of the screen
SetHUD:
    JSR ResetScroll

    LDA $2002 ; read PPU status to reset the high/low latch
    LDA #$20
    STA $2006 ; write the high byte of $2000 address
    LDA #$00
    STA $2006 ; write the low byte of $2000 address

    LDA #<(default_hud)
    STA ptr_lo
    LDA #>(default_hud)
    STA ptr_hi

    ; copy in the data for the heads up display
    LDY #$00
    @Loop:
        LDA (ptr_lo), Y
        STA $2007

        INY
        CPY #$C0 ; should be 6 rows * 32 columns = 192 = $C0
        BNE @Loop

    RTS


; sets background based on ptr_level_lo and ptr_level_hi
SetBackground:

    JSR ResetScroll
    ; figure out current background offset


    ; multiply by 192 (0xC0=0b11000000)
    LDA #$00
    STA ptr_level_hi
    LDA background_idx

    ASL A
    ROL ptr_level_hi
    ADC background_idx

    ; now you have 3 * background_idx

    ASL A
    ROL ptr_level_hi
    ASL A
    ROL ptr_level_hi
    ASL A
    ROL ptr_level_hi
    ASL A
    ROL ptr_level_hi
    ASL A
    ROL ptr_level_hi
    ASL A
    ROL ptr_level_hi

    CLC
    ADC #<(level_A1)
    STA ptr_level_lo
    LDA ptr_level_hi
    ADC #>(level_A1)
    STA ptr_level_hi


    ; store in the pointer used for this function
    LDA ptr_level_lo
    STA ptr_lo
    LDA ptr_level_hi
    STA ptr_hi


    LDA $2002 ; read PPU status to reset the high/low latch
    LDA #$20
    STA $2006 ; write the high byte of $20C0 address
    LDA #$C0
    STA $2006 ; write the low byte of $20C0 address


    LDX #$00
    _SetBackgroundOutsideLoop:
        STX tmp1

        LDY #$00
        @InsideLoop1:
            ; transform it into a metatile offset
            LDA (ptr_lo), Y
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
            
            INY
            CPY #$10 ; 16 = width of the metatile array 
            BNE @InsideLoop1

        ; do it over again for the bottom left and bottom right of the next row of sprites
        ; (the lower half of the metatile row, though)
        LDY #$00
        @InsideLoop2:
            LDA (ptr_lo), Y
            ASL A
            ASL A
            TAX

            ; set bottom left corner
            INX
            INX
            LDA metatiles_defs, x
            STA $2007

            ; set bottom right corner
            INX
            LDA metatiles_defs, x
            STA $2007 
            
            INY
            CPY #$10 ; 16 = width of the metatile array 
            BNE @InsideLoop2

        LDA ptr_lo
        CLC
        ADC #$10
        STA ptr_lo
        LDA ptr_hi
        ; don't set carry so it'll update here
        ADC #$00
        STA ptr_hi

        ; restore and check number of rows written so far
        LDX tmp1
        INX
        CPX #$0C ; C=12 rows
        BNE _SetBackgroundOutsideLoop

    ; copy all 64 attribute bytes (which we assume are 0 right now)   
    LDY #$00
    @AttributesLoop:
        ;LDA generic_attributes, Y
        LDA #$00
        STA $2007

        INY
        CPY #$40 ; 64 bytes
        BNE @AttributesLoop

    LDA $2002 ; reset

    RTS

; moves based on current orientation

MoveBackground:

    @MoveBackgroundN:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000000
        BNE @MoveBackgroundE

        LDA background_idx
        CLC
        ADC #$01
        STA background_idx

        JSR SetBackground
        JSR ResetScroll
        
        LDA #$D0
        S_SPR_Y
        
        RTS

    @MoveBackgroundE:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000100
        BNE @MoveBackgroundS

        LDA background_idx
        CLC
        ADC #$01
        STA background_idx

        JSR SetBackground
        JSR ResetScroll
        
        LDA #$08
        S_SPR_X
        
        RTS

    @MoveBackgroundS:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001000
        BNE @MoveBackgroundW

        LDA background_idx
        SEC
        SBC #$01
        STA background_idx

        JSR SetBackground
        JSR ResetScroll
        
        LDA #$30
        S_SPR_Y
        
        RTS

    @MoveBackgroundW:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001100
        BNE @MoveBackgroundDone

        LDA background_idx
        SEC
        SBC #$01
        STA background_idx

        JSR SetBackground
        JSR ResetScroll
        
        LDA #($FF-$20-$08)
        S_SPR_X
        
        RTS
    @MoveBackgroundDone:
        RTS

;; writes the BCD variables to the HUD at a specified spot
WriteBCDToHUD:
    STA tmp1

    LDA $2002 ; read PPU status to reset the high/low latch
    LDA #$20
    STA $2006 ; write the high byte of address
    LDA tmp1
    STA $2006 ; write the low byte of address

    ; write 100s digit
    LDA bcd_100s
    CLC
    ADC #$80 ; $80 is the offset of the alphabet in the CHR file
    STA $2007
    
    ; write 10s digit
    LDA bcd_100s
    CLC
    ADC #$80 ; $80 is the offset of the alphabet in the CHR file
    STA $2007

    ; write 1s digit
    LDA bcd_10s1s
    AND #$0F
    CLC
    ADC #$80
    STA $2007

; write restof line
    LDA #$00
    STA $2007
    STA $2007
    STA $2007
    STA $2007
    STA $2007
    STA $2007
    STA $2007
    STA $2007

    JSR ResetScroll

    RTS




