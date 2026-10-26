`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : analog_top
// Description : Top-Level Analog Subsystem integrating AMUXBUS, IDACs,
//               Comparators, and Neuromorphic Smart-Sense with AXI4-Lite Slave.
//////////////////////////////////////////////////////////////////////////////////

module analog_top
(
    input  wire         aclk,
    input  wire         aresetn,

    // AXI4-Lite Slave
    input  wire [11:0]  s_axi_awaddr,
    input  wire [2:0]   s_axi_awprot,
    input  wire         s_axi_awvalid,
    output wire         s_axi_awready,
    input  wire [31:0]  s_axi_wdata,
    input  wire [3:0]   s_axi_wstrb,
    input  wire         s_axi_wvalid,
    output wire         s_axi_wready,
    output wire [1:0]   s_axi_bresp,
    output wire         s_axi_bvalid,
    input  wire         s_axi_bready,

    input  wire [11:0]  s_axi_araddr,
    input  wire [2:0]   s_axi_arprot,
    input  wire         s_axi_arvalid,
    output wire         s_axi_arready,
    output wire [31:0]  s_axi_rdata,
    output wire [1:0]   s_axi_rresp,
    output wire         s_axi_rvalid,
    input  wire         s_axi_rready,

    // Pin Analog Emulated Inputs (16x 8-bit values flattened to 128 bits)
    input  wire [127:0] pin_analog_in,

    // Hardware Event Outputs to REM
    output wire         comp1_event,
    output wire         comp2_event,
    output wire         snn_touch_spike,
    output wire         snn_anomaly_flag
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

    reg [15:0] switch_a_reg;
    reg [15:0] switch_b_reg;
    reg [7:0]  idac1_reg;
    reg [6:0]  idac2_reg;
    reg [7:0]  idac_cfg;
    reg [7:0]  vref_reg;
    reg [3:0]  hyst_reg;
    reg [1:0]  comp_en_reg;

    wire [7:0] v_amux_a, v_amux_b;
    wire [7:0] idac1_out, idac2_out;
    wire [31:0] snn_reg_rdata;
    wire [3:0] snn_class;

    analog_mux_bus u_amux (
        .clk(aclk),
        .rst_n(aresetn),
        .switch_a_mask(switch_a_reg),
        .switch_b_mask(switch_b_reg),
        .pin_analog_in(pin_analog_in),
        .amuxbus_a_voltage(v_amux_a),
        .amuxbus_b_voltage(v_amux_b)
    );

    idac_controller u_idac (
        .clk(aclk),
        .rst_n(aresetn),
        .idac1_val(idac1_reg),
        .idac1_en(idac_cfg[0]),
        .idac1_range(idac_cfg[1]),
        .idac1_polarity(idac_cfg[2]),
        .idac2_val(idac2_reg),
        .idac2_en(idac_cfg[4]),
        .idac2_range(idac_cfg[5]),
        .idac2_polarity(idac_cfg[6]),
        .idac1_out_ma(idac1_out),
        .idac2_out_ma(idac2_out)
    );

    comparator_block u_comp (
        .clk(aclk),
        .rst_n(aresetn),
        .v_in1(v_amux_a),
        .v_in2(v_amux_b),
        .comp1_en(comp_en_reg[0]),
        .comp2_en(comp_en_reg[1]),
        .vref_dac(vref_reg),
        .hysteresis_val(hyst_reg),
        .comp1_out(comp1_event),
        .comp2_out(comp2_event)
    );

    neuromorphic_smartsense u_snn (
        .clk(aclk),
        .rst_n(aresetn),
        .amux_voltage(v_amux_a),
        .cfg_we(reg_write_en && (reg_addr[7:4] >= 4'h1)),
        .cfg_addr(reg_addr[7:0]),
        .cfg_wdata(reg_wdata),
        .cfg_rdata(snn_reg_rdata),
        .snn_touch_spike(snn_touch_spike),
        .snn_anomaly_flag(snn_anomaly_flag),
        .snn_gesture_class(snn_class)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            switch_a_reg <= 16'h0001;
            switch_b_reg <= 16'h0002;
            idac1_reg    <= 8'd100;
            idac2_reg    <= 7'd50;
            idac_cfg     <= 8'h11;
            vref_reg     <= 8'd93;
            hyst_reg     <= 4'd5;
            comp_en_reg  <= 2'b11;
        end else if (reg_write_en) begin
            case (reg_addr[7:0])
                8'h00: begin
                    switch_a_reg <= reg_wdata[15:0];
                    switch_b_reg <= reg_wdata[31:16];
                end
                8'h04: begin
                    idac1_reg <= reg_wdata[7:0];
                    idac2_reg <= reg_wdata[14:8];
                    idac_cfg  <= reg_wdata[23:16];
                end
                8'h08: begin
                    vref_reg    <= reg_wdata[7:0];
                    hyst_reg    <= reg_wdata[11:8];
                    comp_en_reg <= reg_wdata[13:12];
                end
                default: ;
            endcase
        end
    end

    always @(*) begin
        case (reg_addr[7:0])
            8'h00: reg_rdata = {switch_b_reg, switch_a_reg};
            8'h04: reg_rdata = {8'h0, idac_cfg, 1'b0, idac2_reg, idac1_reg};
            8'h08: reg_rdata = {18'h0, comp_en_reg, hyst_reg, vref_reg};
            8'h0C: reg_rdata = {30'h0, comp2_event, comp1_event};
            default: reg_rdata = snn_reg_rdata;
        endcase
    end

endmodule
