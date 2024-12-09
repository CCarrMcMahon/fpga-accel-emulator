/**
 * @module clock_generator
 * @param ClkInFreq  Input clock frequency in Hz (default: 100,000,000)
 * @param ClkOutFreq Output clock frequency in Hz (default: 1,000,000)
 * @param PhaseShift Phase shift for the output clock (default: 0.0)
 *
 * @input clk_in  Input clock signal
 * @input resetn  Active-low reset signal
 * @input clear   Asynchronous clear signal
 *
 * @output clk_out Generated clock output signal
 *
 * This module generates a clock signal with a specified frequency and optional phase shift. It includes:
 * - A clock divider to generate the desired output frequency
 * - A phase shift mechanism to adjust the output clock phase
 * - Synchronization of the asynchronous clear signal to the input clock domain
 *
 * Internal signals include:
 * - `counter`: Counter for clock division
 * - `sync_clear`: Synchronized clear signal
 *
 * The module instantiates a synchronizer for the `clear` signal to ensure it is safely sampled and used within the
 * clock domain.
 */
module clock_generator #(
    parameter int  ClkInFreq  = 100_000_000,  // Input clock frequency in Hz
    parameter int  ClkOutFreq = 1_000_000,    // Output clock frequency in Hz
    parameter real PhaseShift = 0.0           // Phase shift for the output clock
) (
    input  logic clk_in,
    input  logic resetn,
    input  logic clear,
    output logic clk_out
);
    // Calculate the divider value and the number of bits needed for the counter
    localparam int Divider = ClkInFreq / (ClkOutFreq * 2);
    localparam int CounterBits = $clog2(Divider);

    // Ensure the phase shift is within a valid range [0.0, 1.0]
    localparam real ValidPhaseShift = (PhaseShift < 0.0) ? 0.0 : (PhaseShift > 1.0) ? 1.0 : PhaseShift;

    // Calculate the offset for the phase shift
    localparam int ShiftOffset = Divider - $rtoi(Divider * ValidPhaseShift);

    // Internal signals
    logic [CounterBits-1:0] counter;
    logic sync_clear;

    // Instantiate a synchronizer for the clear signal
    synchronizer sync_clear_inst (
        .clk(clk_in),
        .resetn(resetn),
        .async_signal(clear),
        .sync_signal(sync_clear)
    );

    // Clock generation logic
    always_ff @(posedge clk_in or negedge resetn) begin
        if (!resetn) begin
            counter <= ShiftOffset;
            clk_out <= 0;
        end else if (sync_clear) begin
            counter <= ShiftOffset;
            clk_out <= 0;
        end else begin
            if (counter == Divider - 1) begin
                counter <= 0;
                clk_out <= ~clk_out;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule
