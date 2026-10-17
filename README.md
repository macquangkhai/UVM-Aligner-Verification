# UVM Verification Environment & AMBA APB VIP for Memory Aligner IP

## 📌 Project Overview
This repository contains a modular **UVM 1.2** verification environment and a reusable **AMBA 3 APB Verification IP (VIP)** developed to verify the control registers and memory alignment logic of an **Aligner IP Core**.

* **DUT:** Memory Aligner (`cfs_aligner`)
* **Data Bus Width:** 32-bit (`ALGN_DATA_WIDTH = 32`)
* **FIFO Depth:** 8 words (`FIFO_DEPTH = 8`)
* **Control Bus Protocol:** AMBA 3 APB (16-bit address, word-aligned, max 5 wait-states)
* **Registers Verified:** `CTRL` (`0x0000`), `STATUS` (`0x000C`), `IRQEN` (`0x00F0`), `IRQ` (`0x00F4`)

---

## 🏗️ Verification Architecture

The testbench is structured following standard UVM methodology:

```
+---------------------------------------------------------------+
|                       UVM Testbench Top                       |
|  +---------------------------------------------------------+  |
|  |                     cfs_algn_env                        |  |
|  |  +---------------------------------------------------+  |  |
|  |  |                  cfs_apb_agent                    |  |  |
|  |  |  +-------------+  +------------+  +------------+  |  |  |
|  |  |  |  Sequencer  |  |   Driver   |  |  Monitor   |  |  |  |
|  |  |  +------+------+  +-----+------+  +-----+------+  |  |  |
|  |  +---------|---------------|---------------|---------+  |  |
|  |            |               |               |            |  |
|  |            |    +----------+----------+    |            |  |
|  |            |    |  cfs_apb_coverage   |<---+ (Analysis) |  |
|  |            |    +---------------------+                 |  |
|  +------------|--------------------------------------------+  |
|               |                                               |
|  +------------v--------------------------------------------+  |
|  |               Virtual Interface (cfs_apb_if)            |  |
|  |              - 10+ SVA Protocol Assertions              |  |
|  +----------------------------+----------------------------+  |
|                               | (PCLK, PADDR, PWDATA, ...)    |
|  +----------------------------v----------------------------+  |
|  |                    DUT (cfs_aligner)                    |  |
|  +---------------------------------------------------------+  |
+---------------------------------------------------------------+
```

### 1. Reusable APB UVM Agent (`cfs_apb_pkg.sv`)
* **Sequence Items:** `cfs_apb_item_drv` (stimulus) and `cfs_apb_item_mon` (sampled transactions).
* **Driver (`cfs_apb_driver`):** Pin-level driver executing APB Setup and Access phases, supporting variable delays and handling `PREADY` wait-states.
* **Monitor (`cfs_apb_monitor`):** Passive bus listener collecting transfer attributes and broadcasting via `uvm_analysis_port`.
* **Sequencer (`cfs_apb_sequencer`):** Manages arbitration between sequences and driver.
* **Sequences:** 
  * `cfs_apb_sequence_rw`: Directed read and write transactions.
  * `cfs_apb_sequence_random`: Constrained-random sequences with randomized address, data, and inter-transfer delays.
* **Reset Recovery:** Implemented `cfs_apb_reset_handler` (SystemVerilog Interface Class) to coordinate clean runtime reset recovery across all components.

### 2. SystemVerilog Protocol Assertions (`cfs_apb_if.sv`)
Includes **10 formal SVA properties** monitoring AMBA 3 APB protocol rules:
* `PENABLE_AT_SETUP_PHASE_A`: Ensures `PENABLE` is deasserted during the Setup phase.
* `PENABLE_ENTERING_SETUP_PHASE_A` & `PENABLE_EXITING_SETUP_PHASE_A`: Checks valid phase transitions.
* `PENABLE_STABLE_AT_ACCESS_PHASE_A`: Verifies `PENABLE` stays asserted during wait-states.
* `PADDR_STABLE_AT_ACCESS_PHASE_A`, `PWDATA_STABLE_AT_ACCESS_PHASE_A`, `PWRITE_STABLE_AT_ACCESS_PHASE_A`: Enforces signal stability using `$stable()`.
* Unknown value detection: Validates that signals never enter high-impedance or undefined states (`$isunknown() == 0`).

