;---------------------------------- Encabezado ---------------------------------
;Archivo: Laboratorio5.s
;Dispositivo: PIC16F887
;Autor: Judah Pérez 21536
;Compilador: pic-as (v2.40), MPLAB X IDE v6.05
;
;Programa: Contador 8 bits / Hexadecimal con displays Multiplexación
;Hardware: 8 leds PORTA<7:0>
;	   2 displays 7 segmentos PORTC<6:0>
;	   2 botones PORTB<4> y PORTB<4>
;	   2 transitores NPN PORTE<1:0>
;	   Los transistores conectan el ánodo común de los displays a tierra.
;
;Creado: 20/02/23
;Última modificación: 20/02/23
;
;-------------------------------------------------------------------------------
    PROCESSOR 16F887
    #include <xc.inc>    
    #include "macros.s"

;configuration word 1
    CONFIG FOSC  = INTRC_NOCLKOUT //OSCILADOR INTERNO SIN SALIDA
    CONFIG WDTE	 = OFF //WDT DISSABLED (REINICIO REPETITIVO DEL PIC)
    CONFIG PWRTE = OFF //PWRT ENABLED (ESPERA 72ms AL INICIAR)
    CONFIG MCLRE = OFF //EL PIN DE MCLR SE UTILIZA COMO I/O
    CONFIG CP	 = OFF //SIN PROTECCIÓN DE CÓDIGO
    CONFIG CPD	 = OFF //SIN PROTECCIÓN DE DATOS
    
    CONFIG BOREN = OFF //SIN REINICIO CUANDO EL VOLTAJE DE ALIMENTACIÓN BAJA DE 4V
    CONFIG IESO  = OFF //REINICIO SIN CAMBIO DE RELOJ INTERNO A EXTERNO
    CONFIG FCMEN = OFF //CAMBIO DE RELOJ EXTERNO A INTERNO EN CASO DE FALLO
    CONFIG LVP	 = OFF //PROGRAMACIÓN EN BAJO VOLTAJE PERMITIDA
    
;configuration word 2
    CONFIG WRT   = OFF //PROTECCIÓN DE AUTOESCRITURA POR EL PROGRAMA DESACTIVADA
    CONFIG BOR4V = BOR40V //REINICIO ABAJO DE 4V, (BOR21V>2.1V)
;
;---------------------------------- Variables ----------------------------------
btnUP	EQU	4	;Button Up count RB
btnDWN  EQU	7	;Button Down count RB
disp0en	EQU	2	;Display 0 enable RE pin
disp1en	EQU	1	;Display 1 enable RE pin
disp2en	EQU	0	;Display 2 enable RE pin
TMR0_n	EQU	61	;TMR0 N value
  
PSECT udata_bank0 ;common memory
    digits:	DS  3	;Hundreads(+2), Tens(+1) & Ones(0) digits in binary
    disp_out:	DS  3	;Hundreads(+2), Tens(+1) & Ones(0) display output
    disp_sel:	DS  1	;Display selector (LSB only)
    count_val:	DS  1	;Store counters value
    mod10:	DS  1	;Module 10 for binary to decimal convertion
    rotations:	DS  1	;Rotations counter for binary to decimal convertion
    
PSECT udata_shr	;common memory
    W_temp:	    DS  1	;Temporary W
    STATUS_temp:    DS	1	;Temporary STATUS
    
;--------------------------------- Vector Reset --------------------------------
PSECT resVect, class=CODE, abs, delta=2
ORG 0000h	    ;posicion 0000h para el reset
    resetVec:
	PAGESEL main
	goto main
	
;------------------------------- Interrupt Vector ------------------------------
PSECT intVect, class=CODE, abs, delta=2
ORG 0004h    ;posición para las interrupciones
	
    push:	;Tamporarily save State before interrupt
	movwf	W_temp		;Copy W to temp register
	swapf	STATUS,	W	;Swap status to be saved into W
	movwf	STATUS_temp	;Save status to STATUS_temp
    isr:	;Interrupt Instructions (Interrupt Service Routine)
	btfsc	RBIF
	call	ioc_PortB
	btfsc	T0IF
	call	T0IF_inter
    pop:	;Restore State before interrupt
	swapf	STATUS_temp,W	;Reverse Swap for status and save into W
	movwf	STATUS		;Move W into STATUS register (Restore State)
	swapf	W_temp,	f	;Swap W_temp nibbles
	swapf	W_temp,	W	;Reverse Swap for W_temp and place it into W
	retfie
;-------------------------- Subrutinas de Interrupcion -------------------------
    
    ioc_PortB:
	;Verify which button triggered the interupt
	banksel	PORTA
	btfss	PORTB,	btnUP
	incf	PORTA
	btfss	PORTB,	btnDWN
	decf	PORTA
	bcf	RBIF	;Reset OIC flag
    return
    
    T0IF_inter:
	;Reset TMR0
	movlw	TMR0_n	    ;reset TRM0 count
	movwf	TMR0
	bcf	T0IF	    ;Reset TMR0 overflow flag
	;Change selected display
	incf	disp_sel
    return
	
;------------------------------------ Tablas -----------------------------------
PSECT code, delta=2, abs
ORG 0100h    ;posición para el código

