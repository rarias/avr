;-------------------------------------------------------------------------
; AVR - Configuración y transmisión por puerto serie
; Tiene las rutinas 
;	RESET: programa principal para testear las rutinas
;	USART_init: configura el puerto serie para tx/rx por interrupciones
;	ISR_RX_USART_COMPLETA: rutina de servicio de interrupción de recepción
;	ISR_REG_USART_VACIO: rutina de serv. de int. de transmisión
;	TEST_TX: rutina de transmisión de prueba
;	TX_MSJ: rutina de transmisión genérica
;
; Ultima actualización: 2019-MAY-05 09:47
;-------------------------------------------------------------------------

;-------------------------------------------------------------------------
; MCU: ATmega8/ATmega328P 
; Según el entorno de desarrollo, el MCU (MicroController Unit) se elige
; a) desde Project->Properties se elige el microcontrolador
; b) con una directiva de include.
; En ambos casos se termina incluyendo un archivo m8def.inc/m328Pdef.inc
; que definen un símbolo _M8DEF_INC_/_M328PDEF_INC_ que se usa en toda
; este código para distinguir entre registros de uno y otro micro.
;-------------------------------------------------------------------------
; Si el modo de seleccionar el MCU es el b) descomentar el include que 
; corresponda:
;.include m8def.inc		; define los registros y constantes del Mega8
;.include m328Pdef.inc	; define los registros y constantes del Mega328P
;-------------------------------------------------------------------------

#define	F_CPU	16000000	; frecuencia del reloj del micro (F_SYS)

;-------------------------------------------------------------------------
; Puerto donde se conecta un LED
;-------------------------------------------------------------------------
; En una placa Arduino uno el led está en PINB.5 y se enciende con '1'
; para otros circuitos verificar la ubicación de algún led y definir lo 
; siguiente:
.equ	PORT_LED	= PORTB	; registro del puerto
.equ	DIR_LED		= DDRB	; registro de direcciones del puerto
.equ	LED			= 5		; nro. de bit (contando de 0 a 7=MSbit)
							; nota: En 1/0 prende/apaga LED

;-------------------------------------------------------------------------
; MACROS
;-------------------------------------------------------------------------
; Inclusión de macros.  El *.inc debe estar en la misma carpeta que los 
; demás archivos fuente o bien incluir un path al mismo mediante:
;	Project->Properties->Toolchain->AVR Assembler->General->Include Paths
.include "avr_macros.inc"	
.listmac					; permite ver las macros en el listado *.lss

;-------------------------------------------------------------------------
; CONSTANTES
;-------------------------------------------------------------------------
.equ	BUF_SIZE	= 64	; tamaño en bytes del buffer de transmisión
.equ	LF	= 13			; '\n' caracter ascii de incremento de línea
.equ	CR  = 10			; '\r' caracter ascii de retorno de carro

;-------------------------------------------------------------------------
; variables en SRAM
;-------------------------------------------------------------------------
		.dseg				; Segmento de datos (RAM)
TX_BUF:	.byte	BUF_SIZE	; buffer de transmisión serie
RX_BUF: .byte	BUF_SIZE	; buffer de recepción de datos por puerto serie
VERSION:.byte	1			; nro. de versión del programa

;-------------------------------------------------------------------------
; variables en registros
;-------------------------------------------------------------------------
.def	ptr_tx_L = r8		; puntero al buffer de datos a transmitir
.def	ptr_tx_H = r9
.def	bytes_a_tx = r10 	; nro. de bytes a transmitir desde el buffer
.def	bytes_recibidos = r11
.def	eventos = r12
.equ	RX_SERIE = 0

.def	t0	= r16			; variable global auxiliar
.def	t1	= r17			; variable global auxiliar

;-------------------------------------------------------------------------
; CODIGO
;-------------------------------------------------------------------------
		.cseg					; segmento de código (FLASH)
		rjmp	RESET			; interrupción del reset

		.org	URXCaddr		; USART, Rx Complete
		rjmp	ISR_RX_USART_COMPLETA
	
		.org	UDREaddr		; USART Data Register Empty
		rjmp	ISR_REG_USART_VACIO

		.org 	INT_VECTORS_SIZE ; salteo todos los vectores de interrupción
