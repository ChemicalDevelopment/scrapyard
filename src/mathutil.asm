;; math utility functions


;; random number into A
;; basically just iterates rand_state = (rand_state * 5 + 3) % 256
RandomNumber:
    LDA rand_state
    ASL A
    ASL A
    CLC
    ADC rand_state
    CLC
    ADC #$03
    STA rand_state
    RTS


;; this calculates the BCD (binary coded decimal) of the accumulator, and stores it in bcd_100s and bcd_10s1s.
CalcBCD:
    STA tmp1

    LDA #$00
    STA bcd_100s
    STA bcd_10s1s

    LDX #$00

    @BCDLoop:
        LDA bcd_100s
        CMP #$05
        BCC @BCDHundredsGood
        LDA bcd_100s
        CLC
        ADC #$03
        STA bcd_100s

        @BCDHundredsGood:
            LDA bcd_10s1s
            AND #$F0
            CMP #$50
            BCC @BCDTensGood
            LDA bcd_10s1s
            CLC
            ADC #$30
            STA bcd_10s1s

        @BCDTensGood:
            LDA bcd_10s1s
            AND #$0F
            CMP #$05
            BCC @BCDOnesGood
            LDA bcd_10s1s
            CLC
            ADC #$03
            STA bcd_10s1s

        @BCDOnesGood:
            CLC
            ROL tmp1
            ROL bcd_10s1s
            ROL bcd_100s

            INX
            CPX #$08
            BNE @BCDLoop
    RTS

