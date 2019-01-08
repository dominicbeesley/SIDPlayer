        .setcpu "6502"
        
        .import play_screen
        .import menu_screen
        .import mulxy
        .exportzp zTMP1, zTMP2, zTMP3
        .export menu
        
zPTR            := $70                  ; general pointer        
zPTR2           := $72                  ; general pointer        
zA_TMP          := $74
zTMP0           := $75
zTMP1           := $76
zTMP2           := $77
zTMP3           := $78
zMSGTMPA        := $79
zCURTUNE        := $7A

zMOSBRKPTR      := $FD                  ; where MOS stores pointer to byte after brk
        
EVENTV          := $220
BRKV            := $202

OSBYTE          := $FFF4
OSASCI          := $FFE3
OSFILE          := $FFDD
OSCLI           := $FFF7
OSWRCH          := $FFEE
        
TUNE_INIT       := $19F8
TUNE_PLAY       := $19FA
TUNE_NUM        := $19FC
TUNE_BRKTAB     := $19FE
TUNE_CODE       := $1A00        

SID_COPY_BASE   := $0720
SID_BASE        := $FC20
        
        .segment "CODE0"
        
start:
                ; detect if a master and replace get char vector if necessary

                lda     #0
                ldx     #1
                jsr     OSBYTE
                cpx     #0
                beq     elk
                cpx     #3
                bcc     @sk1
     
                ; its a master setup char bit get vector
                lda     #<get_ch_bits_MA
                sta     vec_getchbits
                lda     #>get_ch_bits_MA
                sta     vec_getchbits + 1
                                
@sk1:
                jmp main

elk:
                ldx     #<str_elk
                ldy     #>str_elk
                jsr     OSCLI
str_elk:        .byte   "SIDPELK",13,0
str_coff:       .byte   23,0,10,32,0,0,0,0,0,0,$FF

coff:           ldx     #0
@l1:            lda     str_coff,X
                bmi     @s1
                jsr     OSWRCH
                inx
                bne     @l1
@s1:            rts

attack_tab:                     ; rough table of vsyncs until full attack acheived
                                ; todo make this 16 bit?
                .byte   255
                .byte   255
                .byte   255
                .byte   255
                .byte   128
                .byte   128
                .byte   85
                .byte   64
                .byte   52
                .byte   22
                .byte   11
                .byte   7
                .byte   5
                .byte   2
                .byte   1
                .byte   1

decay_tab:                      ; rough table of vsyncs until full attack acheived
                                ; todo make this 16 bit?
                .byte   255
                .byte   255
                .byte   128
                .byte   64
                .byte   42
                .byte   32
                .byte   26
                .byte   22
                .byte   17
                .byte   7
                .byte   4
                .byte   3
                .byte   2
                .byte   1
                .byte   1
                .byte   1


field_ctr:      .dword 0
old_eventv:     .word 0
old_field_ctr:  .byte 0
_scr_ptr:       .byte 0
_osfile_blk:    .res  18
_osfile_menu_m: .byte "M.MENU", 13

menu_sel:       .byte 0
menu_off:       .byte 0
menu_run:       .byte 0

vec_getchbits:  .word   get_ch_bits_BBC

get_ch_bits:    jmp     (vec_getchbits)

get_ch_bits_BBC:lda     (zPTR), y
                rts
get_ch_bits_MA: php
		sei
                lda     $F4
                pha
                ora     #$80
                sta     $FE30
                lda     zPTR + 1
                pha
                sec
                sbc     #$C0 - $89
                sta     zPTR + 1
                lda     (zPTR), Y
                sta     zMSGTMPA
                pla
                sta     zPTR + 1;                lda     $FE30
		pla
                sta     $FE30
                lda     zMSGTMPA
                plp
                rts

                
                

scrprt:         sta     zA_TMP          ; print a char
                txa
                pha
                ldx     _scr_ptr
                lda     zA_TMP
                sta     $7F20, x
                inx
                stx     _scr_ptr
                pla
                tax
                lda     zA_TMP
                rts

printbyte:      pha
                lsr a
                lsr a
                lsr a
                lsr a
                jsr printnibble
                pla
printnibble:    and     #$0F
                cmp     #$0A
                bcc     printb_num
                adc     #$06
printb_num:     adc     #$30
                jmp     scrprt
                
