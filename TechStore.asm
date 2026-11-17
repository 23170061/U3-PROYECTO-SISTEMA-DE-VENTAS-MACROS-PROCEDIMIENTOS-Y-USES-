; =========================================================================
; PROYECTO UNIDAD 3 - LENGUAJES DE INTERFAZ (MASM x86 32 bits - Irvine32)
; SISTEMA DE VENTAS E INVENTARIO "TECHSTORE"
; Version U3: procedimientos reutilizables, macros (TechStoreMacros.inc)
; y directiva USES. Conserva funciones, validaciones y la regla de negocio
; (10% de descuento por mayoreo a partir de 5 unidades) de la Unidad 2.
; =========================================================================

INCLUDE Irvine32.inc
INCLUDE TechStoreMacros.inc

; ---------------------------- Constantes ---------------------------------
; Estructura de 64 bytes por producto:
;   +0  (8 bytes)  : Codigo "ABC-123\0"
;   +8  (26 bytes) : Nombre (1 a 25 caracteres + 0)
;   +34 (4 bytes)  : Precio en centavos (DWORD)
;   +38 (4 bytes)  : Existencia (DWORD)
;   +42 (22 bytes) : Reserva
TAM_REGISTRO EQU 64         ; Tamano de cada producto en bytes
MAX_PROD     EQU 10         ; Limite maximo de productos
TAM_CODIGO   EQU 8          ; Bytes del campo codigo
OFF_NOMBRE   EQU 8          ; Desplazamiento del nombre
OFF_PRECIO   EQU 34         ; Desplazamiento del precio
OFF_STOCK    EQU 38         ; Desplazamiento de la existencia
MAX_NOMBRE   EQU 25         ; Valor de ECX para ReadString del nombre
MAX_STOCK    EQU 100        ; Existencia maxima por producto
PRECIO_MIN   EQU 1          ; $0.01 en centavos
PRECIO_MAX   EQU 999999     ; $9999.99 en centavos
MIN_MAYOREO  EQU 5          ; Unidades para aplicar descuento
PORC_DESC    EQU 10         ; Porcentaje de descuento por mayoreo

