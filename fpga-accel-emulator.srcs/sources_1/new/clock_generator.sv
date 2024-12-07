/**
 * Generates a clock signal with a specified frequency and phase shift.
 *
 * This module takes an input clock signal and generates an output clock signal
 * with a frequency defined by the `ClkOutFreq` parameter. The output clock can
 * also have a phase shift specified by the `PhaseShift` parameter.
 *
 * ## Parameters
 * - `ClkInFreq` (int): Input clock frequency in Hz (default: 100 MHz).
 * - `ClkOutFreq` (int): Output clock frequency in Hz (default: 1 MHz).
 * - `PhaseShift` (real): Phase offset as a fraction of the period (default: 0.0).
 *
 * ## Inputs
 * - `clk_in` (logic): Input clock signal.
 * - `resetn` (logic): Active-low reset signal to initialize the counter and output clock.
 * - `clear` (logic): Clear signal to reset the counter and output clock.
 *
 * ## Outputs
 * - `clk_out` (logic): Generated output clock signal.
 *
 * The module uses a counter to divide the input clock frequency to the desired
 * output frequency. The phase shift is applied by initializing the counter to
 * a specific offset value.
 */
module clock_generator #(
    parameter int  ClkInFreq  = 100_000_000,
    parameter int  ClkOutFreq = 1_000_000,
    parameter real PhaseShift = 0.0
) (
    input  logic clk_in,
    input  logic resetn,
    input  logic clear,
    output logic clk_out
);
    localparam int Divider = ClkInFreq / (ClkOutFreq * 2);
    localparam int CounterBits = $clog2(Divider);
    localparam real ValidPhaseShift = (PhaseShift < 0.0) ? 0.0 : (PhaseShift > 1.0) ? 1.0 : PhaseShift;
    localparam int ShiftOffset = Divider - $rtoi(Divider * ValidPhaseShift);

    logic [CounterBits-1:0] counter;

    always_ff @(posedge clk_in or negedge resetn) begin
        if (!resetn) begin
            counter <= ShiftOffset;
            clk_out <= 0;
        end else if (clear) begin
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
