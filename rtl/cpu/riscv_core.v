`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : riscv_core
// Description : Complete RV32I RISC-V 32-bit Core with AXI4-Lite Master
//////////////////////////////////////////////////////////////////////////////////

module riscv_core
(
    input  wire        clk,
    input  wire        rst_n,

    // Dedicated Fast Instruction Fetch Interface (to SRAM Port A / Boot ROM)
    output wire [31:0] ifetch_addr,
    output wire        ifetch_en,
    input  wire [31:0] ifetch_rdata,

    // AXI4-Lite Master Data & Memory Bus
    output reg  [31:0] m_axi_awaddr,
    output reg  [2:0]  m_axi_awprot,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,

    output reg  [31:0] m_axi_araddr,
    output reg  [2:0]  m_axi_arprot,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready,

    // Interrupts & Sleep Control
    input  wire        irq_external,
    input  wire        irq_timer,
    input  wire        irq_software,
    output wire        cpu_sleep,
    output wire        cpu_deep_sleep
);

    // CPU Pipeline States
    localparam S_FETCH  = 3'd0;
    localparam S_DECODE = 3'd1;
    localparam S_EXEC   = 3'd2;
    localparam S_MEM_WR = 3'd3;
    localparam S_MEM_RD = 3'd4;
    localparam S_WB     = 3'd5;

    reg [2:0]  state;
    reg [31:0] pc;
    reg [31:0] instr;

    // Decoded fields
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediates
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'h0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Register File
    wire [31:0] rdata1, rdata2;
    reg         rf_we;
    reg  [4:0]  rf_waddr;
    reg  [31:0] rf_wdata;

    riscv_regfile u_rf (
        .clk(clk),
        .rst_n(rst_n),
        .raddr1(rs1),
        .rdata1(rdata1),
        .raddr2(rs2),
        .rdata2(rdata2),
        .we(rf_we),
        .waddr(rf_waddr),
        .wdata(rf_wdata)
    );

    // ALU
    reg  [31:0] alu_a, alu_b;
    reg  [3:0]  alu_op;
    wire [31:0] alu_result;
    wire        alu_zero;

    riscv_alu u_alu (
        .a(alu_a),
        .b(alu_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    // CSRs
    wire [31:0] csr_rdata;
    wire        intr_pending;
    wire [31:0] trap_target_pc;
    reg         trap_enter;
    reg         trap_return;
    reg  [1:0]  csr_op;

    riscv_csr u_csr (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr(instr[31:20]),
        .csr_wdata(rdata1),
        .csr_op(csr_op),
        .csr_rdata(csr_rdata),
        .irq_external(irq_external),
        .irq_timer(irq_timer),
        .irq_software(irq_software),
        .trap_pc(pc),
        .trap_enter(trap_enter),
        .trap_return(trap_return),
        .trap_target_pc(trap_target_pc),
        .interrupt_pending(intr_pending)
    );

    assign ifetch_addr = pc;
    assign ifetch_en   = (state == S_FETCH);

    reg is_wfi;
    assign cpu_sleep      = is_wfi;
    assign cpu_deep_sleep = is_wfi && ~irq_external;

    // Execution state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_FETCH;
            pc            <= 32'h00000000; // Boot ROM Base
            instr         <= 32'h00000013;
            rf_we         <= 1'b0;
            rf_waddr      <= 5'd0;
            rf_wdata      <= 32'h0;
            m_axi_awvalid <= 1'b0;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
            trap_enter    <= 1'b0;
            trap_return   <= 1'b0;
            csr_op        <= 2'b00;
            is_wfi        <= 1'b0;
        end else begin
            rf_we       <= 1'b0;
            trap_enter  <= 1'b0;
            trap_return <= 1'b0;
            csr_op      <= 2'b00;

            case (state)
                S_FETCH: begin
                    if (intr_pending && !is_wfi) begin
                        trap_enter <= 1'b1;
                        pc         <= trap_target_pc;
                        state      <= S_FETCH;
                    end else if (is_wfi) begin
                        if (irq_external || irq_timer || irq_software) begin
                            is_wfi <= 1'b0;
                            pc     <= pc + 4;
                            state  <= S_FETCH;
                        end
                    end else begin
                        instr <= ifetch_rdata;
                        state <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    state <= S_EXEC;
                end

                S_EXEC: begin
                    case (opcode)
                        7'h37: begin // LUI
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= imm_u;
                            pc       <= pc + 4;
                            state    <= S_FETCH;
                        end
                        7'h17: begin // AUIPC
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= pc + imm_u;
                            pc       <= pc + 4;
                            state    <= S_FETCH;
                        end
                        7'h6F: begin // JAL
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= pc + 4;
                            pc       <= pc + imm_j;
                            state    <= S_FETCH;
                        end
                        7'h67: begin // JALR
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            rf_wdata <= pc + 4;
                            pc       <= (rdata1 + imm_i) & ~32'd1;
                            state    <= S_FETCH;
                        end
                        7'h63: begin // Branch
                            case (funct3)
                                3'b000: if (rdata1 == rdata2) pc <= pc + imm_b; else pc <= pc + 4; // BEQ
                                3'b001: if (rdata1 != rdata2) pc <= pc + imm_b; else pc <= pc + 4; // BNE
                                3'b100: if ($signed(rdata1) < $signed(rdata2)) pc <= pc + imm_b; else pc <= pc + 4; // BLT
                                3'b101: if ($signed(rdata1) >= $signed(rdata2)) pc <= pc + imm_b; else pc <= pc + 4; // BGE
                                3'b110: if (rdata1 < rdata2) pc <= pc + imm_b; else pc <= pc + 4; // BLTU
                                3'b111: if (rdata1 >= rdata2) pc <= pc + imm_b; else pc <= pc + 4; // BGEU
                                default: pc <= pc + 4;
                            endcase
                            state <= S_FETCH;
                        end
                        7'h13: begin // OP-IMM
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            alu_a    <= rdata1;
                            alu_b    <= imm_i;
                            case (funct3)
                                3'b000: alu_op <= 4'd0; // ADDI
                                3'b010: alu_op <= 4'd3; // SLTI
                                3'b011: alu_op <= 4'd4; // SLTIU
                                3'b100: alu_op <= 4'd5; // XORI
                                3'b110: alu_op <= 4'd8; // ORI
                                3'b111: alu_op <= 4'd9; // ANDI
                                3'b001: alu_op <= 4'd2; // SLLI
                                3'b101: alu_op <= funct7[5] ? 4'd7 : 4'd6; // SRAI / SRLI
                                default: alu_op <= 4'd0;
                            endcase
                            state <= S_WB;
                        end
                        7'h33: begin // OP (Register-Register)
                            rf_we    <= 1'b1;
                            rf_waddr <= rd;
                            alu_a    <= rdata1;
                            alu_b    <= rdata2;
                            case (funct3)
                                3'b000: alu_op <= funct7[5] ? 4'd1 : 4'd0; // SUB / ADD
                                3'b001: alu_op <= 4'd2; // SLL
                                3'b010: alu_op <= 4'd3; // SLT
                                3'b011: alu_op <= 4'd4; // SLTU
                                3'b100: alu_op <= 4'd5; // XOR
                                3'b101: alu_op <= funct7[5] ? 4'd7 : 4'd6; // SRA / SRL
                                3'b110: alu_op <= 4'd8; // OR
                                3'b111: alu_op <= 4'd9; // AND
                                default: alu_op <= 4'd0;
                            endcase
                            state <= S_WB;
                        end
                        7'h03: begin // LOAD (AXI Read)
                            m_axi_araddr  <= rdata1 + imm_i;
                            m_axi_arprot  <= 3'b000;
                            m_axi_arvalid <= 1'b1;
                            m_axi_rready  <= 1'b1;
                            state         <= S_MEM_RD;
                        end
                        7'h23: begin // STORE (AXI Write)
                            m_axi_awaddr  <= rdata1 + imm_s;
                            m_axi_awprot  <= 3'b000;
                            m_axi_awvalid <= 1'b1;
                            m_axi_wdata   <= rdata2;
                            m_axi_wstrb   <= (funct3 == 3'b000) ? 4'b0001 : ((funct3 == 3'b001) ? 4'b0011 : 4'b1111);
                            m_axi_wvalid  <= 1'b1;
                            m_axi_bready  <= 1'b1;
                            state         <= S_MEM_WR;
                        end
                        7'h73: begin // SYSTEM (CSR / WFI / MRET)
                            if (funct3 == 3'b000) begin
                                if (instr[31:20] == 12'h302) begin // MRET
                                    trap_return <= 1'b1;
                                    pc          <= csr_rdata; // mepc
                                    state       <= S_FETCH;
                                end else if (instr[31:20] == 12'h105) begin // WFI
                                    is_wfi <= 1'b1;
                                    state  <= S_FETCH;
                                end else begin
                                    pc    <= pc + 4;
                                    state <= S_FETCH;
                                end
                            end else begin // CSR Read/Write
                                rf_we    <= 1'b1;
                                rf_waddr <= rd;
                                rf_wdata <= csr_rdata;
                                csr_op   <= funct3[1:0];
                                pc       <= pc + 4;
                                state    <= S_FETCH;
                            end
                        end
                        default: begin
                            pc    <= pc + 4;
                            state <= S_FETCH;
                        end
                    endcase
                end

                S_WB: begin
                    rf_wdata <= alu_result;
                    pc       <= pc + 4;
                    state    <= S_FETCH;
                end

                S_MEM_WR: begin
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready)  m_axi_wvalid  <= 1'b0;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        pc           <= pc + 4;
                        state        <= S_FETCH;
                    end
                end

                S_MEM_RD: begin
                    if (m_axi_arready) m_axi_arvalid <= 1'b0;
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        rf_we        <= 1'b1;
                        rf_waddr     <= rd;
                        rf_wdata     <= m_axi_rdata;
                        pc           <= pc + 4;
                        state        <= S_FETCH;
                    end
                end

                default: state <= S_FETCH;
            endcase
        end
    end

endmodule