main:           ; mode 7
                lda     #22
                jsr     OSASCI
                lda     #7
                jsr     OSASCI

                ; cursor editing off
                lda     #4
                ldx     #1
                jsr     OSBYTE

                jsr     coff

                ; load menu data
                ldy     #0
                ldx     #18
                lda     #<_osfile_blk
                sta     zPTR
                lda     #>_osfile_blk
                sta     zPTR + 1
                lda     #0
                jsr     clr_blk
                
                lda     #<_osfile_menu_m
                sta     _osfile_blk
                lda     #>_osfile_menu_m
                sta     _osfile_blk + 1
                lda     #<menu
                sta     _osfile_blk + 2
                lda     #>menu
                sta     _osfile_blk + 3
                lda     #$FF
                ldx     #<_osfile_blk
                ldy     #>_osfile_blk
                jsr     OSFILE
                
                lda     #<menu_screen
                sta     zPTR
                lda     #>menu_screen
                sta     zPTR + 1
                jsr     unpack_screen


init_menu:
                lda     #0
                sta     menu_sel
                sta     menu_off
menu_loop:      jsr     show_men                

                lda     #$81
                ldx     #0
                ldy     #0
                jsr     OSBYTE
                cpy     #$1b
                beq     @men_esc
                cpx     #$8b
                beq     @men_up
                cpx     #$8a
                beq     @men_dn
                cpx     #13
                beq     @men_sel
                jmp     menu_loop
                
                
                
@men_esc:       lda     #126
                jsr     OSBYTE          ;acknowledge esc
                rts

@men_up:        dec     menu_sel
                bmi     @men_up_sk1
                jmp     menu_loop
@men_up_sk1:    lda     #0
                sta     menu_sel
                dec     menu_off
                bmi     @men_up_sk2
                jmp     menu_loop
@men_up_sk2:    sta     menu_off
                jmp     menu_loop

@men_dn:        inc     menu_sel
                lda     #9              ;entries on screen
                cmp     menu_sel
                bcc     @men_dn_sk1
                jmp     menu_loop
@men_dn_sk1:    sta     menu_sel
                lda     menu
                clc
                sbc     #9
                inc     menu_off
                cmp     menu_off
                bcc     @men_dn_sk2
                jmp     menu_loop
@men_dn_sk2:    sta     menu_off
                jmp     menu_loop
                
@men_sel:       clc
                lda     menu_sel
                adc     menu_off
                sta     menu_run        ; tune to play
                tax
                ldy     #42
                jsr     mulxy           ; menu_run *42
                sec                     ; add 1 to skip length byte
                txa
                adc     #<menu          ; add menu offset
                sta     zPTR
                tya
                adc     #>menu
                sta     zPTR + 1
                
                lda     #0              ; copy file name to start of screen
                sta     zPTR2
                lda     #$7C
                sta     zPTR2 + 1
                ldx     #10
                ldy     #0
@ll1:           lda     (zPTR),y
                sta     (zPTR2),y
                iny
                dex
                bne     @ll1
                lda     #13
                sta     $7c0a
                
                ; copy filename in zPTR to zPTR2
                
                ; clear osfile blk
                ldy     #0
                ldx     #18
                lda     #<_osfile_blk
                sta     zPTR
                lda     #>_osfile_blk
                sta     zPTR + 1
                lda     #0
                jsr     clr_blk
                
                lda     #0
                sta     _osfile_blk
                lda     #$7c
                sta     _osfile_blk + 1
                lda     #$F8
                sta     _osfile_blk + 2
                lda     #$19
                sta     _osfile_blk + 3
                lda     #$FF
                ldx     #<_osfile_blk
                ldy     #>_osfile_blk
                jsr     OSFILE

                lda	$19FD				; default song             
                jmp     start_tune
                
                

show_men:
                ; set zPTR to first menu screen position
                men_scr_start = $7C00 + 4 + 4 * 40
                lda     #<men_scr_start
                sta     zPTR
                lda     #>men_scr_start
                sta     zPTR + 1
                lda     #0
                sta     zTMP0
@lp1:           lda     menu_sel
                cmp     zTMP0
                beq     @sk_colour
                lda     #130    ; alpha green
                bne     @sk_colour2
@sk_colour:     lda     #129
@sk_colour2:    ldy     #0
                sta     (zPTR),y

                clc             ; check to see if we're past end of menu
                lda     zTMP0
                adc     menu_off
                cmp     menu
                bcs     @sk1
                
                
                
                tax
                ldy     #42     ; size of menu entry
                jsr     mulxy
                stx     zPTR2
                sty     zPTR2 + 1
                clc
                lda     #<(menu + 10)     ; note l0 to skip filename
                adc     zPTR2
                sta     zPTR2
                lda     #>(menu + 10)
                adc     zPTR2 + 1
                sta     zPTR2 + 1
                ldy     #1              ; skip colour / length byte
                ldx     #32