.data
    inventario     BYTE MAX_PROD * TAM_REGISTRO DUP(0)
    inventarioTemp BYTE MAX_PROD * TAM_REGISTRO DUP(0)  ; Carga segura desde disco
    cantProd       DWORD 0    ; Productos registrados actualmente
    cantArchivo    DWORD 0    ; Productos leidos del archivo (antes de validar)
    ingresosSesion DWORD 0    ; Acumulado de ventas de la sesion en centavos

    bufferLectura   BYTE 30 DUP(0)
    bufferEscritura BYTE 12 DUP(0)

    nombreArchivo   BYTE "inventario.txt", 0
    fileHandle      HANDLE ?

    msgMXN         BYTE " MXN", 0
    msgMenu        BYTE 0Dh, 0Ah, "=== TECHSTORE - SISTEMA DE INVENTARIO Y VENTAS ===", 0Dh, 0Ah
                   BYTE "1. Registrar Producto", 0Dh, 0Ah
                   BYTE "2. Consultar Inventario", 0Dh, 0Ah
                   BYTE "3. Recibir Mercancia", 0Dh, 0Ah
                   BYTE "4. Vender Producto", 0Dh, 0Ah
                   BYTE "5. Mostrar Resumen de Sesion", 0Dh, 0Ah
                   BYTE "6. Guardar / Cargar Inventario", 0Dh, 0Ah
                   BYTE "7. Salir", 0Dh, 0Ah
                   BYTE "Seleccione una opcion: ", 0

    msgPedirCodigo BYTE "Ingrese codigo (Formato ABC-123): ", 0
    msgPedirNombre BYTE "Ingrese nombre (1 a 25 caracteres): ", 0
    msgPedirPrecio BYTE "Ingrese precio (ej. 185.50): ", 0
    msgPedirStock  BYTE "Ingrese existencia inicial (0-100): ", 0
    msgPedirCant   BYTE "Ingrese cantidad: ", 0

    msgSubMenuArch BYTE 0Dh, 0Ah, "=== ARCHIVOS DE DISCO ===", 0Dh, 0Ah
                   BYTE "1. Guardar Inventario en Disco", 0Dh, 0Ah
                   BYTE "2. Cargar Inventario desde Disco", 0Dh, 0Ah
                   BYTE "Seleccione opcion: ", 0

    msgErrLleno    BYTE "ERROR: Capacidad maxima alcanzada (10 productos).", 0Dh, 0Ah, 0
    msgErrCodigo   BYTE "ERROR: Codigo invalido (debe ser 3 MAYUSCULAS, guion, 3 DIGITOS).", 0Dh, 0Ah, 0
    msgErrDup      BYTE "ERROR: El codigo ya esta registrado.", 0Dh, 0Ah, 0
    msgErrNoExiste BYTE "ERROR: Producto no encontrado.", 0Dh, 0Ah, 0
    msgErrPrecio   BYTE "ERROR: El precio debe estar entre $0.01 y $9999.99 MXN.", 0Dh, 0Ah, 0
    msgErrStockEx  BYTE "ERROR: La existencia no puede superar 100 unidades.", 0Dh, 0Ah, 0
    msgErrSinStock BYTE "ERROR: Existencias insuficientes para realizar la venta.", 0Dh, 0Ah, 0

    msgExitoReg    BYTE "--- Producto registrado exitosamente ---", 0Dh, 0Ah, 0
    msgExitoStock  BYTE "--- Inventario actualizado correctamente ---", 0Dh, 0Ah, 0
    msgVentaOK     BYTE "--- Venta procesada exitosamente ---", 0Dh, 0Ah, 0
    msgDescuento   BYTE "¡Se aplico un 10% de descuento por mayoreo (>= 5 unidades)!", 0Dh, 0Ah, 0
    msgTotalPagar  BYTE "Total a cobrar: $", 0

    msgHeaderInv  BYTE 0Dh, 0Ah, "=== CATALOGO DE INVENTARIO ===", 0Dh, 0Ah, 0
    msgCodHeader  BYTE "Codigo: ", 0
    msgNomHeader  BYTE " | Nombre: ", 0
    msgPreHeader  BYTE " | Precio: $", 0
    msgStkHeader  BYTE " | Stock: ", 0

    msgHeaderRes  BYTE 0Dh, 0Ah, "=== RESUMEN DE LA SESION ===", 0Dh, 0Ah, 0
    msgUnidTot    BYTE "Total de unidades disponibles: ", 0
    msgValInvent  BYTE "Valor total del inventario: $", 0
    msgIngrSesion BYTE "Ingresos acumulados de la sesion: $", 0

    msgExitoGuard BYTE "--- Inventario guardado en disco correctamente ---", 0Dh, 0Ah, 0
    msgExitoCarg  BYTE "--- Inventario cargado desde disco correctamente ---", 0Dh, 0Ah, 0
    msgErrArchivo BYTE "ERROR: No se pudo abrir o procesar el archivo.", 0Dh, 0Ah, 0
    msgVacio      BYTE "El inventario esta vacio.", 0Dh, 0Ah, 0

.code
main PROC
    call MenuPrincipal
    exit
main ENDP

; =========================================================================
;                    PROCEDIMIENTOS DE ENTRADA / SALIDA
; =========================================================================

; -------------------------------------------------------------------------
; LeerLinea  (NUEVO)
; Recibe : nada (lee una linea del teclado con ReadString)
; Devuelve: bufferLectura = texto capturado terminado en 0
;           EAX = numero de caracteres leidos
; Conserva: ECX, EDX (USES). EAX queda fuera de USES porque es el resultado.
; -------------------------------------------------------------------------
LeerLinea PROC USES ecx edx
    mov  edx, OFFSET bufferLectura
    mov  ecx, SIZEOF bufferLectura - 1
    call ReadString
    ret
LeerLinea ENDP

; -------------------------------------------------------------------------
; LeerEnteroPropio  (MODIFICADO: usa LeerLinea, mValidarRango, mAcumularDigito)
; Recibe : nada (teclado)
; Devuelve: EAX = valor entero (se detiene en el primer caracter no digito;
;           el 0 final y el Enter tambien son "no digito")
; Conserva: EBX, ESI (USES); ECX y EDX los conserva LeerLinea.
; -------------------------------------------------------------------------
LeerEnteroPropio PROC USES ebx esi
    call LeerLinea
    mov  esi, OFFSET bufferLectura
    xor  eax, eax                       ; Acumulador
    xor  ebx, ebx                       ; Caracter actual (32 bits)
