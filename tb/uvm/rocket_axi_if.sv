// -------------------------------------------------------------------------
// File: rocket_axi_if.sv
// Description: SystemVerilog interface for AXI4-Lite.
// -------------------------------------------------------------------------

`ifndef ROCKET_AXI_IF_SV
`define ROCKET_AXI_IF_SV

interface rocket_axi_if(input logic clk, input logic rst_n);

  logic [31:0] awaddr;
  logic        awvalid;
  logic        awready;

  logic [31:0] wdata;
  logic [3:0]  wstrb;
  logic        wvalid;
  logic        wready;

  logic [1:0]  bresp;
  logic        bvalid;
  logic        bready;

  logic [31:0] araddr;
  logic        arvalid;
  logic        arready;

  logic [31:0] rdata;
  logic [1:0]  rresp;
  logic        rvalid;
  logic        rready;
  
  clocking cb @(posedge clk);
    default input #1step output #1;
    input awvalid, awaddr, wvalid, wdata, wstrb, bready, arvalid, araddr, rready;
    output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp;
  endclocking

  modport master (
    output awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready,
    input  awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

  modport slave (
    input  awaddr, awvalid, wdata, wstrb, wvalid, bready, araddr, arvalid, rready,
    output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp
  );

endinterface : rocket_axi_if

`endif
