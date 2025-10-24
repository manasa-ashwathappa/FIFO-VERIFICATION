# FIFO Verification (SystemVerilog)

A synchronous **8-bit FIFO** (First-In-First-Out) design verified using a lightweight, class-based SystemVerilog testbench.  
The project demonstrates a structured approach to functional verification — including stimulus generation, driving, monitoring, and checking.

---

## Overview

This repository implements and verifies a **16-depth × 8-bit FIFO** using a custom environment inspired by UVM principles (without requiring the full UVM library).

The design supports:
- Write (`wr`) and Read (`rd`) operations
- FIFO status flags (`full`, `empty`)
- Synchronous reset and clocked operations

The verification environment includes:
- **Generator** – produces randomized read/write transactions  
- **Driver** – applies stimulus to the DUT  
- **Monitor** – observes DUT behavior  
- **Scoreboard** – checks correctness using a golden FIFO model  
- **Environment** – connects and coordinates all components  

---

## Repository Structure
```bash
fifo-verification/
├── src/                        # Source files for design and testbench
│   ├── fifo.sv                 # FIFO RTL (Design Under Test)
│   ├── fifo_if.sv              # Interface connecting DUT and testbench
│   ├── classes.sv              # Verification classes (GEN, DRV, MON, SCO, ENV)
│   └── tb_fifo.sv              # Top-level testbench module
│
├── waves/                      # Auto-generated waveform dump directory (created after simulation)
│   └── dump.vcd                # Simulation waveform file (generated)
│
├── Makefile                    # Build, run, lint, and clean commands
├── .gitignore                  # Ignore build artifacts and temp files
├── LICENSE                     # MIT License for open-source use
└── README.md                   # Project documentation (this file)