ConvertirLoop:
    mov  bl, [esi]
    mValidarRango bl, '0', '9', FinConversion
    sub  bl, '0'                        ; ASCII -> valor ('5' -> 5)
    mAcumularDigito eax, ebx            ; EAX = EAX * 10 + digito
    inc  esi
    jmp  ConvertirLoop
FinConversion:
    ret
LeerEnteroPropio ENDP

; -------------------------------------------------------------------------
; ImprimirEnteroPropio  (MODIFICADO: USES y ciclo do-while sin caso especial)
; Recibe : EAX = entero sin signo a mostrar
; Devuelve: nada (imprime con WriteString)
; Conserva: EAX, EBX, EDX, ESI (USES)
; -------------------------------------------------------------------------
ImprimirEnteroPropio PROC USES eax ebx edx esi
    mov  esi, OFFSET bufferEscritura + 10   ; Llenamos de derecha a izquierda
    mov  BYTE PTR [esi], 0
    mov  ebx, 10
BucleDivisiones:                        ; Se ejecuta al menos una vez (0 -> "0")
    xor  edx, edx
    div  ebx                            ; EAX = cociente, EDX = residuo
    add  dl, '0'
    dec  esi
    mov  [esi], dl
    cmp  eax, 0
    jne  BucleDivisiones
    mov  edx, esi
    call WriteString
    ret
ImprimirEnteroPropio ENDP

; -------------------------------------------------------------------------
; LeerPrecioCentavos  (MODIFICADO: macros y correccion del caso con 1 decimal)
; Recibe : nada (teclado). Formatos validos: 185 / 185. / 185.5 / 185.50
; Devuelve: EAX = precio en centavos (0 si es invalido o fuera de rango)
; Conserva: EBX, ECX, ESI (USES)
; ECX = 0 sin punto, 1 = punto leido, 2 = un decimal, 3 = dos decimales
; -------------------------------------------------------------------------
LeerPrecioCentavos PROC USES ebx ecx esi
    call LeerLinea
    mov  esi, OFFSET bufferLectura
    xor  eax, eax
    xor  ebx, ebx
    xor  ecx, ecx
BuclePrecio:
    mov  bl, [esi]
    cmp  bl, 0
    je   AjustarDecimales
    cmp  bl, 0Dh
    je   AjustarDecimales
    cmp  bl, '.'
    je   EncontroPunto
    mValidarRango bl, '0', '9', ErrorPrecio
    sub  bl, '0'
    cmp  ecx, 0
    je   AcumularPrecio                 ; Parte entera
    cmp  ecx, 3
    jae  ErrorPrecio                    ; Rechaza el tercer decimal
    inc  ecx
AcumularPrecio:
    mAcumularDigito eax, ebx
    inc  esi
    jmp  BuclePrecio
EncontroPunto:
    cmp  ecx, 0
    jne  ErrorPrecio                    ; Rechaza un segundo punto
    mov  ecx, 1
    inc  esi
    jmp  BuclePrecio
AjustarDecimales:
    cmp  ecx, 2
    je   UnDecimal                      ; 185.5  -> 1855  * 10  = 18550
    ja   ValidarRangoPrecio             ; 185.50 -> 18550 (ya en centavos)
    imul eax, 100                       ; 185 o 185. -> 185 * 100 = 18500
    jmp  ValidarRangoPrecio
UnDecimal:
    imul eax, 10
ValidarRangoPrecio:
    mValidarRango eax, PRECIO_MIN, PRECIO_MAX, ErrorPrecio
    jmp  FinPrecio
ErrorPrecio:
    xor  eax, eax
FinPrecio:
    ret
LeerPrecioCentavos ENDP

; -------------------------------------------------------------------------
; ImprimirPrecioMXN  (MODIFICADO: USES y mImprimirCaracter)
; Recibe : EAX = importe en centavos
; Devuelve: nada (muestra "185.50 MXN"; el "$" lo pone el mensaje previo)
; Conserva: EAX, EBX, EDX (USES)
; -------------------------------------------------------------------------
ImprimirPrecioMXN PROC USES eax ebx edx
    mov  ebx, 100
    xor  edx, edx
    div  ebx                            ; EAX = pesos, EDX = centavos
    push edx                            ; Centavos a la pila
    call ImprimirEnteroPropio
    mImprimirCaracter '.'
    pop  eax                            ; EAX = centavos (pila equilibrada)
    cmp  eax, 10
    jae  CentavosNormales
    mImprimirCaracter '0'               ; 5 centavos -> ".05"
