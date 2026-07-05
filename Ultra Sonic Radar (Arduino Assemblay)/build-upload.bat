@echo off
REM Upload HEX to Arduino Uno via avrdude

setlocal enabledelayedexpansion

REM Set correct paths from Arduino15
set AVRDUDE_BIN=C:\Users\mtous\AppData\Local\Arduino15\packages\arduino\tools\avrdude\6.3.0-arduino17\bin
set AVRDUDE_CONF=C:\Users\mtous\AppData\Local\Arduino15\packages\arduino\tools\avrdude\6.3.0-arduino17\etc\avrdude.conf

REM Project settings
set MCU=m328p
set PROGRAMMER=arduino
set PORT=COM4
set BAUD=115200
set PROJECT=blink

echo.
echo ===== Uploading to Arduino Uno =====
echo.
echo Arduino: %PORT%
echo Trying baud: 115200, then 57600 if needed
echo Tip: If it fails, press RESET when upload starts.
echo.

REM First attempt: 115200 (official Uno bootloader)
"%AVRDUDE_BIN%\avrdude.exe" -C "%AVRDUDE_CONF%" -c %PROGRAMMER% -p %MCU% -P %PORT% -b 115200 -U flash:w:obj/%PROJECT%.hex:i -v
if errorlevel 1 (
    echo.
    echo First attempt failed. Retrying at 57600...
    echo.
    REM Second attempt: 57600 (common on some clones/old bootloaders)
    "%AVRDUDE_BIN%\avrdude.exe" -C "%AVRDUDE_CONF%" -c %PROGRAMMER% -p %MCU% -P %PORT% -b 57600 -U flash:w:obj/%PROJECT%.hex:i -v
    if errorlevel 1 (
        echo.
        echo ERROR: Upload failed at both baud rates.
        echo Suggestions:
        echo  - Disconnect other apps using %PORT% (Serial Monitor, etc.)
        echo  - Unplug/plug the board and try again
        echo  - Press and release RESET when upload starts
        echo  - Verify COM port is correct (currently %PORT%)
        pause
        exit /b 1
    )
)

echo.
echo Upload successful! If LED state didnt change, well diagnose bootloader/fuses next.
echo.
pause
