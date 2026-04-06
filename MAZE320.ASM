.segment "ZEROPAGE"
; Locations $22-$7F are available for user zero-page variables
addr_lo:          .res 1   ; low byte  of current VRAM pixel address
addr_hi:          .res 1   ; high byte of current VRAM pixel address
; Global Variables
cnt_lo:           .res 1   ; loop counter low  byte (161 pixels: x = 0..160)
cnt_hi:           .res 1   ; loop counter high byte
XPos:             .res 2   ; current X Co-ordinate
YPos:             .res 1   ; current Y Co-ordinate
PixelAddr:        .res 3   ; Pixel address of the current cell (used when converting x/y coords to a memory address)
paint_color:      .res 1
check_color:      .res 1
NorthStride:      .res 1
SouthStride:      .res 1
EastStride:       .res 1
WestStride:       .res 1
backtrack_color:  .res 1
NextDir:          .res 1
NeighbourCount:   .res 1
StackPtr:         .res 2

;******************************************************************
.segment "ONCE"
.segment "CODE"
.org $080D

; PETSCII
SPACE             = $20
CLR               = $93
HOME              = $13
CHAR_Q            = $51

; Colors
BLACK             = 0
WHITE             = 1
RED               = 2
GREEN             = 5
LTGREEN           = 13
LTGREY            = 12

   jmp start  ; jump to the main code routine


; Add any includes here
.include "INC\x16.inc"  ; Standard X16 variables and macros

;******************************************************************
; main code routine starts here
;******************************************************************
start:
   ; Switch to 320x240 256-colour graphics mode.
   ; A = $80, carry clear = set mode.
   lda #$80
   clc
   jsr SCREEN_MODE

   jsr ClearScreen

   jsr DrawMaze

   ;pause before solving
   lda #$00
@pauseLoop:
   jsr delay
   dec
   bne @pauseLoop

   jsr SolveMaze

@waitExit:
   ; check for user input
   jsr GETIN
   cmp #CHAR_Q
   bne @waitExit ; Q was pressed
   rts

; ------------------------------------------------------------------
; MAIN PROGRAM LOOPS
; ------------------------------------------------------------------

DrawMaze:
   ;Set Start Pos at top left of screen (1,1)
   lda #$01
   sta XPos
   sta YPos
   lda #$00
   sta XPos+1
   
   ; Initialise the Stack Pointer
   lda #<stackBase
   sta StackPtr
   lda #>stackBase
   sta StackPtr + 1

   ; set path checking colours
   lda #(BLACK)
   sta check_color
   lda #(WHITE)
   sta backtrack_color

   ; set stride for checkNeighbours 
   lda #%11111000  ; (11101000) stride = -640, bank
   sta NorthStride
   lda #%11110000  ; (11100000) stride = 640, bank
   sta SouthStride
   lda #%00100000  ; (00010000) stride = 2, bank
   sta EastStride
   lda #%00101000  ; (00011000) stride = -2, bank
   sta WestStride

   ; Make the first move
   lda #(WHITE)
   sta paint_color
   jsr paint_cell

   jsr moveSouth

draw_loop:
   jsr getNextDir

   ; check if the move is possible
   lda NextDir
   bne @checkSouth
   ; Look North
   lda YPos
   cmp #$01    ;are we at the top border? 
   beq @next
   jsr lookNorth ; are we able to make a move to the North?
   bne @next
   lda #(WHITE)
   sta paint_color
   jsr moveNorth
   bra @next
@checkSouth:
   lda NextDir
   cmp #$01
   bne @checkEast
   ; Look South
   lda YPos
   cmp #$ED   ;are we at the bottom border (y=237)? 
   beq @next
   jsr lookSouth
   bne @next
   lda #(WHITE)
   sta paint_color
   jsr moveSouth
   bra @next
@checkEast:
   lda NextDir
   cmp #$02
   bne @checkWest
   ; Look East
   lda XPos+1
   beq @contEast ; if XPos+1=0, we're not near the right border
   lda XPos
   cmp #$3D   ;are we at the right border (x=317)? 
   beq @next
@contEast:
   jsr lookEast
   bne @next
   lda #(WHITE)
   sta paint_color
   jsr moveEast
   bra @next
