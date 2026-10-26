// -------------------------------------------------------------------------
// File: rocket_test_top.sv
// Description: Top-level module for the Rocket core UVM testbench.
// -------------------------------------------------------------------------

`timescale 1ns / 1ps
`include "uvm_macros.svh"

module rocket_test_top;
  
  import uvm_pkg::*;
  import rocket_env_pkg::*;

  logic clk;
  logic rst_n;
  
  // Interrupt and status signals
  logic ext_intr, tmr_intr, sw_intr, dbg_intr;
  logic core_halted;
  logic [63:0] debug_pc;
  logic [1:0] priv_mode;

  // Interfaces
  rocket_axi_if axi_if(clk, rst_n);
  rocket_mem_if mem_if(clk, rst_n);
  
  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end
  
  // Reset generation
  initial begin
    rst_n = 0;
    #20 rst_n = 1;
  end

  // DUT Instantiation (Placeholder)
  /*
  rocket_rv64gc dut (
    .clk(clk),
    .rst_n(rst_n),
    
    // AXI4-Lite
    .m_axi_awaddr(axi_if.awaddr),
    .m_axi_awvalid(axi_if.awvalid),
    .m_axi_awready(axi_if.awready),
    .m_axi_wdata(axi_if.wdata),
    .m_axi_wstrb(axi_if.wstrb),
    .m_axi_wvalid(axi_if.wvalid),
    .m_axi_wready(axi_if.wready),
    .m_axi_bresp(axi_if.bresp),
    .m_axi_bvalid(axi_if.bvalid),
    .m_axi_bready(axi_if.bready),
    .m_axi_araddr(axi_if.araddr),
    .m_axi_arvalid(axi_if.arvalid),
    .m_axi_arready(axi_if.arready),
    .m_axi_rdata(axi_if.rdata),
    .m_axi_rresp(axi_if.rresp),
    .m_axi_rvalid(axi_if.rvalid),
    .m_axi_rready(axi_if.rready),
    
    // Memory Interface
    .mem_addr(mem_if.addr),
    .mem_ren(mem_if.ren),
    .mem_wen(mem_if.wen),
    .mem_wdata(mem_if.wdata),
    .mem_wstrb(mem_if.wstrb),
    .mem_rdata(mem_if.rdata),
    
    // Interrupts
    .ext_intr(ext_intr),
    .tmr_intr(tmr_intr),
    .sw_intr(sw_intr),
    .dbg_intr(dbg_intr),
    
    // Status
    .core_halted(core_halted),
    .debug_pc(debug_pc),
    .priv_mode(priv_mode)
  );
  */

  initial begin
    // Set virtual interfaces in UVM config_db
    uvm_config_db#(virtual rocket_axi_if)::set(null, "*", "vif", axi_if);
    // uvm_config_db#(virtual rocket_mem_if)::set(null, "*", "mem_vif", mem_if);
    
    // Run the UVM test
    run_test();
  end
  
endmodule