RESET:	
		ldi		r16,LOW(RAMEND)
		out 	spl,r16
		ldi 	r16,HIGH(RAMEND)
		out 	sph,r16			; inicialización del puntero a la pila

		sbi		DIR_LED, LED	; configuro como salida el puerto para manejar el LED
		sbi		PORT_LED, LED	; PRENDO el LED

		ldi		t0, 0x13
		sts		VERSION, t0		; versión actual de este módulo

		rcall	USART_init		; Configuro el puerto serie para tx/rx a 19.2 kbps
								; y habilito la interrupción de recepción de datos.

		sei						; habilitación global de todas las interrupciones

		rcall	TEST_TX			; transmite un mensaje de prueba

MAIN:							; Programa principal (bucle infinito)
		tst		eventos			; Pasó algo?
		breq	MAIN			;	nada

		mov		t0, eventos		;	ocurrió un evento: el bit encendido indica
		andi	t0, (1<<RX_SERIE)	;  el tipo de evento ocurrido.
		breq	MAIN			
	
	; Por ahora: sólo chequeo recepciones de tramas x puerto serie
		ldi		t0, ~(1<<RX_SERIE)
		and		eventos, t0		; Borro el flag del evento recepción 

		clr		bytes_recibidos ; esto no es muy prolijo y trae problemas

		lds		t0, RX_BUF		; miro el 1er caracter de la trama recibida
		cpi		t0, '1'
		brne	VER_SI_ES_CERO

		sbi		PORT_LED, LED	; Si recibió un '1', prende el LED
		rjmp	MAIN

VER_SI_ES_CERO:
		cpi		t0, '0'
		brne	MAIN

		cbi		PORT_LED, LED	; Si recibe un '0', apaga el LED
		rjmp	MAIN


;-------------------------------------------------------------------------
;					COMUNICACION SERIE
;-------------------------------------------------------------------------
#if	F_CPU == 8000000
.equ	BAUD_RATE	= 51	; 19.2 kbps e=0.2% 	@8MHz y U2X=1
#elif F_CPU == 16000000
.equ	BAUD_RATE	= 103	; 19.2 kbps  e=0.2% @16MHz y U2X=1
#else
.error "Falta calcular el baud rate para el F_CPU definido!"
#endif

;-------------------------------------------------------------------------
USART_init:
		push	t0
		push	t1
		pushw	X

#ifdef  _M328PDEF_INC_
		outi	UBRR0H, high(BAUD_RATE)
		outi	UBRR0L,low(BAUD_RATE)
		outi	UCSR0A, (1<<U2X0)
		; Trama: 8 bits de datos, sin paridad y 1 bit de stop, 
		outi 	UCSR0C,(0<<UPM01)|(0<<UPM00)|(0<<USBS0)|(0<<UCSZ02)|(1<<UCSZ01)|(1<<UCSZ00)
		; Configura los terminales de TX y RX; y habilita
		; 	únicamente la int. de recepción
		outi	UCSR0B,(1<<RXCIE0)|(1<<RXEN0)|(1<<TXEN0)|(0<<UDRIE0)
#else
		outi	UBRRH,high(BAUD_RATE)	; Velocidad de transmisión
		outi	UBRRL,low(BAUD_RATE)
		outi	UCSRA,(1<<U2X)			; Modo asinc., doble velocidad
		outi 	UCSRC,(1<<URSEL)|(0<<UPM1)|(0<<UPM0)|(0<<USBS)|(1<<UCSZ1)|(1<<UCSZ0)
		outi	UCSRB,(1<<RXCIE)|(1<<RXEN)|(1<<TXEN)|(0<<UDRIE)
#endif
		movi	ptr_tx_L,LOW(TX_BUF)	; inicializa puntero al 
		movi	ptr_tx_H,HIGH(TX_BUF)	; buffer de transmisión.
	
		ldiw	X,TX_BUF				; limpia BUF_SIZE posiciones 
		ldi		t1, BUF_SIZE			; del buffer de transmisión
		clr		t0
