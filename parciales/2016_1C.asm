;--------------------------------------------------------------
; 66.09 / 86.07 Labo. de Microcontroladores
; 2016 - 1er Cuatrimestre
; Examen parcial 1er Instancia 27-mayo-2016
;--------------------------------------------------------------
.include "m328def.inc"


		.cseg
		rjmp	INICIO


		.org	INT_VECTORS_SIZE

INICIO:	ldi		r20, 6
		ldi		r22, 18
		rcall	MULTIPLO

X_SIEMPRE:
		rjmp	X_SIEMPRE

;--------------------------------------------------------------
; Ejercicio 1: rutina A (r20) múltiplo de B (r22)
; Se supone que A y B son números sin signo.
; Si A y/o B son cero, no es múltiplo
; Se devuelve el fag T en 1 cuando A es múltiplo de B
;--------------------------------------------------------------
.def	A = r20
.def	B = r22
MULTIPLO:
		tst		A
		breq	NO_ES_MULT
		tst		B
		breq	NO_ES_MULT

BUCLE_MULTIPLO:
		sub		A, B
		brcs	NO_ES_MULT
		brne	BUCLE_MULTIPLO

		set		; T=1, A es múltiplo de B
FIN_MULT:
		ret

NO_ES_MULT:
		clt		; T=0, A no es múltiplo de B
		rjmp	FIN_MULT

;--------------------------------------------------------------
; Ejercicio 2: Dada una fecha DD-MM-AA calcular la fecha que 
; 			   esté R19 días más adelante.
;--------------------------------------------------------------
.def	DD_INI = r16
.def	MM_INI = r17
.def	AA_INI = r18
.def	DIAS_SUMADOS = r19
.def	DD_FIN = r20
.def	MM_FIN = r21
.def	AA_FIN = r22

.def	DIAS_DEL_MES = r23
.def	AUX	   = r24

CALCULA_FECHA:
		mov		DD_FIN, DD_INI
		mov		MM_FIN, MM_INI
		mov		AA_FIN, AA_INI

		add		DD_FIN, DIAS_SUMADOS
; la fecha final es la inicial mas los días sumados

; busco cuántos días tiene el mes actual
		ldi		ZH, high(TABLA_DIAS_X_MES*2-1)
		ldi		ZL, low(TABLA_DIAS_X_MES*2-1)
		clr		AUX
		add		ZL, MM_FIN
		adc		ZH, AUX		; Z apunta a los días del mes

BUCLE_CALCULA_FECHA:
		lpm		DIAS_DEL_MES, Z+
		cpi		MM_FIN, 12
		brne	PTR_A_SGTE_MES_OK

		sbiw	ZH:ZL, 12	; Z apunta a los días de enero

PTR_A_SGTE_MES_OK:
		cp		DD_FIN, DIAS_DEL_MES
		brlo	FIN_CALCULA_FECHA
		breq	FIN_CALCULA_FECHA

; DD_FIN tiene más días que los del mes actual, inc MM_FIN
		inc		MM_FIN			; paso a sgte. mes
		cpi		MM_FIN, 13
		brlo	BUCLE_CALCULA_FECHA

		ldi		MM_FIN, 1		; si siguiente mes es enero 
		inc		AA_FIN			; incremnto año
		rjmp	BUCLE_CALCULA_FECHA
		
FIN_CALCULA_FECHA:
		ret

; dias de los meses:    ene feb mar abr may jun jul ago sep oct nov dic
TABLA_DIAS_X_MES:	.db	31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31


;--------------------------------------------------------------
; Ejercicio 3: ordenamiento de un vector
;--------------------------------------------------------------
.equ	N	= 35	; nro. de elementos (bytes) de los vectores
		.dseg
VECTOR:		.byte	N	; vector desordenado
VECTOR_ORD:	.byte	N	; vector ordenado
	
		.cseg

ORDENA_VECTOR:
		ldi		r16, N		; nro. de elementos del vector
		ldi		YH,high(VECTOR)
		ldi		YL,low(VECTOR)		; Y = VECTOR


COPIO_VECTOR:
		ld		r17,Y+		; [Z+]<-[Y+] N veces
		st		Z+,r17
		dec		r16
		brne	COPIO_VECTOR

BUCLE_ORDENA:
		ldi		ZH,high(VECTOR_ORD)
		ldi		ZL,low(VECTOR_ORD)	; Z = VECTOR_ORD

		ldi		r16, N-1	; N-1 iteraciones
		clr		r17			; nro. de intercambios
		rcall	BURBUJEA

		tst		r17
		breq	FIN_ORDENA	; si no hubo intercambios, fin

		dec		r16
		brne	BUCLE_ORDENA

FIN_ORDENA:
		ret

; compara un elemento del vector con el siguiente,
; si es menor, los intercambia y continúa comparando
BURBUJEA:
		ldi		r18,N-1

BUCLE_BURBUJEA:
		ld		r19,Z+		; |r19|r20|
		ld		r20,Z		;       Z
		cp		r19, r20	
		brlo	INTERCAMBIA

BUCLE_INTERCAMBIA:
		dec		r18
		brne	BUCLE_BURBUJEA

FIN_BURBUJEA:
		ret

INTERCAMBIA:				; [-Z]=r20 Z++, [Z]=r19
		inc		r17			; nro. de intercambios ++
		sbiw	Z,1			; Z--
		st		Z+, r20		; |r20|r19|...|
		st		Z+, r19		;           Z
		rjmp	BUCLE_INTERCAMBIA
		
;--------------------------------------------------------------
; Ejercicio 4: sobre interrupciones
; i) a)
; ii) Verdadero 
; iii) Verdadero
;--------------------------------------------------------------
