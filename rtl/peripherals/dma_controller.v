`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : dma_controller
// Description : 4-Channel Autonomous Direct Memory Access (DMA) Engine
//               Master AXI4-Lite port for memory/peripheral data transfers
//////////////////////////////////////////////////////////////////////////////////

module dma_controller
(
    input  wire        aclk,
    input  wire        aresetn,

    // AXI4-Lite Slave (Control Registers)
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

    // AXI4-Lite Master (Data Transfer)
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

    // Hardware Event Triggers from REM
    input  wire [3:0]  rem_dma_trig,

    // Interrupt Outputs
    output reg  [3:0]  dma_done_irq
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

    // Channel Registers: 4 channels
    reg [31:0] src_addr [0:3];
    reg [31:0] dst_addr [0:3];
    reg [15:0] length   [0:3];
    reg [3:0]  ch_en;
    reg [3:0]  ch_busy;

    // Transfer State Machine
    localparam S_IDLE = 2'd0;
    localparam S_READ = 2'd1;
    localparam S_WRIT = 2'd2;

    reg [1:0]  state;
    reg [1:0]  active_ch;
    reg [31:0] temp_data;
    reg [15:0] transfer_count;

    integer c;
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            for (c = 0; c < 4; c = c + 1) begin
                src_addr[c] <= 32'h0;
                dst_addr[c] <= 32'h0;
                length[c]   <= 16'd0;
            end
            ch_en          <= 4'h0;
            ch_busy        <= 4'h0;
            dma_done_irq   <= 4'h0;
            state          <= S_IDLE;
            active_ch      <= 2'd0;
            transfer_count <= 16'd0;
            m_axi_arvalid  <= 1'b0;
            m_axi_awvalid  <= 1'b0;
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b0;
            m_axi_rready   <= 1'b0;
        end else begin
            dma_done_irq <= 4'h0;

            if (reg_write_en) begin
                case (reg_addr[7:4])
                    4'h0: ch_en <= reg_wdata[3:0];
                    4'h1: src_addr[reg_addr[3:2]] <= reg_wdata;
                    4'h2: dst_addr[reg_addr[3:2]] <= reg_wdata;
                    4'h3: length[reg_addr[3:2]]   <= reg_wdata[15:0];
                    default: ;
                endcase
            end

            // Hardware trigger check
            for (c = 0; c < 4; c = c + 1) begin
                if (rem_dma_trig[c]) ch_en[c] <= 1'b1;
            end

            case (state)
                S_IDLE: begin
                    if (ch_en[0]) begin active_ch <= 2'd0; state <= S_READ; ch_busy[0] <= 1'b1; transfer_count <= 0; end
                    else if (ch_en[1]) begin active_ch <= 2'd1; state <= S_READ; ch_busy[1] <= 1'b1; transfer_count <= 0; end
                    else if (ch_en[2]) begin active_ch <= 2'd2; state <= S_READ; ch_busy[2] <= 1'b1; transfer_count <= 0; end
                    else if (ch_en[3]) begin active_ch <= 2'd3; state <= S_READ; ch_busy[3] <= 1'b1; transfer_count <= 0; end
                end

                S_READ: begin
                    m_axi_araddr  <= src_addr[active_ch] + (transfer_count << 2);
                    m_axi_arvalid <= 1'b1;
                    m_axi_rready  <= 1'b1;
                    if (m_axi_arready) m_axi_arvalid <= 1'b0;
                    if (m_axi_rvalid && m_axi_rready) begin
                        m_axi_rready <= 1'b0;
                        temp_data    <= m_axi_rdata;
                        state        <= S_WRIT;
                    end
                end

                S_WRIT: begin
                    m_axi_awaddr  <= dst_addr[active_ch] + (transfer_count << 2);
                    m_axi_awvalid <= 1'b1;
                    m_axi_wdata   <= temp_data;
                    m_axi_wstrb   <= 4'b1111;
                    m_axi_wvalid  <= 1'b1;
                    m_axi_bready  <= 1'b1;
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready)  m_axi_wvalid  <= 1'b0;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready   <= 1'b0;
                        transfer_count <= transfer_count + 16'd1;
                        if (transfer_count + 1 >= length[active_ch]) begin
                            ch_en[active_ch]        <= 1'b0;
                            ch_busy[active_ch]      <= 1'b0;
                            dma_done_irq[active_ch] <= 1'b1;
                            state                   <= S_IDLE;
                        end else begin
                            state <= S_READ;
                        end
                    end
                end
            endcase
        end
    end

    always @(*) begin
        case (reg_addr[7:4])
            4'h0: reg_rdata = {24'h0, ch_busy, ch_en};
            4'h1: reg_rdata = src_addr[reg_addr[3:2]];
            4'h2: reg_rdata = dst_addr[reg_addr[3:2]];
            4'h3: reg_rdata = {16'h0, length[reg_addr[3:2]]};
            default: reg_rdata = 32'h0;
        endcase
    end

endmodule