loop_limpia:
		st		X+,t0
		dec		t1
		brne	loop_limpia
					
		clr		bytes_a_tx		; nada pendiente de transmisión
		clr		bytes_recibidos	; nada recibido aún.

		popw	X
		pop		t1
		pop		t0
		ret


;-------------------------------------------------------------------------
; RECEPCION: Interrumpe cada vez que se recibe un byte x RS232.
;
; Recibe:	UDR (byte de dato)
; Devuelve: nada
;-------------------------------------------------------------------------
ISR_RX_USART_COMPLETA:
; EL registro UDR tiene un dato y debería ser procesado
		push	t0
		pushi	SREG
		pushw	Y

		ldiw	Y, RX_BUF
		add		YL, bytes_recibidos
		clr		t0
		adc		YH, t0

#ifdef  _M328PDEF_INC_
		input	t0,	UDR0
		output	UDR0, t0
#else
		input	t0, UDR
#endif
		st		Y, t0
		inc		bytes_recibidos
		ldi		t0, BUF_SIZE
		cp		bytes_recibidos, t0
		brlo	BUF_RX_CON_ESPACIO

		clr		bytes_recibidos		; error, se sobrepasó el espacio disponible 
									; para mensajes recibidos x puerto serie.
									; Debería informar al main (pero no lo hago).
BUF_RX_CON_ESPACIO:		
		ld		t0, Y
ACA:
		cpi		t0, LF
		brne	FIN_ISR_RX_USART

		ldi		t0,(1<<RX_SERIE)
		or		eventos, t0

FIN_ISR_RX_USART:
		popw	Y
		popi	SREG
		pop		t0
    	reti 

;------------------------------------------------------------------------
; TRANSMISION: interrumpe cada vez que puede transmitir un byte.
; Se transmiten "bytes_a_tx" comenzando desde la posición TX_BUF del
; buffer. Si "bytes_a_tx" llega a cero, se deshabilita la interrupción.
;
; Recibe: 	bytes_a_tx.
; Devuelve: ptr_tx_H:ptr_tx_L, y bytes_a_tx.
;------------------------------------------------------------------------
ISR_REG_USART_VACIO:		; UDR está vacío
		push	t0
		push	t1
		pushi	SREG
		pushw	X


		tst		bytes_a_tx	; hay datos pendientes de transmisión?
		breq	FIN_TRANSMISION

		movw	XL,ptr_tx_L	; Recupera puntero al próximo byte a tx.
		ld		t0,X+		; lee byte del buffer y apunta al

#ifdef  _M328PDEF_INC_
		output	UDR0, t0
#else
		output	UDR, t0		; sgte. dato a transmitir (en la próxima int.)
#endif

		cpi		XL,LOW(TX_BUF+BUF_SIZE)
		brlo	SALVA_PTR_TX
		cpi		XH,HIGH(TX_BUF+BUF_SIZE)
		brlo	SALVA_PTR_TX
		ldiw	X,TX_BUF	; ptr_tx=ptr_tx+1, (módulo BUF_SIZE)

SALVA_PTR_TX:
		movw	ptr_tx_L,XL	; preserva puntero a sgte. dato

		dec		bytes_a_tx	; Descuenta el nro. de bytes a tx. en 1
		brne	SIGUE_TX	; si quedan datos que transmitir
							;	vuelve en la próxima int.

FIN_TRANSMISION:			; si no hay nada que enviar,
#ifdef  _M328PDEF_INC_
		cbix	UCSR0B, UDRIE0
#else
		cbix	UCSRB,	UDRIE	; 	se deshabilita la interrupción.
#endif

sigue_tx:
		popw	X
		popi	SREG
		pop		t1
		pop		t0
		reti

