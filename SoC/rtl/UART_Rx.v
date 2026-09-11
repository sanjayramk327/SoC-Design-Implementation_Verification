`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_rx
// Description : UART Receiver (Stage 1)
//               - RX Input Synchronizer
//               - Falling Edge Detector
//
// Author      :
// Target FPGA : Xilinx Artix-7
//////////////////////////////////////////////////////////////////////////////////

module uart_rx
(
    input  wire       clk,
    input  wire       rst,

    // Baud Tick Generator
    input  wire       baud_tick,

    // UART RX Input
    input  wire       rx,

    // UART Configuration
    input  wire       parity_enable,
    input  wire       parity_type,      // 0 = Even, 1 = Odd

    // UART Outputs
    output reg [7:0]  rx_data,
    output reg        rx_done,
    output reg        parity_error,
    output reg        framing_error
);

///////////////////////////////////////////////////////////////////////////////
// Synchronizer Registers
///////////////////////////////////////////////////////////////////////////////

reg rx_sync1;
reg rx_sync2;

///////////////////////////////////////////////////////////////////////////////
// Edge Detection
///////////////////////////////////////////////////////////////////////////////

reg  rx_prev;
wire start_edge;

assign start_edge = (rx_prev == 1'b1) &&
                    (rx_sync2 == 1'b0);

///////////////////////////////////////////////////////////////////////////////
// RX Input Synchronizer
//
// Purpose:
// Synchronizes asynchronous UART RX input to FPGA clock domain.
// Prevents metastability.
//
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin
        rx_sync1 <= 1'b1;
        rx_sync2 <= 1'b1;
    end
    else
    begin
        rx_sync1 <= rx;
        rx_sync2 <= rx_sync1;
    end

end

///////////////////////////////////////////////////////////////////////////////
// Previous Sample Register
//
// Purpose:
// Stores previous synchronized RX value.
// Used for falling-edge detection.
//
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
        rx_prev <= 1'b1;
    else
        rx_prev <= rx_sync2;

end

///////////////////////////////////////////////////////////////////////////////
// Output Register Initialization
//
// This block initializes the receiver outputs.
// Future stages will update these signals.
//
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin

        rx_data        <= 8'd0;
        rx_done        <= 1'b0;
        parity_error   <= 1'b0;
        framing_error  <= 1'b0;

    end
    else
    begin

        // Default values (will be driven by FSM later)
        rx_done <= 1'b0;

    end

end

///////////////////////////////////////////////////////////////////////////////
// Sample Center Generator
//
// Generates one pulse exactly at the center
// of the UART bit (8th oversample).
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        sample_count  <= 4'd0;
        sample_center <= 1'b0;

    end

    else
    begin

        sample_center <= 1'b0;

        //----------------------------------------------------
        // Only count while validating start bit
        //----------------------------------------------------

        if(rx_active && baud_tick)
        begin

            if(baud_tick)
            begin

                if(sample_count == 4'd7)
                begin

                    sample_center <= 1'b1;

                    sample_count <= sample_count + 1'b1;

                end

                else if(sample_count == 4'd15)
                begin

                    sample_count <= 4'd0;

                end

                else
                begin

                    sample_count <= sample_count + 1'b1;

                end

            end

        end

        else
        begin

            sample_count <= 4'd0;

        end

    end

end

///////////////////////////////////////////////////////////////////////////////
// Future Stages
///////////////////////////////////////////////////////////////////////////////

/*

Stage 2
--------
Start Bit Validation

*/
///////////////////////////////////////////////////////////////////////////////
// Receiver FSM
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if (rst)
    begin

        state <= IDLE;

        start_wait <= 1'b0;

        rx_done <= 1'b0;

        parity_error <= 1'b0;

        framing_error <= 1'b0;

        rx_data <= 8'd0;

    end

    else
    begin

        //------------------------------------------------------
        // Default Outputs
        //------------------------------------------------------

        rx_done <= 1'b0;

        //------------------------------------------------------
        // FSM
        //------------------------------------------------------

        case(state)

        ////////////////////////////////////////////////////////
        // IDLE
        ////////////////////////////////////////////////////////

        IDLE:
        begin

            start_wait <= 1'b0;

            if(start_edge)
            begin

                state <= START;

            end

        end

        ////////////////////////////////////////////////////////
        // START
        ////////////////////////////////////////////////////////

        //////////////////////////////////////////////////////////
// START STATE
//////////////////////////////////////////////////////////

START:
begin

    //----------------------------------------------------
    // Wait until center of start bit
    //----------------------------------------------------

    if(sample_center)
    begin

        //------------------------------------------------
        // Confirm it is still LOW
        //------------------------------------------------

        if(rx_sync2 == 1'b0)
        begin

            //------------------------------------------------
            // Valid Start Bit
            //------------------------------------------------

            sample_count <= 4'd0;

            // Stage 3:
            // state <= BIT0;

        end

        else
        begin

            //------------------------------------------------
            // False start
            //------------------------------------------------

            state <= IDLE;

        end

    end

end

   

/*
Stage 3
--------
Baud Sampling Logic

*/

///////////////////////////////////////////////////////////////////////////////
// Stage 3 : 16x Oversampling Timing Engine
//
// Purpose:
// Counts the 16 oversampling ticks for each UART bit.
//
// sample_center : asserted once at count = 7
//                 Used only for validating the START bit.
//
// sample_tick   : asserted once at count = 15
//                 Used by the FSM to sample DATA,
//                 PARITY and STOP bits.
//
// This block does NOT receive UART data.
// It only generates timing pulses.
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        sample_count  <= 4'd0;
        sample_center <= 1'b0;
        sample_tick   <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------
        // Default Outputs
        //--------------------------------------------------

        sample_center <= 1'b0;
        sample_tick   <= 1'b0;

        //--------------------------------------------------
        // Run only while receiver is active
        //--------------------------------------------------

        if(rx_active && baud_tick)
        begin

            //--------------------------------------------------
            // Middle of UART Bit
            //--------------------------------------------------

            if(sample_count == 4'd7)
            begin

                sample_center <= 1'b1;

                sample_count <= sample_count + 1'b1;

            end

            //--------------------------------------------------
            // End of UART Bit
            //--------------------------------------------------

            else if(sample_count == 4'd15)
            begin

                sample_tick <= 1'b1;

                sample_count <= 4'd0;

            end

            //--------------------------------------------------
            // Continue Counting
            //--------------------------------------------------

            else
            begin

                sample_count <= sample_count + 1'b1;

            end

        end

        //--------------------------------------------------
        // Receiver Idle
        //--------------------------------------------------

        else
        begin

            sample_count <= 4'd0;

        end

    end

end

/*

Stage 4
--------
Receiver FSM
*/

///////////////////////////////////////////////////////////////////////////////
// Stage 4 : Receiver FSM
//
// Controls the UART reception sequence.
//
// IDLE
// START
// DATA
// PARITY
// STOP
// DONE
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        state <= IDLE;

        rx_active <= 1'b0;

        bit_index <= 3'd0;

    end

    else
    begin

        case(state)

        //////////////////////////////////////////////////////
        // IDLE
        //////////////////////////////////////////////////////
        IDLE:
        begin

            rx_active <= 1'b0;

            bit_index <= 3'd0;

            if(start_edge)
            begin

                rx_active <= 1'b1;

                state <= START;

            end

        end

        //////////////////////////////////////////////////////
        // START
        //////////////////////////////////////////////////////
        START:
        begin

            //------------------------------------------------
            // Wait until middle of start bit
            //------------------------------------------------

            if(sample_center)
            begin

                if(rx_sync2 == 1'b0)
                begin

                    //------------------------------------------------
                    // Valid start bit
                    //------------------------------------------------

                    bit_index <= 3'd0;

                    state <= DATA;

                end

                else
                begin

                    //------------------------------------------------
                    // False start
                    //------------------------------------------------

                    rx_active <= 1'b0;

                    state <= IDLE;

                end

            end

        end

        //////////////////////////////////////////////////////
        // DATA
        //////////////////////////////////////////////////////
        DATA:
        begin

            //------------------------------------------------
            // Wait one full UART bit
            //------------------------------------------------

            if(sample_tick)
            begin

                if(bit_index == 3'd7)
                begin

                    if(parity_enable)
                        state <= PARITY;
                    else
                        state <= STOP;

                end

                else
                begin

                    bit_index <= bit_index + 1'b1;

                end

            end

        end

        //////////////////////////////////////////////////////
        // PARITY
        //////////////////////////////////////////////////////
        PARITY:
        begin

            if(sample_tick)
            begin

                state <= STOP;

            end

        end

        //////////////////////////////////////////////////////
        // STOP
        //////////////////////////////////////////////////////
        STOP:
        begin

            if(sample_tick)
            begin

                state <= DONE;

            end

        end

        //////////////////////////////////////////////////////
        // DONE
        //////////////////////////////////////////////////////
        DONE:
        begin

            rx_active <= 1'b0;

            state <= IDLE;

        end

        //////////////////////////////////////////////////////
        // Safety
        //////////////////////////////////////////////////////
        default:
        begin

            state <= IDLE;

        end

        endcase

    end

end


/*
Stage 5
--------
Shift Register

*/

///////////////////////////////////////////////////////////////////////////////
// Stage 5 : Shift Register
//
// Samples the UART RX line once every sample_tick while
// the receiver is in the DATA state.
//
// UART transmits LSB first.
//
// bit_index = 0 -> D0
// bit_index = 1 -> D1
// ...
// bit_index = 7 -> D7
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        shift_reg <= 8'd0;

    end

    else
    begin

        //------------------------------------------------------
        // Receive Data Bits
        //------------------------------------------------------

        if(state == DATA && sample_tick)
        begin

            shift_reg[bit_index] <= rx_sync2;

        end

    end

end

/*

Stage 6
--------
Parity Checking
*/

///////////////////////////////////////////////////////////////////////////////
// Stage 6 : Receive Parity Bit
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        parity_bit <= 1'b0;

    end

    else
    begin

        if(state == PARITY && sample_tick)
        begin

            parity_bit <= rx_sync2;

        end

    end

end

///////////////////////////////////////////////////////////////////////////////
// Stage 6 : Parity Checker
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        parity_error <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------
        // Clear before every new frame
        //--------------------------------------------------

        if(state == IDLE)
            parity_error <= 1'b0;

        //--------------------------------------------------
        // Compare parity
        //--------------------------------------------------

        else if(state == PARITY && sample_tick)
        begin

            if(parity_bit != expected_parity)
                parity_error <= 1'b1;
            else
                parity_error <= 1'b0;

        end

    end

end

/*

Stage 7
--------
Stop Bit Verification

*/

///////////////////////////////////////////////////////////////////////////////
// Stage 7 : Stop Bit Verification
//
// The stop bit must be HIGH.
//
// If the stop bit is LOW,
// a framing error has occurred.
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        framing_error <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------
        // Clear error at beginning of next frame
        //--------------------------------------------------

        if(state == IDLE)
        begin

            framing_error <= 1'b0;

        end

        //--------------------------------------------------
        // Verify Stop Bit
        //--------------------------------------------------

        else if(state == STOP && sample_tick)
        begin

            if(rx_sync2 == 1'b1)
                framing_error <= 1'b0;
            else
                framing_error <= 1'b1;

        end

    end

end

/*

Stage 8
--------
Output Register Update

*/



///////////////////////////////////////////////////////////////////////////////
// Stage 8 : Output Register Update
//
// Copies received data to the output only after the
// complete UART frame has been received.
///////////////////////////////////////////////////////////////////////////////

always @(posedge clk)
begin

    if(rst)
    begin

        rx_data <= 8'd0;

        rx_done <= 1'b0;

    end

    else
    begin

        //--------------------------------------------------
        // Default
        //--------------------------------------------------

        rx_done <= 1'b0;

        //--------------------------------------------------
        // Frame Completed
        //--------------------------------------------------

        if(state == DONE)
        begin

            //--------------------------------------------------
            // Accept data only if no errors
            //--------------------------------------------------

            if( (framing_error == 1'b0) &&
                (parity_enable == 1'b0 || parity_error == 1'b0) )
            begin

                rx_data <= shift_reg;

            end

            //--------------------------------------------------
            // One-clock pulse
            //--------------------------------------------------

            rx_done <= 1'b1;

        end

    end

end

endmodule