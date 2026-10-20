# Nexys A7-100T / Artix-7 XC7A100T - Research Report for FPGA Video Game Development

> [!note] General board research, not the CS-256 game specification
> The generic 640 × 480 recommendations below are examples for FPGA game development. The CS-256 Tron project follows its course handout's 1280 × 800 mode and the accepted project architecture; see [[CS-256 VGA and Sprite Design Plan]] and [[CS-256 Tron Agreed Specification 2026-10-20]].

**Scope assumption:** this report assumes the board is the **Digilent Nexys A7-100T**, populated with the **AMD/Xilinx Artix-7 XC7A100T-1CSG324C**. If your silkscreen says **Arty A7-100T** or another XC7A100T board, the FPGA resources are similar but the onboard peripherals and connectors are different.

## Executive summary

The Nexys A7-100T is well suited to a fully-FPGA educational video game, particularly a 2D VGA game. It combines the XC7A100T FPGA with 128 MiB of DDR2, 12-bit VGA output, switches/buttons, a 3-axis ADXL362 accelerometer, a temperature sensor, a PDM microphone, USB-UART, a limited USB HID host path for keyboard/mouse, microSD, Ethernet, audio output, four standard Pmod headers and an XADC Pmod header. The FPGA provides 63,400 6-input LUTs, 126,800 flip-flops, 4,860 Kb of block RAM, 1,188 Kb of distributed RAM, 240 DSP48E1 slices and six clock-management tiles.

For a first game, the most robust architecture is **640x480 VGA at about 60 Hz**, with tile/sprite graphics, game logic in RTL or a MicroBlaze soft processor, sprites/tile maps in BRAM, larger assets/framebuffers in DDR2 or microSD, onboard buttons plus the accelerometer for control, and PWM audio. A true 3D renderer is possible, but there is no hard GPU. A sensible FPGA-native 3D path is fixed-point arithmetic, a pipelined triangle or raycasting renderer, low internal resolution such as 320x240, BRAM line/tile buffers, and DDR2 for color/depth/texture storage.

## Source corrections that matter

1. Some older Digilent Nexys A7 documentation lists **1,188 Kbits as Block RAM**. AMD DS180 identifies 1,188 Kb as **maximum distributed RAM** for XC7A100T, while the actual block RAM is **4,860 Kb** (270 x 18 Kb or 135 x 36 Kb blocks). The current Digilent product page also lists 4,860 Kbits of Block RAM.
2. The Nexys A7 reference manual describes an ADMP421 PDM microphone, while the Rev. D.0 schematic identifies IC1 as **SPK0833LM4H**. For HDL design, treat the interface as PDM clock/data, but verify your PCB revision/BOM before relying on microphone-specific acoustic/electrical parameters.

## FPGA resources and package

- Device: XC7A100T-1CSG324C, speed grade -1.
- 101,440 logic cells; 15,850 CLB slices.
- 4 LUTs per slice -> 63,400 6-input LUTs.
- 8 flip-flops per slice -> 126,800 flip-flops.
- 1,188 Kb maximum distributed RAM.
- 4,860 Kb Block RAM = 135 x 36 Kb = 270 x 18 Kb equivalents.
- 240 DSP48E1 slices.
- 6 Clock Management Tiles, each with an MMCM and PLL.
- 1 XADC block, dual 12-bit, 1 MSPS ADC architecture.
- The CSG324 package used by Nexys A7 exposes up to 210 user I/Os and **does not include GTP transceivers**. Do not plan multi-gigabit serial links that require GTPs on this board.

## Board-level resources

