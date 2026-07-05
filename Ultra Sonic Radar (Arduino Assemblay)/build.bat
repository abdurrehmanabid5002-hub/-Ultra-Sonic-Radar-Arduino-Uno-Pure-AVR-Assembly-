@echo off
REM AVR Assembly Build Script for Arduino Uno (ATmega328P)
REM This script assembles, links, and generates a HEX file

setlocal enabledelayedexpansion

REM Set correct paths from Arduino15
set AVR_GCC_BIN=C:\Users\mtous\AppData\Local\Arduino15\packages\arduino\tools\avr-gcc\7.3.0-atmel3.6.1-arduino7\bin

REM Project settings
set MCU=atmega328p
set PROJECT=blink

REM Create output directory
if not exist "obj" mkdir obj

echo.
echo ===== AVR Assembly Build =====
echo.

REM Step 1: Assemble
echo [1/4] Assembling %PROJECT%.asm...
"%AVR_GCC_BIN%\avr-as.exe" -mmcu=%MCU% -o obj/%PROJECT%.o %PROJECT%.asm
if errorlevel 1 (
    echo ERROR: Assembly failed!
    pause
    exit /b 1
)
echo Assembly successful.

REM Step 2: Link
echo [2/4] Linking...
"%AVR_GCC_BIN%\avr-gcc.exe" -mmcu=%MCU% -nostartfiles -Wl,-Tatmega328p.ld -o obj/%PROJECT%.elf obj/%PROJECT%.o
if errorlevel 1 (
    echo ERROR: Linking failed!
    pause
    exit /b 1
)
echo Linking successful.

REM Step 3: Generate HEX
echo [3/4] Generating HEX file...
"%AVR_GCC_BIN%\avr-objcopy.exe" -O ihex obj/%PROJECT%.elf obj/%PROJECT%.hex
if errorlevel 1 (
    echo ERROR: HEX generation failed!
    pause
    exit /b 1
)
echo HEX generation successful.

REM Step 4: Success
echo.
echo ===== Build Complete =====
echo HEX file: obj/%PROJECT%.hex
echo.
echo Now run: build-upload.bat
echo.
pause
