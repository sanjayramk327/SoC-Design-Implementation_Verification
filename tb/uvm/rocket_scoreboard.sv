// -------------------------------------------------------------------------
// File: rocket_scoreboard.sv
// Description: UVM Scoreboard for verifying AXI transactions.
// -------------------------------------------------------------------------

`ifndef ROCKET_SCOREBOARD_SV
`define ROCKET_SCOREBOARD_SV

class rocket_scoreboard extends uvm_scoreboard;
  
  `uvm_component_utils(rocket_scoreboard)
  
  uvm_analysis_imp #(rocket_axi_item, rocket_scoreboard) axi_imp;
  
  int total_transactions;
  int passes;
  int failures;
  
  bit [31:0] ref_mem[bit [31:0]];

  function new(string name = "rocket_scoreboard", uvm_component parent);
    super.new(name, parent);
    axi_imp = new("axi_imp", this);
    total_transactions = 0;
    passes = 0;
    failures = 0;
  endfunction
  
  virtual function void write(rocket_axi_item item);
    total_transactions++;
    if (item.write) begin
      ref_mem[item.addr] = item.data;
    end else begin
      if (ref_mem.exists(item.addr)) begin
        if (ref_mem[item.addr] == item.data) begin
          passes++;
        end else begin
          failures++;
          `uvm_error("SCBD", $sformatf("Data mismatch at addr %h: exp %h, got %h", item.addr, ref_mem[item.addr], item.data))
        end
      end
    end
  endfunction
  
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCBD_REPORT", $sformatf("Total: %0d, Passes: %0d, Failures: %0d", total_transactions, passes, failures), UVM_NONE)
  endfunction

endclass : rocket_scoreboard

`endif
