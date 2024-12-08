/**
 * @module synchronizer
 *
 * @input clk          System clock signal
 * @input resetn       Active-low reset signal
 * @input async_signal Asynchronous input signal to be synchronized
 *
 * @output sync_signal Synchronized output signal
 *
 * This module synchronizes an asynchronous input signal to the system clock domain. It uses a two-stage
 * flip-flop synchronizer to mitigate metastability issues and ensure a stable output.
 *
 * Internal signals include:
 * - `stage1`: First stage flip-flop output
 * - `stage2`: Second stage flip-flop output
 *
 * The always_ff block updates the stages on the rising edge of the clock or resets them on the falling edge of the
 * reset signal. The synchronized signal is taken from the output of the second stage flip-flop.
 */
module synchronizer (
    input  logic clk,
    input  logic resetn,
    input  logic async_signal,
    output logic sync_signal
);
    logic stage1, stage2;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            stage1 <= 1'b0;
            stage2 <= 1'b0;
        end else begin
            stage1 <= async_signal;
            stage2 <= stage1;
        end
    end

    assign sync_signal = stage2;
endmodule
