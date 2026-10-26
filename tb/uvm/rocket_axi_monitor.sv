// -------------------------------------------------------------------------
// File: rocket_axi_monitor.sv
// Description: UVM Monitor for capturing AXI4-Lite transactions.
// -------------------------------------------------------------------------

`ifndef ROCKET_AXI_MONITOR_SV
`define ROCKET_AXI_MONITOR_SV

class rocket_axi_monitor extends uvm_monitor;
  
  `uvm_component_utils(rocket_axi_monitor)
  
  virtual rocket_axi_if vif;
  uvm_analysis_port #(rocket_axi_item) item_collected_port;
  
  function new(string name = "rocket_axi_monitor", uvm_component parent);
    super.new(name, parent);
    item_collected_port = new("item_collected_port", this);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rocket_axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    rocket_axi_item item;
    
    forever begin
      @(posedge vif.clk);
      
      // Monitor write transactions
      if (vif.awvalid && vif.awready && vif.wvalid && vif.wready) begin
        item = rocket_axi_item::type_id::create("item");
        item.addr = vif.awaddr;
        item.data = vif.wdata;
        item.wstrb = vif.wstrb;
        item.write = 1;
        item_collected_port.write(item);
      end
      
      // Monitor read transactions
      if (vif.arvalid && vif.arready && vif.rvalid && vif.rready) begin
        item = rocket_axi_item::type_id::create("item");
        item.addr = vif.araddr;
        item.data = vif.rdata;
        item.write = 0;
        item_collected_port.write(item);
      end
    end
  endtask

endclass : rocket_axi_monitor

`endif
