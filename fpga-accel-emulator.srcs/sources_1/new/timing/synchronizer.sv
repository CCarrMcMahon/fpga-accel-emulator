/**
 * @module synchronizer
 * @brief Signal Synchronizer Module
 *
 * This module synchronizes an asynchronous input signal `async_signal` to the clock domain of `clk`. It uses a
 * two-stage flip-flop to mitigate metastability issues and provide a stable synchronized output `sync_signal`.
 *
 * @input clk          The clock signal to which the asynchronous signal is synchronized.
 * @input resetn       Active-low reset signal.
 * @input async_signal The asynchronous input signal to be synchronized.
 *
 * @output sync_signal The synchronized output signal.
 *
 * The module uses two flip-flop stages to synchronize the asynchronous signal. On each rising edge of the clock, the
 * asynchronous signal is sampled and passed through the two stages, resulting in a stable synchronized output.
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
            stage1 <= 0;
            stage2 <= 0;
        end else begin
            stage1 <= async_signal;
            stage2 <= stage1;
        end
    end

    assign sync_signal = stage2;
endmodule