@lp2:           lda     (zPTR2), y
                sta     (zPTR), y
                iny
                dex
                bne     @lp2
                jmp     @sk2
                
                
@sk1:           ldy     #0
                ldx     #33
                lda     #32
                jsr     clr_blk
                
@sk2:           ; move to next screen line
                clc
                lda     #40
                adc     zPTR
                sta     zPTR
                lda     #0
                adc     zPTR + 1
                sta     zPTR + 1
                
                inc     zTMP0
                lda     #19
                cmp     zTMP0
                bcs     @lp1
                rts



show_sid_regs:
                ldx     #0                      ; print out SID registers to screen
                stx     _scr_ptr
@lp2:           lda     SID_COPY_BASE, X
                jsr     printbyte

                lda     #32
                jsr     scrprt
                
                cpx     #6
                beq     @ss1
                cpx     #13
                beq     @ss1
                cpx     #20
                beq     @ss1
                cpx     #24
                beq     @ss2
                bne     @ss3
@ss1:           lda     _scr_ptr
                adc     #18
                sta     _scr_ptr
                jmp     @ss3
@ss2:           lda     _scr_ptr
                adc     #27
                sta     _scr_ptr
                jmp     @ss3
@ss3:           inx
                cpx     #25
                bne     @lp2
                
@lp3:           lda     SID_BASE, X
                jsr     printbyte

                lda     #32
                jsr     scrprt
                inx
                cpx     #29
                bne     @lp3
                rts
                
show_freq_vol:
                lda     #<($7C00 + 5 + 1 * 40)      ; zPTR = line 1
                sta     zPTR
                lda     #>($7C00 + 5 + 1 * 40)      
                sta     zPTR + 1
                
                ldx     #0                     ; channel 0
                jsr     showfrq

                lda     #<($7C00 + 5 + 4 * 40)      ; zPTR = line 4
                sta     zPTR
                lda     #>($7C00 + 5 + 4 * 40)      
                sta     zPTR + 1
                
                ldx     #7                     ; channel 1
                jsr     showfrq

                lda     #<($7C00 + 5 + 7 * 40)      ; zPTR = line 7
                sta     zPTR
                lda     #>($7C00 + 5 + 7 * 40)      
                sta     zPTR + 1
                
                ldx     #14                      ; channel 2
                jsr     showfrq
                
                
                
                
                lda     #<($7C00 + 7 + 11 * 40)      ; zPTR = 7x11
                sta     zPTR
                lda     #>($7C00 + 7 + 11 * 40)      
                sta     zPTR + 1
                
                ldx     #0                      ; channel 0
                jsr     showvol

                lda     #<($7C00 + 19 + 11 * 40)      ; zPTR = 19x11
                sta     zPTR
                lda     #>($7C00 + 19 + 11 * 40)      
                sta     zPTR + 1
                
                ldx     #1                      ; channel 0
                jsr     showvol

                lda     #<($7C00 + 31 + 11 * 40)      ; zPTR = 19x11
                sta     zPTR
                lda     #>($7C00 + 31 + 11 * 40)      
                sta     zPTR + 1
                
                ldx     #2                      ; channel 0
                jmp     showvol

start_tune:
@sk1:                
                jsr     init_tune

                jsr     screen_play

                ; setup vectors
                sei                     ; disable interrupts while we mess with vectors
                ; Grab the EVENTV vector
                lda     EVENTV
                sta     old_eventv
                lda     EVENTV + 1
                sta     old_eventv + 1
                lda     #<eventv_trap
                sta     EVENTV
                lda     #>eventv_trap
                sta     EVENTV + 1
                              
                cli
                                              
                ; enable the vsync event
                lda     #14
                ldx     #4
                jsr     OSBYTE               
                
                ;jmp     tune_loop
                

tune_loop:      lda     field_ctr
@lp:            cmp     field_ctr
                beq     @lp             ; wait for vsync
                lda     field_ctr
                sta     old_field_ctr
                

                jsr     play_tune

                jsr     show_freq_vol                             
                                
                jsr     show_message                        
                                                               
                jsr     show_sid_regs

                        
                lda     #$81
                ldx     #0
                ldy     #0
                jsr     OSBYTE
                cpy     #$1b
                beq     tune_loop_esc
                bcs	@sknokey
                cpx	#'<'
                beq	tune_loop_song_prev
                cpx	#','
                beq	tune_loop_song_prev
                cpx	#'>'
                beq	tune_loop_song_next
                cpx	#'.'
                beq	tune_loop_song_next

