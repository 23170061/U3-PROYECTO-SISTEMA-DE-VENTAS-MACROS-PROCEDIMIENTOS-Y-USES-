# U3-PROYECTO-SISTEMA-DE-VENTAS-MACROS-PROCEDIMIENTOS-Y-USES-

# AGUIRRE GRIJALVA EDUARDO AGUSTIN
# SALAZAR ORTIZ CARLOS ALBERTO

# TechStore – Sistema de Ventas e Inventario (MASM x86 32 bits + Irvine32)

Proyecto de **Lenguajes de Interfaz – Unidad 3**: versión del sistema de la Unidad 2 reorganizada con **procedimientos, macros y USES**. Conserva todas las funciones, validaciones y la regla de negocio (10 % de descuento por mayoreo a partir de 5 unidades).

> Se usa el nombre `TechStoreMacros.inc` (y no `Macros.inc`) para no chocar con el archivo de macros que trae la biblioteca Irvine en `C:\Irvine`.

## Uso del inventario de prueba

El programa lee y escribe `inventario.txt` en el **directorio de trabajo**.

Contenido esperado del archivo de prueba:

| Código | Nombre | Precio | Stock |
|---|---|---|---|
| MON-300 | Monitor 24 pulgadas | $3499.00 MXN | 5 |
| USB-064 | Memoria USB 64GB | $149.90 MXN | 40 |
| AUD-110 | Audifonos Bluetooth | $599.50 MXN | 12 |
| CAM-720 | Camara Web HD | $450.00 MXN | 8 |

Formato binario: 4 bytes con `cantProd` seguidos de `cantProd` bloques de 64 bytes (código +0, nombre +8, precio en centavos +34, existencia +38).
