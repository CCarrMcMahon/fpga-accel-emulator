/**
 * @module pulse_generator
 * @brief Pulse Generator Module
 *
 * This module generates an output pulse `pulse_out` with a specified frequency and phase shift from an input clock
 * `clk_in`. The output pulse frequency and phase shift are configurable through parameters.
 *
 * @param ClkInFreq    The frequency of the input clock in Hz (default: 100 MHz).
 * @param PulseOutFreq The desired frequency of the output pulse in Hz (default: 1 MHz).
 * @param PhaseShift   The phase shift for the output pulse, specified as a fraction of the clock period (default: 0.0).
 *
 * @input clk_in The input clock signal.
 * @input resetn Active-low reset signal.
 * @input clear  Signal to clear and reset the pulse generator.
 *
 * @output pulse_out The generated output pulse signal.
 *
 * The module calculates the necessary divider value and counter bits based on the input and output pulse frequencies.
 * It also ensures that the phase shift is within a valid range [0.0, 1.0]. The internal counter and logic generate the
 * output pulse with the specified frequency and phase shift.
 */
module pulse_generator #(
    parameter int  ClkInFreq    = 100_000_000,  // Input clock frequency in Hz
    parameter int  PulseOutFreq = 1_000_000,    // Output pulse frequency in Hz
    parameter real PhaseShift   = 0.0           // Phase shift for the output pulse
) (
    input  logic clk_in,
    input  logic resetn,
    input  logic clear,
    output logic pulse_out
);
    // Calculate the divider value and the number of bits needed for the counter
    localparam int Divider = ClkInFreq / PulseOutFreq;
    localparam int CounterBits = $clog2(Divider);

    // Ensure the phase shift is within a valid range [0.0, 1.0]
    localparam real ValidPhaseShift = (PhaseShift < 0.0) ? 0.0 : (PhaseShift > 1.0) ? 1.0 : PhaseShift;

    // Calculate the offset for the phase shift
    localparam int ShiftOffset = Divider - $rtoi(Divider * ValidPhaseShift);

    // Internal signals
    logic [CounterBits-1:0] counter;
    logic synced_clear;

    // Instantiate a synchronizer for the clear signal
    synchronizer clear_synchronizer_inst_1 (
        .clk(clk_in),
        .resetn(resetn),
        .async_signal(clear),
        .sync_signal(synced_clear)
    );

    // Pulse generation logic
    always_ff @(posedge clk_in or negedge resetn) begin
        if (!resetn) begin
            counter   <= ShiftOffset;
            pulse_out <= 0;
        end else if (synced_clear) begin
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