@sknokey:


                jmp     tune_loop
                
tune_loop_song_prev:
		ldx	zCURTUNE
		cpx	#2
		bcc	tune_loop
		dex
		txa
		pha

		jsr	tune_stop

		pla
		jmp	start_tune

tune_loop_song_next:
		ldx	zCURTUNE
		cpx	$19FC
		bcs	tune_loop
		inx	
		txa
		pha

		jsr	tune_stop

		pla
		jmp	start_tune


tune_loop_esc:
                lda     #126
                jsr     OSBYTE          ;acknowledge esc

                jsr	tune_stop

                jmp     main

tune_stop:
                php
                sei

                lda     old_eventv
                sta     EVENTV
                lda     old_eventv+1
                sta     EVENTV+1

                lda     #13
                ldx     #4
                jsr     OSBYTE

                plp

                jmp	shut_up



play_tune:      jmp     (TUNE_PLAY)
init_tune:      sta	zCURTUNE
                tax
		dex
		txa
                jmp     (TUNE_INIT)
                
eventv_trap:
                cmp     #4              ; vsync
                bne     @sk
                inc     field_ctr       ; increment the field counter
                bne     @sk
                inc     field_ctr + 1
                bne     @sk
                inc     field_ctr + 2
                bne     @sk
                inc     field_ctr + 3
@sk:            jmp     (old_eventv)

oldgate:        .res    3                       ; 3 bytes storing old flags gate flags value
vol:            .res    3                       ; 3 byets storing old volume level

showvol:        stx     zTMP0
                txa
                asl
                adc     zTMP0
                asl
                adc     zTMP0                   ; * 7
                sta     zTMP1                   ; zTMP1 = ch * 7
                tax
                lda     SID_COPY_BASE + 4, x    ; channel X flags
                and     #1
                ldx     zTMP0
                cmp     oldgate, x
                beq     @sk1
                
                ; gate value changed - if to 1 set vol to max
                
                sta     oldgate, x
                cmp     #0
                beq     @sk1
                lda     #255
                sta     vol, x
                jmp     @sk2
                
@sk1:           ; gate stayed the same just do decay for now
                
                ldy     #0
                sty     zTMP2
                cmp     #0
                beq     @sk3
                ; get envelope sustain level                
                ldx     zTMP1
                lda     SID_COPY_BASE + 6,x
                and     #$F0
                ldx     zTMP0
                sta     zTMP2
                
@sk3:           lda     vol, x
                cmp     zTMP2
                beq     @sk2
                bcs     @sk4
                lda     zTMP2
                sta     vol, x
                jmp     @sk2
@sk4:                
                sec
                sbc     #5
                sta     vol, x
                
@sk2:           lsr     A
                lsr     A
                lsr     A
                lsr     A
                adc     #240
                sta     zTMP2
                
                ;shift old vol markers along one dot
                ldx     #5
                ldy     #3
@shlp1:         jsr     swapch
                dey
                jsr     swapch
                dey
                jsr     swapch
                dey
                jsr     swapch
                dey
                tya
                clc
                adc     #44             ; next line
                tay
                dex
                bne     @shlp1
                
                
                ldx     #5
                ldy     #0
@lp1:           lda     (zPTR),y        ; get old char
                and     #$4A
                ora     #$A0            ; keep right hand graphics bits and add 160 for gfx base
                inc     zTMP2           ; inc vol and see if overflows - set bits when it does
                bmi     @skd1
                ora     #$01
@skd1:          inc     zTMP2
                bmi     @skd2
                ora     #$04
@skd2:          inc     zTMP2
                bmi     @skd3
                ora     #$10
@skd3:          sta     (zPTR),y
                tya                     ; next line
                clc
                adc     #40
                tay
                dex
                bne     @lp1
                rts
                
swapch:         lda     (zPTR), y
                and     #$15            ;keep left most pixels
                asl     A               ;move to right
                sta     zTMP0
                and     #$20            ; if bit 32 is set shift to 64
                asl     A
                ora     zTMP0           ; we'll have an extra 32 bit left but no mind we or that later
                and     #$4A
                sta     zTMP0
                
                dey
                lda     (zPTR), y       ; get prev char
                and     #$4A            ; keep right most pixels
                lsr     A               ; move left
                sta     zTMP1
                and     #$20
                lsr     A
                ora     zTMP1
                and     #$15
                ora     zTMP0
                ora     #160
                iny
                sta     (zPTR), y
                rts

