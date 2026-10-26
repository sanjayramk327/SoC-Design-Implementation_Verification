`timescale 1ns / 1ps

module rocket_muldiv (
    input  wire        clk,
    input  wire        rst_n,
    
    input  wire [63:0] rs1,
    input  wire [63:0] rs2,
    input  wire [2:0]  op,    // 0=MUL, 1=MULH, 2=MULHSU, 3=MULHU, 4=DIV, 5=DIVU, 6=REM, 7=REMU
    input  wire        is_32, // 32-bit variant (MULW, DIVW, etc.)
    input  wire        valid,
    
    output reg  [63:0] rd,
    output reg         ready,
    output reg         done
);

    reg [5:0] state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd <= 64'd0;
            ready <= 1'b1;
            done <= 1'b0;
            state <= 6'd0;
        end else begin
            if (valid && ready) begin
                ready <= 1'b0;
                done <= 1'b0;
                
                if (op[2]) begin
                    // Divide/Rem (Takes up to 64 cycles)
                    state <= is_32 ? 6'd32 : 6'd64;
                end else begin
                    // Multiply (Fast 2-cycle)
                    state <= 6'd2;
                end
            end else if (state > 6'd1) begin
                state <= state - 6'd1;
                done <= 1'b0;
            end else if (state == 6'd1) begin
                state <= 6'd0;
                ready <= 1'b1;
                done <= 1'b1;
                rd <= rs1 + rs2; // Mock result
                
                $display("[%0t] MULDIV: Completed operation %h", $time, op);
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
