`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : tx_fifo
// Description : Robust UART Transmit FIFO
//
// Implemented Stages:
//
//   Stage 1 : FIFO Memory & Parameters
//   Stage 2 : Write Pointer & Write Logic
//   Stage 3 : Read Pointer & Read Logic
//   Stage 4 : FIFO Occupancy Counter
//   Stage 5 : Status Flags
//   Stage 6 : Overflow / Underflow Status
//   Stage 7 : Simultaneous Read / Write Handling
//   Stage 8 : Integration & Safety
//   Stage 9 : Verification Support
//
// Features:
//
//   - Parameterized data width
//   - Parameterized FIFO depth
//   - Synchronous write
//   - Synchronous registered read
//   - Full / Empty flags
//   - Almost Full / Almost Empty flags
//   - Overflow detection
//   - Underflow detection
//   - Simultaneous read/write support
//   - Full-rate read/write operation
//   - Pointer wrap-around
//   - Occupancy counter
//   - Safe reset behavior
//
// Target FPGA : Xilinx Artix-7
//////////////////////////////////////////////////////////////////////////////////

module tx_fifo
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,

    //--------------------------------------------------------------
    // Almost-full threshold
    //--------------------------------------------------------------
    parameter ALMOST_FULL_THRESHOLD =
                    (FIFO_DEPTH > 2) ? FIFO_DEPTH - 2 : FIFO_DEPTH,

    //--------------------------------------------------------------
    // Almost-empty threshold
    //--------------------------------------------------------------
    parameter ALMOST_EMPTY_THRESHOLD = 2,

    //--------------------------------------------------------------
    // Address width
    //--------------------------------------------------------------
    parameter ADDR_WIDTH =
                    (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH) : 1,

    //--------------------------------------------------------------
    // Counter width
    //--------------------------------------------------------------
    parameter COUNT_WIDTH =
                    (FIFO_DEPTH > 1) ? $clog2(FIFO_DEPTH + 1) : 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    ///////////////////////////////////////////////////////////////////////////
    // WRITE INTERFACE
    ///////////////////////////////////////////////////////////////////////////

    input  wire                     wr_en,
    input  wire [DATA_WIDTH-1:0]    wr_data,

    ///////////////////////////////////////////////////////////////////////////
    // READ INTERFACE
    ///////////////////////////////////////////////////////////////////////////

    input  wire                     rd_en,
    output reg  [DATA_WIDTH-1:0]    rd_data,

    ///////////////////////////////////////////////////////////////////////////
    // FIFO STATUS
    ///////////////////////////////////////////////////////////////////////////

    output wire                     full,
    output wire                     empty,

    output wire                     almost_full,
    output wire                     almost_empty,

    ///////////////////////////////////////////////////////////////////////////
    // ERROR STATUS
    ///////////////////////////////////////////////////////////////////////////

    output reg                      overflow,
    output reg                      underflow,

    ///////////////////////////////////////////////////////////////////////////
    // FIFO OCCUPANCY
    ///////////////////////////////////////////////////////////////////////////

    output reg [COUNT_WIDTH-1:0]    count

);


///////////////////////////////////////////////////////////////////////////////
// Stage 1 : FIFO MEMORY
///////////////////////////////////////////////////////////////////////////////

reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];


///////////////////////////////////////////////////////////////////////////////
// Stage 1 : FIFO POINTERS
///////////////////////////////////////////////////////////////////////////////

reg [ADDR_WIDTH-1:0] wr_ptr;
reg [ADDR_WIDTH-1:0] rd_ptr;


///////////////////////////////////////////////////////////////////////////////
// Stage 5 : FIFO STATUS FLAGS
///////////////////////////////////////////////////////////////////////////////

assign empty =
    (count == 0);

assign full =
    (count == FIFO_DEPTH);

assign almost_empty =
    (count <= ALMOST_EMPTY_THRESHOLD);

assign almost_full =
    (count >= ALMOST_FULL_THRESHOLD);


///////////////////////////////////////////////////////////////////////////////
// Stage 7 : ACCEPTED FIFO OPERATIONS
//
// Normal operation:
//
//     write_accept = wr_en && !full
//     read_accept  = rd_en && !empty
//
// However, when FIFO is FULL:
//
//     wr_en = 1
//     rd_en = 1
//
// the read frees one FIFO location during the same clock cycle.
// Therefore the write can also be accepted.
//
// This allows:
//
//     FULL + READ + WRITE
//
// without creating a throughput bubble.
///////////////////////////////////////////////////////////////////////////////

wire read_accept;
wire write_accept;

assign read_accept =
    rd_en && !empty;

assign write_accept =
    wr_en && (!full || read_accept);


///////////////////////////////////////////////////////////////////////////////
// Stage 2 + Stage 7 : WRITE LOGIC
//
// Handles:
//
//     1. Normal write
//     2. Pointer increment
//     3. Pointer wrap-around
//     4. Full + simultaneous read/write
//     5. Overflow detection
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin

        wr_ptr   <= {ADDR_WIDTH{1'b0}};
        overflow <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------------------
        // Default
        //
        // Overflow is an event pulse.
        //--------------------------------------------------------------

        overflow <= 1'b0;


        //--------------------------------------------------------------
        // Accepted write
        //--------------------------------------------------------------

        if (write_accept)
        begin

            //----------------------------------------------------------
            // Store data
            //----------------------------------------------------------

            fifo_mem[wr_ptr] <= wr_data;


            //----------------------------------------------------------
            // Increment / wrap write pointer
            //----------------------------------------------------------

            if (wr_ptr == FIFO_DEPTH-1)
            begin

                wr_ptr <= {ADDR_WIDTH{1'b0}};

            end
            else
            begin

                wr_ptr <= wr_ptr + 1'b1;

            end

        end


        //--------------------------------------------------------------
        // Write rejected
        //
        // A write is rejected only when:
        //
        //     wr_en = 1
        //     full  = 1
        //     read_accept = 0
        //
        //--------------------------------------------------------------

        else if (wr_en)
        begin

            overflow <= 1'b1;

        end

    end

end


///////////////////////////////////////////////////////////////////////////////
// Stage 3 + Stage 7 : READ LOGIC
//
// Handles:
//
//     1. Normal read
//     2. Registered output
//     3. Pointer increment
//     4. Pointer wrap-around
//     5. Underflow detection
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin

        rd_ptr    <= {ADDR_WIDTH{1'b0}};
        rd_data   <= {DATA_WIDTH{1'b0}};
        underflow <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------------------
        // Default
        //
        // Underflow is an event pulse.
        //--------------------------------------------------------------

        underflow <= 1'b0;


        //--------------------------------------------------------------
        // Accepted read
        //--------------------------------------------------------------

        if (read_accept)
        begin

            //----------------------------------------------------------
            // Read current FIFO entry
            //----------------------------------------------------------

            rd_data <= fifo_mem[rd_ptr];


            //----------------------------------------------------------
            // Increment / wrap read pointer
            //----------------------------------------------------------

            if (rd_ptr == FIFO_DEPTH-1)
            begin

                rd_ptr <= {ADDR_WIDTH{1'b0}};

            end
            else
            begin

                rd_ptr <= rd_ptr + 1'b1;

            end

        end


        //--------------------------------------------------------------
        // Read rejected because FIFO is empty
        //--------------------------------------------------------------

        else if (rd_en)
        begin

            underflow <= 1'b1;

        end

    end

end


///////////////////////////////////////////////////////////////////////////////
// Stage 4 + Stage 7 : FIFO OCCUPANCY COUNTER
//
// Operation:
//
//     Write only:
//
//         count = count + 1
//
//     Read only:
//
//         count = count - 1
//
//     Read + Write:
//
//         count = unchanged
//
//     No operation:
//
//         count = unchanged
//
// This remains correct even when the FIFO is FULL and both
// read and write occur simultaneously.
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin

        count <= {COUNT_WIDTH{1'b0}};

    end

    else
    begin

        case ({write_accept, read_accept})

            //----------------------------------------------------------
            // No operation
            //----------------------------------------------------------

            2'b00:
            begin

                count <= count;

            end


            //----------------------------------------------------------
            // Write only
            //----------------------------------------------------------

            2'b10:
            begin

                count <= count + 1'b1;

            end


            //----------------------------------------------------------
            // Read only
            //----------------------------------------------------------

            2'b01:
            begin

                count <= count - 1'b1;

            end


            //----------------------------------------------------------
            // Simultaneous read + write
            //----------------------------------------------------------

            2'b11:
            begin

                count <= count;

            end


            //----------------------------------------------------------
            // Safety case
            //----------------------------------------------------------

            default:
            begin

                count <= count;

            end

        endcase

    end

end


///////////////////////////////////////////////////////////////////////////////
// Stage 8 : INTEGRATION / SAFETY CHECKS
//
// The following synthesis-time checks help prevent accidental use of
// invalid FIFO parameters.
//
// These checks do not affect normal hardware operation.
///////////////////////////////////////////////////////////////////////////////

initial
begin

    if (FIFO_DEPTH < 2)
    begin

        $display("ERROR: FIFO_DEPTH must be >= 2");

    end


    if (DATA_WIDTH < 1)
    begin

        $display("ERROR: DATA_WIDTH must be >= 1");

    end


    if (ALMOST_EMPTY_THRESHOLD > FIFO_DEPTH)
    begin

        $display("ERROR: ALMOST_EMPTY_THRESHOLD exceeds FIFO_DEPTH");

    end


    if (ALMOST_FULL_THRESHOLD > FIFO_DEPTH)
    begin

        $display("ERROR: ALMOST_FULL_THRESHOLD exceeds FIFO_DEPTH");

    end

end


///////////////////////////////////////////////////////////////////////////////
// Stage 9 : VERIFICATION SUPPORT
//
// Simulation-time assertions.
//
// These checks help detect illegal FIFO states during simulation.
//
// They are not required for synthesis functionality.
///////////////////////////////////////////////////////////////////////////////

`ifndef SYNTHESIS

always @(posedge clk)
begin

    //--------------------------------------------------------------
    // FIFO count must never exceed FIFO depth
    //--------------------------------------------------------------

    if (count > FIFO_DEPTH)
    begin

        $display(
            "ERROR: FIFO count exceeded FIFO depth at time %0t",
            $time
        );

    end


    //--------------------------------------------------------------
    // FIFO count must never become negative.
    //
    // Since count is unsigned, an underflow would appear as a
    // very large value. The previous check catches this because
    // it would exceed FIFO_DEPTH.
    //--------------------------------------------------------------

    //--------------------------------------------------------------
    // Full and empty must never be simultaneously asserted.
    //--------------------------------------------------------------

    if (full && empty)
    begin

        $display(
            "ERROR: FIFO FULL and EMPTY asserted simultaneously at time %0t",
            $time
        );

    end

end

`endif


///////////////////////////////////////////////////////////////////////////////
// End of TX FIFO
///////////////////////////////////////////////////////////////////////////////

endmodule