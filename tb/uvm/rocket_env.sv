// -------------------------------------------------------------------------
// File: rocket_env.sv
// Description: UVM Environment instantiating agents, scoreboard, coverage.
// -------------------------------------------------------------------------

`ifndef ROCKET_ENV_SV
`define ROCKET_ENV_SV

class rocket_env extends uvm_env;
  
  `uvm_component_utils(rocket_env)
  
  rocket_axi_agent axi_agent;
  rocket_mem_agent mem_agent;
  rocket_scoreboard scbd;
  rocket_coverage cov;

  function new(string name = "rocket_env", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axi_agent = rocket_axi_agent::type_id::create("axi_agent", this);
    mem_agent = rocket_mem_agent::type_id::create("mem_agent", this);
    scbd = rocket_scoreboard::type_id::create("scbd", this);
    cov = rocket_coverage::type_id::create("cov", this);
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    axi_agent.ap.connect(scbd.axi_imp);
    axi_agent.ap.connect(cov.analysis_export);
  endfunction

endclass : rocket_env

`endif