showfrq:        ; show freq, X points at SID channel base
                ; zPTR points at start of line to show
                txa
                pha
                lda     #32
                ldx     #32
                ldy     #0
                jsr     clr_blk
                ldx     #32
                ldy     #40
                jsr     clr_blk
                pla
                tax
                
                ; get sid freq and store in zTMP0,1
                lda     SID_COPY_BASE,X
                sta     zTMP0
                lda     SID_COPY_BASE + 1,X
                sta     zTMP1
                
                ldy     #$FF
                sec
@lp:            rol     zTMP0           ; roll freq left until carry out
                rol     zTMP1
                iny
                bcc     @lp
                sty     zTMP2           ; Y is octave (reverse)
                lda     #30
                asl     zTMP2           ; *2 for octave marker 2 chars long
                sbc     zTMP2
                bpl     @sk2
                lda     #0           
@sk2:           tay
                lda     #255
                sta     (zPTR),y
                iny
                sta     (zPTR),y

                lda     #181            ; vert bar
                lsr     zTMP1            ; get 5 bottom bits of TMP1 and show as note marker
                lsr     zTMP1
                lsr     zTMP1
                bcc     @sk1
                lda     #234            ; if carry move bar on one pixel
@sk1:           pha           

                clc
                lda     zTMP1
                adc     #40             ; next line
                tay

                pla

                sta     (zPTR),Y        ; store graphic
                rts
                
                
                
clr_blk:        sta     (zPTR), y
                iny
                dex
                bne     clr_blk
                rts
                
unpack_screen:  ; unpack a screen's worth of data (1000 bytes) from the RLE data in zPTR, RLE data is encoded as either straight bytes or <32 specifies a length, followed by the char to repeat
                lda     #$7C
                sta     zPTR2 + 1
                lda     #0
                sta     zPTR2
@lp1:           ldy     #0
                lda     (zPTR),y
                cmp     #32
                bcs     @sk1    ; >= 32 genuine char
                tax
                iny
                lda     (zPTR),y
                inc     zPTR
                bne     @sk11
                inc     zPTR + 1
                jmp     @sk11
                
@sk1:           ldx     #1
@sk11:          ldy     #0
@lp2:           sta     (zPTR2), y
                inc     zPTR2
                bne     @sk2
                inc     zPTR2 + 1
                bmi     @sk3
@sk2:           dex
                bne     @lp2
                inc     zPTR
                bne     @lp1
                inc     zPTR + 1
                bne     @lp1


@sk3:           rts
                
scroll:         ; before doing scroll check to see if left most chars are colour codes and if they are move into col2
                lda     $7C00 + 17 * 40 + 3
                cmp     #128
                bcc     @ssk1
                cmp     #160
                bcs     @ssk1
                sta     $7C00 + 17 * 40 + 2
                sta     $7C00 + 18 * 40 + 2
                sta     $7C00 + 19 * 40 + 2

@ssk1:          lda     #<($7C00 + 17 * 40 + 3)
                sta     zPTR
                lda     #>($7C00 + 17 * 40 + 3)
                sta     zPTR + 1
                lda     #<($7C00 + 17 * 40 + 4)
                sta     zPTR2
                lda     #>($7C00 + 17 * 40 + 4)
                sta     zPTR2 + 1
                ldx     #3
                stx     zTMP0
                ldy     #0
@lp1:           ldx     #36
                
@lp2:           lda     #0
                sta     zTMP3
                lda     (zPTR), y
                cmp     #160
                bcc     @colourcodeL
                and     #$4A
                lsr     A
                sta     zTMP2
                and     #$20
                lsr     A
                ora     zTMP2
                sta     zTMP2
                
@ccsk3:         lda     (zPTR2), y
                cmp     #160                    ;check to see if it's a colour code
                bcc     @colourcode
                and     #$15
                asl     A
                sta     zTMP1
                and     #$20
                asl     A
                ora     zTMP1
                bne     @blank_sk               
                lda     zTMP3                   ;if zTMP3 is not blank then keep colour code
                bne     @ccsk2
@blank_sk:      ora     zTMP2
@ccsk:          ora     #160
@ccsk2:         sta     (zPTR), Y
                
                iny
                dex
                bne     @lp2
                tya
                clc
                adc     #4
                tay
                dec     zTMP0
                bne     @lp1
                rts
                
