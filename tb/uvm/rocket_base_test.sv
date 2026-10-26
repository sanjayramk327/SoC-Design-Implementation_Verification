// -------------------------------------------------------------------------
// File: rocket_base_test.sv
// Description: Base test class for the Rocket core verification.
// -------------------------------------------------------------------------

`ifndef ROCKET_BASE_TEST_SV
`define ROCKET_BASE_TEST_SV

class rocket_base_test extends uvm_test;
  
  `uvm_component_utils(rocket_base_test)
  
  rocket_env env;

  function new(string name = "rocket_base_test", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = rocket_env::type_id::create("env", this);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.axi_agent.sequencer.run_phase", "default_sequence", rocket_random_rw_seq::type_id::get());
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    #1000ns;
    phase.drop_objection(this);
  endtask

endclass : rocket_base_test

// Derived test
class rocket_uart_test extends rocket_base_test;
  `uvm_component_utils(rocket_uart_test)
  
  function new(string name = "rocket_uart_test", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_object_wrapper)::set(this, "env.axi_agent.sequencer.run_phase", "default_sequence", rocket_uart_hello_seq::type_id::get());
  endfunction
endclass

`endif
