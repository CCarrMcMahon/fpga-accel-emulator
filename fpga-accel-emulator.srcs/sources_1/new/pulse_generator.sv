/**
 * Generates a pulse signal with a specified frequency and phase shift.
 *
 * This module takes an input clock signal and generates an output pulse signal
 * with a frequency defined by the `PulseOutFreq` parameter. The output pulse can
 * also have a phase shift specified by the `PhaseShift` parameter.
 *
 * ## Parameters
 * - `ClkInFreq` (int): Input clock frequency in Hz (default: 100 MHz).
 * - `PulseOutFreq` (int): Output pulse frequency in Hz (default: 1 MHz).
 * - `PhaseShift` (real): Phase offset as a fraction of the period (default: 0.0).
 *
 * ## Inputs
 * - `clk_in` (logic): Input clock signal.
 * - `rst_n` (logic): Active-low reset signal to initialize the counter and output pulse.
 * - `clear` (logic): Clear signal to reset the counter and output pulse.
 *
 * ## Outputs
 * - `pulse_out` (logic): Generated output pulse signal.
 *
 * The module uses a counter to divide the input clock frequency to the desired
 * output pulse frequency. The phase shift is applied by initializing the counter
 * to a specific offset value.
 */
module pulse_generator #(
    parameter int  ClkInFreq    = 100_000_000,
    parameter int  PulseOutFreq = 1_000_000,
    parameter real PhaseShift   = 0.0
) (
    input  logic clk_in,
    input  logic rst_n,
    input  logic clear,
    output logic pulse_out
);
    localparam int Divider = ClkInFreq / PulseOutFreq;
    localparam int CounterBits = $clog2(Divider);
    localparam real ValidPhaseShift = (PhaseShift < 0.0) ? 0.0 : (PhaseShift > 1.0) ? 1.0 : PhaseShift;
    localparam int ShiftOffset = Divider - $rtoi(Divider * ValidPhaseShift);

    logic [CounterBits-1:0] counter;

    always_ff @(posedge clk_in or negedge rst_n) begin
        if (!rst_n) begin
            counter   <= ShiftOffset;
            pulse_out <= 0;
        end else if (clear) begin
            counter   <= ShiftOffset;
            pulse_out <= 0;
        end else begin
            if (counter == Divider - 1) begin
                counter   <= 0;
                pulse_out <= 1;
            end else begin
                counter   <= counter + 1;
                pulse_out <= 0;
            end
        end
    end
endmodule
