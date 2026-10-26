// -------------------------------------------------------------------------
// File: rocket_coverage.sv
// Description: Functional coverage collector.
// -------------------------------------------------------------------------

`ifndef ROCKET_COVERAGE_SV
`define ROCKET_COVERAGE_SV

class rocket_coverage extends uvm_subscriber #(rocket_axi_item);
  
  `uvm_component_utils(rocket_coverage)
  
  covergroup axi_cg;
    option.per_instance = 1;
    
    cp_addr: coverpoint item.addr {
      bins rom   = { [32'h4000_0000 : 32'h4000_1FFF] };
      bins sram  = { [32'h4000_2000 : 32'h4000_3FFF] };
      bins gpio  = { [32'h4000_4000 : 32'h4000_4FFF] };
      bins udb   = { [32'h4000_5000 : 32'h4000_5FFF] };
      bins uart  = { [32'h4000_6000 : 32'h4000_6FFF] };
      bins other = default;
    }
    
    cp_write: coverpoint item.write {
      bins read  = { 0 };
      bins write = { 1 };
    }
    
    cross cp_addr, cp_write;
  endgroup
  
  rocket_axi_item item;

  function new(string name = "rocket_coverage", uvm_component parent);
    super.new(name, parent);
    axi_cg = new();
  endfunction
  
  virtual function void write(rocket_axi_item t);
    item = t;
    axi_cg.sample();
  endfunction

endclass : rocket_coverage

`endif