;-------------------------------------------------------------------------
; TEST_TX: transmite el mensaje almacenado en memoria flash a partir
; de la dirección MSJ_TEST_TX que termina con 0x00 (el 0 no se transmite).
; Recibe: nada
; Devuelve: nada
;-------------------------------------------------------------------------
TEST_TX:
		pushw	Z
		push	t0

		ldiw	Z,(MSJ_TEST_TX*2)
		rcall	TX_MSJ

		pop		t0
		popw	Z
		ret

MSJ_TEST_TX:
;.db	"Puerto Serie Version 0.3 ",'\r','\n',0
.db		"Puerto Serie Version %"
.dw		VERSION		; dirección RAM de la variable (byte hexa) a tx
.db		'\r','\n',0,0	; el 2do cero completa un nro. par de bytes

;-------------------------------------------------------------------------
; TX_MSJ: transmite el mensaje almacenado en memoria flash a partir
; de la dirección que se pase en el puntero Z.   El mensaje debe termina 
; con 0x00 (el 0 no se transmite).
; 
; Recibe: Z (=r31|r30)
; Devuelve: bytes_a_tx > 0
; Habilita la int. de transmisión serie con ISR en ISR_REG_USART_VACIO().
;-------------------------------------------------------------------------
TX_MSJ:
			push	t0
			pushi	SREG
			pushw	X

			movw	XL, ptr_tx_L	; toma el último valor del puntero

COPIA_A_TX_BUF:
			lpm		t0,Z+			; y copia de flash a ram
			tst		t0				; si encuentra un 0x00 en el mensaje, termina
			breq	ACTIVA_TX_MSJ	;	de cargar el buffer en RAM e incia la transmisión.

; Si el carcter es '%' seguido de un nro. hexadecimal de 16 bits, toma el byte
; de esa dirección de RAM, lo convierte a ASCII y lo pone en el buffer de transmisión.
			cpi		t0, '%'
			brne	NO_HAY_VARIABLES

			pushw	Y
			lpm		YL, Z+
			lpm		YH, Z+
			ld		t0, Y
			rcall	BYTE_2_ASCII	; devuelve en r1|r0 el ascii del byte
			popw	Y

			st		X+, r1
			inc		bytes_a_tx

			mov		t0, r0
			cpi		XL, low(TX_BUF+BUF_SIZE)
			brlo	NO_HAY_VARIABLES
			cpi		XH, high(TX_BUF+BUF_SIZE)
			brlo	NO_HAY_VARIABLES
			ldiw	X, TX_BUF		; ptr_tx++ módulo BUF_SIZE

NO_HAY_VARIABLES:
			st		X+,t0
			inc		bytes_a_tx

			cpi		XL, low(TX_BUF+BUF_SIZE)
			brlo	COPIA_A_TX_BUF
			cpi		XH, high(TX_BUF+BUF_SIZE)
			brlo	COPIA_A_TX_BUF
			ldiw	X, TX_BUF		; ptr_tx++ módulo BUF_SIZE

			rjmp	COPIA_A_TX_BUF
	
ACTIVA_TX_MSJ:						; habilita la int. de tx
#ifdef  _M328PDEF_INC_
			sbix	UCSR0B, UDRIE0
#else
			sbix	UCSRB,	UDRIE
#endif

			popw	X
			popi	SREG
			pop		t0
			ret

;-------------------------------------------------------------------------
;  Recibe t0 y devuelve el ascii en r1|r0
;-------------------------------------------------------------------------
BYTE_2_ASCII:
			mov		r0,	t0
			andi	t0, 0xF0
			swap	t0
			cpi		t0, 0x0A
			brlo	sumo_30h
			subi	t0,	-0x07
sumo_30h:
			subi	t0,	-0x30
			mov		r1, t0

			mov		t0, r0
			andi	t0, 0x0F
			cpi		t0, 0x0A
			brlo	sumo_30h_bajo
			subi	t0,	-0x07		; sino 0x30+0x07
sumo_30h_bajo:
			subi	t0, -0x30		; if r1<=9, sumo 30
			mov		r0, t0
			ret
;-------------------------------------------------------------------------
; fin del código
;-------------------------------------------------------------------------
