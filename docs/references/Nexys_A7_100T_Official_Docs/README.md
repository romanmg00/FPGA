# Nexys A7-100T / Artix-7 XC7A100T — Official Documentation Bundle

Target board: **Digilent Nexys A7-100T**
FPGA: **AMD/Xilinx Artix-7 XC7A100T-1CSG324C**

This bundle contains shortcut files to the official vendor documents plus a small Python downloader (`download_official_docs.py`) that downloads the vendor PDFs/XDC to a local `Downloaded/` folder.

## Board documentation (Digilent)

1. Nexys A7 Reference Manual
   - https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7_rm.pdf
2. Nexys A7 Schematic, Rev. D.0
   - https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7-sch.pdf
3. Nexys A7-100T Master XDC
   - https://raw.githubusercontent.com/Digilent/digilent-xdc/master/Nexys-A7-100T-Master.xdc

## FPGA documentation (AMD/Xilinx)

4. DS180 — 7 Series FPGAs Data Sheet: Overview
   - https://docs.amd.com/v/u/en-US/ds180_7Series_Overview
   - Use this for device resource counts (logic cells, LUTs, BRAM, DSPs, I/O, etc.).
5. DS181 — Artix-7 FPGAs Data Sheet: DC and AC Switching Characteristics
   - https://docs.amd.com/v/u/en-US/ds181_Artix_7_Data_Sheet
   - Use this for voltage, timing, clock, I/O, and speed-grade limits.
6. UG480 — 7 Series FPGAs and Zynq-7000 SoC XADC User Guide
   - https://docs.amd.com/r/en-US/ug480_7Series_XADC
   - Relevant for analog inputs / joystick interfacing through JXADC.

## On-board sensors

7. ADXL362 — 3-axis digital accelerometer (SPI)
   - https://www.analog.com/media/en/technical-documentation/data-sheets/adxl362.pdf
8. ADT7420 — 16-bit digital temperature sensor (I2C)
   - https://www.analog.com/media/en/technical-documentation/data-sheets/adt7420.pdf
9. ADMP421 — omnidirectional MEMS microphone (PDM)
   - https://www.analog.com/media/en/technical-documentation/obsolete-data-sheets/ADMP421.pdf

## Important board note

The Digilent Nexys A7 Reference Manual identifies the on-board motion sensor as the **ADXL362** and the microphone as the **ADMP421**. The board includes an accelerometer but **no on-board gyroscope**.

## Using the downloader

Run:

```bash
python download_official_docs.py
```

The script only uses Python's standard library and downloads the official vendor files into `Downloaded/`.
