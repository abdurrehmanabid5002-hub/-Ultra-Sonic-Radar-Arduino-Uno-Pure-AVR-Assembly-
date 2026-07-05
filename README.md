# 🛸 Ultra Sonic Radar — Arduino Uno (Pure AVR Assembly)

A proximity-sensing radar sweep system written entirely in **bare-metal AVR Assembly** for the **ATmega328P** (Arduino Uno). No Arduino libraries, no C runtime — just raw register manipulation and hand-tuned delay loops running at 16 MHz.

---

## 📋 Project Summary

This firmware drives three peripherals simultaneously:

| Peripheral | Purpose |
|---|---|
| **HC-SR04 Ultrasonic Sensor** | Measures distance to the nearest object by timing an echo pulse |
| **SG90 Servo Motor** | Sweeps through 0°→90°→180° to scan a 180° arc |
| **Onboard LED (Pin 13)** | Lights up as a proximity warning when an object is too close |

A continuous radar loop sweeps the servo left → center → right. At every position, the ultrasonic sensor samples the environment. If an obstacle is detected within the close-range threshold (~1.5 ft), the sweep **freezes at center**, the **LED turns on**, and the system holds until the path is clear. Distance telemetry is streamed over **UART at 9600 baud** as hexadecimal values for live monitoring via Serial Monitor.

---

## 🔌 Hardware Wiring

```
Arduino Uno (ATmega328P @ 16 MHz)
┌──────────────────────────────────┐
│                                  │
│  D2  (PD2) ◄──── ECHO  (HC-SR04)│
│  D6  (PD6) ────► SIGNAL (Servo) │
│  D7  (PD7) ────► TRIG  (HC-SR04)│
│  D13 (PB5) ────► Onboard LED    │
│  D1  (PD1) ────► TX (UART out)  │
│                                  │
│  5V  ────────► VCC (HC-SR04)     │
│  5V  ────────► VCC (Servo)       │
│  GND ────────► GND (all)         │
└──────────────────────────────────┘
```

### Pin Map

| Arduino Pin | AVR Port | Direction | Connected To | Signal |
|:-----------:|:--------:|:---------:|:-------------|:-------|
| D1 | PD1 | Output | USB/Serial | UART TX (9600 8N1) |
| D2 | PD2 | Input | HC-SR04 ECHO | Pulse width = distance |
| D6 | PD6 | Output | Servo signal wire | Software PWM (1–2 ms pulse in 20 ms frame) |
| D7 | PD7 | Output | HC-SR04 TRIG | 10 µs trigger pulse |
| D13 | PB5 | Output | Onboard LED | HIGH = object close |

---

## ⚙️ How It Works

### Main Loop (`RADAR_LOOP`)

```
┌─────────────────────────────────────────────────────────┐
│                      RADAR_LOOP                         │
│                                                         │
│  1. Sample ultrasonic distance                          │
│  2. Object close? ──YES──► CLOSE_HOLD (freeze center)  │
│                   ──NO───► RADAR_SEQ                    │
│                                                         │
│  RADAR_SEQ:                                             │
│    ├── Sweep to Center (90°)  × 50 frames (~1 sec)     │
│    ├── Sweep to Right (180°)  × 50 frames (~1 sec)     │
│    ├── Sweep to Left  (0°)    × 50 frames (~1 sec)     │
│    └── Loop back to RADAR_LOOP                          │
│                                                         │
│  CLOSE_HOLD:                                            │
│    ├── Hold servo at center (1.5 ms pulse)              │
│    ├── LED ON                                           │
│    ├── Keep sampling until object clears                │
│    └── Return to RADAR_LOOP                             │
└─────────────────────────────────────────────────────────┘
```

### Servo Control (Software PWM)

Standard hobby servos expect a 50 Hz signal (20 ms period) with a variable-width high pulse:

| Position | Pulse Width | Delay Routine |
|:--------:|:-----------:|:--------------|
| 0° (Left) | 1.0 ms | `SERVO_PULSE_1MS` |
| 90° (Center) | 1.5 ms | `SERVO_PULSE_1_5MS` |
| 180° (Right) | 2.0 ms | `SERVO_PULSE_2MS` |