### 3. Functional Coverage Model (`cfs_apb_coverage.sv`)
Built with 3 covergroups tracking:
* Transaction direction (`READ` vs `WRITE`).
* Slave response types (`OKAY` vs `SLVERR` on illegal accesses).
* Transfer durations (wait-states) and inter-transaction idle delays.
* Asynchronous reset occurrence while bus access is active (`cover_reset.access_ongoing`).

---

## 📊 Verification Results (Extracted from Cadence Xcelium Log)

Simulations were executed using **Cadence Xcelium 25.03 / 20.09** on testcase `cfs_algn_test_reg_access`:

* **UVM Report Summary:**
  ```text
  --- UVM Report Summary ---
  Quit count : 0 of 1
  ** Report counts by severity
  UVM_INFO    : 17
  UVM_WARNING : 0
  UVM_ERROR   : 0
  UVM_FATAL   : 0
  Simulation complete via $finish(1) at time 595 NS
  ```

* **Functional Coverage Breakdown:**
  * **Direction Coverage:** `100.00%` (both READ and WRITE exercised)
  * **Response Coverage:** `100.00%` (both OKAY and SLVERR responses verified)
  * **Direction Transitions:** `75.00%`
  * **Address & Data Slices:** `100.00%` on targeted register lanes
  * **Overall Initial Coverage:** `69.52%` (corner-case wait-states and dynamic resets left for stress tests)

---

## 🚀 How to Run Simulation

### Method 1: Using Cadence Xcelium (Command Line)
Execute the simulation script:
```bash
chmod +x run.sh
./run.sh
```

Or run directly using `xrun`:
```bash
xrun -Q -unbuffered -timescale 1ns/1ns -sysv -coverage functional -access +rw \
     +UVM_TESTNAME=cfs_algn_test_reg_access design.sv testbench.sv
```

### Method 2: Running on EDA Playground
1. Upload/copy the files into [EDA Playground](https://www.edaplayground.com).
2. Set **Tools & Simulators** to **Cadence Xcelium 20.09** (or **Synopsys VCS**).
3. Set **Compile Options**: `-timescale 1ns/1ns -sysv`.
4. Set **Run Options**: `+UVM_TESTNAME=cfs_algn_test_reg_access`.
5. Check **Open EPWave after run** to observe waveform activity.
6. Click **Run**.

---

## 📂 Repository Structure
```text
├── docs/
│   └── aligner_datasheet_v_1_0.pdf    # Complete DUT Hardware Specification
├── cfs_aligner.v                      # DUT Top Wrapper
├── cfs_aligner_core.v                 # Aligner Core Logic
├── cfs_ctrl.v                         # Core Control Module
├── cfs_rx_ctrl.v                      # RX Controller
├── cfs_tx_ctrl.v                      # TX Controller
├── cfs_regs.v                         # Register File
├── cfs_synch_fifo.v                   # Synchronous FIFO
├── cfs_synch.v                        # Clock Synchronizer
├── cfs_edge_detect.v                  # Edge Detector
├── design.sv                          # Top RTL Filelist
├── cfs_apb_if.sv                      # APB Interface with SVA Assertions
├── cfs_apb_pkg.sv                     # Reusable APB UVM VIP Package
├── cfs_algn_pkg.sv                    # Aligner Environment Package
├── cfs_algn_env.sv                    # Aligner Top Environment
├── cfs_algn_test_pkg.sv               # Test Package
├── cfs_algn_test_base.sv              # Base Test Class
├── cfs_algn_test_reg_access.sv        # Register Access Testcase
├── testbench.sv                       # Top Testbench Module
├── run.sh                             # Simulation Shell Script
├── .gitignore                         # Git Exclusion Rules
└── README.md                          # Project Documentation
```