- 100 MHz board oscillator.
- 128 MiB DDR2 SDRAM on a 16-bit data interface. Digilent recommends a 650 Mb/s DDR data rate from the 100 MHz reference clock, giving about 1.3 GB/s raw theoretical data bandwidth before controller/refresh/arbitration overhead.
- 16 MiB serial QSPI flash and microSD connector.
- VGA: 4 bits red + 4 green + 4 blue + HS + VS = RGB444, 4096 colors.
- 10/100 Ethernet via LAN8720A/RMII.
- USB-JTAG and USB-UART.
- USB HID host bridge for a boot keyboard OR boot mouse, presented to the FPGA as PS/2-like clock/data. It is not a generic USB gamepad host.
- 16 slide switches, 16 LEDs, 2 RGB LEDs, 5 directional/general pushbuttons plus CPU reset, and two four-digit seven-segment displays (8 digits total).
- PDM microphone and mono PWM/PDM audio output.
- Four standard Pmod connectors plus JXADC.

## Inputs and protocols

An FPGA does not have fixed MCU-style UART/I2C/SPI peripherals in the same sense as a microcontroller. The Artix-7 I/O pins are programmable digital I/O; UART, SPI, I2C, PS/2, quadrature decoding and custom serial protocols are implemented in HDL, AMD IP or a soft processor peripheral. On the Nexys board, specific onboard devices are already wired using particular interfaces.

### Native/onboard player inputs

- **Buttons:** 5 directional/general buttons, ideal as a D-pad, plus the reset button if repurposed.
- **Switches:** 16 static slide switches for menus, debug, game modes or configuration.
- **Accelerometer:** ADXL362, three axes, 12-bit output, selectable +/-2 g, +/-4 g and +/-8 g, SPI plus two interrupt lines. Useful for tilt steering, shake, motion gestures and balance games.
- **Keyboard/mouse:** the onboard USB-A host bridge supports one boot-HID mouse OR keyboard and translates it to a PS/2-style two-wire interface to the FPGA.
- **Microphone:** PDM input can support sound-energy, clap or rhythm mechanics after filtering/decimation.
- **PC serial:** USB-UART can be used as a debugging console or as a bridge where a PC sends controller state to the FPGA.

### External controller and sensor options

- **Digital joystick / arcade buttons:** direct 3.3 V GPIO on a Pmod.
- **Pmod JSTK2:** two-axis joystick over SPI, with center/trigger buttons and RGB LED.
- **Analog joystick:** JXADC inputs or an external ADC over SPI/I2C. The XADC is 12-bit and up to 1 MSPS; check UG480 and the board schematic for allowed analog ranges and front-end design before connecting a 3.3 V analog signal directly.
- **Gyroscope / IMU:** no onboard gyro. Add a 3.3 V SPI/I2C IMU. Digilent Pmod NAV is a convenient example with accelerometer, gyroscope, magnetometer and barometer.
- **Rotary encoder:** two digital GPIOs plus optional pushbutton.
- **Bluetooth/USB console-style controller:** easiest robust route is an external MCU/module that handles USB/Bluetooth and forwards normalized controller state to the FPGA over UART/SPI. The Nexys USB host bridge is not designed as a generic gamepad host.
- **CAN/RS-485:** possible only with an external physical-layer transceiver; FPGA GPIO cannot be connected directly to those bus voltage levels.

### Pmod electrical constraints

Each standard 12-pin Pmod provides 8 logic signals, 2 x 3.3 V and 2 x GND. Four Pmods therefore expose 32 general digital signal positions. Digilent's master XDC configures these Pmod lines as LVCMOS33. Treat them as **3.3 V logic, not 5 V-tolerant inputs**. Use a level shifter for 5 V devices. Pmod traces are general-purpose I/O; they are not characterized as matched high-speed differential transmission pairs.

The JXADC header provides eight signal pins arranged as four differential-capable XADC pairs. These pins can also be used as digital I/O. For analog use, follow UG480 and the Nexys schematic rather than treating them like ordinary 0-3.3 V ADC inputs.

## Graphics: 2D

### Recommended first pipeline

`100 MHz clock -> clock generation -> game state -> tile/sprite fetch -> compositor -> HUD/text -> VGA timing/output`

At 640x480, a common VGA pixel clock is about 25 MHz. The Nexys VGA DAC is a resistor network driven by 12 RGB bits plus HS/VS, so the FPGA must generate video timing and pixel colors.

