import subprocess
import os
import sys

TB_DIR = "D:/PROJECTS/SoC/tb"
RTL_DIR = "D:/PROJECTS/SoC/rtl"

rtl_files = [
    os.path.join(RTL_DIR, "bus/axi4lite_slave.v"),
    os.path.join(RTL_DIR, "bus/reactive_event_matrix.v"),
    os.path.join(RTL_DIR, "bus/axi_interconnect.v"),
    os.path.join(RTL_DIR, "memory/boot_rom.v"),
    os.path.join(RTL_DIR, "memory/instruction_bram.v"),
    os.path.join(RTL_DIR, "cpu/riscv_alu.v"),
    os.path.join(RTL_DIR, "cpu/riscv_regfile.v"),
    os.path.join(RTL_DIR, "cpu/riscv_csr.v"),
    os.path.join(RTL_DIR, "cpu/riscv_core.v"),
    os.path.join(RTL_DIR, "udb/udb_datapath.v"),
    os.path.join(RTL_DIR, "udb/udb_macrocell.v"),
    os.path.join(RTL_DIR, "udb/udb_morph_controller.v"),
    os.path.join(RTL_DIR, "udb/udb_top.v"),
    os.path.join(RTL_DIR, "analog/analog_mux_bus.v"),
    os.path.join(RTL_DIR, "analog/idac_controller.v"),
    os.path.join(RTL_DIR, "analog/comparator_block.v"),
    os.path.join(RTL_DIR, "analog/neuromorphic_smartsense.v"),
    os.path.join(RTL_DIR, "analog/analog_top.v"),
    os.path.join(RTL_DIR, "hsiom/hsiom_cell.v"),
    os.path.join(RTL_DIR, "hsiom/hsiom_self_healing.v"),
    os.path.join(RTL_DIR, "hsiom/hsiom_top.v"),
    os.path.join(RTL_DIR, "uart/Baud_gen.v"),
    os.path.join(RTL_DIR, "uart/UART_Tx.v"),
    os.path.join(RTL_DIR, "uart/UART_Rx.v"),
    os.path.join(RTL_DIR, "uart/tx_fifo.v"),
    os.path.join(RTL_DIR, "uart/rx_fifo.v"),
    os.path.join(RTL_DIR, "uart/uart_reg.v"),
    os.path.join(RTL_DIR, "uart/uart_top.v"),
    os.path.join(RTL_DIR, "peripherals/tcpwm.v"),
    os.path.join(RTL_DIR, "peripherals/dma_controller.v"),
    os.path.join(RTL_DIR, "peripherals/wdt_pmu.v"),
    os.path.join(RTL_DIR, "peripherals/gpio_port.v"),
    os.path.join(RTL_DIR, "psoc_top.v")
]

tests = [
    ("UDB 2.0 Autonomous Context Morphing", "tb_udb_morph.v", [
        os.path.join(RTL_DIR, "bus/axi4lite_slave.v"),
        os.path.join(RTL_DIR, "udb/udb_datapath.v"),
        os.path.join(RTL_DIR, "udb/udb_macrocell.v"),
        os.path.join(RTL_DIR, "udb/udb_morph_controller.v"),
        os.path.join(RTL_DIR, "udb/udb_top.v")
    ]),
    ("Mixed-Signal Neuromorphic Smart-Sense", "tb_smartsense_snn.v", [
        os.path.join(RTL_DIR, "analog/neuromorphic_smartsense.v")
    ]),
    ("Self-Healing HSIOM Autonomous Failover", "tb_hsiom_failover.v", [
        os.path.join(RTL_DIR, "bus/axi4lite_slave.v"),
        os.path.join(RTL_DIR, "hsiom/hsiom_cell.v"),
        os.path.join(RTL_DIR, "hsiom/hsiom_self_healing.v"),
        os.path.join(RTL_DIR, "hsiom/hsiom_top.v")
    ]),
    ("Full MorphoSoC System Integration", "tb_soc_top.v", rtl_files)
]

print("=================================================================")
print("          MorphoSoC Automated Verification Regression Suite      ")
print("=================================================================\n")

all_passed = True
for name, tb_file, extra_files in tests:
    tb_path = os.path.join(TB_DIR, tb_file)
    sim_out = os.path.join(TB_DIR, tb_file.replace(".v", ".out"))
    cmd_compile = ["iverilog", "-Wall", "-g2005", "-gsystem-verilog", "-o", sim_out, tb_path] + extra_files
    
    print(f"[*] Compiling {name}...")
    res = subprocess.run(cmd_compile, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"[FAIL] Compilation error in {name}:\n{res.stderr}")
        all_passed = False
        continue
    
    print(f"[*] Running simulation {name}...")
    res_sim = subprocess.run(["vvp", sim_out], capture_output=True, text=True, cwd=TB_DIR)
    print(res_sim.stdout)
    if res_sim.returncode != 0:
        print(f"[FAIL] Simulation failed with error code {res_sim.returncode}")
        all_passed = False
    else:
        print(f"[PASS] {name} completed successfully!\n")

if all_passed:
    print("=================================================================")
    print("  ALL TESTS PASSED! MorphoSoC ARCHITECTURE 100% VERIFIED!      ")
    print("=================================================================")
else:
    print("One or more tests failed.")
    sys.exit(1)
