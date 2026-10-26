`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : psoc_top
// Description : Complete MorphoSoC Programmable System-on-Chip
//               Integrates:
//               - RV32I RISC-V 32-bit CPU
//               - AXI4-Lite Crossbar Interconnect & Reactive Event Matrix (REM)
//               - 8KB Boot ROM & 32KB Zero-Wait-State SRAM
//               - [PATENT 1] Polymorphic UDB 2.0 Array with Single-Cycle Morphing
//               - [PATENT 2] Mixed-Signal Neuromorphic Smart-Sense Engine & AMUX
//               - [PATENT 3] Self-Healing HSIOM with Dynamic Pin Failover
//               - Fixed Peripherals: SCB UART, TCPWM (Deadband & Kill), DMA, PMU/WDT
//               - 16 Package GPIO Pins (Ports 0 & 1)
//////////////////////////////////////////////////////////////////////////////////

module psoc_top
(
    input  wire        clk,
    input  wire        rst_n,

    // External Package I/O Pins (Ports 0 & 1 matching PSoC 4)
    inout  wire [15:0] gpio_pads,

    // Emulated Mixed-Signal Analog Inputs (16 pins x 8-bit analog scale)
    input  wire [127:0] pin_analog_in,

    // Debug / Telemetry Status Indicators
    output wire        telemetry_failover_active,
    output wire [1:0]  telemetry_udb_context,
    output wire        telemetry_snn_spike,
    output wire        telemetry_cpu_sleep
);

    // ==========================================================
    // Internal Bus & Clock Wires
    // ==========================================================
    wire cpu_clk;
    wire clk_gated;
    assign cpu_clk = clk_gated ? 1'b0 : clk;

    // AXI Crossbar Slaves (11 Slaves)
    localparam NUM_SLAVES = 11;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    wire [NUM_SLAVES*ADDR_WIDTH-1:0] s_axi_awaddr;
    wire [NUM_SLAVES-1:0]            s_axi_awvalid;
    wire [NUM_SLAVES-1:0]            s_axi_awready;
    wire [NUM_SLAVES*DATA_WIDTH-1:0] s_axi_wdata;
    wire [NUM_SLAVES*4-1:0]          s_axi_wstrb;
    wire [NUM_SLAVES-1:0]            s_axi_wvalid;
    wire [NUM_SLAVES-1:0]            s_axi_wready;
    wire [NUM_SLAVES*2-1:0]          s_axi_bresp;
    wire [NUM_SLAVES-1:0]            s_axi_bvalid;
    wire [NUM_SLAVES-1:0]            s_axi_bready;

    wire [NUM_SLAVES*ADDR_WIDTH-1:0] s_axi_araddr;
    wire [NUM_SLAVES-1:0]            s_axi_arvalid;
    wire [NUM_SLAVES-1:0]            s_axi_arready;
    wire [NUM_SLAVES*DATA_WIDTH-1:0] s_axi_rdata;
    wire [NUM_SLAVES*2-1:0]          s_axi_rresp;
    wire [NUM_SLAVES-1:0]            s_axi_rvalid;
    wire [NUM_SLAVES-1:0]            s_axi_rready;

    // CPU Master 0
    wire [31:0] m0_awaddr, m0_wdata, m0_araddr, m0_rdata;
    wire [3:0]  m0_wstrb;
    wire [2:0]  m0_awprot, m0_arprot;
    wire [1:0]  m0_bresp, m0_rresp;
    wire        m0_awvalid, m0_awready, m0_wvalid, m0_wready, m0_bvalid, m0_bready;
    wire        m0_arvalid, m0_arready, m0_rvalid, m0_rready;

    // DMA Master 1
    wire [31:0] m1_awaddr, m1_wdata, m1_araddr, m1_rdata;
    wire [3:0]  m1_wstrb;
    wire [2:0]  m1_awprot, m1_arprot;
    wire [1:0]  m1_bresp, m1_rresp;
    wire        m1_awvalid, m1_awready, m1_wvalid, m1_wready, m1_bvalid, m1_bready;
    wire        m1_arvalid, m1_arready, m1_rvalid, m1_rready;

    // ==========================================================
    // Reactive Event Matrix (REM) - 16 Events to 8 Actions
    // ==========================================================
    wire [15:0] rem_events;
    wire [7:0]  rem_actions;

    reactive_event_matrix u_rem (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_we(s_axi_wvalid[10] && s_axi_wready[10]),
        .cfg_addr(s_axi_awaddr[10*32 +: 8]),
        .cfg_wdata(s_axi_wdata[10*32 +: 32]),
        .cfg_rdata(s_axi_rdata[10*32 +: 32]),
        .event_sources(rem_events),
        .action_triggers(rem_actions)
    );

    // REM Slave Handshakes
    assign s_axi_awready[10] = 1'b1;
    assign s_axi_wready[10]  = 1'b1;
    assign s_axi_bvalid[10]  = 1'b1;
    assign s_axi_bresp[10*2 +: 2] = 2'b00;
    assign s_axi_arready[10] = 1'b1;
    assign s_axi_rvalid[10]  = 1'b1;
    assign s_axi_rresp[10*2 +: 2] = 2'b00;

    // ==========================================================
    // CPU Core & PMU
    // ==========================================================
    wire [31:0] ifetch_addr, ifetch_rdata;
    wire        ifetch_en;
    wire        cpu_sleep, cpu_deepsleep;

    assign telemetry_cpu_sleep = cpu_sleep;

    riscv_core u_cpu (
        .clk(cpu_clk),
        .rst_n(rst_n),
        .ifetch_addr(ifetch_addr),
        .ifetch_en(ifetch_en),
        .ifetch_rdata(ifetch_rdata),
        .m_axi_awaddr(m0_awaddr),
        .m_axi_awprot(m0_awprot),
        .m_axi_awvalid(m0_awvalid),
        .m_axi_awready(m0_awready),
        .m_axi_wdata(m0_wdata),
        .m_axi_wstrb(m0_wstrb),
        .m_axi_wvalid(m0_wvalid),
        .m_axi_wready(m0_wready),
        .m_axi_bresp(m0_bresp),
        .m_axi_bvalid(m0_bvalid),
        .m_axi_bready(m0_bready),
        .m_axi_araddr(m0_araddr),
        .m_axi_arprot(m0_arprot),
        .m_axi_arvalid(m0_arvalid),
        .m_axi_arready(m0_arready),
        .m_axi_rdata(m0_rdata),
        .m_axi_rresp(m0_rresp),
        .m_axi_rvalid(m0_rvalid),
        .m_axi_rready(m0_rready),
        .irq_external(rem_actions[6]),
        .irq_timer(rem_actions[7]),
        .irq_software(1'b0),
        .cpu_sleep(cpu_sleep),
        .cpu_deep_sleep(cpu_deepsleep)
    );

    // ==========================================================
    // AXI Crossbar
    // ==========================================================
    axi_interconnect #(
        .NUM_SLAVES(NUM_SLAVES),
        .ADDR_WIDTH(32),
        .DATA_WIDTH(32)
    ) u_interconnect (
        .aclk(clk),
        .aresetn(rst_n),
        .m0_axi_awaddr(m0_awaddr),
        .m0_axi_awprot(m0_awprot),
        .m0_axi_awvalid(m0_awvalid),
        .m0_axi_awready(m0_awready),
        .m0_axi_wdata(m0_wdata),
        .m0_axi_wstrb(m0_wstrb),
        .m0_axi_wvalid(m0_wvalid),
        .m0_axi_wready(m0_wready),
        .m0_axi_bresp(m0_bresp),
        .m0_axi_bvalid(m0_bvalid),
        .m0_axi_bready(m0_bready),
        .m0_axi_araddr(m0_araddr),
        .m0_axi_arprot(m0_arprot),
        .m0_axi_arvalid(m0_arvalid),
        .m0_axi_arready(m0_arready),
        .m0_axi_rdata(m0_rdata),
        .m0_axi_rresp(m0_rresp),
        .m0_axi_rvalid(m0_rvalid),
        .m0_axi_rready(m0_rready),
        .m1_axi_awaddr(m1_awaddr),
        .m1_axi_awprot(m1_awprot),
        .m1_axi_awvalid(m1_awvalid),
        .m1_axi_awready(m1_awready),
        .m1_axi_wdata(m1_wdata),
        .m1_axi_wstrb(m1_wstrb),
        .m1_axi_wvalid(m1_wvalid),
        .m1_axi_wready(m1_wready),
        .m1_axi_bresp(m1_bresp),
        .m1_axi_bvalid(m1_bvalid),
        .m1_axi_bready(m1_bready),
        .m1_axi_araddr(m1_araddr),
        .m1_axi_arprot(m1_arprot),
        .m1_axi_arvalid(m1_arvalid),
        .m1_axi_arready(m1_arready),
        .m1_axi_rdata(m1_rdata),
        .m1_axi_rresp(m1_rresp),
        .m1_axi_rvalid(m1_rvalid),
        .m1_axi_rready(m1_rready),
        .s_axi_awaddr(s_axi_awaddr),
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
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // ==========================================================
    // Slave 0: Boot ROM (0x0000_0000)
    // ==========================================================
    boot_rom u_rom (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_araddr(s_axi_araddr[0*32 +: 13]),
        .s_axi_arvalid(s_axi_arvalid[0]),
        .s_axi_arready(s_axi_arready[0]),
        .s_axi_rdata(s_axi_rdata[0*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[0*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[0]),
        .s_axi_rready(s_axi_rready[0])
    );
    assign s_axi_awready[0] = 1'b1;
    assign s_axi_wready[0]  = 1'b1;
    assign s_axi_bresp[0*2 +: 2] = 2'b10; // Read-only SLVERR
    assign s_axi_bvalid[0]  = 1'b1;

    // ==========================================================
    // Slave 1: Instruction & Data SRAM (0x2000_0000)
    // ==========================================================
    instruction_bram u_sram (
        .clk(clk),
        .rst_n(rst_n),
        .ifetch_addr(ifetch_addr[14:0]),
        .ifetch_en(ifetch_en),
        .ifetch_rdata(ifetch_rdata),
        .s_axi_awaddr(s_axi_awaddr[1*32 +: 15]),
        .s_axi_awvalid(s_axi_awvalid[1]),
        .s_axi_awready(s_axi_awready[1]),
        .s_axi_wdata(s_axi_wdata[1*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[1*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[1]),
        .s_axi_wready(s_axi_wready[1]),
        .s_axi_bresp(s_axi_bresp[1*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[1]),
        .s_axi_bready(s_axi_bready[1]),
        .s_axi_araddr(s_axi_araddr[1*32 +: 15]),
        .s_axi_arvalid(s_axi_arvalid[1]),
        .s_axi_arready(s_axi_arready[1]),
        .s_axi_rdata(s_axi_rdata[1*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[1*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[1]),
        .s_axi_rready(s_axi_rready[1])
    );

    // ==========================================================
    // Slave 2: HSIOM (0x4000_0000)
    // ==========================================================
    wire [15:0] port_dr_bus;
    wire        uart_tx_sig, uart_rx_sig;
    wire        tcpwm_out0_sig, tcpwm_nout0_sig;
    wire [7:0]  udb_out_bus;
    wire        snn_spike_sig;
    wire [15:0] pad_out_bus, pad_oe_bus, pad_in_bus;
    wire        hsiom_fault_sig;

    hsiom_top u_hsiom (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[2*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[2]),
        .s_axi_awready(s_axi_awready[2]),
        .s_axi_wdata(s_axi_wdata[2*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[2*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[2]),
        .s_axi_wready(s_axi_wready[2]),
        .s_axi_bresp(s_axi_bresp[2*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[2]),
        .s_axi_bready(s_axi_bready[2]),
        .s_axi_araddr(s_axi_araddr[2*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[2]),
        .s_axi_arready(s_axi_arready[2]),
        .s_axi_rdata(s_axi_rdata[2*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[2*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[2]),
        .s_axi_rready(s_axi_rready[2]),
        .gpio_dr(port_dr_bus),
        .uart_tx(uart_tx_sig),
        .uart_rx(uart_rx_sig),
        .tcpwm_out0(tcpwm_out0_sig),
        .tcpwm_nout0(tcpwm_nout0_sig),
        .udb_out(udb_out_bus),
        .snn_spike(snn_spike_sig),
        .pad_out(pad_out_bus),
        .pad_oe(pad_oe_bus),
        .pad_in(pad_in_bus),
        .hsiom_fault_event(hsiom_fault_sig)
    );

    // Bidirectional GPIO Pads
    genvar b;
    generate
        for (b = 0; b < 16; b = b + 1) begin : PADS_GEN
            assign gpio_pads[b]  = pad_oe_bus[b] ? pad_out_bus[b] : 1'bz;
            assign pad_in_bus[b] = gpio_pads[b];
        end
    endgenerate

    assign telemetry_failover_active = hsiom_fault_sig;

    // ==========================================================
    // Slave 3: GPIO Ports (0x4000_1000)
    // ==========================================================
    wire gpio_irq_p0;
    gpio_port u_gpio (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[3*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[3]),
        .s_axi_awready(s_axi_awready[3]),
        .s_axi_wdata(s_axi_wdata[3*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[3*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[3]),
        .s_axi_wready(s_axi_wready[3]),
        .s_axi_bresp(s_axi_bresp[3*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[3]),
        .s_axi_bready(s_axi_bready[3]),
        .s_axi_araddr(s_axi_araddr[3*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[3]),
        .s_axi_arready(s_axi_arready[3]),
        .s_axi_rdata(s_axi_rdata[3*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[3*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[3]),
        .s_axi_rready(s_axi_rready[3]),
        .port_dr(port_dr_bus[7:0]),
        .port_ps(pad_in_bus[7:0]),
        .port_irq(gpio_irq_p0)
    );
    assign port_dr_bus[15:8] = 8'h00;

    // ==========================================================
    // Slave 4: UDB 2.0 Polymorphic Datapath Array (0x4000_2000)
    // ==========================================================
    wire [1:0] udb_context_id;
    assign telemetry_udb_context = udb_context_id;

    udb_top u_udb (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[4*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[4]),
        .s_axi_awready(s_axi_awready[4]),
        .s_axi_wdata(s_axi_wdata[4*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[4*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[4]),
        .s_axi_wready(s_axi_wready[4]),
        .s_axi_bresp(s_axi_bresp[4*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[4]),
        .s_axi_bready(s_axi_bready[4]),
        .s_axi_araddr(s_axi_araddr[4*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[4]),
        .s_axi_arready(s_axi_arready[4]),
        .s_axi_rdata(s_axi_rdata[4*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[4*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[4]),
        .s_axi_rready(s_axi_rready[4]),
        .rem_morph_trigger(rem_actions[0]), // PATENT 1 Trigger
        .rem_target_context(2'b01),         // Morph to Context 1 (e.g. Decryptor)
        .udb_io_in(pad_in_bus[7:0]),
        .udb_io_out(udb_out_bus),
        .current_context(udb_context_id)
    );

    // ==========================================================
    // Slave 5: Analog & Neuromorphic Smart-Sense (0x4000_3000)
    // ==========================================================
    wire comp1_evt, comp2_evt, snn_spike_evt, snn_anom_evt;
    assign telemetry_snn_spike = snn_spike_evt;
    assign snn_spike_sig       = snn_spike_evt;

    analog_top u_analog (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[5*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[5]),
        .s_axi_awready(s_axi_awready[5]),
        .s_axi_wdata(s_axi_wdata[5*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[5*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[5]),
        .s_axi_wready(s_axi_wready[5]),
        .s_axi_bresp(s_axi_bresp[5*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[5]),
        .s_axi_bready(s_axi_bready[5]),
        .s_axi_araddr(s_axi_araddr[5*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[5]),
        .s_axi_arready(s_axi_arready[5]),
        .s_axi_rdata(s_axi_rdata[5*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[5*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[5]),
        .s_axi_rready(s_axi_rready[5]),
        .pin_analog_in(pin_analog_in),
        .comp1_event(comp1_evt),
        .comp2_event(comp2_evt),
        .snn_touch_spike(snn_spike_evt),
        .snn_anomaly_flag(snn_anom_evt)
    );

    // ==========================================================
    // Slave 6: SCB UART (0x4000_4000)
    // ==========================================================
    wire uart_irq, uart_txdone_evt, uart_rxdone_evt;

    uart_top u_uart (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[6*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[6]),
        .s_axi_awready(s_axi_awready[6]),
        .s_axi_wdata(s_axi_wdata[6*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[6*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[6]),
        .s_axi_wready(s_axi_wready[6]),
        .s_axi_bresp(s_axi_bresp[6*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[6]),
        .s_axi_bready(s_axi_bready[6]),
        .s_axi_araddr(s_axi_araddr[6*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[6]),
        .s_axi_arready(s_axi_arready[6]),
        .s_axi_rdata(s_axi_rdata[6*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[6*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[6]),
        .s_axi_rready(s_axi_rready[6]),
        .uart_rx(uart_rx_sig),
        .uart_tx(uart_tx_sig),
        .uart_irq(uart_irq),
        .uart_tx_done(uart_txdone_evt),
        .uart_rx_done(uart_rxdone_evt)
    );

    // ==========================================================
    // Slave 7: TCPWM (0x4000_5000)
    // ==========================================================
    wire tcpwm_ovf_evt, tcpwm_unf_evt, tcpwm_cmp_evt;

    tcpwm u_tcpwm (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[7*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[7]),
        .s_axi_awready(s_axi_awready[7]),
        .s_axi_wdata(s_axi_wdata[7*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[7*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[7]),
        .s_axi_wready(s_axi_wready[7]),
        .s_axi_bresp(s_axi_bresp[7*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[7]),
        .s_axi_bready(s_axi_bready[7]),
        .s_axi_araddr(s_axi_araddr[7*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[7]),
        .s_axi_arready(s_axi_arready[7]),
        .s_axi_rdata(s_axi_rdata[7*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[7*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[7]),
        .s_axi_rready(s_axi_rready[7]),
        .hw_kill_trig(rem_actions[1]),
        .hw_reload_trig(1'b0),
        .pwm_out0(tcpwm_out0_sig),
        .pwm_nout0(tcpwm_nout0_sig),
        .event_overflow(tcpwm_ovf_evt),
        .event_underflow(tcpwm_unf_evt),
        .event_compare_match(tcpwm_cmp_evt)
    );

    // ==========================================================
    // Slave 8: DMA Controller (0x4000_6000)
    // ==========================================================
    wire [3:0] dma_done_irq;

    dma_controller u_dma (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[8*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[8]),
        .s_axi_awready(s_axi_awready[8]),
        .s_axi_wdata(s_axi_wdata[8*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[8*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[8]),
        .s_axi_wready(s_axi_wready[8]),
        .s_axi_bresp(s_axi_bresp[8*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[8]),
        .s_axi_bready(s_axi_bready[8]),
        .s_axi_araddr(s_axi_araddr[8*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[8]),
        .s_axi_arready(s_axi_arready[8]),
        .s_axi_rdata(s_axi_rdata[8*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[8*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[8]),
        .s_axi_rready(s_axi_rready[8]),
        .m_axi_awaddr(m1_awaddr),
        .m_axi_awprot(m1_awprot),
        .m_axi_awvalid(m1_awvalid),
        .m_axi_awready(m1_awready),
        .m_axi_wdata(m1_wdata),
        .m_axi_wstrb(m1_wstrb),
        .m_axi_wvalid(m1_wvalid),
        .m_axi_wready(m1_wready),
        .m_axi_bresp(m1_bresp),
        .m_axi_bvalid(m1_bvalid),
        .m_axi_bready(m1_bready),
        .m_axi_araddr(m1_araddr),
        .m_axi_arprot(m1_arprot),
        .m_axi_arvalid(m1_arvalid),
        .m_axi_arready(m1_arready),
        .m_axi_rdata(m1_rdata),
        .m_axi_rresp(m1_rresp),
        .m_axi_rvalid(m1_rvalid),
        .m_axi_rready(m1_rready),
        .rem_dma_trig({2'b0, rem_actions[3], rem_actions[2]}),
        .dma_done_irq(dma_done_irq)
    );

    // ==========================================================
    // Slave 9: PMU & Watchdog (0x4000_7000)
    // ==========================================================
    wire wdt_rst_sig, wdt_prewarn_evt;

    wdt_pmu u_pmu (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr[9*32 +: 12]),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid[9]),
        .s_axi_awready(s_axi_awready[9]),
        .s_axi_wdata(s_axi_wdata[9*32 +: 32]),
        .s_axi_wstrb(s_axi_wstrb[9*4 +: 4]),
        .s_axi_wvalid(s_axi_wvalid[9]),
        .s_axi_wready(s_axi_wready[9]),
        .s_axi_bresp(s_axi_bresp[9*2 +: 2]),
        .s_axi_bvalid(s_axi_bvalid[9]),
        .s_axi_bready(s_axi_bready[9]),
        .s_axi_araddr(s_axi_araddr[9*32 +: 12]),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid[9]),
        .s_axi_arready(s_axi_arready[9]),
        .s_axi_rdata(s_axi_rdata[9*32 +: 32]),
        .s_axi_rresp(s_axi_rresp[9*2 +: 2]),
        .s_axi_rvalid(s_axi_rvalid[9]),
        .s_axi_rready(s_axi_rready[9]),
        .rem_wakeup_event(rem_actions[4]),
        .cpu_sleep_req(cpu_sleep),
        .cpu_deepsleep_req(cpu_deepsleep),
        .clock_gate_cpu(clk_gated),
        .wdt_reset_out(wdt_rst_sig),
        .wdt_prewarn_event(wdt_prewarn_evt)
    );

    // ==========================================================
    // Reactive Event Matrix (REM) Inputs Connection
    // ==========================================================
    assign rem_events[0]  = comp1_evt;
    assign rem_events[1]  = comp2_evt;
    assign rem_events[2]  = snn_spike_evt;
    assign rem_events[3]  = snn_anom_evt;
    assign rem_events[4]  = tcpwm_ovf_evt;
    assign rem_events[5]  = tcpwm_cmp_evt;
    assign rem_events[6]  = tcpwm_unf_evt;
    assign rem_events[7]  = uart_rxdone_evt;
    assign rem_events[8]  = uart_txdone_evt;
    assign rem_events[9]  = dma_done_irq[0];
    assign rem_events[10] = dma_done_irq[1];
    assign rem_events[11] = gpio_irq_p0;
    assign rem_events[12] = 1'b0;
    assign rem_events[13] = wdt_prewarn_evt;
    assign rem_events[14] = hsiom_fault_sig;
    assign rem_events[15] = 1'b0;

endmodule