CentavosNormales:
    call ImprimirEnteroPropio
    mImprimir msgMXN
    ret
ImprimirPrecioMXN ENDP

; -------------------------------------------------------------------------
; ImprimirProducto  (NUEVO: se extrajo del ciclo de ConsultarInventario)
; Recibe : ESI = direccion del registro del producto
; Devuelve: nada (imprime una linea del catalogo)
; Conserva: EDX (USES). EAX lo conservan las macros mMostrarPrecio/Entero.
; -------------------------------------------------------------------------
ImprimirProducto PROC USES edx
    mImprimir msgCodHeader
    mov  edx, esi
    call WriteString
    mImprimir msgNomHeader
    lea  edx, [esi + OFF_NOMBRE]
    call WriteString
    mMostrarPrecio msgPreHeader, [esi+OFF_PRECIO]
    mMostrarEntero msgStkHeader, [esi+OFF_STOCK]
    call Crlf
    ret
ImprimirProducto ENDP

; =========================================================================
;                    VALIDACION Y BUSQUEDA DE PRODUCTOS
; =========================================================================

; -------------------------------------------------------------------------
; ValidarFormatoCodigo  (MODIFICADO: USES y mValidarRango)
; Recibe : EDX = direccion del codigo capturado
; Devuelve: EAX = 1 si cumple ABC-123, 0 si no
; Conserva: EBX, ECX, ESI (USES)
; -------------------------------------------------------------------------
ValidarFormatoCodigo PROC USES ebx ecx esi
    mov  esi, edx
    mov  ecx, 3
ValLetras:
    mov  bl, [esi]
    mValidarRango bl, 'A', 'Z', CodigoInvalido
    inc  esi
    loop ValLetras
    cmp  BYTE PTR [esi], '-'
    jne  CodigoInvalido
    inc  esi
    mov  ecx, 3
ValDigitos:
    mov  bl, [esi]
    mValidarRango bl, '0', '9', CodigoInvalido
    inc  esi
    loop ValDigitos
    cmp  BYTE PTR [esi], 0              ; Debe terminar despues del 3er digito
    jne  CodigoInvalido
    mov  eax, 1
    jmp  FinValCodigo
CodigoInvalido:
    xor  eax, eax
FinValCodigo:
    ret
ValidarFormatoCodigo ENDP

; -------------------------------------------------------------------------
; CompararCadenas  (NUEVO: se extrajo del ciclo interno de BuscarProducto)
; Recibe : ESI = cadena 1, EDI = cadena 2 (terminadas en 0)
; Devuelve: EAX = 1 si son iguales, 0 si son diferentes
; Conserva: EBX, ESI, EDI (USES)
; -------------------------------------------------------------------------
CompararCadenas PROC USES ebx esi edi
    xor  eax, eax
CompararCaracter:
    mov  bl, [esi]
    cmp  bl, [edi]
    jne  FinComparar
    inc  esi
    inc  edi
    cmp  bl, 0
    jne  CompararCaracter
    mov  eax, 1                         ; Llegaron juntas al terminador
FinComparar:
    ret
CompararCadenas ENDP

; -------------------------------------------------------------------------
; BuscarProducto  (MODIFICADO: usa CompararCadenas, sin PUSH/POP en el ciclo)
; Recibe : EDX = direccion del codigo a buscar
; Devuelve: EAX = indice del producto o -1 si no existe
;           ESI = direccion del registro encontrado
; Conserva: EBX, EDI (USES). EAX y ESI quedan fuera porque son resultados.
; -------------------------------------------------------------------------
BuscarProducto PROC USES ebx edi
    mov  esi, OFFSET inventario
    xor  ebx, ebx                       ; Indice actual
BucleBusqueda:
    cmp  ebx, cantProd
    jae  NoEncontrado
    mov  edi, edx
    call CompararCadenas                ; Compara [ESI] con el codigo buscado
    cmp  eax, 1
    je   Encontrado
    add  esi, TAM_REGISTRO
    inc  ebx
    jmp  BucleBusqueda
NoEncontrado:
    mov  eax, -1
    jmp  SalirBuscar
