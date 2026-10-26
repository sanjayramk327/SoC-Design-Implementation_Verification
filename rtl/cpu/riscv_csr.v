`timescale 1ns / 1ps

module riscv_csr
(
    input  wire        clk,
    input  wire        rst_n,

    // CSR Read/Write
    input  wire [11:0] csr_addr,
    input  wire [31:0] csr_wdata,
    input  wire [1:0]  csr_op, // 0: None, 1: RW, 2: RS, 3: RC
    output reg  [31:0] csr_rdata,

    // Interrupt / Trap Inputs
    input  wire        irq_external,
    input  wire        irq_timer,
    input  wire        irq_software,
    input  wire [31:0] trap_pc,
    input  wire        trap_enter,
    input  wire        trap_return,
    output wire [31:0] trap_target_pc,
    output wire        interrupt_pending
);

    // Standard CSR Addresses
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MIE     = 12'h304;
    localparam CSR_MTVEC   = 12'h305;
    localparam CSR_MEPC    = 12'h341;
    localparam CSR_MCAUSE  = 12'h342;
    localparam CSR_MIP     = 12'h344;

    reg [31:0] mstatus;
    reg [31:0] mie;
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;

    wire [31:0] mip = {20'h0, irq_external, 3'h0, irq_timer, 3'h0, irq_software, 3'h0};

    // MIE (Machine Interrupt Enable) is mstatus[3]
    assign interrupt_pending = mstatus[3] & (| (mie & mip));
    assign trap_target_pc    = mtvec;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'h00000008; // MIE enabled by default
            mie     <= 32'h00000888; // External, timer, soft interrupts enabled
            mtvec   <= 32'h00000010; // Default trap vector
            mepc    <= 32'h0;
            mcause  <= 32'h0;
        end else begin
            if (trap_enter) begin
                mstatus[7] <= mstatus[3]; // MPIE = MIE
                mstatus[3] <= 1'b0;       // Disable MIE
                mepc       <= trap_pc;
                mcause     <= irq_external ? 32'h8000000B : (irq_timer ? 32'h80000007 : 32'h80000003);
            end else if (trap_return) begin
                mstatus[3] <= mstatus[7]; // MIE = MPIE
                mstatus[7] <= 1'b1;
            end else if (csr_op != 2'b00) begin
                case (csr_addr)
                    CSR_MSTATUS: mstatus <= (csr_op == 2'b01) ? csr_wdata : ((csr_op == 2'b10) ? (mstatus | csr_wdata) : (mstatus & ~csr_wdata));
                    CSR_MIE:     mie     <= (csr_op == 2'b01) ? csr_wdata : ((csr_op == 2'b10) ? (mie | csr_wdata) : (mie & ~csr_wdata));
                    CSR_MTVEC:   mtvec   <= (csr_op == 2'b01) ? csr_wdata : ((csr_op == 2'b10) ? (mtvec | csr_wdata) : (mtvec & ~csr_wdata));
                    CSR_MEPC:    mepc    <= (csr_op == 2'b01) ? csr_wdata : ((csr_op == 2'b10) ? (mepc | csr_wdata) : (mepc & ~csr_wdata));
                    CSR_MCAUSE:  mcause  <= (csr_op == 2'b01) ? csr_wdata : ((csr_op == 2'b10) ? (mcause | csr_wdata) : (mcause & ~csr_wdata));
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS: csr_rdata = mstatus;
            CSR_MIE:     csr_rdata = mie;
            CSR_MTVEC:   csr_rdata = mtvec;
            CSR_MEPC:    csr_rdata = mepc;
            CSR_MCAUSE:  csr_rdata = mcause;
            CSR_MIP:     csr_rdata = mip;
            default:     csr_rdata = 32'h0;
        endcase
    end

endmodule
