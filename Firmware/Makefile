# MCU firmware — PlatformIO wrappers.
# Prefer: make -C Firmware build | upload | clean
#
# On Windows, pio.exe may not be on PATH; default uses the Python launcher.

PIO ?= py -3 -m platformio
ENV ?= blackpill_f411ce

.PHONY: build upload clean monitor build-mock upload-mock

build:
	$(PIO) run -e $(ENV)

upload:
	$(PIO) run -e $(ENV) -t upload

# UART mock stub (no SPI) — env blackpill_uart_mock
build-mock:
	$(PIO) run -e blackpill_uart_mock

upload-mock:
	$(PIO) run -e blackpill_uart_mock -t upload

# Serial monitor attaches to whatever PlatformIO picks as the upload/monitor
# port. For CP2102 host telemetry, prefer GUI scripts or:
#   py -3 -m serial.tools.miniterm COMx 115200
monitor:
	$(PIO) device monitor -b 115200

clean:
	$(PIO) run -t clean