Each position is held for **50 consecutive frames** (50 × 20 ms = 1 second) to give the servo time to physically reach the target angle.

### Ultrasonic Distance Measurement (`ULTRA_SAMPLE`)

1. Pull **TRIG** high for 10 µs, then low
2. Wait for **ECHO** to go high (with a 255-iteration timeout)
3. Count loop iterations while ECHO stays high → stored as a 16-bit value in `r31:r30`
4. Compare count against the **close threshold** (`0x0400` = 1024 counts ≈ 1.5 ft)
5. Set `r26 = 1` (close) or `r26 = 0` (far)

### UART Telemetry (`BLINK_UPDATE`)

Every **10 frames** (~200 ms), the firmware transmits the raw 16-bit echo count over serial as 4 hex characters followed by `\r\n`. Open a serial monitor at **9600 baud** to see live readings:

```
0A3F
082C
0012    ← object very close
0008    ← object very close
04FF
```

### LED Behavior

The onboard LED on pin 13 acts as a real-time proximity indicator:
- **ON** → Object detected within threshold
- **OFF** → No object in close range

---

## 🗂️ Project Structure

```
Ultra Sonic Radar (Arduino Assemblay)/
├── Ultra Sonic Radar (Arduino Assemblay)/
│   ├── blink.asm            ← Main assembly source (351 lines)
│   ├── atmega328p.ld        ← Linker script (Flash 32K, RAM 2K)
│   ├── build.bat            ← Assemble + Link + Generate HEX
│   ├── build-upload.bat     ← Flash HEX to Arduino via avrdude
│   ├── inspect.bat          ← Disassemble ELF for debugging
│   └── obj/
│       ├── blink.o          ← Assembled object file
│       ├── blink.elf        ← Linked ELF binary
│       └── blink.hex        ← Intel HEX for flashing
└── README.md                ← This file
```

### File Details

| File | Purpose |
|:-----|:--------|
| [blink.asm](Ultra%20Sonic%20Radar%20(Arduino%20Assemblay)/blink.asm) | The entire firmware — initialization, servo PWM, ultrasonic driver, UART TX, delay routines, and the main radar loop. All 351 lines of hand-written AVR assembly. |
| [atmega328p.ld](Ultra%20Sonic%20Radar%20(Arduino%20Assemblay)/atmega328p.ld) | Custom GNU linker script defining the ATmega328P memory layout: 32 KB Flash at `0x0000` and 2 KB SRAM at `0x800060`. Places `.text`/`.rodata` in Flash and `.data`/`.bss` in RAM. |
| [build.bat](Ultra%20Sonic%20Radar%20(Arduino%20Assemblay)/build.bat) | Windows batch script that runs the 3-step build pipeline: `avr-as` (assemble) → `avr-gcc` (link with custom linker script, no C startup) → `avr-objcopy` (convert ELF to Intel HEX). |
| [build-upload.bat](Ultra%20Sonic%20Radar%20(Arduino%20Assemblay)/build-upload.bat) | Flashes `blink.hex` to the Arduino using `avrdude`. Tries 115200 baud first, falls back to 57600 for clone boards with older bootloaders. |
| [inspect.bat](Ultra%20Sonic%20Radar%20(Arduino%20Assemblay)/inspect.bat) | Debug helper — runs `avr-objdump -h` (section headers) and `avr-objdump -d` (disassembly) on the ELF file to verify the compiled binary. |

---

## 🔨 Build Toolchain

The project uses the **AVR GCC toolchain** bundled with the Arduino IDE (no separate install required).

### Build Pipeline

```
blink.asm ──► avr-as ──► blink.o ──► avr-gcc ──► blink.elf ──► avr-objcopy ──► blink.hex
              (assemble)              (link with               (convert to
                                       atmega328p.ld,           Intel HEX)
                                       -nostartfiles)
```

### Key Compiler Flags

