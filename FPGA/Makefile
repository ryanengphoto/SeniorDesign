# FPGA / Vivado — run from FPGA/ (make build) or repo root (make -C FPGA build).
# Requires Vivado on PATH, or override:
#   make build VIVADO="C:/Xilinx/Vivado/2018.2/bin/vivado.bat"

VIVADO      ?= vivado
VIVADO_JOBS ?= 4
PROJECT     := senior_design.xpr
SCRIPTS     := scripts

# Optional sim knobs (passed into Tcl via env):
#   make sim SIM_TOP=tb_sniffer SIM_TIME=10us
SIM_TOP  ?= tb_sniffer
SIM_TIME ?=
PYTHON   ?= python
SIM_LOG  := sim_last.log

.PHONY: help build synth sim sim-status gui clean check-vivado

.DEFAULT_GOAL := help

help:
	@echo "FPGA Vivado targets (FPGA/)"
	@echo ""
	@echo "  make build    Synth + implement + write bitstream"
	@echo "  make synth    Synthesis only"
	@echo "  make sim         Behavioral sim (XSim); default top $(SIM_TOP)"
	@echo "  make sim-status  Score last sim log (no Vivado)"
	@echo "  make gui         Open $(PROJECT) in the Vivado GUI"
	@echo "  make clean       Remove generated Vivado dirs/logs (keeps sources + .xpr)"
	@echo ""
	@echo "Overrides:"
	@echo "  VIVADO=...          Path to vivado / vivado.bat if not on PATH"
	@echo "  VIVADO_JOBS=N       Parallel jobs for runs (default $(VIVADO_JOBS))"
	@echo "  SIM_TOP=module      Override sim_1 top module (default $(SIM_TOP))"
	@echo "  SIM_TIME=10us       Run for a fixed time instead of 'run all'"
	@echo "  PYTHON=python       Interpreter for scripts/check_sim.py"

check-vivado:
	@command -v "$(VIVADO)" >/dev/null 2>&1 || { \
	  echo "ERROR: '$(VIVADO)' not found on PATH." >&2; \
	  echo "Install Vivado and add its bin/ to PATH, or pass VIVADO=..." >&2; \
	  exit 1; \
	}

build: check-vivado
	VIVADO_JOBS=$(VIVADO_JOBS) $(VIVADO) -mode batch -source $(SCRIPTS)/build.tcl -nojournal -nolog

synth: check-vivado
	VIVADO_JOBS=$(VIVADO_JOBS) $(VIVADO) -mode batch -source $(SCRIPTS)/synth.tcl -nojournal -nolog

# Vivado produces the log; Python only scores TEST PASSED / TEST FAILED
# (GnuWin32 make has no reliable grep). Leading '-' still runs sim-status
# if the batch run fails, so the verdict comes from the log.
ifeq ($(OS),Windows_NT)
sim:
	-cmd /c "set SIM_TOP=$(SIM_TOP)&& set SIM_TIME=$(SIM_TIME)&& $(VIVADO) -mode batch -source $(SCRIPTS)/sim.tcl -nojournal -nolog > $(SIM_LOG) 2>&1"
	$(PYTHON) $(SCRIPTS)/check_sim.py $(SIM_LOG)
else
sim:
	-SIM_TOP="$(SIM_TOP)" SIM_TIME="$(SIM_TIME)" \
	  $(VIVADO) -mode batch -source $(SCRIPTS)/sim.tcl -nojournal -nolog \
	  > $(SIM_LOG) 2>&1
	$(PYTHON) $(SCRIPTS)/check_sim.py $(SIM_LOG)
endif

sim-status:
	$(PYTHON) $(SCRIPTS)/check_sim.py $(SIM_LOG)

gui: check-vivado
	$(VIVADO) $(PROJECT)

clean:
	rm -rf senior_design.cache senior_design.runs senior_design.sim \
	  senior_design.hw senior_design.ip_user_files senior_design.gen \
	  .Xil
	rm -f *.jou *.log *.str vivado_*.backup.jou vivado_*.backup.log
