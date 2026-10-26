`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_top
// Description : Complete AXI4-Lite SCB UART Core integrating Baud Gen,
//               Tx/Rx FSMs, FIFOs, and AXI4-Lite Slave Adapter.
//////////////////////////////////////////////////////////////////////////////////

module uart_top
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave
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

    // Physical Serial Signals
    input  wire        uart_rx,
    output wire        uart_tx,

    // Interrupt / Event Output
    output wire        uart_irq,
    output wire        uart_tx_done,
    output wire        uart_rx_done
);

    wire [11:0] reg_addr;
    wire [31:0] reg_wdata;
    wire [3:0]  reg_wstrb;
    wire        reg_write_en;
    wire        reg_read_en;
    wire [31:0] reg_rdata;

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

    wire        tx_en, rx_en, parity_en, parity_type;
    wire [31:0] baud_div;
    wire        tx_wr_en, rx_rd_en;
    wire [7:0]  tx_wr_data, rx_rd_data;
    wire        tx_full, rx_empty;
    wire [4:0]  tx_occ, rx_occ;
    wire        tx_busy, tx_done, rx_done, parity_err, frame_err;

    assign uart_tx_done = tx_done;
    assign uart_rx_done = rx_done;

    uart_reg u_reg (
        .clk(aclk),
        .rst_n(aresetn),
        .reg_we(reg_write_en),
        .reg_addr(reg_addr[7:0]),
        .reg_wdata(reg_wdata),
        .reg_rdata(reg_rdata),
        .tx_en(tx_en),
        .rx_en(rx_en),
        .parity_en(parity_en),
        .parity_type(parity_type),
        .baud_div(baud_div),
        .tx_wr_en(tx_wr_en),
        .tx_wr_data(tx_wr_data),
        .tx_full(tx_full),
        .tx_occupancy(tx_occ),
        .rx_rd_en(rx_rd_en),
        .rx_rd_data(rx_rd_data),
        .rx_empty(rx_empty),
        .rx_occupancy(rx_occ),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx_done(rx_done),
        .parity_err(parity_err),
        .frame_err(frame_err),
        .uart_irq(uart_irq)
    );

    // Baud Tick Generator
    reg [31:0] baud_cnt;
    reg        baud_tick;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            baud_cnt  <= 0;
            baud_tick <= 0;
        end else if (baud_cnt >= baud_div) begin
            baud_cnt  <= 0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt  <= baud_cnt + 1'b1;
            baud_tick <= 1'b0;
        end
    end

    // TX FIFO
    wire [7:0] fifo_tx_data;
    wire       fifo_tx_empty;
    reg        tx_fsm_start;

    tx_fifo #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(16),
        .ADDR_WIDTH(4)
    ) u_tx_fifo (
        .clk(aclk),
        .rst(~aresetn),
        .wr_en(tx_wr_en),
        .wr_data(tx_wr_data),
        .full(tx_full),
        .almost_full(),
        .overflow(),
        .rd_en(tx_fsm_start),
        .rd_data(fifo_tx_data),
        .empty(fifo_tx_empty),
        .almost_empty(),
        .underflow(),
        .count(tx_occ)
    );

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn)
            tx_fsm_start <= 1'b0;
        else if (!fifo_tx_empty && !tx_busy && !tx_fsm_start)
            tx_fsm_start <= 1'b1;
        else
            tx_fsm_start <= 1'b0;
    end

    uart_tx u_tx (
        .clk(aclk),
        .rst(~aresetn),
        .baud_tick(baud_tick),
        .tx_start(tx_fsm_start),
        .tx_data(fifo_tx_data),
        .parity_enable(parity_en),
        .parity_type(parity_type),
        .tx(uart_tx),
        .busy(tx_busy),
        .done(tx_done)
    );

    // RX Path
    wire [7:0] raw_rx_data;
    wire       raw_rx_done;

    uart_rx u_rx (
        .clk(aclk),
        .rst(~aresetn),
        .baud_tick(baud_tick),
        .rx(uart_rx),
        .parity_enable(parity_en),
        .parity_type(parity_type),
        .rx_data(raw_rx_data),
        .rx_done(raw_rx_done),
        .parity_error(parity_err),
        .framing_error(frame_err)
    );

    rx_fifo #(
        .DATA_WIDTH(8),
        .FIFO_DEPTH(16),
        .ADDR_WIDTH(4)
    ) u_rx_fifo (
        .clk(aclk),
        .rst(~aresetn),
        .wr_en(raw_rx_done),
        .wr_data(raw_rx_data),
        .full(),
        .overflow(),
        .rd_en(rx_rd_en),
        .rd_data(rx_rd_data),
        .empty(rx_empty),
        .underflow(),
        .occupancy(rx_occ)
    );

    assign rx_done = raw_rx_done;

endmodule