@checkWest:
   ; Look West
   lda XPos+1
   bne @contWest ; if XPos+1<>0, we're not near the left border
   lda XPos
   cmp #$01   ;are we at the left border? 
   beq @next
@contWest:
   jsr lookWest
   bne @next
   lda #(WHITE)
   sta paint_color
   jsr moveWest
   bra @next

@next:
   ;jsr delay
   jsr checkNeighbourCount
   ; Check if the stack is empty (maze complete?)
   lda StackPtr
   cmp #<stackBase
   bne @nextLoop
   lda StackPtr + 1
   cmp #>stackBase
   bne @nextLoop
   ; done
   bra @exit
@nextLoop:
   ; check for user input
   jsr GETIN
   cmp #CHAR_Q
   beq @exit ; Q was pressed
   jmp draw_loop

@exit:
   jsr drawStartFinish
   rts


SolveMaze:
   ;Set Start Pos at top left of screen (1,1)
   lda #$01
   sta XPos
   sta YPos
   lda #$00
   sta XPos+1
   
   ; Initialise the Stack Pointer
   lda #<stackBase
   sta StackPtr
   lda #>stackBase
   sta StackPtr + 1

   ; set path checking colours
   lda #(WHITE)
   sta check_color
   lda #(LTGREY)
   sta backtrack_color

   ; set stride for checkNeighbours 
   lda #%11101000  ; (11101000) stride = -320, bank
   sta NorthStride
   lda #%11100000  ; (11100000) stride = 320, bank
   sta SouthStride
   lda #%00010000  ; (00010000) stride = 1, bank
   sta EastStride
   lda #%00011000  ; (00011000) stride = -1, bank
   sta WestStride

   ; Make the first move
   lda #(LTGREEN)
   sta paint_color
   jsr paint_cell

   jsr moveSouth

solve_Loop:
   jsr lookEast
   cmp #(WHITE)
   bne @checkPathSouth
   lda #(LTGREEN)
   sta paint_color
   jsr moveEast
   bra @nextPath
@checkPathSouth:
   jsr lookSouth
   cmp #(WHITE)
   bne @checkPathNorth
   lda #(LTGREEN)
   sta paint_color
   jsr moveSouth
   bra @nextPath
@checkPathNorth:
   jsr lookNorth
   cmp #(WHITE)
   bne @checkPathWest
   lda #(LTGREEN)
   sta paint_color
   jsr moveNorth
   bra @nextPath
@checkPathWest:
   jsr lookWest
   cmp #(WHITE)
   bne @checkPathWest
   lda #(LTGREEN)
   sta paint_color
   jsr moveWest
   bra @nextPath

@nextPath:
   jsr delay
   jsr checkNeighbourCount
   ; Check if the stack is empty (hopefully the stack will never be empty)
   lda StackPtr
   cmp #<stackBase
   bne @nextPathLoop
   lda StackPtr + 1
   cmp #>stackBase
   bne @nextPathLoop
   ; done
   bra @solve_exit
@nextPathLoop:
   ; check if we are at the finish
   jsr checkFinished
   cmp #$FF
   beq @solve_exit
@checkUserInput:
   ; check for user input
   jsr GETIN
   cmp #CHAR_Q
   beq @solve_exit ; Q was pressed
   jmp solve_Loop

@solve_exit:
   rts

;******************************************************************
; SUBROUTINES
;******************************************************************


checkFinished:
   ; check if we are at the finish
   ; returns $FF if we are at the finish
   lda YPos
   cmp #$ED
   bne @checkFinishedDone
   lda XPos + 1
   beq @checkFinishedDone
   lda XPos
   cmp #$3D
   bne @checkFinishedDone
   lda #$FF
@checkFinishedDone:
   rts

getNextDir:
   ; NextDir Values:
   ; 0=North
   ; 1=South
   ; 2=East
   ; 3=West
   jsr ENTROPY_GET
   and #%00000011    ; only want four directions (N/S/E/W)
   sta NextDir
   rts

lookNorth:
   ; Starting at XPos and YPos, look north and return the cell colour
   jsr getPixelAddr       
   stz VERA_ctrl   
   lda PixelAddr+2
   ora NorthStride
   sta VERA_addr_bank
   lda PixelAddr+1
   sta VERA_addr_high 
   lda PixelAddr
   sta VERA_addr_low 
   lda VERA_data0   
   lda VERA_data0 
   rts

