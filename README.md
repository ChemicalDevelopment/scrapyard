
# SCRAPYARD

This is an NES game

Compile with `compile.bat`. The compiler is included (and is only on Windows)

I will add other instructions for MacOS/Linux hopefully in the near future


# SPECS

256x240 px screen




;; this uses `csprite_y` as input and writes over it!
MoveS:

  LDA csprite_x 
  AND #$0F
  BNE CheckSpecialPx

  ;; special px Y and 0px X
  ; CheckSpecialPx0Px:
  ;  LDA csprite_y 
  ;  AND #$0F
  ;  CMP #$0D
  ;  BEQ MoveS_SpecialPx0Px
  ;  JMP MoveS_0Px

  MoveS_SpecialPx0Px:
    ; need to add 2 to Y and subtract 1 from x
    LDA #$20
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS

    JMP RealMoveS

  CheckSpecialPx:
    LDA csprite_y 
    AND #$0F
    CMP #$0D
    BEQ MoveS_SpecialPx; if it is that special pixel, run another test

  MoveS_Normal:
    LDA #$00
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS

    LDA #$01
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS
    JMP RealMoveS

  ; special pixel routine
  MoveS_SpecialPx:
    LDA #$20
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS

    ; first check
    LDA #$21
    STA arg1
    JSR CheckMoveOffsetADD
    BNE EndMoveS
    JMP RealMoveS

  MoveS_0Px:
    ;LDA #$00
    ;STA arg1
    ;JSR CheckMoveOffsetADD
    ;BNE EndMoveS

    ; first check
    ;LDA #$01
    ;STA arg1
    ;JSR CheckMoveOffsetADD
    ;BNE EndMoveS

    JMP RealMoveS


  RealMoveS:
  INC csprite_y