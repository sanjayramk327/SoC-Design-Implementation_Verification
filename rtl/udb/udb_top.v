`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : udb_top
// Description : Top-Level Universal Digital Block Subsystem (UDB 2.0)
//               Integrates AXI4-Lite Slave, Morph Controller, Datapath, & PLD.
//////////////////////////////////////////////////////////////////////////////////

module udb_top
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave Interface
    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // REM Hardware Event Trigger (Patent 1)
    input  wire        rem_morph_trigger,
    input  wire [1:0]  rem_target_context,

    // I/O Matrix connections
    input  wire [7:0]  udb_io_in,
    output wire [7:0]  udb_io_out,
    output wire [1:0]  current_context
);

    wire [11:0] reg_addr;
    wire [31:0] reg_wdata;
    wire [3:0]  reg_wstrb;
    wire        reg_write_en;
    wire        reg_read_en;
    reg  [31:0] reg_rdata;

    axi4lite_slave #(.ADDR_WIDTH(12), .DATA_WIDTH(32)) u_axislave (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .reg_addr(reg_addr),
        .reg_wdata(reg_wdata),
        .reg_wstrb(reg_wstrb),
        .reg_write_en(reg_write_en),
        .reg_read_en(reg_read_en),
        .reg_rdata(reg_rdata),
        .reg_ack(1'b1)
    );

    wire [3:0]  alu_op;
    wire [1:0]  src_a_sel, src_b_sel;
    wire [7:0]  imm_val;
    wire        acc_load, shift_right;
    wire [23:0] pld_lut_config;
    wire [31:0] morph_cycles;
    wire [31:0] morph_reg_rdata;

    reg [7:0] sw_din;
    wire [7:0] datapath_dout;
    wire [7:0] accum_out;
    wire       flag_zero, flag_carry, flag_sign;

    udb_morph_controller u_morph (
        .clk(aclk),
        .rst_n(aresetn),
        .event_morph_trigger(rem_morph_trigger),
        .event_target_context(rem_target_context),
        .reg_we(reg_write_en && (reg_addr[11:8] == 4'h0)),
        .reg_addr(reg_addr[7:0]),
        .reg_wdata(reg_wdata),
        .reg_rdata(morph_reg_rdata),
        .active_alu_op(alu_op),
        .active_src_a_sel(src_a_sel),
        .active_src_b_sel(src_b_sel),
        .active_imm_val(imm_val),
        .active_acc_load(acc_load),
        .active_shift_right(shift_right),
        .active_pld_lut_config(pld_lut_config),
        .current_context_id(current_context),
        .morph_cycle_counter(morph_cycles)
    );

    wire [7:0] effective_din = (|udb_io_in) ? udb_io_in : sw_din;

    udb_datapath u_dp (
        .clk(aclk),
        .rst_n(aresetn),
        .alu_op(alu_op),
        .src_a_sel(src_a_sel),
        .src_b_sel(src_b_sel),
        .imm_val(imm_val),
        .acc_load(acc_load | (reg_write_en && reg_addr[7:0] == 8'h30)),
        .shift_right(shift_right),
        .din(effective_din),
        .dout(datapath_dout),
        .accum_out(accum_out),
        .flag_zero(flag_zero),
        .flag_carry(flag_carry),
        .flag_sign(flag_sign)
    );

    wire [11:0] pld_out;
    udb_macrocell u_pld (
        .clk(aclk),
        .rst_n(aresetn),
        .pld_inputs({4'b0, effective_din}),
        .pld_lut_config(pld_lut_config),
        .pld_outputs(pld_out)
    );

    assign udb_io_out = datapath_dout;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            sw_din <= 8'h00;
        end else if (reg_write_en && (reg_addr[7:0] == 8'h30)) begin
            sw_din <= reg_wdata[7:0];
        end
    end

    always @(*) begin
        case (reg_addr[7:0])
            8'h30: reg_rdata = {24'h0, sw_din};
            8'h34: reg_rdata = {24'h0, datapath_dout};
            8'h38: reg_rdata = {24'h0, accum_out};
            8'h3C: reg_rdata = {29'h0, flag_sign, flag_carry, flag_zero};
            default: reg_rdata = morph_reg_rdata;
        endcase
    end

endmodule
