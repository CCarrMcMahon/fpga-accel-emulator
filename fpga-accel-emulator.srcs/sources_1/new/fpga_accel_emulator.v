`timescale 1ns / 1ps
module fpga_accel_emulator (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire [7:0] SW,
    output reg [7:0] LED
);
    always @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN) begin
            LED <= 8'b0;
        end else begin
            LED <= SW;
        end
    end
endmodule