Encontrado:
    mov  eax, ebx
SalirBuscar:
    ret
BuscarProducto ENDP

; -------------------------------------------------------------------------
; LeerCodigo  (NUEVO: captura comun de Registrar, Recibir y Vender)
; Recibe : nada (muestra el mensaje y lee del teclado)
; Devuelve: EDX = OFFSET bufferLectura con el codigo capturado
;           EAX = longitud capturada
; Conserva: EBX, ECX, ESI, EDI (no los modifica)
; -------------------------------------------------------------------------
LeerCodigo PROC
    mImprimir msgPedirCodigo
    call LeerLinea
    mov  edx, OFFSET bufferLectura
    ret
LeerCodigo ENDP

; -------------------------------------------------------------------------
; PedirProductoExistente  (NUEVO: comun de Recibir y Vender)
; Recibe : nada (pide el codigo y lo busca)
; Devuelve: EAX = indice o -1 (si es -1 ya se mostro "Producto no encontrado")
;           ESI = direccion del registro
; Conserva: EDX (USES)
; -------------------------------------------------------------------------
PedirProductoExistente PROC USES edx
    call LeerCodigo
    call BuscarProducto
    cmp  eax, -1
    jne  FinPedir
    mImprimir msgErrNoExiste
FinPedir:
    ret
PedirProductoExistente ENDP

; =========================================================================
;                    REGLA DE NEGOCIO Y OPERACIONES
; =========================================================================

; -------------------------------------------------------------------------
; CalcularImporte  (NUEVO: separa la regla de negocio de la venta)
; Recibe : ESI = registro del producto, ECX = cantidad vendida
; Devuelve: EAX = importe a cobrar en centavos. Si ECX >= MIN_MAYOREO se
;           resta 10% (division entera: la fraccion de centavo se descarta)
; Conserva: EBX, EDX, EDI (USES). EAX queda fuera porque es el resultado.
; -------------------------------------------------------------------------
CalcularImporte PROC USES ebx edx edi
    mov  eax, [esi + OFF_PRECIO]
    mul  ecx                            ; EDX:EAX = precio * cantidad
    cmp  ecx, MIN_MAYOREO
    jb   FinImporte
    mov  ebx, eax                       ; EBX = subtotal
    imul eax, PORC_DESC                 ; EAX = subtotal * 10
    xor  edx, edx
    mov  edi, 100
    div  edi                            ; EAX = descuento (EDX = fraccion)
    sub  ebx, eax
    mov  eax, ebx                       ; EAX = subtotal - descuento
FinImporte:
    ret
CalcularImporte ENDP

; -------------------------------------------------------------------------
; RegistrarProducto  (MODIFICADO)
; Recibe/Devuelve: nada (interactivo). Actualiza inventario y cantProd.
; Conserva: EAX, ECX, EDX, ESI, EDI (USES)
; -------------------------------------------------------------------------
RegistrarProducto PROC USES eax ecx edx esi edi
    cmp  cantProd, MAX_PROD
    jae  ErrLleno
    call LeerCodigo                     ; EDX = codigo capturado
    call ValidarFormatoCodigo
    cmp  eax, 0
    je   ErrCodFormat
    call BuscarProducto
    cmp  eax, -1
    jne  ErrDuplicado

    imul esi, cantProd, TAM_REGISTRO    ; ESI = inventario + cantProd * 64
    add  esi, OFFSET inventario
    mov  edi, esi                       ; Copia los 8 bytes del codigo
    push esi
    mov  esi, OFFSET bufferLectura
    mov  ecx, TAM_CODIGO
    rep  movsb
    pop  esi

    mImprimir msgPedirNombre
    lea  edx, [esi + OFF_NOMBRE]
    mov  ecx, MAX_NOMBRE
    call ReadString

    mImprimir msgPedirPrecio
    call LeerPrecioCentavos
    cmp  eax, 0
    je   ErrPrecio
    mov  [esi + OFF_PRECIO], eax

    mImprimir msgPedirStock
    call LeerEnteroPropio
    cmp  eax, MAX_STOCK
    ja   ErrStock
    mov  [esi + OFF_STOCK], eax

    inc  cantProd
    mMostrarYSalir msgExitoReg, FinRegistrar
ErrLleno:
    mMostrarYSalir msgErrLleno, FinRegistrar
