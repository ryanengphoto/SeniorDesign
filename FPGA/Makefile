# FPGA / Vivado — run from FPGA/ (make build) or repo root (make -C FPGA build).
# Requires Vivado on PATH, or override:
#   make build VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat"
#
# On Windows (this lab PC), default to the 2018.2 bat if present so
# check-vivado / sim / sim-all work under GnuWin32 make without bash.

ifeq ($(OS),Windows_NT)
  ifeq ($(origin VIVADO),undefined)
    ifneq ($(wildcard C:/Xilinx/Vivado/2018.2/bin/vivado.bat),)
      VIVADO := C:/Xilinx/Vivado/2018.2/bin/vivado.bat
    endif
  endif
  # GnuWin32 make often sets SHELL=sh.exe even when sh is absent.
  SHELL := cmd.exe
  .SHELLFLAGS := /C
endif

VIVADO      ?= vivado
VIVADO_JOBS ?= 4
PROJECT     := senior_design.xpr
SCRIPTS     := scripts

# Optional sim knobs (passed into Tcl via env):
#   make sim SIM_TOP=tb_main_wrapper SIM_TIME=10us
#   make sim-all COV=1   # native XSim code coverage when Vivado supports it
SIM_TOP  ?=
SIM_TIME ?=
COV      ?= 0

# Regression tops (must match scripts/sim_all.tcl)
SIM_ALL_TOPS := \
	tb_sniffer \
	tb_enumeration_analysis \
	tb_kill_e2e \
	tb_enum_e2e \
	tb_demo_threat \
	tb_spi_enum_e2e \
	tb_main_selfstim \
	tb_spi_manual_kill \
	tb_kill_manual_cross

.PHONY: help build synth sim sim-all cov-verilator gui clean check-vivado check-verilator

.DEFAULT_GOAL := help

help:
	@echo "FPGA Vivado targets (FPGA/)"
	@echo ""
	@echo "  make build      Synth + implement + write bitstream"
	@echo "  make synth      Synthesis only"
	@echo "  make sim        Behavioral sim (XSim); needs a testbench as sim top"
	@echo "  make sim-all       Run full sniffer TB regression (scripts/sim_all.tcl)"
	@echo "  make cov-verilator Line/branch/toggle coverage via Verilator (MSYS2)"
	@echo "  make gui           Open $(PROJECT) in the Vivado GUI"
	@echo "  make clean         Remove generated Vivado dirs/logs (keeps sources + .xpr)"
	@echo ""
	@echo "Overrides:"
	@echo "  VIVADO=...          Path to vivado / vivado.bat if not on PATH"
	@echo "  VIVADO_JOBS=N       Parallel jobs for runs (default $(VIVADO_JOBS))"
	@echo "  SIM_TOP=module      Override sim_1 top module"
	@echo "  SIM_TIME=10us       Run for a fixed time instead of 'run all'"
	@echo "  COV=1               Try native XSim code coverage (needs Vivado ~2020.1+)"
	@echo "                      Always writes FPGA/cov/scenario_matrix.txt"
	@echo "  MSYS_BASH=...       bash for cov-verilator (default C:/msys64/usr/bin/bash.exe)"
	@echo ""
	@echo "sim-all tops: $(SIM_ALL_TOPS)"
	@echo "See testing.md for TB inventory + Verilator coverage details."

# Portable existence check: prefer full path; else rely on PATH via -version.
check-vivado:
ifeq ($(OS),Windows_NT)
	@if not exist "$(subst /,\,$(VIVADO))" ( \
	  echo ERROR: Vivado not found at $(VIVADO). Pass VIVADO=... or add bin to PATH. & \
	  exit /b 1 \
	)
else
	@command -v "$(VIVADO)" >/dev/null 2>&1 || { \
	  echo "ERROR: '$(VIVADO)' not found on PATH." >&2; \
	  echo "Install Vivado and add its bin/ to PATH, or pass VIVADO=..." >&2; \
	  exit 1; \
	}
