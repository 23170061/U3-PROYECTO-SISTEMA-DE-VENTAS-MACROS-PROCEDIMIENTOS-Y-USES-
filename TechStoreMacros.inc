; =========================================================================
; TechStoreMacros.inc - Macros del sistema TechStore (Unidad 3)
; Se incluye desde TechStore.asm despues de Irvine32.inc.
; Nota: el nombre evita choque con el Macros.inc que trae la libreria Irvine.
; =========================================================================

; -------------------------------------------------------------------------
; mImprimir texto
; Muestra una cadena terminada en 0 declarada en .data.
; Recibe : texto = etiqueta de la cadena
; Conserva: EDX (se respalda dentro de la macro)
; Sustituye a la pareja "mov edx, OFFSET msg / call WriteString".
; -------------------------------------------------------------------------
mImprimir MACRO texto
    push edx
    mov  edx, OFFSET texto
    call WriteString
    pop  edx
ENDM

; -------------------------------------------------------------------------
; mMostrarYSalir texto, destino
; Muestra un mensaje (error o exito) y salta a la etiqueta de salida
; del procedimiento. Sustituye los bloques "mensaje + jmp Fin".
; -------------------------------------------------------------------------
mMostrarYSalir MACRO texto, destino
    mImprimir texto
    jmp  destino
ENDM

; -------------------------------------------------------------------------
; mImprimirCaracter caracter
; Muestra un caracter con WriteChar sin perder el valor de EAX.
; -------------------------------------------------------------------------
mImprimirCaracter MACRO caracter
    push eax
    mov  al, caracter
    call WriteChar
    pop  eax
ENDM

; -------------------------------------------------------------------------
; mValidarRango valor, minimo, maximo, destinoError
; Salta a destinoError si valor < minimo o valor > maximo (sin signo).
; Se usa con caracteres ('0'-'9', 'A'-'Z') y con importes en centavos.
; -------------------------------------------------------------------------
mValidarRango MACRO valor, minimo, maximo, destinoError
    cmp  valor, minimo
    jb   destinoError
    cmp  valor, maximo
    ja   destinoError
ENDM

; -------------------------------------------------------------------------
; mAcumularDigito acumulador, digito
; acumulador = acumulador * 10 + digito (conversion ASCII -> entero).
; -------------------------------------------------------------------------
mAcumularDigito MACRO acumulador, digito
    imul acumulador, 10
    add  acumulador, digito
ENDM

; -------------------------------------------------------------------------
; mMostrarEntero etiqueta, valor
; Muestra un texto seguido de un entero (ImprimirEnteroPropio).
; Conserva: EAX y EDX.
; -------------------------------------------------------------------------
mMostrarEntero MACRO etiqueta, valor
    mImprimir etiqueta
    push eax
    mov  eax, valor
    call ImprimirEnteroPropio
    pop  eax
ENDM

; -------------------------------------------------------------------------
; mMostrarPrecio etiqueta, valor
; Muestra un texto seguido de un importe en centavos con formato MXN.
; Conserva: EAX y EDX.
; -------------------------------------------------------------------------
mMostrarPrecio MACRO etiqueta, valor
    mImprimir etiqueta
    push eax
    mov  eax, valor
    call ImprimirPrecioMXN
    pop  eax
ENDM

; -------------------------------------------------------------------------
; mTransferirArchivo rutina, buffer, numBytes
; Prepara EAX = handle, EDX = buffer y ECX = bytes y llama a
; WriteToFile o ReadFromFile. Devuelve lo que devuelva la rutina
; (EAX = bytes transferidos, CF = 1 si hubo error).
; -------------------------------------------------------------------------
mTransferirArchivo MACRO rutina, buffer, numBytes
    mov  ecx, numBytes
    mov  eax, fileHandle
    mov  edx, OFFSET buffer
    call rutina
ENDM

; -------------------------------------------------------------------------
; mOpcionMenu numero, procedimiento, regreso
; Si EAX = numero, llama al procedimiento y salta a "regreso".
; Usa la etiqueta interna "siguiente", declarada con LOCAL porque la
; macro se invoca varias veces dentro del mismo procedimiento; MASM
; genera un nombre distinto (??0000, ??0001, ...) en cada expansion.
; -------------------------------------------------------------------------
mOpcionMenu MACRO numero, procedimiento, regreso
    LOCAL siguiente
    cmp  eax, numero
    jne  siguiente
    call procedimiento
    jmp  regreso
siguiente:
ENDM