@colourcodeL:   ; left char is a colour code
                sta     zTMP3                   ;store colour code in zTMP3
                lda     #0
                sta     zTMP2
                jmp     @ccsk3
                
@colourcode:    ; right char is a colour code - if the left char is blank copy it in
                pha
                lda     zTMP2
                bne     @ccsk_x   ; previous char not blank                
                pla               ; prev char is blank
                jmp     @ccsk2
                
@ccsk_x:        pla
                lda     zTMP2
                jmp     @ccsk
                
show_message:   jsr     scroll
                ldy     message_ptr
                lda     $19FE
                sta     zPTR2
                lda     $19FF
                sta     zPTR2 + 1
@aa:            lda     (zPTR2),y
                beq     @end
                bmi     @code

                sec                     ; make into index into C000 rom char table
                sbc     #32     
                ldx     #0
                stx     zPTR + 1

                asl     A
                rol     zPTR + 1
                asl     A
                rol     zPTR + 1
                asl     A
                rol     zPTR + 1

                sta     zPTR

                lda     #$C0
                clc
                adc     zPTR + 1
                sta     zPTR + 1
                
                ldy     #0              ; line
@lp1:           jsr     @getchbits
                sta     $7C00 + 17 * 40 + 39
                jsr     @getchbits
                sta     $7C00 + 18 * 40 + 39
                jsr     @getchbits
                and     #$AF
                sta     $7C00 + 19 * 40 + 39
                
                inc     message_col
                lda     #7
                cmp     message_col
                bcs     @x
@nextch:        lda     #0
                sta     message_col
                inc     message_ptr
                
@x:             rts
@end:           jsr     message_reset
                beq     @aa

@code:          ; control code - just output the char
                sta     $7C00 + 17 * 40 + 39
                sta     $7C00 + 18 * 40 + 39
                sta     $7C00 + 19 * 40 + 39
                inc     message_col
                lda     #4
                cmp     message_col
                bcc     @nextch
                rts                

                
@getchbits:     jsr     @shift_bmp
                lsr     A             
                lsr     A             
                lsr     A             
                lsr     A             
                lsr     A             
                lsr     A
                sta     zTMP0
                jsr     @shift_bmp
                lsr     A             
                lsr     A             
                lsr     A             
                lsr     A
                ora     zTMP0
                sta     zTMP0
                jsr     @shift_bmp
                lsr     A             
                lsr     A             
                ora     zTMP0                
                sta     zTMP0
                and     #$20
                asl     A
                ora     zTMP0
                ora     #160
                rts
                
                
@shift_bmp:
                ;lda     (zPTR), y       ; bitmap
                jsr     get_ch_bits
                iny
                ldx     message_col
@shlp1:         beq     @o
                asl     A
                dex
                jmp     @shlp1
@o:             and     #$80            ; keep left most bit
                asl     A
                bcc     @p
                ora     #$40
@p:             rts
                
message_reset:
                ldy     #0
                sty     message_ptr
                rts


screen_play:    lda     #<play_screen
                sta     zPTR
                lda     #>play_screen
                sta     zPTR + 1
                jsr     unpack_screen

                jsr     message_reset

                lda     #31
                jsr     OSWRCH
                lda     #30
                jsr     OSWRCH
                lda     #23
                jsr     OSWRCH

                lda     #132                            ;alpha blue
                jsr     OSWRCH

                ldx     zCURTUNE
                lda     #'<'
                cpx     #2
                bcs     @sge
                lda     #' '
@sge:           jsr     OSWRCH
                ldx     zCURTUNE
@lp:            txa
                clc
                adc     #'0'
                jsr     OSWRCH
                lda     #'>'
                ldx     zCURTUNE
                cpx     $19FC
                bcc     @slt2
                lda     #' '
@slt2:          jsr     OSWRCH
                
shut_up:        ldx     #23
                lda     #0
@1:             sta     SID_BASE, X
                dex
                bpl     @1
                rts
                
                
message_ptr:    .byte 0
message_col:    .byte 0         ; bit column(s) to shift in (0..7)
message:        .byte 145,"SIDPLAY",147," - hello world this is sid player.... A",145,"A",146,"A",147,"A",148,"A",149,"A",150,"A",151,"A",145,"A",145,"A",145,"A",145,"ooooooooo                   ",0                

menu:           .res  1261      ; menu space 1 byte contains number of tunes followed by 10 chars of filename, 32 chars title

                
                