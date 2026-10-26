// -------------------------------------------------------------------------
// File: rocket_sequences.sv
// Description: UVM Sequences for the Rocket core testbench.
// -------------------------------------------------------------------------

`ifndef ROCKET_SEQUENCES_SV
`define ROCKET_SEQUENCES_SV

class rocket_base_seq extends uvm_sequence #(rocket_axi_item);
  `uvm_object_utils(rocket_base_seq)
  
  function new(string name = "rocket_base_seq");
    super.new(name);
  endfunction
endclass

class rocket_random_rw_seq extends rocket_base_seq;
  `uvm_object_utils(rocket_random_rw_seq)
  
  function new(string name = "rocket_random_rw_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(20) begin
      `uvm_do(req)
    end
  endtask
endclass

class rocket_uart_hello_seq extends rocket_base_seq;
  `uvm_object_utils(rocket_uart_hello_seq)
  
  function new(string name = "rocket_uart_hello_seq");
    super.new(name);
  endfunction
  
  virtual task body();
    // Simulate writing "Hello" to UART peripheral
    `uvm_do_with(req, {addr == 32'h4000_6000; data == 32'h48; write == 1;}) // H
    `uvm_do_with(req, {addr == 32'h4000_6000; data == 32'h65; write == 1;}) // e
    `uvm_do_with(req, {addr == 32'h4000_6000; data == 32'h6C; write == 1;}) // l
    `uvm_do_with(req, {addr == 32'h4000_6000; data == 32'h6C; write == 1;}) // l
    `uvm_do_with(req, {addr == 32'h4000_6000; data == 32'h6F; write == 1;}) // o
  endtask
endclass

`endif