lookSouth:
   ; Starting at XPos and YPos, look south and return the cell colour
   jsr getPixelAddr    
   stz VERA_ctrl   
   lda PixelAddr+2
   ora SouthStride
   sta VERA_addr_bank
   lda PixelAddr+1
   sta VERA_addr_high 
   lda PixelAddr
   sta VERA_addr_low 
   lda VERA_data0   
   lda VERA_data0 
   rts

lookEast:
   ; Starting at XPos and YPos, look south and return the cell colour
   jsr getPixelAddr
   stz VERA_ctrl   
   lda PixelAddr+2
   ora EastStride
   sta VERA_addr_bank
   lda PixelAddr+1
   sta VERA_addr_high 
   lda PixelAddr
   sta VERA_addr_low 
   lda VERA_data0 
   lda VERA_data0 
   rts

lookWest:
   ; Starting at XPos and YPos, look south and return the cell colour
   jsr getPixelAddr
   stz VERA_ctrl   
   lda PixelAddr+2
   ora WestStride
   sta VERA_addr_bank
   lda PixelAddr+1
   sta VERA_addr_high 
   lda PixelAddr
   sta VERA_addr_low  
   lda VERA_data0 
   lda VERA_data0 
   rts

moveNorth:
   ; move two cells north
   lda YPos
   sec
   sbc #$01
   sta YPos
   jsr paint_cell
   lda YPos
   sec
   sbc #$01
   sta YPos
   jsr paint_cell
   jsr pushStack
   rts

moveSouth:
   ; move two cells south
   lda YPos
   clc
   adc #$01
   sta YPos
   jsr paint_cell
   lda YPos
   clc
   adc #$01
   sta YPos
   jsr paint_cell
   jsr pushStack
   rts

moveEast:
   ; move two cells east
   lda XPos
   clc
   adc #$01
   sta XPos
   lda XPos + 1
   adc #$00
   sta XPos + 1
   jsr paint_cell
   lda XPos
   clc
   adc #$01
   sta XPos
   lda XPos + 1
   adc #$00
   sta XPos + 1
   jsr paint_cell
   jsr pushStack
   rts

moveWest:
   ; move two cells west
   lda XPos
   sec
   sbc #$01
   sta XPos
   lda XPos + 1
   sbc #$00
   sta XPos +1
   jsr paint_cell
   lda XPos
   sec
   sbc #$01
   sta XPos
   lda XPos + 1
   sbc #$00
   sta XPos + 1
   jsr paint_cell
   jsr pushStack
   rts


paint_cell: 
   ; Input: XPos/YPos = text map coordinates
   ; Input: paint_color
   jsr getPixelAddr
   stz VERA_ctrl
   lda PixelAddr + 2 ; stride = 0, bank
   sta VERA_addr_bank
   lda PixelAddr + 1
   sta VERA_addr_high 
   lda PixelAddr
   sta VERA_addr_low 
   lda paint_color
   sta VERA_data0
   rts

ClearScreen:
   ; ------------------------------------------------------------------
   ; Clear the screen to black (colour index 0).
   ;
   ; Use VERA auto-increment (stride 1) to stream 76 800 zero bytes
   ; (320 × 240) into VRAM starting at $00000.
   ; 76 800 = 300 pages of 256 bytes; outer counter is 16-bit ($012C).
   ; ------------------------------------------------------------------
   stz VERA_ctrl
   lda #$10             ; bank 0, stride 1 (auto-increment each write)
   sta VERA_addr_bank
   lda #0
   sta VERA_addr_high
   sta VERA_addr_low

   lda #$01             ; outer count high byte  (300 = $012C)
   sta cnt_hi
   lda #$2C             ; outer count low  byte
   sta cnt_lo

@clear_outer:
   ldy #0               ; inner counter: 256 bytes per page
@clear_inner:
   lda #0
   sta VERA_data0       ; write black pixel; VERA auto-advances address
   dey
   bne @clear_inner

   ; decrement 16-bit outer counter
   lda cnt_lo
   bne :+
   dec cnt_hi
:  dec cnt_lo
   lda cnt_lo
   ora cnt_hi
   bne @clear_outer

   rts


checkNeighbourCount:
   ; Input: XPos/YPos = text map coordinates
   stz NeighbourCount
