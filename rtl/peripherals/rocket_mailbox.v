`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : rocket_mailbox
// Description : Inter-Core Mailbox for heterogeneous RV32I ↔ Rocket RV64GC
//               communication in MorphoSoC
//
// Features:
//   - 8 × 32-bit mailbox registers:
//       Slots 0-3: RV32I → Rocket direction (written by RV32I, read by Rocket)
//       Slots 4-7: Rocket → RV32I direction (written by Rocket, read by RV32I)
//   - Status register with per-slot new-message flags
//   - Interrupt output for each core on new message arrival
//   - AXI4-Lite slave interface
//
// Register Map (byte addresses):
//   0x00-0x0C : Mailbox slots 0-3 (RV32I → Rocket)
//   0x10-0x1C : Mailbox slots 4-7 (Rocket → RV32I)
//   0x20      : Status register [7:0] = new_msg flags per slot
//   0x24      : IRQ enable register [1:0] = {rocket_irq_en, rv32_irq_en}
//   0x28      : IRQ clear (write-1-to-clear any pending flag)
//////////////////////////////////////////////////////////////////////////////////

module rocket_mailbox
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave
    input  wire [11:0] s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready,
    output reg  [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [11:0] s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready,
    output reg  [31:0] s_axi_rdata,
    output reg  [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid,
    input  wire        s_axi_rready,

    // Interrupt outputs
    output wire        irq_to_rv32,     // Interrupt to RV32I core
    output wire        irq_to_rocket    // Interrupt to Rocket core
);

    // ===================================================================
    // Mailbox Storage
    // ===================================================================
    reg [31:0] mbox [0:7];       // 8 mailbox slots
    reg [7:0]  new_msg_flags;    // Per-slot new-message indicator
    reg [1:0]  irq_enable;       // [0]=rv32_irq_en, [1]=rocket_irq_en

    // Interrupt logic
    // RV32I gets interrupted when Rocket writes to slots 4-7
    // Rocket gets interrupted when RV32I writes to slots 0-3
    assign irq_to_rv32   = irq_enable[0] && (|new_msg_flags[7:4]);
    assign irq_to_rocket = irq_enable[1] && (|new_msg_flags[3:0]);

    // ===================================================================
    // AXI4-Lite Slave Logic
    // ===================================================================
    reg        aw_en;
    reg [11:0] awaddr_reg;

    integer k;
    initial begin
        for (k = 0; k < 8; k = k + 1)
            mbox[k] = 32'h0;
    end

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= 32'h0;
            aw_en         <= 1'b1;
            awaddr_reg    <= 12'h0;
            new_msg_flags <= 8'h0;
            irq_enable    <= 2'b00;
        end else begin
            // -------------------------------------------------------
            // Write Channel
            // -------------------------------------------------------
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                awaddr_reg    <= s_axi_awaddr;
                aw_en         <= 1'b0;

                case (s_axi_awaddr[7:0])
                    8'h00: begin mbox[0] <= s_axi_wdata; new_msg_flags[0] <= 1'b1; end
                    8'h04: begin mbox[1] <= s_axi_wdata; new_msg_flags[1] <= 1'b1; end
                    8'h08: begin mbox[2] <= s_axi_wdata; new_msg_flags[2] <= 1'b1; end
                    8'h0C: begin mbox[3] <= s_axi_wdata; new_msg_flags[3] <= 1'b1; end
                    8'h10: begin mbox[4] <= s_axi_wdata; new_msg_flags[4] <= 1'b1; end
                    8'h14: begin mbox[5] <= s_axi_wdata; new_msg_flags[5] <= 1'b1; end
                    8'h18: begin mbox[6] <= s_axi_wdata; new_msg_flags[6] <= 1'b1; end
                    8'h1C: begin mbox[7] <= s_axi_wdata; new_msg_flags[7] <= 1'b1; end
                    8'h24: irq_enable <= s_axi_wdata[1:0];
                    8'h28: new_msg_flags <= new_msg_flags & ~s_axi_wdata[7:0]; // W1C
                    default: ; // ignore
                endcase
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
                if (s_axi_bready && s_axi_bvalid)
                    aw_en <= 1'b1;
            end

            if (s_axi_awready && s_axi_wready && ~s_axi_bvalid) begin
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            // -------------------------------------------------------
            // Read Channel
            // -------------------------------------------------------
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00;
                case (s_axi_araddr[7:0])
                    8'h00: s_axi_rdata <= mbox[0];
                    8'h04: s_axi_rdata <= mbox[1];
                    8'h08: s_axi_rdata <= mbox[2];
                    8'h0C: s_axi_rdata <= mbox[3];
                    8'h10: s_axi_rdata <= mbox[4];
                    8'h14: s_axi_rdata <= mbox[5];
                    8'h18: s_axi_rdata <= mbox[6];
                    8'h1C: s_axi_rdata <= mbox[7];
                    8'h20: s_axi_rdata <= {24'h0, new_msg_flags};
                    8'h24: s_axi_rdata <= {30'h0, irq_enable};
                    default: s_axi_rdata <= 32'hDEAD_BEEF;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
