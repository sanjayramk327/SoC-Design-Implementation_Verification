`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_interconnect
// Description : High-Performance AXI4-Lite Crossbar Interconnect for MorphoSoC
//               Connects 2 Masters (CPU, DMA) to 11 Peripherals/Memories
//////////////////////////////////////////////////////////////////////////////////

module axi_interconnect
#(
    parameter NUM_SLAVES = 11,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)
(
    input  wire                    aclk,
    input  wire                    aresetn,

    // Master 0 (CPU)
    input  wire [ADDR_WIDTH-1:0]   m0_axi_awaddr,
    input  wire [2:0]              m0_axi_awprot,
    input  wire                    m0_axi_awvalid,
    output wire                    m0_axi_awready,
    input  wire [DATA_WIDTH-1:0]   m0_axi_wdata,
    input  wire [3:0]              m0_axi_wstrb,
    input  wire                    m0_axi_wvalid,
    output wire                    m0_axi_wready,
    output wire [1:0]              m0_axi_bresp,
    output wire                    m0_axi_bvalid,
    input  wire                    m0_axi_bready,

    input  wire [ADDR_WIDTH-1:0]   m0_axi_araddr,
    input  wire [2:0]              m0_axi_arprot,
    input  wire                    m0_axi_arvalid,
    output wire                    m0_axi_arready,
    output wire [DATA_WIDTH-1:0]   m0_axi_rdata,
    output wire [1:0]              m0_axi_rresp,
    output wire                    m0_axi_rvalid,
    input  wire                    m0_axi_rready,

    // Master 1 (DMA)
    input  wire [ADDR_WIDTH-1:0]   m1_axi_awaddr,
    input  wire [2:0]              m1_axi_awprot,
    input  wire                    m1_axi_awvalid,
    output wire                    m1_axi_awready,
    input  wire [DATA_WIDTH-1:0]   m1_axi_wdata,
    input  wire [3:0]              m1_axi_wstrb,
    input  wire                    m1_axi_wvalid,
    output wire                    m1_axi_wready,
    output wire [1:0]              m1_axi_bresp,
    output wire                    m1_axi_bvalid,
    input  wire                    m1_axi_bready,

    input  wire [ADDR_WIDTH-1:0]   m1_axi_araddr,
    input  wire [2:0]              m1_axi_arprot,
    input  wire                    m1_axi_arvalid,
    output wire                    m1_axi_arready,
    output wire [DATA_WIDTH-1:0]   m1_axi_rdata,
    output wire [1:0]              m1_axi_rresp,
    output wire                    m1_axi_rvalid,
    input  wire                    m1_axi_rready,

    // Flattened Slave Interfaces [NUM_SLAVES*32 - 1 : 0]
    output wire [NUM_SLAVES*ADDR_WIDTH-1:0] s_axi_awaddr,
    output wire [NUM_SLAVES-1:0]            s_axi_awvalid,
    input  wire [NUM_SLAVES-1:0]            s_axi_awready,
    output wire [NUM_SLAVES*DATA_WIDTH-1:0] s_axi_wdata,
    output wire [NUM_SLAVES*4-1:0]          s_axi_wstrb,
    output wire [NUM_SLAVES-1:0]            s_axi_wvalid,
    input  wire [NUM_SLAVES-1:0]            s_axi_wready,
    input  wire [NUM_SLAVES*2-1:0]          s_axi_bresp,
    input  wire [NUM_SLAVES-1:0]            s_axi_bvalid,
    output wire [NUM_SLAVES-1:0]            s_axi_bready,

    output wire [NUM_SLAVES*ADDR_WIDTH-1:0] s_axi_araddr,
    output wire [NUM_SLAVES-1:0]            s_axi_arvalid,
    input  wire [NUM_SLAVES-1:0]            s_axi_arready,
    input  wire [NUM_SLAVES*DATA_WIDTH-1:0] s_axi_rdata,
    input  wire [NUM_SLAVES*2-1:0]          s_axi_rresp,
    input  wire [NUM_SLAVES-1:0]            s_axi_rvalid,
    output wire [NUM_SLAVES-1:0]            s_axi_rready
);

    reg write_grant; // 0 = M0, 1 = M1
    reg read_grant;  // 0 = M0, 1 = M1

    wire m0_write_req = m0_axi_awvalid && m0_axi_wvalid;
    wire m1_write_req = m1_axi_awvalid && m1_axi_wvalid;
    wire m0_read_req  = m0_axi_arvalid;
    wire m1_read_req  = m1_axi_arvalid;

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            write_grant <= 1'b0;
            read_grant  <= 1'b0;
        end else begin
            if (write_grant == 1'b0) begin
                if (!m0_write_req && m1_write_req)
                    write_grant <= 1'b1;
            end else begin
                if (!m1_write_req && m0_write_req)
                    write_grant <= 1'b0;
            end

            if (read_grant == 1'b0) begin
                if (!m0_read_req && m1_read_req)
                    read_grant <= 1'b1;
            end else begin
                if (!m1_read_req && m0_read_req)
                    read_grant <= 1'b0;
            end
        end
    end

    wire [ADDR_WIDTH-1:0] cur_awaddr  = (write_grant == 1'b0) ? m0_axi_awaddr : m1_axi_awaddr;
    wire                  cur_awvalid = (write_grant == 1'b0) ? m0_axi_awvalid : m1_axi_awvalid;
    wire [DATA_WIDTH-1:0] cur_wdata   = (write_grant == 1'b0) ? m0_axi_wdata  : m1_axi_wdata;
    wire [3:0]            cur_wstrb   = (write_grant == 1'b0) ? m0_axi_wstrb  : m1_axi_wstrb;
    wire                  cur_wvalid  = (write_grant == 1'b0) ? m0_axi_wvalid : m1_axi_wvalid;
    wire                  cur_bready  = (write_grant == 1'b0) ? m0_axi_bready : m1_axi_bready;

    wire [ADDR_WIDTH-1:0] cur_araddr  = (read_grant == 1'b0) ? m0_axi_araddr : m1_axi_araddr;
    wire                  cur_arvalid = (read_grant == 1'b0) ? m0_axi_arvalid : m1_axi_arvalid;
    wire                  cur_rready  = (read_grant == 1'b0) ? m0_axi_rready : m1_axi_rready;

    function [3:0] decode_slave;
        input [31:0] addr;
        begin
            if (addr[31:16] == 16'h0000)
                decode_slave = 4'd0;  // 0: ROM
            else if (addr[31:28] == 4'h2)
                decode_slave = 4'd1;  // 1: SRAM
            else if (addr[31:16] == 16'h4000) begin
                case (addr[15:12])
                    4'h0: decode_slave = 4'd2;  // 2: HSIOM
                    4'h1: decode_slave = 4'd3;  // 3: GPIO
                    4'h2: decode_slave = 4'd4;  // 4: UDB
                    4'h3: decode_slave = 4'd5;  // 5: Analog
                    4'h4: decode_slave = 4'd6;  // 6: UART
                    4'h5: decode_slave = 4'd7;  // 7: TCPWM
                    4'h6: decode_slave = 4'd8;  // 8: DMA
                    4'h7: decode_slave = 4'd9;  // 9: PMU
                    4'h8: decode_slave = 4'd10; // 10: REM
                    default: decode_slave = 4'd1;
                endcase
            end else begin
                decode_slave = 4'd1;
            end
        end
    endfunction

    wire [3:0] write_slave_sel = decode_slave(cur_awaddr);
    wire [3:0] read_slave_sel  = decode_slave(cur_araddr);

    genvar i;
    generate
        for (i = 0; i < NUM_SLAVES; i = i + 1) begin : SLAVE_ROUTING
            assign s_axi_awaddr[i*ADDR_WIDTH +: ADDR_WIDTH] = cur_awaddr;
            assign s_axi_wdata[i*DATA_WIDTH +: DATA_WIDTH]   = cur_wdata;
            assign s_axi_wstrb[i*4 +: 4]                     = cur_wstrb;
            assign s_axi_awvalid[i] = cur_awvalid && (write_slave_sel == i[3:0]);
            assign s_axi_wvalid[i]  = cur_wvalid && (write_slave_sel == i[3:0]);
            assign s_axi_bready[i]  = cur_bready && (write_slave_sel == i[3:0]);

            assign s_axi_araddr[i*ADDR_WIDTH +: ADDR_WIDTH] = cur_araddr;
            assign s_axi_arvalid[i] = cur_arvalid && (read_slave_sel == i[3:0]);
            assign s_axi_rready[i]  = cur_rready && (read_slave_sel == i[3:0]);
        end
    endgenerate

    wire cur_awready = s_axi_awready[write_slave_sel];
    wire cur_wready  = s_axi_wready[write_slave_sel];
    wire [1:0] cur_bresp = s_axi_bresp[write_slave_sel*2 +: 2];
    wire cur_bvalid  = s_axi_bvalid[write_slave_sel];

    wire cur_arready = s_axi_arready[read_slave_sel];
    wire [DATA_WIDTH-1:0] cur_rdata = s_axi_rdata[read_slave_sel*DATA_WIDTH +: DATA_WIDTH];
    wire [1:0] cur_rresp = s_axi_rresp[read_slave_sel*2 +: 2];
    wire cur_rvalid  = s_axi_rvalid[read_slave_sel];

    assign m0_axi_awready = (write_grant == 1'b0) ? cur_awready : 1'b0;
    assign m0_axi_wready  = (write_grant == 1'b0) ? cur_wready  : 1'b0;
    assign m0_axi_bresp   = cur_bresp;
    assign m0_axi_bvalid  = (write_grant == 1'b0) ? cur_bvalid  : 1'b0;

    assign m0_axi_arready = (read_grant == 1'b0) ? cur_arready  : 1'b0;
    assign m0_axi_rdata   = cur_rdata;
    assign m0_axi_rresp   = cur_rresp;
    assign m0_axi_rvalid  = (read_grant == 1'b0) ? cur_rvalid   : 1'b0;

    assign m1_axi_awready = (write_grant == 1'b1) ? cur_awready : 1'b0;
    assign m1_axi_wready  = (write_grant == 1'b1) ? cur_wready  : 1'b0;
    assign m1_axi_bresp   = cur_bresp;
    assign m1_axi_bvalid  = (write_grant == 1'b1) ? cur_bvalid  : 1'b0;

    assign m1_axi_arready = (read_grant == 1'b1) ? cur_arready  : 1'b0;
    assign m1_axi_rdata   = cur_rdata;
    assign m1_axi_rresp   = cur_rresp;
    assign m1_axi_rvalid  = (read_grant == 1'b1) ? cur_rvalid   : 1'b0;

endmodule
