
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
; each metatile is 4 bytes. They are sequentially arranged, TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHt in which background tile

  ; $00 starts here

  ; blank
  .byte $00, $00, $00, $00

  ; whole block
  .byte $01, $01, $01, $01

  ;; lattice patterns (starts at metatile $02)
  .byte $02, $02, $02, $02 ; Solid
  .byte $0B, $0C, $0B, $0C ; Road middle (up/down)
  .byte $0D, $0D, $0E, $0E ; Road middle (left/right)

  ; $05 starts here
  .byte $03, $03, $02, $02 ; Barrier N
  .byte $02, $04, $02, $04 ; Barrier E 
  .byte $02, $02, $05, $05 ; Barrier S
  .byte $06, $02, $06, $02 ; Barrier W

  ; $09 starts here
  .byte $03, $08, $02, $04 ; Corner NE
  .byte $02, $04, $05, $0A ; Corner SE
  .byte $06, $02, $09, $05 ; Corner SW
  .byte $07, $03, $06, $02 ; Corner NW

  ; $0D starts here
  .byte $0B, $0F, $02, $0E ; RoadLinePipe NE
  .byte $0B, $0F, $02, $0E ; TODO
  .byte $0B, $0F, $02, $0E ; TODO
  .byte $0B, $0F, $02, $0E ; TODO

  ; $11 starts here
  .byte $10, $10, $10, $10


;; metadata about that sort of tile (does it block player movement, activate something, etc)
metatiles_attr:
; metadata byte:
; %ABCDEFGH 
; H: is considered a blocking obstacle if 1


  .byte %00000000, %00000000, %00000000, %00000000    , %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000
  .byte %00000000, %00000000, %00000000, %00000000

  ; blocks
  .byte %00000001

  .byte %00000000, %00000000, %00000000, %00000000


level_A1:

;; stored in metatiles, visually like below:
;; total of 12 (NOT! 16, basically the 15 minus the GUI room) rows, and 16 columns
;; each is an index into the `metatiles` address to tell which metatile is located on the grid
;; so this section is 12 * 16 = 192 bytes
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $06, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $03, $02, $05, $05, $05, $05, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $08, $0D, $04, $04, $04, $04, $04, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $0B, $07, $07, $07, $07, $07, $07, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $11, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
  .byte $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00


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
