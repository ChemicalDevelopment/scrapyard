;; utility functions


; sprite attribute byte:
; ____ABC__
; A=if the tile set being used is east facing (if A=0, then it is N facing)
; BC=orientation, 0=N,1=E,2=S,3=W

; waits for a vblank period
vblankwait:
    BIT $2002
    BPL vblankwait
    RTS

;; this reads the input, stores the actual buttons into `raw_input`, and a modified version with only the most recent direction in `input`, and updates `last_input`
ReadInput:
    ; this code basically "latches" down the controller inputs.
    LDA #$01
    STA $4016 ; controller #1
    LDA #$00
    STA $4016

    LDX #$00
    STX raw_input
    
    ; Loop 8 times to read the buttons
    @Loop:
        ASL raw_input
        LDA CONTROLLER_1
        AND #%01
        ORA raw_input
        STA raw_input

        INX
        CPX #$08
        BNE @Loop


    ; if nothing has changed, we're done
    LDA last_input
    CMP raw_input
    BEQ @ReadInputDone ; if they're equal, skip ahead

    ; now change to create a more usable input
    LDA raw_input
    STA input

    ; this is used to filter out opposite presses (Up+Down), and reject diagonal presses but in effect, use the newest pressed.
    @FilterInput:

        LDA input
        AND #%00001111
        BEQ @ReadInputDone
        
        ; test whether any diagonals are pressed
        SEC
        SBC #%01
        AND input
        BEQ @ReadInputDone

        ; Use the new directions instead
        LDA #$FF
        SEC
        SBC last_input
        AND input
        STA input
        ; input = (!last_input) && input, so only new button presses
        ; input is now filtered down, and raw_input has the exact button presses

    @ReadInputDone:

    LDA raw_input
    STA last_input

    RTS

;; sets the orientation of the player based on input
SetPlayerOrient:

    @SetPlayerOrientTryN:
    LDA input
    AND #%1000
    BEQ @SetPlayerOrientTryE
    L_SPR_ATTR
    AND #%11110011
    ORA #%00000000
    S_SPR_ATTR

    @SetPlayerOrientTryE:
    LDA input
    AND #%0001
    BEQ @SetPlayerOrientTryS
    L_SPR_ATTR
    AND #%11110011
    ORA #%00000100
    S_SPR_ATTR

    @SetPlayerOrientTryS:
    LDA input
    AND #%0100
    BEQ @SetPlayerOrientTryW
    L_SPR_ATTR
    AND #%11110011
    ORA #%00001000
    S_SPR_ATTR

    @SetPlayerOrientTryW:
    LDA input
    AND #%0010
    BEQ @SetPlayerOrientEnd
    L_SPR_ATTR
    AND #%11110011
    ORA #%00001100
    S_SPR_ATTR

    ; done
    @SetPlayerOrientEnd:
    RTS


; checks the metatile collision flag
CheckMetatileCollisionFlag:
    TAY
    LDA (ptr_level_lo), Y
    TAY
    LDA metatiles_attr, Y
    RTS

