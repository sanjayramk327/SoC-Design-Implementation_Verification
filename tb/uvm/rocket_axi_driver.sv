// -------------------------------------------------------------------------
// File: rocket_axi_driver.sv
// Description: UVM Driver for AXI4-Lite interface. Acts as a memory slave.
// -------------------------------------------------------------------------

`ifndef ROCKET_AXI_DRIVER_SV
`define ROCKET_AXI_DRIVER_SV

class rocket_axi_driver extends uvm_driver #(rocket_axi_item);
  
  `uvm_component_utils(rocket_axi_driver)
  
  virtual rocket_axi_if vif;
  
  // Internal memory model for responses
  bit [31:0] mem[bit [31:0]];

  function new(string name = "rocket_axi_driver", uvm_component parent);
    super.new(name, parent);
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual rocket_axi_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"});
    end
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    vif.awready <= 0;
    vif.wready <= 0;
    vif.bvalid <= 0;
    vif.arready <= 0;
    vif.rvalid <= 0;
    
    forever begin
      @(posedge vif.clk);
      
      // Simple slave response logic
      // Handle Writes
      if (vif.awvalid && !vif.awready) begin
        vif.awready <= 1;
        @(posedge vif.clk);
        vif.awready <= 0;
      end
      if (vif.wvalid && !vif.wready) begin
        vif.wready <= 1;
        mem[vif.awaddr] = vif.wdata; // simplified
        @(posedge vif.clk);
        vif.wready <= 0;
        vif.bvalid <= 1;
        vif.bresp <= 2'b00; // OKAY
      end
      if (vif.bvalid && vif.bready) begin
        vif.bvalid <= 0;
      end
      
      // Handle Reads
      if (vif.arvalid && !vif.arready) begin
        vif.arready <= 1;
        @(posedge vif.clk);
        vif.arready <= 0;
        vif.rvalid <= 1;
        if (mem.exists(vif.araddr))
          vif.rdata <= mem[vif.araddr];
        else
          vif.rdata <= 32'hDEADBEEF;
        vif.rresp <= 2'b00;
      end
      if (vif.rvalid && vif.rready) begin
        vif.rvalid <= 0;
      end
    end
  endtask

endclass : rocket_axi_driver

`endif
