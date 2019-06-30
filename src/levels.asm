
;; this is the top 6 rows that are set for HUD (heads up display)/information
default_hud:
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $AA, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $AB, $00
  .byte $00, $A6, $9C, $8C, $9B, $8A, $99, $A2, $8A, $9B, $8D, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $9C, $8E, $8C, $A4, $8A, $80, $A8, $00
  .byte $00, $A6, $B0, $A4, $A4, $A4, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $A8, $00
  .byte $00, $A6, $B1, $A4, $A4, $A4, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $A8, $00
  .byte $00, $A7, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A5, $A9, $00


;; storage for the definitions of metatiles
metatiles_defs:
; each metatile is 4 bytes. They are sequentially arranged, TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT in which background tile

  ; $00 starts here
  .byte $00, $00, $00, $00 ; blank
  .byte $02, $02, $02, $02 ; solid
  .byte $0B, $0C, $0B, $0C ; Road middle (up/down)
  .byte $0D, $0D, $0E, $0E ; Road middle (left/right)

  ; $04 starts here
  .byte $03, $03, $02, $02 ; Road Side N
  .byte $02, $04, $02, $04 ; Road Side E
  .byte $02, $02, $05, $05 ; Road Side S
  .byte $06, $02, $06, $02 ; Road Side W

  ; $08 starts here
  .byte $03, $08, $02, $04 ; Corner NE
  .byte $02, $04, $05, $0A ; Corner SE
  .byte $06, $02, $09, $05 ; Corner SW
  .byte $07, $03, $06, $02 ; Corner NW

  ; $0C starts here
  .byte $0B, $0F, $02, $0E ; RoadLinePipe NE
  .byte $0B, $0F, $02, $0E ; TODO
  .byte $0B, $0F, $02, $0E ; TODO
  .byte $0B, $0F, $02, $0E ; TODO

  ; $10 starts here
  .byte $10, $10, $10, $10 ; barrier #1 (smallest)
  .byte $11, $11, $11, $11 ; barrier #2
  .byte $12, $12, $12, $12 ; barrier #3
  .byte $13, $02, $02, $13 ; barrier #4 (largest)

  ; $14 starts here
  .byte $20, $20, $20, $20 ; tile simple 2x2
  .byte $07, $08, $09, $0A ; tile big 1x1
  .byte $00, $00, $00, $00 ; TODO
  .byte $00, $00, $00, $00 ; TODO

  ; $18 starts here
  .byte $22, $22, $02, $02 ; Sidewalk N
  .byte $02, $23, $02, $23 ; Sidewalk E
  .byte $02, $02, $24, $24 ; Sidewalk S
  .byte $21, $02, $21, $02 ; Sidewalk W

  ; $1C starts here
  .byte $22, $25, $02, $23 ; Sidewalk Corner NE
  .byte $22, $25, $02, $23 ; Sidewalk Corner SE
  .byte $21, $02, $27, $24 ; Sidewalk Corner SW
  .byte $22, $25, $02, $23 ; Sidewalk Corner NW


;; metadata about that sort of tile (does it block player movement, activate something, etc)
metatiles_attr:
; metadata byte:
; %ABCDEFGH 
; H: is considered a blocking obstacle if 1

  ; blocks $00-$10
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  
  ; blocks $10-$20
  .byte %00000001, %00000001, %00000001, %00000001
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000


;; stored in metatiles, visually like below:
;; total of 12 (NOT! 16, basically the 15 minus the GUI room) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 12 * 16 = 192 bytes

level_A1:

  .byte $13, $19, $07, $02, $05, $1B, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $05, $1B, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $05, $1B, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $05, $1B, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $05, $1B, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $05, $1E, $1A, $1A, $1A, $11, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $02, $01, $04, $04, $04, $04, $11, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $07, $0C, $03, $03, $03, $03, $03, $11, $00, $00, $00, $00, $00, $00
  .byte $13, $19, $0A, $06, $06, $06, $06, $06, $06, $11, $00, $00, $00, $00, $00, $00
  .byte $13, $01, $18, $18, $18, $18, $18, $18, $18, $11, $00, $00, $00, $00, $00, $00
  .byte $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13
  .byte $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13, $13


;; main level, with included attributes
level_A2:

;; stored in metatiles, visually like below:
;; total of 15 (NOT! 16) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 15 * 16 = 240 bytes
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $11, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $11, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $03, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00



