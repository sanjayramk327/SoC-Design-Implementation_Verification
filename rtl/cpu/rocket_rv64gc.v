`timescale 1ns / 1ps

module rocket_rv64gc (
    input  wire        clk,
    input  wire        rst_n,
    
    // AXI4-Lite Master Interface (32-bit address, 32-bit data — for peripheral access)
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
    
    // 64-bit Local Memory Interface (for Rocket's own SRAM)
    output wire [63:0] lmem_addr,
    output wire        lmem_ren,
    output wire        lmem_wen,
    output wire [63:0] lmem_wdata,
    output wire [7:0]  lmem_wstrb,
    input  wire [63:0] lmem_rdata,
    
    // Interrupts
    input  wire        irq_external,
    input  wire        irq_timer,
    input  wire        irq_software,
    input  wire        irq_debug,
    
    // Status
    output wire        core_halted,
    output wire [63:0] debug_pc,
    output wire [1:0]  priv_mode  // 00=U, 01=S, 11=M
);

    // ==========================================
    // Internal Registers and State
    // ==========================================
    reg [63:0] pc;
    reg [1:0]  current_priv_mode; // 00=U, 01=S, 11=M
    
    assign debug_pc = pc;
    assign priv_mode = current_priv_mode;
    assign core_halted = 1'b0;

    // AXI Default assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axi_awaddr <= 32'd0;
            m_axi_awprot <= 3'd0;
            m_axi_awvalid <= 1'b0;
            m_axi_wdata <= 32'd0;
            m_axi_wstrb <= 4'd0;
            m_axi_wvalid <= 1'b0;
            m_axi_bready <= 1'b1;
            m_axi_araddr <= 32'd0;
            m_axi_arprot <= 3'd0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready <= 1'b1;
        end else begin
            // Simplified AXI logic mock
        end
    end

    // Local Memory default assignments
    assign lmem_addr = pc;
    assign lmem_ren = 1'b1; // Always fetching for simplicity in stub
    assign lmem_wen = 1'b0;
    assign lmem_wdata = 64'd0;
    assign lmem_wstrb = 8'd0;

    // ==========================================
    // Module Instantiations
    // ==========================================
    
    // MMU
    wire [55:0] mmu_paddr;
    wire mmu_req_ready;
    rocket_mmu mmu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .vaddr(pc),
        .access_type(2'b00),
        .priv_mode(current_priv_mode),
        .req_valid(1'b1),
        .req_ready(mmu_req_ready),
        .paddr(mmu_paddr),
        .tlb_hit(),
        .page_fault(),
        .done(),
        .satp(64'd0),
        .sum(1'b0),
        .mxr(1'b0),
        .sfence_vma(1'b0)
    );

    // I-Cache
    wire icache_req_ready;
    wire [31:0] inst_out;
    wire inst_valid;
    rocket_icache icache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(mmu_paddr),
        .req_valid(mmu_req_ready),
        .req_ready(icache_req_ready),
        .inst_out(inst_out),
        .inst_valid(inst_valid),
        .mem_addr(),
        .mem_req(),
        .mem_ready(1'b1),
        .mem_rdata(64'd0),
        .mem_rvalid(1'b0),
        .fence_i(1'b0)
    );

    // D-Cache
    wire dcache_req_ready;
    wire [63:0] dcache_rdata;
    wire dcache_rvalid;
    rocket_dcache dcache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .paddr(56'd0),
        .wdata(64'd0),
        .wstrb(8'd0),
        .ren(1'b0),
        .wen(1'b0),
        .amo_op(5'd0),
        .req_ready(dcache_req_ready),
        .rdata(dcache_rdata),
        .rvalid(dcache_rvalid),
        .mem_addr(),
        .mem_ren(),
        .mem_wen(),
        .mem_wdata(),
        .mem_ready(1'b1),
        .mem_rdata(64'd0),
        .mem_rvalid(1'b0)
    );

    // Branch Target Buffer
    wire btb_hit, btb_flush;
    wire [63:0] btb_target_pc;
    rocket_btb btb_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pc(pc),
        .hit(btb_hit),
        .target_pc(btb_target_pc),
        .is_jump(),
        .is_call(),
        .is_ret(),
        .update_valid(1'b0),
        .update_pc(64'd0),
        .update_target(64'd0),
        .update_taken(1'b0),
        .mispredicted(1'b0),
        .flush_pipeline(btb_flush)
    );

    // FPU
    wire [63:0] fpu_rd;
    wire fpu_ready, fpu_done;
    rocket_fpu fpu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_data(64'd0),
        .rs2_data(64'd0),
        .rs3_data(64'd0),
        .fpu_op(5'd0),
        .fpu_prec(2'd0),
        .rm(3'd0),
        .valid(1'b0),
        .rd_data(fpu_rd),
        .fflags(),
        .ready(fpu_ready),
        .done(fpu_done)
    );

    // MULDIV
    wire [63:0] md_rd;
    wire md_ready, md_done;
    rocket_muldiv muldiv_inst (
        .clk(clk),
        .rst_n(rst_n),
        .rs1(64'd0),
        .rs2(64'd0),
        .op(3'd0),
        .is_32(1'b0),
        .valid(1'b0),
        .rd(md_rd),
        .ready(md_ready),
        .done(md_done)
    );

    // ==========================================
    // Basic Pipeline Control (Mock)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'h80000000;
            current_priv_mode <= 2'b11; // Machine mode
        end else begin
            if (inst_valid) begin
                pc <= pc + 4;
                $display("[%0t] ROCKET: Fetched Instruction %h at PC %h", $time, inst_out, pc);
            end
            
            if (irq_external || irq_timer || irq_software) begin
                $display("[%0t] ROCKET: Interrupt received", $time);
            end
        end
    end

endmodule