ErrCodFormat:
    mMostrarYSalir msgErrCodigo, FinRegistrar
ErrDuplicado:
    mMostrarYSalir msgErrDup, FinRegistrar
ErrPrecio:
    mMostrarYSalir msgErrPrecio, FinRegistrar
ErrStock:
    mImprimir msgErrStockEx
FinRegistrar:
    ret
RegistrarProducto ENDP

; -------------------------------------------------------------------------
; ConsultarInventario  (MODIFICADO: usa ImprimirProducto)
; Conserva: ECX, ESI (USES)
; -------------------------------------------------------------------------
ConsultarInventario PROC USES ecx esi
    mov  ecx, cantProd
    cmp  ecx, 0
    je   InvVacio
    mImprimir msgHeaderInv
    mov  esi, OFFSET inventario
BucleMostrar:
    call ImprimirProducto
    add  esi, TAM_REGISTRO
    loop BucleMostrar
    jmp  FinConsultar
InvVacio:
    mImprimir msgVacio
FinConsultar:
    ret
ConsultarInventario ENDP

; -------------------------------------------------------------------------
; RecibirMercancia  (MODIFICADO: usa PedirProductoExistente)
; Conserva: EAX, ESI (USES). Antes ECX se perdia al llamar a ReadString.
; -------------------------------------------------------------------------
RecibirMercancia PROC USES eax esi
    call PedirProductoExistente
    cmp  eax, -1
    je   FinRecibir
    mImprimir msgPedirCant
    call LeerEnteroPropio
    cmp  eax, 0
    je   FinRecibir
    add  eax, [esi + OFF_STOCK]         ; Nueva existencia
    cmp  eax, MAX_STOCK
    ja   ErrExcede
    mov  [esi + OFF_STOCK], eax
    mMostrarYSalir msgExitoStock, FinRecibir
ErrExcede:
    mImprimir msgErrStockEx
FinRecibir:
    ret
RecibirMercancia ENDP

; -------------------------------------------------------------------------
; VenderProducto  (MODIFICADO: usa PedirProductoExistente y CalcularImporte)
; Conserva: EAX, EBX, ECX, ESI (USES)
; -------------------------------------------------------------------------
VenderProducto PROC USES eax ebx ecx esi
    call PedirProductoExistente
    cmp  eax, -1
    je   FinVenta
    mImprimir msgPedirCant
    call LeerEnteroPropio
    mov  ecx, eax                       ; ECX = cantidad solicitada
    cmp  ecx, 0
    je   FinVenta
    cmp  ecx, [esi + OFF_STOCK]
    ja   ErrSinStock

    call CalcularImporte                ; EAX = total con regla de mayoreo
    mov  ebx, eax
    cmp  ecx, MIN_MAYOREO
    jb   ActualizarVenta
    mImprimir msgDescuento
ActualizarVenta:
    sub  [esi + OFF_STOCK], ecx         ; Descuenta existencias
    add  ingresosSesion, ebx            ; Acumula ingresos
    mImprimir msgVentaOK
    mMostrarPrecio msgTotalPagar, ebx
    call Crlf
    jmp  FinVenta
ErrSinStock:
    mImprimir msgErrSinStock
FinVenta:
    ret
VenderProducto ENDP

; -------------------------------------------------------------------------
; MostrarResumen  (MODIFICADO: se elimino el bloque duplicado ResumenCero)
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI (USES)
; -------------------------------------------------------------------------
MostrarResumen PROC USES eax ebx ecx edx esi edi
    mImprimir msgHeaderRes
    xor  ebx, ebx                       ; EBX = unidades totales
    xor  edi, edi                       ; EDI = valor del inventario
    mov  esi, OFFSET inventario
    mov  ecx, cantProd
    cmp  ecx, 0
    je   MostrarTotales                 ; Sin productos: se muestran ceros
BucleCalculoResumen:
    mov  eax, [esi + OFF_STOCK]
    add  ebx, eax
    mul  DWORD PTR [esi + OFF_PRECIO]   ; EDX:EAX = stock * precio
    add  edi, eax
    add  esi, TAM_REGISTRO
    loop BucleCalculoResumen
MostrarTotales:
    mMostrarEntero msgUnidTot, ebx
    call Crlf
    mMostrarPrecio msgValInvent, edi
    call Crlf
    mMostrarPrecio msgIngrSesion, ingresosSesion
    call Crlf
    ret
