# SPDX-License-Identifier: MIT
# (c) 2025 Manasa Ashwathappa
#
# ---------------------------------------------------------------
# Makefile for FIFO Verification Project
# ---------------------------------------------------------------
# Supports:
#   - Building and running simulation using Icarus Verilog
#   - Viewing waveforms in GTKWave
#   - Cleaning up generated files
#
# Usage:
#   make run      → Compile and run simulation
#   make view     → Open GTKWave to view dump.vcd
#   make clean    → Delete generated files
# ---------------------------------------------------------------

# ----------------------------------------------------------------
# File paths
# ----------------------------------------------------------------
SRC = src/fifo.sv src/fifo_if.sv src/classes.sv src/tb_fifo.sv
OUT = sim.vvp
WAVES = waves/dump.vcd

# ----------------------------------------------------------------
# Compiler settings
# ----------------------------------------------------------------
IVERILOG = iverilog
IVERILOG_FLAGS = -g2012 -Wall

# ----------------------------------------------------------------
# Default target
# ----------------------------------------------------------------
all: run

# ----------------------------------------------------------------
# Build target
# ----------------------------------------------------------------
build:
	@echo "🔧 Building FIFO simulation..."
	@mkdir -p waves
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(OUT) $(SRC)
	@echo "✅ Build complete."

# ----------------------------------------------------------------
# Run simulation
# ----------------------------------------------------------------
run: build
	@echo "🚀 Running simulation..."
	@vvp $(OUT)
	@echo "✅ Simulation finished."

# ----------------------------------------------------------------
# View waveform in GTKWave
# ----------------------------------------------------------------
view:
	@echo "📊 Opening waveform in GTKWave..."
	@gtkwave $(WAVES) >/dev/null 2>&1 &

# ----------------------------------------------------------------
# Lint (optional, if Verilator installed)
# ----------------------------------------------------------------
lint:
	@echo "🔍 Linting with Verilator..."
	verilator --lint-only -Wall $(SRC)

# ----------------------------------------------------------------
# Clean generated files
# ----------------------------------------------------------------
clean:
	@echo "🧹 Cleaning up..."
	rm -rf $(OUT) $(WAVES)
	@echo "✅ Cleanup complete."

.PHONY: all build run view lint clean
