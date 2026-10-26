// -------------------------------------------------------------------------
// File: rocket_axi_item.sv
// Description: UVM Sequence Item for AXI4-Lite transactions.
// -------------------------------------------------------------------------

`ifndef ROCKET_AXI_ITEM_SV
`define ROCKET_AXI_ITEM_SV

class rocket_axi_item extends uvm_sequence_item;
  
  // AXI4-Lite transaction fields
  rand bit [31:0] addr;
  rand bit [31:0] data;
  rand bit [3:0]  wstrb;
  rand bit        write; // 1 for write, 0 for read
  bit      [1:0]  resp;
  
  // Factory registration
  `uvm_object_utils(rocket_axi_item)
  
  // Constraints
  // Peripheral map 0x4000_xxxx
  constraint addr_c {
    addr inside { [32'h4000_0000 : 32'h4000_FFFF] };
  }
  
  // Constructor
  function new(string name = "rocket_axi_item");
    super.new(name);
  endfunction
  
  // UVM object methods
  virtual function void do_copy(uvm_object rhs);
    rocket_axi_item rhs_;
    if (!$cast(rhs_, rhs))
      `uvm_fatal("DO_COPY", "Cast failed")
    super.do_copy(rhs);
    this.addr  = rhs_.addr;
    this.data  = rhs_.data;
    this.wstrb = rhs_.wstrb;
    this.write = rhs_.write;
    this.resp  = rhs_.resp;
  endfunction

  virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    rocket_axi_item rhs_;
    if (!$cast(rhs_, rhs))
      return 0;
    return (super.do_compare(rhs, comparer) &&
            this.addr == rhs_.addr &&
            this.data == rhs_.data &&
            this.wstrb == rhs_.wstrb &&
            this.write == rhs_.write &&
            this.resp == rhs_.resp);
  endfunction

  virtual function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("addr", addr, 32, UVM_HEX);
    printer.print_field("data", data, 32, UVM_HEX);
    printer.print_field("wstrb", wstrb, 4, UVM_HEX);
    printer.print_field("write", write, 1, UVM_BIN);
    printer.print_field("resp", resp, 2, UVM_BIN);
  endfunction

endclass : rocket_axi_item

`endif