MostrarResumen ENDP

; =========================================================================
;                    PERSISTENCIA EN DISCO
; Formato de inventario.txt: 4 bytes (cantProd) + cantProd * 64 bytes
; =========================================================================

; -------------------------------------------------------------------------
; GuardarInventario  (MODIFICADO: usa mTransferirArchivo)
; Conserva: EAX, EBX, ECX, EDX (USES)
; -------------------------------------------------------------------------
GuardarInventario PROC USES eax ebx ecx edx
    mov  edx, OFFSET nombreArchivo
    call CreateOutputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   ErrGuardar
    mov  fileHandle, eax
    mTransferirArchivo WriteToFile, cantProd, SIZEOF cantProd
    imul ebx, cantProd, TAM_REGISTRO
    mTransferirArchivo WriteToFile, inventario, ebx
    mov  eax, fileHandle
    call CloseFile
    mMostrarYSalir msgExitoGuard, FinGuardar
ErrGuardar:
    mImprimir msgErrArchivo
FinGuardar:
    ret
GuardarInventario ENDP

; -------------------------------------------------------------------------
; CargarInventario  (MODIFICADO: valida el archivo antes de reemplazar)
; Lee primero a cantArchivo / inventarioTemp; solo si la lectura esta
; completa y cantArchivo <= MAX_PROD copia los datos al inventario activo.
; Conserva: EAX, EBX, ECX, EDX, ESI, EDI (USES)
; -------------------------------------------------------------------------
CargarInventario PROC USES eax ebx ecx edx esi edi
    mov  edx, OFFSET nombreArchivo
    call OpenInputFile
    cmp  eax, INVALID_HANDLE_VALUE
    je   ErrCargar
    mov  fileHandle, eax

    mTransferirArchivo ReadFromFile, cantArchivo, SIZEOF cantArchivo
    jc   ErrCerrar
    cmp  eax, SIZEOF cantArchivo
    jne  ErrCerrar
    cmp  cantArchivo, MAX_PROD
    ja   ErrCerrar

    imul ebx, cantArchivo, TAM_REGISTRO
    mTransferirArchivo ReadFromFile, inventarioTemp, ebx
    jc   ErrCerrar
    cmp  eax, ebx
    jne  ErrCerrar

    mov  eax, fileHandle
    call CloseFile
    mov  esi, OFFSET inventarioTemp     ; Lectura valida: se reemplaza
    mov  edi, OFFSET inventario
    mov  ecx, ebx
    rep  movsb
    mov  eax, cantArchivo
    mov  cantProd, eax
    mMostrarYSalir msgExitoCarg, FinCargar
ErrCerrar:
    mov  eax, fileHandle
    call CloseFile
ErrCargar:
    mImprimir msgErrArchivo
FinCargar:
    ret
CargarInventario ENDP

; =========================================================================
;                    MENUS
; =========================================================================

; -------------------------------------------------------------------------
; ControlArchivos  (MODIFICADO: macro mOpcionMenu)
; Conserva: EAX (USES)
; -------------------------------------------------------------------------
ControlArchivos PROC USES eax
    mImprimir msgSubMenuArch
    call LeerEnteroPropio
    mOpcionMenu 1, GuardarInventario, FinControlArch
    mOpcionMenu 2, CargarInventario,  FinControlArch
FinControlArch:
    ret
ControlArchivos ENDP

; -------------------------------------------------------------------------
; MenuPrincipal  (MODIFICADO: macro mOpcionMenu sustituye 14 lineas cmp/je
; y 12 lineas call/jmp de las etiquetas Opcion...)
; Conserva: EAX (USES)
; -------------------------------------------------------------------------
MenuPrincipal PROC USES eax
BucleMenu:
    mImprimir msgMenu
    call LeerEnteroPropio
    mOpcionMenu 1, RegistrarProducto,   BucleMenu
    mOpcionMenu 2, ConsultarInventario, BucleMenu
    mOpcionMenu 3, RecibirMercancia,    BucleMenu
    mOpcionMenu 4, VenderProducto,      BucleMenu
    mOpcionMenu 5, MostrarResumen,      BucleMenu
    mOpcionMenu 6, ControlArchivos,     BucleMenu
    cmp  eax, 7
    jne  BucleMenu
    ret
MenuPrincipal ENDP

END main
