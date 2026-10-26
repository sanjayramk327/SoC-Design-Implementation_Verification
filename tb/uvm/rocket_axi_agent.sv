// -------------------------------------------------------------------------
// File: rocket_axi_agent.sv
// Description: UVM Agent combining AXI driver, monitor, and sequencer.
// -------------------------------------------------------------------------

`ifndef ROCKET_AXI_AGENT_SV
`define ROCKET_AXI_AGENT_SV

class rocket_axi_agent extends uvm_agent;
  
  `uvm_component_utils(rocket_axi_agent)
  
  uvm_sequencer #(rocket_axi_item) sequencer;
  rocket_axi_driver driver;
  rocket_axi_monitor monitor;
  
  uvm_analysis_port #(rocket_axi_item) ap;

  function new(string name = "rocket_axi_agent", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    monitor = rocket_axi_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = uvm_sequencer#(rocket_axi_item)::type_id::create("sequencer", this);
      driver = rocket_axi_driver::type_id::create("driver", this);
    end
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor.item_collected_port.connect(ap);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass : rocket_axi_agent

`endif
