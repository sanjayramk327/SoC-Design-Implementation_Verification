// -------------------------------------------------------------------------
// File: rocket_mem_if.sv
// Description: SystemVerilog interface for the 64-bit local memory.
// -------------------------------------------------------------------------

`ifndef ROCKET_MEM_IF_SV
`define ROCKET_MEM_IF_SV

interface rocket_mem_if(input logic clk, input logic rst_n);

  logic [31:0] addr;
  logic        ren;
  logic        wen;
  logic [63:0] wdata;
  logic [7:0]  wstrb;
  logic [63:0] rdata;
  
  clocking cb @(posedge clk);
    default input #1step output #1;
    input addr, ren, wen, wdata, wstrb;
    output rdata;
  endclocking

  modport core (
    output addr, ren, wen, wdata, wstrb,
    input  rdata
  );

  modport mem (
    input  addr, ren, wen, wdata, wstrb,
    output rdata
  );

endinterface : rocket_mem_if

`endif