endif

build: check-vivado
ifeq ($(OS),Windows_NT)
	set VIVADO_JOBS=$(VIVADO_JOBS)&& $(VIVADO) -mode batch -source $(SCRIPTS)/build.tcl -nojournal -nolog
else
	VIVADO_JOBS=$(VIVADO_JOBS) $(VIVADO) -mode batch -source $(SCRIPTS)/build.tcl -nojournal -nolog
endif

synth: check-vivado
ifeq ($(OS),Windows_NT)
	set VIVADO_JOBS=$(VIVADO_JOBS)&& $(VIVADO) -mode batch -source $(SCRIPTS)/synth.tcl -nojournal -nolog
else
	VIVADO_JOBS=$(VIVADO_JOBS) $(VIVADO) -mode batch -source $(SCRIPTS)/synth.tcl -nojournal -nolog
endif

sim: check-vivado
ifeq ($(OS),Windows_NT)
	set SIM_TOP=$(SIM_TOP)&& set SIM_TIME=$(SIM_TIME)&& $(VIVADO) -mode batch -source $(SCRIPTS)/sim.tcl -nojournal -nolog
else
	SIM_TOP="$(SIM_TOP)" SIM_TIME="$(SIM_TIME)" \
	  $(VIVADO) -mode batch -source $(SCRIPTS)/sim.tcl -nojournal -nolog
endif

# Full regression: one Vivado process, all SIM_ALL_TOPS via scripts/sim_all.tcl
sim-all: check-vivado
ifeq ($(OS),Windows_NT)
	set SIM_TIME=$(SIM_TIME)&& set COV=$(COV)&& $(VIVADO) -mode batch -source $(SCRIPTS)/sim_all.tcl -nojournal -nolog
else
	SIM_TIME="$(SIM_TIME)" COV="$(COV)" \
	  $(VIVADO) -mode batch -source $(SCRIPTS)/sim_all.tcl -nojournal -nolog
endif

# Verilator code coverage (MSYS2 ucrt64). Acceptance gate remains make sim-all.
MSYS_BASH ?= C:/msys64/usr/bin/bash.exe

check-verilator:
ifeq ($(OS),Windows_NT)
	@if not exist "$(subst /,\,$(MSYS_BASH))" ( \
	  echo ERROR: MSYS bash not found at $(MSYS_BASH). Install MSYS2 or pass MSYS_BASH=... & \
	  exit /b 1 \
	)
else
	@command -v verilator >/dev/null 2>&1 || { \
	  echo "ERROR: verilator not on PATH. Install or use MSYS2 ucrt64." >&2; \
	  exit 1; \
	}
endif

cov-verilator: check-verilator
ifeq ($(OS),Windows_NT)
	"$(MSYS_BASH)" "$(subst \,/,$(CURDIR))/scripts/run_verilator_cov.sh"
else
	bash scripts/run_verilator_cov.sh
endif

gui: check-vivado
	$(VIVADO) $(PROJECT)

clean:
ifeq ($(OS),Windows_NT)
	-rmdir /s /q senior_design.cache 2>NUL
	-rmdir /s /q senior_design.runs 2>NUL
	-rmdir /s /q senior_design.sim 2>NUL
	-rmdir /s /q senior_design.hw 2>NUL
	-rmdir /s /q senior_design.ip_user_files 2>NUL
	-rmdir /s /q senior_design.gen 2>NUL
	-rmdir /s /q cov 2>NUL
	-rmdir /s /q verilator\obj_dir 2>NUL
	-rmdir /s /q .Xil 2>NUL
	-del /q *.jou *.log *.str vivado_*.backup.jou vivado_*.backup.log 2>NUL
else
	rm -rf senior_design.cache senior_design.runs senior_design.sim \
	  senior_design.hw senior_design.ip_user_files senior_design.gen \
	  cov verilator/obj_dir .Xil
	rm -f *.jou *.log *.str vivado_*.backup.jou vivado_*.backup.log
endif