@North:
   lda YPos
   cmp #$01    ;are we at the top? 
   beq @incNorthCount
   jsr lookNorth
   cmp check_color
   beq @East
@incNorthCount:
   inc NeighbourCount ; increment the count
@East:
   lda XPos+1
   beq @contCountEast ; if XPos+1=0, we're not near the right border
   lda XPos
   cmp #$3D   ;are we at the right border (x=317)? 
   beq @incEastCount
@contCountEast:
   jsr lookEast
   cmp check_color
   beq @South
@incEastCount:
   inc NeighbourCount ; increment the count
@South:   
   lda YPos
   cmp #$ED   ;are we at the bottom border (y=237)? 
   beq @incSouthCount
   jsr lookSouth
   cmp check_color
   beq @West
@incSouthCount:
   inc NeighbourCount ; increment the count
@West:
   lda XPos+1
   bne @contCountWest ; if XPos+1<>0, we're not near the left border
   lda XPos
   cmp #$01   ;are we at the left border? 
   beq @incWestCount
@contCountWest:
   jsr lookWest
   cmp check_color
   beq @done
@incWestCount:
   inc NeighbourCount ; increment the count
@done:
   lda NeighbourCount
   cmp #$04       ; four neighbours would indicate we are at a dead end
   bne @checkNeighboursEnd
   ; No more moves
   lda check_color
   beq @backtrack  ;skip checking for the finish if we are in draw mode
   ; check if we are at the finish
   jsr checkFinished
   cmp #$FF
   beq @checkNeighboursEnd
@backtrack:
   jsr popStack   ; backtrack to the previous position
   ldx XPos
   ldy YPos
   lda backtrack_color
   sta paint_color
   jsr paint_cell
   ; Check if the stack is empty
   lda StackPtr
   cmp #<stackBase
   bne checkNeighbourCount
   lda StackPtr + 1
   cmp #>stackBase
   bne checkNeighbourCount

@checkNeighboursEnd:
   rts


pushStack:
   ; Push the X and Y co-ordinates of the current position to the stack
   lda XPos
   sta (StackPtr)
   clc
   lda StackPtr
   adc #$01
   sta StackPtr
   lda StackPtr + 1
   adc #$00
   sta StackPtr + 1
   lda XPos + 1
   sta (StackPtr)
   clc
   lda StackPtr
   adc #$01
   sta StackPtr
   lda StackPtr + 1
   adc #$00
   sta StackPtr + 1
   lda YPos
   sta (StackPtr)
   clc
   lda StackPtr
   adc #$01
   sta StackPtr
   lda StackPtr + 1
   adc #$00
   sta StackPtr + 1
   rts


popStack:
   ; Pop the Y and X co-ordinates of the previous position from the stack
   ; (backtrack to the previous location on the path)
   sec
   lda StackPtr
   sbc #$01
   sta StackPtr
   lda StackPtr + 1
   sbc #$00
   sta StackPtr + 1 
   lda (StackPtr)
   sta YPos
   sec
   lda StackPtr
   sbc #$01
   sta StackPtr
   lda StackPtr + 1
   sbc #$00
   sta StackPtr + 1 
   lda (StackPtr)
   sta XPos + 1
   sec
   lda StackPtr
   sbc #$01
   sta StackPtr
   lda StackPtr + 1   
   sbc #$00
   sta StackPtr + 1 
   lda (StackPtr)
   sta XPos
   lda #(RED)
   sta paint_color
   ldx XPos
   ldy YPos
   jsr paint_cell
   lda backtrack_color ; provides a short delay when drawing and a long delay when solving
   ;lda #$07
@popDelay:
   jsr delay
   dec
   bne @popDelay
   rts


getPixelAddr:
   ; Input: XPos/YPos = text map coordinates
   ; Output: PixelAddr
   lda YPos
   cmp #$cd
   bcs @getBank1Pixel ; YPos >= $CD (205)
   ; multiply Ypos x 2
   asl
   bcs @getBank0BPixel
   tay
   ;Y should now point to the correct index row in the YBaseAddrTable
   stz PixelAddr+2
   lda YBaseAddrTableB0A,y
   sta PixelAddr+1
   iny
   lda YBaseAddrTableB0A,y
   sta PixelAddr
   jmp @addX
