#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RTL="${SCRIPT_DIR}/../fpga/rtl"
OUTPUT="${SCRIPT_DIR}/riscv_sim"

echo "Compiling RV32M core checks (Icarus)..."
iverilog -g2012 -o "${SCRIPT_DIR}/riscv_m_extension_sim" \
    "${RTL}/riscv_pkg.sv" \
    "${RTL}/riscv_alu.sv" \
    "${RTL}/riscv_regfile.sv" \
    "${RTL}/riscv_decode.sv" \
    "${RTL}/riscv_csr.sv" \
    "${RTL}/riscv_lsu.sv" \
    "${RTL}/riscv_hazard.sv" \
    "${RTL}/riscv_core.sv" \
    "${SCRIPT_DIR}/riscv_m_extension_tb.sv"

echo "RV32M core simulation running..."
(
    cd "${SCRIPT_DIR}"
    vvp "${SCRIPT_DIR}/riscv_m_extension_sim"
)

echo "Compiling external interrupt checks (Icarus)..."
iverilog -g2012 -o "${SCRIPT_DIR}/riscv_external_irq_sim" \
    "${RTL}/riscv_pkg.sv" \
    "${RTL}/riscv_alu.sv" \
    "${RTL}/riscv_regfile.sv" \
    "${RTL}/riscv_decode.sv" \
    "${RTL}/riscv_csr.sv" \
    "${RTL}/riscv_lsu.sv" \
    "${RTL}/riscv_hazard.sv" \
    "${RTL}/riscv_core.sv" \
    "${SCRIPT_DIR}/riscv_external_irq_tb.sv"

echo "External interrupt simulation running..."
(
    cd "${SCRIPT_DIR}"
    vvp "${SCRIPT_DIR}/riscv_external_irq_sim"
)

echo "Compiling direct BRAM wrapper checks (Icarus)..."
iverilog -g2012 -o "${SCRIPT_DIR}/riscv_zynq_wrapper_sim" \
    "${RTL}/riscv_pkg.sv" \
    "${RTL}/riscv_alu.sv" \
    "${RTL}/riscv_regfile.sv" \
    "${RTL}/riscv_decode.sv" \
    "${RTL}/riscv_csr.sv" \
    "${RTL}/riscv_lsu.sv" \
    "${RTL}/riscv_hazard.sv" \
    "${RTL}/riscv_core.sv" \
    "${RTL}/axi_lite_control.sv" \
    "${RTL}/riscv_axi_lite_master.sv" \
    "${RTL}/riscv_zynq_wrapper.sv" \
    "${SCRIPT_DIR}/riscv_zynq_wrapper_tb.sv"

echo "Direct BRAM wrapper simulation running..."
(
    cd "${SCRIPT_DIR}"
    vvp "${SCRIPT_DIR}/riscv_zynq_wrapper_sim"
)

echo "Compiling BRAM plus AXI-Lite peripheral wrapper checks (Icarus)..."
iverilog -g2012 -o "${SCRIPT_DIR}/riscv_zynq_axi_periph_sim" \
    "${RTL}/riscv_pkg.sv" \
    "${RTL}/riscv_alu.sv" \
    "${RTL}/riscv_regfile.sv" \
    "${RTL}/riscv_decode.sv" \
    "${RTL}/riscv_csr.sv" \
    "${RTL}/riscv_lsu.sv" \
    "${RTL}/riscv_hazard.sv" \
    "${RTL}/riscv_core.sv" \
    "${RTL}/axi_lite_control.sv" \
    "${RTL}/riscv_axi_lite_master.sv" \
    "${RTL}/riscv_zynq_wrapper.sv" \
    "${SCRIPT_DIR}/riscv_zynq_axi_periph_tb.sv"

echo "BRAM plus AXI-Lite peripheral wrapper simulation running..."
(
    cd "${SCRIPT_DIR}"
    vvp "${SCRIPT_DIR}/riscv_zynq_axi_periph_sim"
)

echo "Compiling SystemVerilog (Icarus)..."
# Package must be listed first, then the modules, then the core, then the TB.
iverilog -g2012 -o "${OUTPUT}" \
    "${RTL}/riscv_pkg.sv" \
    "${RTL}/riscv_alu.sv" \
    "${RTL}/riscv_regfile.sv" \
    "${RTL}/riscv_decode.sv" \
    "${RTL}/riscv_csr.sv" \
    "${RTL}/riscv_lsu.sv" \
    "${RTL}/riscv_hazard.sv" \
    "${RTL}/riscv_core.sv" \
    "${SCRIPT_DIR}/riscv_tb.sv"

echo "Simulation running..."
(
    cd "${SCRIPT_DIR}"
    vvp "${OUTPUT}"
)
echo "Simulation finished. Waveform saved to riscv_core.vcd"
