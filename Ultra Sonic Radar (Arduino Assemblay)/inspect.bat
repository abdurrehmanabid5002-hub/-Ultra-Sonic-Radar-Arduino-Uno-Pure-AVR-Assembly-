@echo off
setlocal enabledelayedexpansion

set AVR_GCC_BIN=C:\Users\mtous\AppData\Local\Arduino15\packages\arduino\tools\avr-gcc\7.3.0-atmel3.6.1-arduino7\bin

echo.
echo ===== ELF Inspection =====
echo.

"%AVR_GCC_BIN%\avr-objdump.exe" -h obj/blink.elf
echo.
echo.

"%AVR_GCC_BIN%\avr-objdump.exe" -d obj/blink.elf

pause
