.segment "STARTUP"
;******************************************************************
; 
;******************************************************************

.segment "ZEROPAGE"
;******************************************************************
; The KERNAL and BASIC reserve all the addresses from $0080-$00FF. 
; Locations $00 and $01 determine which banks of RAM and ROM are  
; visible in high memory, and locations $02 through $21 are the
; pseudoregisters used by some of the new KERNAL calls
; (r0 = $02+$03, r1 = $04+$05, etc)
; So we have $22 through $7f to do with as we please, which is 
; where .segment "ZEROPAGE" variables are stored.
;******************************************************************
; screen size: 80x60

.org $0022

; Zero Page
XPos:             .res 1
YPos:             .res 1

; Global Variables
paint_color:      .res 1
NextDir:          .res 1
NeighbourCount:   .res 1
StackPtr:         .res 2

.segment "INIT"
.segment "ONCE"
.segment "CODE"
.org $080D

   jmp start

.include "x16.inc"

; VERA
VSYNC_BIT         = $01

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

start:
   ; clear screen
   lda #CLR
   jsr CHROUT

   lda #SPACE
   jsr ClearScreen

   ; Initialise the Stack Pointer
   lda #<stackBase
   sta StackPtr
   lda #>stackBase
   sta StackPtr + 1

   ; Set starting pixel
   lda #$01
   sta XPos
   sta YPos
   jsr pushStack
   lda #(WHITE << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   jsr paint_cell

   ; make the first move
   jsr moveSouth

main_loop:

   jsr getNextDir

   ; check if the move is possible
   lda NextDir
   bne @checkSouth
   ; Look North
   ldx XPos
   lda YPos
   cmp #$01    ;are we at the top border? 
   beq @next
   sec
   sbc #$02
   tay
   jsr getCell
   bne @next
   jsr moveNorth
   bra @next
@checkSouth:
   lda NextDir
   cmp #$01
   bne @checkEast
   ; Look South
   ldx XPos
   lda YPos
   cmp #$39   ;are we at the bottom border? 
   beq @next
   clc
   adc #$02
   tay
   jsr getCell
   bne @next
   jsr moveSouth
   bra @next
@checkEast:
   lda NextDir
   cmp #$02
   bne @checkWest
   ; Look East
   lda XPos
   cmp #$4D   ;are we at the right border? 
   beq @next
   clc
   adc #$02
   tax
   ldy YPos
   jsr getCell
   bne @next
   jsr moveEast
   bra @next
@checkWest:
   ; Look West
   lda XPos
   cmp #$01   ;are we at the left border? 
   beq @next
   sec
   sbc #$02
   tax
   ldy YPos
   jsr getCell
   bne @next
   jsr moveWest
   bra @next

@next:
   jsr delay
   ldx XPos
   ldy YPos
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
   jmp main_loop

@exit:
   jsr drawBorder

@waitExit:
   ; check for user input
   jsr GETIN
   cmp #CHAR_Q
   bne @waitExit ; Q was pressed
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


moveNorth:
   ; move two cells north
   lda #(WHITE << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   dey 
   jsr paint_cell
   dey 
   jsr paint_cell
   sty YPos
   jsr pushStack
   rts

moveSouth:
   ; move two cells south
   lda #(WHITE << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   iny 
   jsr paint_cell
   iny 
   jsr paint_cell
   sty YPos
   jsr pushStack
   rts

moveEast:
   ; move two cells east
   lda #(WHITE << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   inx 
   jsr paint_cell
   inx 
   jsr paint_cell
   stx XPos
   jsr pushStack
   rts

moveWest:
   ; move two cells west
   lda #(WHITE << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   dex 
   jsr paint_cell
   dex 
   jsr paint_cell
   stx XPos
   jsr pushStack
   rts


paint_cell: 
   ; Input: X/Y = text map coordinates
   ; Input: paint_color
   phx
   phy
   stz VERA_ctrl
   lda #$01 ; stride = 0, bank 1
   sta VERA_addr_bank
   tya
   clc
   adc #$B0
   sta VERA_addr_high ; Y
   txa
   asl
   inc
   sta VERA_addr_low ; 2*X + 1
   lda paint_color
   sta VERA_data0
   ply
   plx
   rts