Two useful approaches:

1. **Scanline/tile/sprite renderer without a full framebuffer.** Generate each pixel from the tile map and sprite list as the raster scans. This conserves memory and gives deterministic throughput.
2. **Framebuffer renderer in DDR2.** Easier for arbitrary drawing and later 3D, but requires a DDR controller, arbitration and buffering so VGA scanout never underflows.

A 640x480 RGB444 buffer uses 460,800 bytes = 450 KiB. It fits in the XC7A100T's roughly 607.5 KiB of BRAM, but consumes most of it. Two such buffers require 900 KiB and therefore do not fit. For animation with double buffering, larger resolutions, textures or a depth buffer, use DDR2.

## Graphics: 3D

A 3D game can run entirely on the FPGA board, but there is no hard GPU. You must build the graphics pipeline yourself or combine a MicroBlaze soft CPU for game logic with custom hardware accelerators.

### Feasible renderer classes

- **2.5D raycaster:** lowest risk. Excellent for Wolfenstein/Doom-like presentation and teaches fixed-point geometry and memory scheduling.
- **Wireframe / flat-shaded 3D:** matrix transforms plus line/triangle rasterization.
- **Triangle rasterizer with Z-buffer:** feasible with fixed-point math, but substantially more design and memory complexity.
- **Textured, perspective-correct pipeline:** possible, but memory bandwidth, divider/reciprocal logic, texture access patterns and timing closure become the dominant engineering issues.

### Suggested 3D hardware stages

`vertex fetch -> model/view/projection transform -> clipping/culling -> triangle setup -> edge/barycentric rasterizer -> depth test -> texture/lighting -> color buffer -> VGA scanout`

Use the 240 DSP48E1 slices for multiply-accumulate work and prefer fixed-point arithmetic. Floating-point IP is useful selectively, but a broad floating-point pipeline consumes more LUT/DSP resources and typically reduces achievable clock frequency.

A strong first 3D target is **320x240 internally**, scaled 2x to 640x480 output. At RGB444, the color buffer is 112.5 KiB and a 16-bit depth buffer is 150 KiB, totaling 262.5 KiB. At 640x480, the same combination is about 1.025 MiB, which already exceeds on-chip BRAM, so DDR2 is mandatory.

## Clocking and timing limits

The board oscillator is 100 MHz. MMCM/PLL resources can derive the video pixel clock, memory-related clocks and other domains. Digilent advertises Artix-7 internal clock capability above 450 MHz, but this is **not a guaranteed frequency for your complete game design**. Maximum frequency is determined by the speed grade, logic depth, routing, fanout and setup/hold closure after implementation.

Practical project strategy: begin with game/render logic around 100 MHz and the exact pixel clock required by the video mode. Only raise internal clocks after timing reports show positive slack. Use synchronizers or asynchronous FIFOs for clock-domain crossings between pixel, game, DDR and peripheral domains.

## Memory and bandwidth

- BRAM: approximately 607.5 KiB total. Best for line buffers, FIFOs, sprite/tile caches, small ROMs and hot state.
- Distributed RAM: approximately 148.5 KiB maximum, but it consumes LUT fabric and should not be treated as free memory.
- DDR2: 128 MiB, preferred for framebuffers, large textures, maps and asset caches.
- microSD: mass asset storage; significantly higher and more variable latency than BRAM/DDR2.
- QSPI flash: useful for nonvolatile assets/configuration if space remains after FPGA configuration needs.

The 16-bit DDR2 interface at the recommended 650 Mb/s data rate has a raw theoretical payload rate of about 1.3 GB/s. Real usable throughput is lower. A robust video system gives scanout predictable priority and uses line FIFOs so DDR latency does not create visible artifacts.

## Audio

The Nexys A7 provides a mono audio output driven from the FPGA using a 1-bit PWM/PDM style stream and onboard low-pass/amplifier circuitry. This is enough for generated waveforms, retro music engines and sampled sound effects. Samples can live in BRAM, DDR2 or microSD. The onboard microphone can be processed by a PDM decimator and simple envelope detector for game input.