display7_table:
    clrf    PCLATH	
    bsf	    PCLATH, 0	;0100h
    addwf   PCL,    f	;Offset
    retlw   00111111B   ;0
    retlw   00000110B   ;1
    retlw   01011011B   ;2
    retlw   01001111B   ;3
    retlw   01100110B   ;4
    retlw   01101101B   ;5
    retlw   01111101B   ;6
    retlw   00000111B   ;7
    retlw   01111111B   ;8
    retlw   01101111B   ;9
    retlw   01110111B   ;A
    retlw   01111100B   ;B
    retlw   00111001B   ;C
    retlw   01011110B   ;D
    retlw   01111001B   ;E
    retlw   01110001B   ;F
    retlw   01110110B   ;X "Offset > 15"
	   ;_gfedcba segments
	   
;------------------------------- Configuración uC ------------------------------

    main:
	call	config_io	;Configure Inputs/Outputs
	call	config_TMR0	;Configure TMR0
	call	config_ie	;Configure Interrupt Enable
	call	init_portNvars	;Initialize Ports and Variables

;-------------------------------- Loop Principal -------------------------------
    loop:
	call	get_digits	;Get counter's value in decimal digits
	;call	restrict_counters   ;Restrict counters before tables offset
	call	fetch_disp_out	;Prepare displays outputs
	call	show_display	;Show display output
	
	goto	loop	    ;loop forever
	
;--------------------------------- Sub Rutinas ---------------------------------
    config_io:
	banksel ANSEL
	clrf	ANSEL	    ;PortA Digital
	clrf	ANSELH	    ;PortB Digital
	
	banksel TRISA
	clrf	TRISA	    ;PortA Output
	clrf	TRISC	    ;PortC Output
	clrf	TRISD	    ;PortD Output
	clrf	TRISE	    ;PortE Output
	
	bsf	TRISB,	btnUP	;Input on buttons
	bsf	TRISB,	btnDWN
	bsf	WPUB,	btnUP	;Pull-up's on buttons
	bsf	WPUB,	btnDWN
	
	bcf	OPTION_REG, 7	;Enable PortB Pull-ups
    return
    
    config_TMR0:
	;TMR0 period set to 20ms (altogether with TMR0_n)
	bsf	OSCCON,	6   ;Internal clock 2 MHz
	bcf	OSCCON,	5   
	bsf	OSCCON,	4   
	bsf	OSCCON,	0	
	
	bcf	OPTION_REG, 5	;TMR0 internal instruction cycle source 
	bcf	OPTION_REG, 4	;Low-to-High transition
	bcf	OPTION_REG, 3	;Prescaler assigned to TMR0 module
	
	bsf	OPTION_REG, 2	;TMR0 prescaler 1:256
	bsf	OPTION_REG, 1	
	bsf	OPTION_REG, 0
    return
    
    config_ie:
	bsf	INTCON,	7	;Enable Global Interrupt
	
	bsf	INTCON,	5	;Enable TMR0 Overflow Interrupt
	
	bsf	INTCON,	3	;Enable PortB Interrupts
	bsf	IOCB,	btnUP	;Enable Interrupt-on-Change
	bsf	IOCB,	btnDWN	;Enable Interrupt-on-Change
    return
    
    restrict_counters:
	;Ones digit
	movlw	10		
	subwf	digits, W   ;Check 10
	btfss	STATUS,	2   ;Check zero flag
	goto	$+3	    ;Skip overflow reset
	clrf	digits
	incf	digits+1
	
   return
    
    init_portNvars:
	banksel PORTA	    ;Clear Output Ports
	clrf	PORTA
	clrf	PORTC
	clrf	PORTD
	clrf	PORTE
	clrw
    return
    
    get_digits:
	bin_to_dec  PORTA,digits
	bin_to_dec  count_val,digits+1
	bin_to_dec  count_val,digits+2
    return
    
    fetch_disp_out:
	;Ones display
	movf	digits, W
	call	display7_table	;Returns binary code for 7 segment display
	movwf	disp_out
	
	;Tens display
	movf	digits+1, W
	call	display7_table	;Returns binary code for 7 segment display
	movwf	disp_out+1
	
	;Hundreds display
	movf	digits+2, W
	call	display7_table	;Returns binary code for 7 segment display
	movwf	disp_out+2
    return
    
    show_display:
	btfsc	disp_sel,   1
	goto	Display_2 ;Jump to display 2
	btfsc	disp_sel,   0
	goto	Display_1 ;Jump to display 1
	
	Display_0: ;Ones
	bcf	PORTE,	disp2en	;Disable display 2
	movf	disp_out, W	;Load display 0 value
	movwf	PORTC		;to PortC
	bsf	PORTE,	disp0en	;Enable display 0
    return
    
	Display_1: ;Tens
	bcf	PORTE,	disp0en	;Disable display 0
	movf	disp_out+1, W	;Load display 1 value
	movwf	PORTC		;to PortC
	bsf	PORTE,	disp1en	;Enable display 1
    return
    
	Display_2: ;Hundreds
	bcf	PORTE,	disp1en	;Disable display 1
	movf	disp_out+2, W	;Load display 1 value
	movwf	PORTC		;to PortC
	bsf	PORTE,	disp2en	;Enable display 2
    return
    
    END