ClearScreen:
   ; Input: A contains the charcter to write to the screen
   ; Clear the screen to black
   pha
   stz VERA_ctrl
   lda #$11 ; stride = 1
   sta VERA_addr_bank
   lda #$B0
   sta VERA_addr_high
   stz VERA_addr_low
TOTALPIXELCOUNT = 63*128
   ldx #<TOTALPIXELCOUNT ; #$00 ;(0)
   ldy #>TOTALPIXELCOUNT ; #$20 ;(32)
@canvas_loop:
   pla
   sta VERA_data0
   pha
   lda #(BLACK << 4)
   sta VERA_data0
   dex
   bne @canvas_loop
   cpy #$00
   beq @EndClearScreen
   dey
   bra @canvas_loop
@EndClearScreen:
   pla
   rts


getCell: 
   ; Input: X/Y = text map coordinates
   ; Output: A = value of the tile
   stz VERA_ctrl
   lda #$01 ; stride = 0, bank 1
   sta VERA_addr_bank
   tya
   clc
   adc #$B0
   sta VERA_addr_high ; Y
   txa
   asl
   inc
   sta VERA_addr_low ; 2*X + 1
   lda VERA_data0   
   rts


checkNeighbourCount:
   ; Input: X/Y = text map coordinates
   ; Sets PaintColour for result
   stz NeighbourCount
@North:
   tya
   cmp #$01    ;are we at the top? 
   beq @incNorthCount
   dey
   dey
   jsr getCell
   iny
   iny
   cmp #(BLACK << 4)
   beq @East
@incNorthCount:
   inc NeighbourCount ; increment the count
@East:
   txa
   cmp #$4D    ;are we at the right side? 
   beq @incEastCount
   inx
   inx
   jsr getCell
   dex
   dex
   cmp #(BLACK << 4)
   beq @South
@incEastCount:
   inc NeighbourCount ; increment the count
@South:   
   tya
   cmp #$39   ;are we at the bottom? 
   beq @incSouthCount
   iny
   iny
   jsr getCell
   dey
   dey
   cmp #(BLACK << 4)
   beq @West
@incSouthCount:
   inc NeighbourCount ; increment the count
@West:
   txa
   cmp #$01    ;are we at the left side? 
   beq @incWestCount
   dex
   dex
   jsr getCell
   inx
   inx
   cmp #(BLACK << 4)
   beq @done
@incWestCount:
   inc NeighbourCount ; increment the count
@done:
   lda NeighbourCount
   cmp #$04       ; four neighbours would indicate we are at a dead end
   bne @checkNeighboursEnd
   ; No more moves
   jsr popStack   ; backtrack to the previous position
   ldx XPos
   ldy YPos
   lda #(WHITE << 4)
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
   sta XPos
   lda #(RED << 4)
   sta paint_color
   ldx XPos
   ldy YPos
   jsr paint_cell
   lda #$07
@popDelay:
   jsr delay
   dec
   bne @popDelay
   rts

drawBorder:
   ; set border
   lda #(WHITE << 4)
   sta paint_color
   ldx #$4F
   ldy #$3B
@btmBorder:
   jsr paint_cell
   dex
   bne @btmBorder
   jsr paint_cell
   ldx #$4F
@rtBorder:
   jsr paint_cell
   dey
   bne @rtBorder
   jsr paint_cell

   ;set red destination
   lda #(RED << 4)
   sta paint_color
   ldx #$4D
   ldy #$39
   jsr paint_cell
   ldx #$4E
   ldy #$39
   jsr paint_cell
   ldx #$4D
   ldy #$3A
   jsr paint_cell
   ldx #$4E
   ldy #$3A
   jsr paint_cell

   ;set green origin
   lda #(GREEN << 4)
   sta paint_color
   ldx #00
   ldy #00
   jsr paint_cell
   ldx #00
   ldy #01
   jsr paint_cell
   ldx #01
   ldy #00
   jsr paint_cell
   ldx #01
   ldy #01
   jsr paint_cell


delay:                  ; Standard issue delay loop
   pha
   lda #$7f
delayloop_outer:
   pha
   lda #$ff
delayloop_inner:
   dec
   bne delayloop_inner
   pla
   dec   
   bne delayloop_outer
   pla
   rts

stackBase:   ; the bottom of the tracking stack