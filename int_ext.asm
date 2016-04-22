;------------------------------------------------------------------
; AVR - Configuración y manejo de interrupción externa 0
;------------------------------------------------------------------
; Atmega328p, clock interno 8MHz, fusibles: E:0xFF H:0xE9 L:0x62
;------------------------------------------------------------------
.include "m328pdef.inc"	; definición de registros, bits y constantes del micro 
.include "avr_macros.inc" ; macros

;------------------------------------------------------------------
; periféricos
;------------------------------------------------------------------
.equ	LED_VE = 2	; Cátodo del LED en B.2 (se prende con 0)
.equ	PULSADOR = 2 	; Apretar el pulsador hace que pinD.2==0 y
			; al soltarlo el pull-up lleva a pinD.2==1

;------------------------------------------------------------------
; variables de registro
;------------------------------------------------------------------
.def	t0	= r16
.def	t1	= r17
.def	t2	= r18
.def	t3	= r19

;------------------------------------------------------------------
; codigo
;------------------------------------------------------------------
		.cseg
		rjmp	RESET			; interrupción del reset

		.org	INT0addr
		rjmp	ISR_INT_EXT_0	; ocurre flanco de bajada en pulsador

;------------------------------------------------------------------
; programa principal
;------------------------------------------------------------------
		.org INT_VECTORS_SIZE	; (salteo todos los vectores de int)
RESET:
		ldi	t0,HIGH(RAMEND)	; inicializo stack
		out	SPH,t0
		ldi	t0,LOW(RAMEND)
		out	SPL,t0

		sbi	DDRB,LED_VE		; B.LED_VE es una salida
		sbi	PORTB,LED_VE	; LED apagado

		cbi	DDRD,PULSADOR 	; pin_D.PULSADOR es entrada del micro
		sbi	PORTB,PULSADOR	; conecto resistor de pull-up (al soltar 
								; pulsador, el pinD.PULSADOR va a VCC).

		input	t0,EICRA		; configuro int. ext. 0 x flanco de bajada
		andi	t0,~((1<<ISC01)|(1<<ISC00))
		ori	t0,(1<<ISC01)|(0<<ISC00)
		output	EICRA,t0		
		
		input	t0,EIMSK
		ori	t0,(1<<INT0)	; habilito int. externa 0
		output	EIMSK,t0

		sei			; habilitación global de interrupciones

X_SIEMPRE:	brts	PULSADOR_APRETADO
		rjmp	X_SIEMPRE	; si flag T==0, no pasa nada

PULSADOR_APRETADO:			; sino, alguien oprimió el pulsador
		clt			; limpio el evento (y lo proceso)
		rcall	DEMORA_100mS	; espero 100 mili-segundos

		sbic	PIND,PULSADOR	; miro el pinD.PULSADOR
		rjmp	X_SIEMPRE	; si volvió a uno antes de 100mS, es ruido

		in	t0,PORTB	; sino, se apretó el pulsador en serio
		ldi	t1,(1<<LED_VE)
		eor	t0,t1		; conmuto el estado del LED_VE
		out	PORTB,t0
		rjmp	X_SIEMPRE	; y vuelvo al ciclo principal del programa

;------------------------------------------------------------------
; fin del programa principal
;------------------------------------------------------------------

;------------------------------------------------------------------
; Rutina de servicio de interrupción externa 0.
; Al ocurrir un flanco de bajada (se oprime el pulsador, o rebotes)
; se devulve el flag SREG.T en 1.
;------------------------------------------------------------------
ISR_INT_EXT_0:
		set	; flag T <- 1
		reti	; re-habilitación global de int. y vuelve al prog.
			; principal 

;------------------------------------------------------------------
; Rutina de demora de 100 mili-segundos.
; (Todos los registros y flags usados se salvan en la pila)
;------------------------------------------------------------------
DEMORA_100mS:
		push	t0
		push	t1
		push	t2
		in	t0,SREG
		push	t0

		ldi	t0,26
bucle_0:	ldi	t1,101
bucle_1:	ldi	t2,101
bucle_2:	dec	t2
		brne	bucle_2
		
		dec	t1
		brne	bucle_1
		
		dec	t0
		brne	bucle_0

		pop	t0
		out	SREG,t0
		pop	t2
		pop	t1
		pop	t0
		ret
;------------------------------------------------------------------
; fin del código
;------------------------------------------------------------------