## Recommended system architecture

```text
                     +----------------------+
 Buttons/Switches -->|                      |
 ADXL362 SPI ------->|   Input Manager      |----+
 Keyboard/Mouse ---->|                      |    |
 Pmod/UART/XADC ---->|                      |    v
                     +----------------------+  Game State / FSM
                                                 or MicroBlaze
                                                      |
                  +---------------------------+-------+--------+
                  |                           |                |
                  v                           v                v
           2D/3D Renderer                Audio Engine     Asset Manager
                  |                           |                |
          BRAM caches/FIFOs                   |          microSD/QSPI
                  |                           |                |
                  +-------- DDR2 Arbiter -----+----------------+
                               |
                       Frame/Depth/Textures
                               |
                         VGA Scanout FIFO
                               |
                          RGB444 + HS/VS
```

For a pure-RTL project, game state can be FSMs/data-path modules. For a more software-like game, a MicroBlaze soft CPU can run game logic while VGA, sprite composition, audio and sensor interfaces remain hardware peripherals. A MicroBlaze is still synthesized inside the FPGA; whether that satisfies your course's meaning of "entirely in FPGA" should be confirmed with the instructor.

## Proposed development roadmap

1. **Board bring-up:** clock, reset, switches/buttons, LEDs, seven-segment and a UART debug console.
2. **Video baseline:** 640x480 VGA timing, color bars/test pattern, then text/HUD.
3. **2D game core:** tile map + sprite engine + collision + button controls.
4. **Motion control:** ADXL362 SPI driver, calibration/dead-zone/filter, map tilt to gameplay.
5. **Audio:** PWM/PDM output and simple sound generator/sample player.
6. **External controller:** Pmod JSTK2 or generic SPI/I2C/UART joystick/IMU.
7. **Memory expansion:** MIG DDR2, DMA-like framebuffer access, scanout FIFO, optional double buffer.
8. **Advanced graphics:** start 320x240 internal rendering; add fixed-point transform/raycast/triangles, then optional Z-buffer/textures.
9. **Asset pipeline:** microSD/QSPI loader, palette/tile/texture formats and offline conversion scripts.
10. **Optimization:** synthesis utilization, timing closure, BRAM/DSP banking, pipelining and CDC verification.

## Technical risks to plan for

- **Memory contention:** VGA scanout is a real-time consumer; renderer and asset loader must not starve it.
- **BRAM pressure:** a full 640x480 buffer almost fills BRAM; avoid assuming on-chip double buffering.
- **Timing closure:** multiply/divide, large mux trees, sprite priority chains and wide comparators can become long paths.
- **Controller voltage:** Pmods are 3.3 V. Protect the FPGA from 5 V modules.
- **USB expectations:** onboard USB HID bridge is limited to boot keyboard/mouse, not arbitrary gamepads.
- **Analog joystick:** validate XADC electrical limits/front end before wiring.
- **Mechanical motion input:** the onboard accelerometer measures the board itself. If the board remains on a desk, an external handheld IMU/joystick is ergonomically better.
- **Sensor filtering:** raw accelerometer/joystick values need dead zones, low-pass filtering and calibration for good game feel.

## Recommended proof-of-concept specification

A technically balanced first milestone is a **2D 640x480@60-ish Hz VGA game** with RGB444 output, 16x16 or 32x32 tiles, 8-32 active sprites, button controls plus optional tilt from ADXL362, simple AABB/tile collisions, text HUD, and PWM audio. Keep assets in BRAM first. Introduce DDR2 only when the renderer and controls are stable. This establishes the video timing, input architecture and game loop before adding the two hardest subsystems: external memory arbitration and 3D rasterization.

## Documentation package

The companion folder contains direct `.url` shortcuts to the official/current vendor documentation, plus a source index and game-relevant XDC excerpt. The canonical XDC remains the Digilent GitHub file so pin constraints can be checked against the latest revision.