@getBank0BPixel:
   tay
   ;Y should now point to the correct index row in the YBaseAddrTable
   stz PixelAddr+2
   lda YBaseAddrTableB0B,y
   sta PixelAddr+1
   iny
   lda YBaseAddrTableB0B,y
   sta PixelAddr
   jmp @addX
@getBank1Pixel:
   lda YPos
   sec
   sbc #$cd
  ; multiply Ypos x 2
   asl
   tay
   ;Y should now point to the correct index row in the YBaseAddrTable
   lda #$01
   sta PixelAddr+2
   lda YBaseAddrTableB1,y
   sta PixelAddr+1
   iny
   lda YBaseAddrTableB1,y
   sta PixelAddr
@addX:
   clc
   lda PixelAddr
   adc XPos
   sta PixelAddr
   lda PixelAddr+1
   adc XPos+1
   sta PixelAddr+1
   lda PixelAddr+2
   adc #$00
   sta PixelAddr+2
   rts 


drawStartFinish:
   ; Paint the start green
   lda #(GREEN)
   sta paint_color
   stz YPos
   stz XPos
   stz XPos + 1
   jsr paint_cell
   inc XPos
   jsr paint_cell
   inc YPos
   ;jsr paint_cell
   dec XPos
   jsr paint_cell
   ; Paint the finish red
   lda #(RED)
   sta paint_color
   lda #$ED
   sta YPos
   lda #$3D
   sta XPos
   lda #$01
   sta XPos + 1
   ;jsr paint_cell
   inc XPos
   jsr paint_cell
   inc YPos
   jsr paint_cell
   dec XPos
   jsr paint_cell
   rts


delay:                  ; Standard issue delay loop
   pha
   lda #$3f
@delayloop_outer:
   pha
   lda #$ff
@delayloop_inner:
   dec
   bne @delayloop_inner
   pla
   dec   
   bne @delayloop_outer
   pla
   rts


; This lookup table is used by the getPixelAddr subroutine
; Each row represents the address of the left-most pixel of each row
; There are 240 rows
YBaseAddrTableB0A:
   .byte $00,$00
   .byte $01,$40
   .byte $02,$80
   .byte $03,$C0
   .byte $05,$00
   .byte $06,$40
   .byte $07,$80
   .byte $08,$C0
   .byte $0A,$00
   .byte $0B,$40
   .byte $0C,$80
   .byte $0D,$C0
   .byte $0F,$00
   .byte $10,$40
   .byte $11,$80
   .byte $12,$C0
   .byte $14,$00
   .byte $15,$40
   .byte $16,$80
   .byte $17,$C0
   .byte $19,$00
   .byte $1A,$40
   .byte $1B,$80
   .byte $1C,$C0
   .byte $1E,$00
   .byte $1F,$40
   .byte $20,$80
   .byte $21,$C0
   .byte $23,$00
   .byte $24,$40
   .byte $25,$80
   .byte $26,$C0
   .byte $28,$00
   .byte $29,$40
   .byte $2A,$80
   .byte $2B,$C0
   .byte $2D,$00
   .byte $2E,$40
   .byte $2F,$80
   .byte $30,$C0
   .byte $32,$00
   .byte $33,$40
   .byte $34,$80
   .byte $35,$C0
   .byte $37,$00
   .byte $38,$40
   .byte $39,$80
   .byte $3A,$C0
   .byte $3C,$00
   .byte $3D,$40
   .byte $3E,$80
   .byte $3F,$C0
   .byte $41,$00
   .byte $42,$40
   .byte $43,$80
   .byte $44,$C0
   .byte $46,$00
   .byte $47,$40
   .byte $48,$80
   .byte $49,$C0
   .byte $4B,$00
   .byte $4C,$40
   .byte $4D,$80
   .byte $4E,$C0
   .byte $50,$00
   .byte $51,$40
   .byte $52,$80
   .byte $53,$C0
   .byte $55,$00
   .byte $56,$40
   .byte $57,$80
   .byte $58,$C0
   .byte $5A,$00
   .byte $5B,$40
   .byte $5C,$80
   .byte $5D,$C0
   .byte $5F,$00
   .byte $60,$40
   .byte $61,$80
   .byte $62,$C0
   .byte $64,$00
   .byte $65,$40
   .byte $66,$80
   .byte $67,$C0
   .byte $69,$00
   .byte $6A,$40
   .byte $6B,$80
   .byte $6C,$C0
   .byte $6E,$00
   .byte $6F,$40
   .byte $70,$80
   .byte $71,$C0
   .byte $73,$00
   .byte $74,$40
   .byte $75,$80
   .byte $76,$C0
   .byte $78,$00
   .byte $79,$40
   .byte $7A,$80
   .byte $7B,$C0
   .byte $7D,$00
   .byte $7E,$40
   .byte $7F,$80
   .byte $80,$C0
   .byte $82,$00
   .byte $83,$40
   .byte $84,$80
   .byte $85,$C0
   .byte $87,$00
   .byte $88,$40
   .byte $89,$80
   .byte $8A,$C0
   .byte $8C,$00
   .byte $8D,$40
   .byte $8E,$80
   .byte $8F,$C0
   .byte $91,$00
   .byte $92,$40
   .byte $93,$80
   .byte $94,$C0
   .byte $96,$00
   .byte $97,$40
   .byte $98,$80
   .byte $99,$C0
   .byte $9B,$00
   .byte $9C,$40
   .byte $9D,$80
   .byte $9E,$C0

