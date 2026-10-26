// -------------------------------------------------------------------------
// File: rocket_mem_agent.sv
// Description: UVM Agent for the 64-bit local memory interface.
// -------------------------------------------------------------------------

`ifndef ROCKET_MEM_AGENT_SV
`define ROCKET_MEM_AGENT_SV

class rocket_mem_agent extends uvm_agent;
  
  `uvm_component_utils(rocket_mem_agent)
  
  // Components for mem agent would be instantiated here
  // (Driver, Monitor, Sequencer)
  // Simplified for this example structure
  
  function new(string name = "rocket_mem_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Build mem driver/monitor
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // Connect mem driver/monitor
  endfunction

endclass : rocket_mem_agent

`endif
