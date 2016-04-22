;------------------------------------------------------------------
; colección de macros para microcontroladores AVR
;------------------------------------------------------------------
; Sintaxis:
; 	.macro NOMBRE_MACRO
; 		; cuerpo de la macro
;		; los parámetros de la macro se referencian como
;		; @0 (1er parámetro), @1 (2do parámetro), etc.
; 	.endm
;------------------------------------------------------------------

;------------------------------------------------------------------
; input: resuelve si usa "in"/"lds" según la dirección del registro
;        de E/S que se lee.
;------------------------------------------------------------------
.macro	input ; @0= destino {r0, ... , r31}
              ; @1= fuente I/0 ($0000-$FFFF)
.if	@1<0x40
	in	@0,@1	; si dir del reg de E/S <0x40 uso "in"
.else
	lds	@0,@1	; sino uso "lds"
.endif
.endm

;------------------------------------------------------------------
; output: resuelve si usa "out"/"sts" según la dirección del registro
;         de E/S que se escribe.
;------------------------------------------------------------------
.macro	output		; @0= destino I/O ($0000-$FFFF)
			; @1= fuente, cte o r0..r31
.if	@0<0x40
	out	@0,@1	; si dir del reg de E/S <0x40 uso "out"
.else
	sts	@0,@1	; sino uso "sts"
.endif
.endm