YBaseAddrTableB0B:
   .byte $A0,$00
   .byte $A1,$40
   .byte $A2,$80
   .byte $A3,$C0
   .byte $A5,$00
   .byte $A6,$40
   .byte $A7,$80
   .byte $A8,$C0
   .byte $AA,$00
   .byte $AB,$40
   .byte $AC,$80
   .byte $AD,$C0
   .byte $AF,$00
   .byte $B0,$40
   .byte $B1,$80
   .byte $B2,$C0
   .byte $B4,$00
   .byte $B5,$40
   .byte $B6,$80
   .byte $B7,$C0
   .byte $B9,$00
   .byte $BA,$40
   .byte $BB,$80
   .byte $BC,$C0
   .byte $BE,$00
   .byte $BF,$40
   .byte $C0,$80
   .byte $C1,$C0
   .byte $C3,$00
   .byte $C4,$40
   .byte $C5,$80
   .byte $C6,$C0
   .byte $C8,$00
   .byte $C9,$40
   .byte $CA,$80
   .byte $CB,$C0
   .byte $CD,$00
   .byte $CE,$40
   .byte $CF,$80
   .byte $D0,$C0
   .byte $D2,$00
   .byte $D3,$40
   .byte $D4,$80
   .byte $D5,$C0
   .byte $D7,$00
   .byte $D8,$40
   .byte $D9,$80
   .byte $DA,$C0
   .byte $DC,$00
   .byte $DD,$40
   .byte $DE,$80
   .byte $DF,$C0
   .byte $E1,$00
   .byte $E2,$40
   .byte $E3,$80
   .byte $E4,$C0
   .byte $E6,$00
   .byte $E7,$40
   .byte $E8,$80
   .byte $E9,$C0
   .byte $EB,$00
   .byte $EC,$40
   .byte $ED,$80
   .byte $EE,$C0
   .byte $F0,$00
   .byte $F1,$40
   .byte $F2,$80
   .byte $F3,$C0
   .byte $F5,$00
   .byte $F6,$40
   .byte $F7,$80
   .byte $F8,$C0
   .byte $FA,$00
   .byte $FB,$40
   .byte $FC,$80
   .byte $FD,$C0
   .byte $FF,$00

YBaseAddrTableB1:
   .byte $00,$40
   .byte $01,$80
   .byte $02,$C0
   .byte $04,$00
   .byte $05,$40
   .byte $06,$80
   .byte $07,$C0
   .byte $09,$00
   .byte $0A,$40
   .byte $0B,$80
   .byte $0C,$C0
   .byte $0E,$00
   .byte $0F,$40
   .byte $10,$80
   .byte $11,$C0
   .byte $13,$00
   .byte $14,$40
   .byte $15,$80
   .byte $16,$C0
   .byte $18,$00
   .byte $19,$40
   .byte $1A,$80
   .byte $1B,$C0
   .byte $1D,$00
   .byte $1E,$40
   .byte $1F,$80
   .byte $20,$C0
   .byte $22,$00
   .byte $23,$40
   .byte $24,$80
   .byte $25,$C0
   .byte $27,$00
   .byte $28,$40
   .byte $29,$80
   .byte $2A,$C0


stackBase:   ; the bottom of the tracking stack
