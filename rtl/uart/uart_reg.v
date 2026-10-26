`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_reg
// Description : Register file for SCB UART Subsystem
//////////////////////////////////////////////////////////////////////////////////

module uart_reg
(
    input  wire        clk,
    input  wire        rst_n,

    // Register interface from AXI slave
    input  wire        reg_we,
    input  wire [7:0]  reg_addr,
    input  wire [31:0] reg_wdata,
    output reg  [31:0] reg_rdata,

    // UART Control Signals
    output reg         tx_en,
    output reg         rx_en,
    output reg         parity_en,
    output reg         parity_type,
    output reg  [31:0] baud_div,

    // FIFO Interface
    output reg         tx_wr_en,
    output reg  [7:0]  tx_wr_data,
    input  wire        tx_full,
    input  wire [4:0]  tx_occupancy,

    output reg         rx_rd_en,
    input  wire [7:0]  rx_rd_data,
    input  wire        rx_empty,
    input  wire [4:0]  rx_occupancy,

    // Status inputs
    input  wire        tx_busy,
    input  wire        tx_done,
    input  wire        rx_done,
    input  wire        parity_err,
    input  wire        frame_err,

    // Interrupts
    output reg         uart_irq
);

    reg [31:0] ctrl_reg;
    reg [31:0] intr_en_reg;
    reg [31:0] intr_stat_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ctrl_reg      <= 32'h00000003; // TX & RX enabled
            baud_div      <= 32'd868;      // 100MHz / 115200 baud = ~868
            intr_en_reg   <= 32'h0;
            intr_stat_reg <= 32'h0;
            tx_wr_en      <= 1'b0;
            tx_wr_data    <= 8'h0;
            rx_rd_en      <= 1'b0;
            uart_irq      <= 1'b0;
        end else begin
            tx_wr_en <= 1'b0;
            rx_rd_en <= 1'b0;

            // Status latching
            if (tx_done)    intr_stat_reg[0] <= 1'b1;
            if (rx_done)    intr_stat_reg[1] <= 1'b1;
            if (parity_err) intr_stat_reg[2] <= 1'b1;
            if (frame_err)  intr_stat_reg[3] <= 1'b1;

            if (reg_we) begin
                case (reg_addr)
                    8'h00: ctrl_reg    <= reg_wdata;
                    8'h04: baud_div    <= reg_wdata;
                    8'h08: begin
                        tx_wr_data <= reg_wdata[7:0];
                        tx_wr_en   <= 1'b1;
                    end
                    8'h18: intr_en_reg <= reg_wdata;
                    8'h1C: intr_stat_reg <= intr_stat_reg & ~reg_wdata; // W1C
                    default: ;
                endcase
            end else if (reg_addr == 8'h0C) begin
                rx_rd_en <= 1'b1; // Read strobe from RX FIFO
            end

            uart_irq <= | (intr_en_reg & intr_stat_reg);
        end
    end

    always @(*) begin
        tx_en       = ctrl_reg[0];
        rx_en       = ctrl_reg[1];
        parity_en   = ctrl_reg[2];
        parity_type = ctrl_reg[3];

        case (reg_addr)
            8'h00: reg_rdata = ctrl_reg;
            8'h04: reg_rdata = baud_div;
            8'h08: reg_rdata = 32'h0;
            8'h0C: reg_rdata = {24'h0, rx_rd_data};
            8'h10: reg_rdata = {26'h0, frame_err, parity_err, rx_empty, tx_full, tx_done, tx_busy};
            8'h14: reg_rdata = {22'h0, rx_occupancy, 3'h0, tx_occupancy};
            8'h18: reg_rdata = intr_en_reg;
            8'h1C: reg_rdata = intr_stat_reg;
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