;; moves based on orientation
MoveSprite:
    @TryMoveSpriteN:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000000
        BNE @TryMoveSpriteE
        ; we are moving N
        ; now test boundaries
        L_SPR_Y
        CMP #$30
        BCC @OffscreenN

        @FirstCheckN:
            LDA csprite_metatile
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleN
        
        @SecondCheckN:
            L_SPR_X
            AND #$0F
            BEQ @RealMoveN
        
        @ThirdCheckN:
            LDA csprite_metatile
            CLC
            ADC #$01
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleN

        ;; one of these three will terminate it
        @RealMoveN:
            ; actually moving
            L_SPR_Y
            SEC
            SBC #$01
            S_SPR_Y
            RTS
        @OffscreenN: 
            ; trying to go offscreen
            LDA game_flag
            ORA #%00000001
            STA game_flag
            RTS
        @ObstacleN:
            ; hit an obstacle
            LDA game_flag
            ORA #%00000010
            STA game_flag
            RTS
    @TryMoveSpriteE:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000100
        BNE @TryMoveSpriteS
    
        ; now test obstacle collision
        L_SPR_X
        CMP #$E5
        BCS @OffscreenE

        @FirstCheckE:
            LDA csprite_metatile
            CLC
            ADC #$11
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleE
        
        @SecondCheckE:
            L_SPR_Y
            AND #$0F
            CMP #$0F
            BEQ @RealMoveE
        
        @ThirdCheckE:
            LDA csprite_metatile
            CLC
            ADC #$01
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleE

        @RealMoveE:
            L_SPR_X
            CLC
            ADC #$01
            S_SPR_X
            RTS
        @OffscreenE: 
            ; trying to go offscreen
            LDA game_flag
            ORA #%00000001
            STA game_flag
            RTS
        @ObstacleE:
            ; hit an obstacle
            LDA game_flag
            ORA #%00000010
            STA game_flag
            RTS
    @TryMoveSpriteS:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001000
        BEQ @_TryMoveSpriteS
        JMP @TryMoveSpriteW

        @_TryMoveSpriteS: ; too many instructions

        ; now test for obstacles/offscreen
        L_SPR_Y
        CMP #$CF
        BCS @OffscreenS

        @FirstCheckS:
            L_SPR_Y
            AND #$0F
            CMP #$0F
            BEQ @YFCheckS

            L_SPR_X
            AND #$0F
            BEQ @X0CheckS

        @SecondCheckS:
            LDA csprite_metatile
            CLC
            ADC #$10
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS

            LDA csprite_metatile
            CLC
            ADC #$11
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS
            JMP @RealMoveS

        @YFCheckS:
            L_SPR_X
            AND #$0F
            BEQ @YFX0CheckS
        
            LDA csprite_metatile
            CLC
            ADC #$21
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS

            LDA csprite_metatile
            CLC
            ADC #$20
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS
            JMP @RealMoveS
        
        @X0CheckS:
            LDA csprite_metatile
            CLC
            ADC #$0
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS
            JMP @RealMoveS

        @YFX0CheckS:
            LDA csprite_metatile
            CLC
            ADC #$20
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleS

        @RealMoveS:
            L_SPR_Y
            CLC
            ADC #$01
            S_SPR_Y
            RTS
        @OffscreenS: 
            ; trying to go offscreen
            LDA game_flag
            ORA #%00000001
            STA game_flag
            RTS
        @ObstacleS:
            ; hit an obstacle
            LDA game_flag
            ORA #%00000010
            STA game_flag
            RTS

    @TryMoveSpriteW:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001100
        BEQ @_TryMoveSpriteW
        JMP @TryMoveSpriteDone

        ; just use this because TryMoveSpriteDone is too far away
        @_TryMoveSpriteW:

        ; try and move west now
        L_SPR_X
        CMP #$0C
        BCC @OffscreenW

        L_SPR_Y
        AND #$0F
        CMP #$0F
        BEQ @YFCheckW

        L_SPR_X
        AND #$0F
        BEQ @X0CheckW

        @FirstCheckW:
            LDA csprite_metatile
            CLC
            ADC #$10
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW

            LDA csprite_metatile
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW
            JMP @RealMoveW

        @YFCheckW:
            L_SPR_X
            AND #$0F
            BEQ @YFX0CheckW

            LDA csprite_metatile
            CLC
            ADC #$11
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW
            JMP @RealMoveW

        @X0CheckW:
            LDA csprite_metatile
            CLC
            ADC #$10
            SEC
            SBC #$01
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW

            LDA csprite_metatile
            SEC
            SBC #$01
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW
            JMP @RealMoveW

        @YFX0CheckW:
            LDA csprite_metatile
            CLC
            ADC #$10
            SEC
            SBC #$01
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW

            LDA csprite_metatile
            CLC
            ADC #$10
            JSR CheckMetatileCollisionFlag
            BNE @ObstacleW

        @RealMoveW:
            L_SPR_X
            SEC
            SBC #$01
            S_SPR_X
            RTS
        @OffscreenW: 
            ; trying to go offscreen
            LDA game_flag
            ORA #%00000001
            STA game_flag
            RTS
        @ObstacleW:
            ; hit an obstacle
            LDA game_flag
            ORA #%00000010
            STA game_flag
            RTS

    @TryMoveSpriteDone:
    RTS

