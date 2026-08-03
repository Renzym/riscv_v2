# Icarus-Verilog simulation script for the modular RV32IM core (no caches).

$RTL = "../fpga/rtl"

Write-Host "Compiling RV32M core checks (Icarus)..."
iverilog -g2012 -o riscv_m_extension_sim `
    "$RTL/riscv_pkg.sv" `
    "$RTL/riscv_alu.sv" `
    "$RTL/riscv_regfile.sv" `
    "$RTL/riscv_decode.sv" `
    "$RTL/riscv_csr.sv" `
    "$RTL/riscv_lsu.sv" `
    "$RTL/riscv_hazard.sv" `
    "$RTL/riscv_core.sv" `
    ./riscv_m_extension_tb.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "RV32M core compilation failed."
    exit $LASTEXITCODE
}

Write-Host "RV32M core simulation running..."
vvp riscv_m_extension_sim
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Compiling external interrupt checks (Icarus)..."
iverilog -g2012 -o riscv_external_irq_sim `
    "$RTL/riscv_pkg.sv" `
    "$RTL/riscv_alu.sv" `
    "$RTL/riscv_regfile.sv" `
    "$RTL/riscv_decode.sv" `
    "$RTL/riscv_csr.sv" `
    "$RTL/riscv_lsu.sv" `
    "$RTL/riscv_hazard.sv" `
    "$RTL/riscv_core.sv" `
    ./riscv_external_irq_tb.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "External interrupt compilation failed."
    exit $LASTEXITCODE
}

Write-Host "External interrupt simulation running..."
vvp riscv_external_irq_sim
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Compiling direct BRAM wrapper checks (Icarus)..."
iverilog -g2012 -o riscv_zynq_wrapper_sim `
    "$RTL/riscv_pkg.sv" `
    "$RTL/riscv_alu.sv" `
    "$RTL/riscv_regfile.sv" `
    "$RTL/riscv_decode.sv" `
    "$RTL/riscv_csr.sv" `
    "$RTL/riscv_lsu.sv" `
    "$RTL/riscv_hazard.sv" `
    "$RTL/riscv_core.sv" `
    "$RTL/axi_lite_control.sv" `
    "$RTL/riscv_axi_lite_master.sv" `
    "$RTL/riscv_zynq_wrapper.sv" `
    ./riscv_zynq_wrapper_tb.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "Direct BRAM wrapper compilation failed."
    exit $LASTEXITCODE
}

Write-Host "Direct BRAM wrapper simulation running..."
vvp riscv_zynq_wrapper_sim
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Compiling BRAM plus AXI-Lite peripheral wrapper checks (Icarus)..."
iverilog -g2012 -o riscv_zynq_axi_periph_sim `
    "$RTL/riscv_pkg.sv" `
    "$RTL/riscv_alu.sv" `
    "$RTL/riscv_regfile.sv" `
    "$RTL/riscv_decode.sv" `
    "$RTL/riscv_csr.sv" `
    "$RTL/riscv_lsu.sv" `
    "$RTL/riscv_hazard.sv" `
    "$RTL/riscv_core.sv" `
    "$RTL/axi_lite_control.sv" `
    "$RTL/riscv_axi_lite_master.sv" `
    "$RTL/riscv_zynq_wrapper.sv" `
    ./riscv_zynq_axi_periph_tb.sv

if ($LASTEXITCODE -ne 0) {
    Write-Host "BRAM plus AXI-Lite peripheral wrapper compilation failed."
    exit $LASTEXITCODE
}

Write-Host "BRAM plus AXI-Lite peripheral wrapper simulation running..."
vvp riscv_zynq_axi_periph_sim
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "Compiling SystemVerilog (Icarus)..."
# -g2012 enables SystemVerilog 2012. Package first, then modules, core, then TB.
iverilog -g2012 -o riscv_sim `
    "$RTL/riscv_pkg.sv" `
    "$RTL/riscv_alu.sv" `
    "$RTL/riscv_regfile.sv" `
    "$RTL/riscv_decode.sv" `
    "$RTL/riscv_csr.sv" `
    "$RTL/riscv_lsu.sv" `
    "$RTL/riscv_hazard.sv" `
    "$RTL/riscv_core.sv" `
    ./riscv_tb.sv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Simulation running..."
    vvp riscv_sim
    Write-Host "Simulation finished. Waveform saved to riscv_core.vcd"
} else {
    Write-Host "Compilation failed."
}