| Tool | Flags | Why |
|:-----|:------|:----|
| `avr-as` | `-mmcu=atmega328p` | Target the correct instruction set |
| `avr-gcc` | `-mmcu=atmega328p -nostartfiles -Wl,-Tatmega328p.ld` | Link without C runtime; use custom memory map |
| `avr-objcopy` | `-O ihex` | Produce the HEX format that avrdude expects |
| `avrdude` | `-c arduino -p m328p -b 115200` | Flash via Arduino bootloader over USB serial |

---

## 🚀 Getting Started

### Prerequisites

- **Arduino Uno** (or compatible ATmega328P board)
- **HC-SR04** ultrasonic sensor
- **SG90** (or similar) hobby servo
- **AVR GCC toolchain** — installed automatically with the [Arduino IDE](https://www.arduino.cc/en/software)

### Step 1 — Configure Paths

Edit the `set` lines at the top of each `.bat` file to match your local Arduino installation:

```bat
REM In build.bat and inspect.bat:
set AVR_GCC_BIN=C:\Users\<YourUsername>\AppData\Local\Arduino15\packages\arduino\tools\avr-gcc\<version>\bin

REM In build-upload.bat:
set AVRDUDE_BIN=C:\Users\<YourUsername>\AppData\Local\Arduino15\packages\arduino\tools\avrdude\<version>\bin
set AVRDUDE_CONF=C:\Users\<YourUsername>\AppData\Local\Arduino15\packages\arduino\tools\avrdude\<version>\etc\avrdude.conf
set PORT=COM4          ← change to your Arduino's COM port
```

### Step 2 — Build

```cmd
cd "Ultra Sonic Radar (Arduino Assemblay)"
build.bat
```

Expected output:
```
===== AVR Assembly Build =====

[1/4] Assembling blink.asm...
Assembly successful.
[2/4] Linking...
Linking successful.
[3/4] Generating HEX file...
HEX generation successful.

===== Build Complete =====
HEX file: obj/blink.hex
```

### Step 3 — Upload

Connect the Arduino via USB, then:

```cmd
build-upload.bat
```

The script tries 115200 baud first, then 57600 baud as a fallback for clone boards.

### Step 4 — Monitor

Open any serial terminal (Arduino Serial Monitor, PuTTY, etc.) at **9600 baud** to see live distance readings in hexadecimal.

---

## 🧠 Register Usage Map

The firmware makes deliberate use of AVR general-purpose registers without a stack frame:

| Register | Purpose |
|:---------|:--------|
| `r16` | Scratch / I/O reads |
| `r17` | Servo repeat loop counter (50 iterations) |
| `r18` | ECHO wait-for-high timeout counter |
| `r20` | Inner delay loop counter / threshold compare |
| `r21` | Middle delay loop counter / threshold compare |
| `r22` | Millisecond delay counter for `DELAY_MS_GENERIC` |
| `r24` | UART TX data byte |
| `r26` | Proximity flag: `0` = far, `1` = close |
| `r27` | LED state flag (legacy, now driven by proximity) |
| `r28` | UART print rate limiter (counts down from 10) |
| `r30:r31` | 16-bit ultrasonic echo duration counter (Z register pair) |

---

## 🎛️ Tuning

| Constant | Default | Location | What It Controls |
|:---------|:--------|:---------|:-----------------|
| `CLOSE_THR_H:L` | `0x0400` (1024) | `blink.asm` line 26-27 | Echo count threshold for "close" detection. Lower = closer trigger distance. |
| Servo repeat count | `50` | `SERVO_*_REPEAT` routines | Frames per position (50 × 20 ms = 1 s hold time). Increase for slower sweep. |
| UART log interval | `10` | `BLINK_UPDATE` (r28 init) | Print every N frames. Increase to reduce serial traffic. |
| UBRR | `103` | `START` UART init | Baud rate divider. 103 = 9600 baud @ 16 MHz. |

---

## 📜 License

This project is provided as-is for educational purposes. Feel free to use, modify, and distribute.