; update the csprite_metatile
UpdateCspriteMetatile:
    L_SPR_Y
    SEC 
    SBC #$30
    AND #$F0
    STA csprite_metatile
    L_SPR_X
    LSR A
    LSR A
    LSR A
    LSR A
    EOR csprite_metatile
    STA csprite_metatile
    
    RTS

; updates the other 3 sprites to be in accordance
UpdateSprite3Extra:
    L_SPR_Y
    LDY #(OFFSET_Y+4)
    STA (ptr_csprite_lo), Y

    CLC
    ADC #$08
    LDY #(OFFSET_Y+4*2)
    STA (ptr_csprite_lo), Y
    LDY #(OFFSET_Y+4*3)
    STA (ptr_csprite_lo), Y

    L_SPR_X
    LDY #(OFFSET_X+4*2)
    STA (ptr_csprite_lo), Y
    
    CLC
    ADC #$08
    LDY #(OFFSET_X+4*1)
    STA (ptr_csprite_lo), Y
    LDY #(OFFSET_X+4*3)
    STA (ptr_csprite_lo), Y

    ;;setting tile/attr

    ; you need to compare top left and bottom right because tiles are re used.
    ; a N facing sprite set will be: 0, 1, 2, 3
    ; but a S facing sprite will be: 3, 2, 1, 0 and have attributes set to flip them

    L_SPR_TILE
    STA tmp1 ; tmp1 has tile for top left

    LDY #(OFFSET_TILE+4*3)
    LDA (ptr_csprite_lo), Y
    STA tmp2 ; tmp2 has tile for bottom right

    CMP tmp1
    BCS @SetTiles

    ; otherwise, swap them so that the minimum is tmp1
    LDA tmp2
    STA tmp1

    @SetTiles:

    L_SPR_ATTR
    AND #%00010000
    BEQ @HandleTilesN

    @HandleTilesE:
    ; east facing
        LDA tmp1
        SEC
        SBC #$20
        STA tmp1

    @HandleTilesN:
    ; north facing

    ; tmp1 now contains the starting tile, tmp2 now contains ending tile

    @SetTilesN:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000000
        BNE @SetTilesE

        LDA tmp1
        LDY #(OFFSET_TILE)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*2)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*3)
        STA (ptr_csprite_lo), Y

        ; set attributes
        L_SPR_ATTR
        AND #%00101111

        LDY #(OFFSET_ATTR)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*2)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*3)
        STA (ptr_csprite_lo), Y

        JMP @SetTilesDone
    
    @SetTilesE:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00000100
        BNE @SetTilesS

        LDA tmp1
        CLC
        ADC #$20

        LDY #(OFFSET_TILE)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*2)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*3)
        STA (ptr_csprite_lo), Y

        ; set attributes
        L_SPR_ATTR
        AND #%00111111
        ORA #%00010000

        LDY #(OFFSET_ATTR)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*2)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*3)
        STA (ptr_csprite_lo), Y

        JMP @SetTilesDone
    
    @SetTilesS:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001000
        BNE @SetTilesW

        ; reverse order
        LDA tmp1
        LDY #(OFFSET_TILE+4*3)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*2)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE)
        STA (ptr_csprite_lo), Y

        L_SPR_ATTR
        AND #%00101111
        ORA #%11000000

        LDY #(OFFSET_ATTR)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*2)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*3)
        STA (ptr_csprite_lo), Y

        JMP @SetTilesDone
    
    @SetTilesW:
        L_SPR_ATTR
        AND #%00001100
        CMP #%00001100
        BNE @SetTilesDone

        LDA tmp1
        CLC
        ADC #$20

        LDY #(OFFSET_TILE+4*3)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4*2)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE+4)
        STA (ptr_csprite_lo), Y
        CLC
        ADC #$01
        LDY #(OFFSET_TILE)
        STA (ptr_csprite_lo), Y

        ; set attributes
        L_SPR_ATTR
        AND #%00111111
        ORA #%11010000

        LDY #(OFFSET_ATTR)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*2)
        STA (ptr_csprite_lo), Y
        LDY #(OFFSET_ATTR+4*3)
        STA (ptr_csprite_lo), Y


    @SetTilesDone:


    ; we need to get the start of the set, because for 

    RTS
