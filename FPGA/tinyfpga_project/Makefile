# TinyFPGA RX bring-up — Vivado XSim only.
# From FPGA/tinyfpga_project:
#   make sim
# Or from repo root:
#   make -C FPGA/tinyfpga_project sim

VIVADO ?= vivado

.PHONY: help sim sim-rx clean check-vivado
SIM_TOP ?=

.DEFAULT_GOAL := help

help:
	@echo "tinyfpga_project (Vivado XSim)"
	@echo "  make sim              Run tb_sniffer_frontend (frontend + kill)"
	@echo "  make sim-rx           Run tb_usb_fs_rx (raw RX bring-up)"
	@echo "  make clean            Remove xsim_work artifacts"
	@echo "  VIVADO=...            Override vivado / vivado.bat path"
	@echo "  SIM_TOP=module        Override default sim top"

check-vivado:
	@command -v "$(VIVADO)" >/dev/null 2>&1 || { \
	  echo "ERROR: '$(VIVADO)' not found on PATH." >&2; \
	  echo "Example: make sim VIVADO=\"C:/Xilinx/Vivado/2018.2/bin/vivado.bat\"" >&2; \
	  exit 1; \
	}

sim: check-vivado
	SIM_TOP="$(SIM_TOP)" $(VIVADO) -mode batch -source scripts/sim_xsim.tcl -nojournal -nolog

sim-rx: check-vivado
	SIM_TOP=tb_usb_fs_rx $(VIVADO) -mode batch -source scripts/sim_xsim.tcl -nojournal -nolog

clean:
	rm -rf xsim_work
	rm -f *.jou *.log *.pb *.wdb
