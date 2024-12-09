/**
 * @module pulse_generator
 * @param ClkInFreq    Input clock frequency in Hz (default: 100,000,000)
 * @param PulseOutFreq Output pulse frequency in Hz (default: 1,000,000)
 * @param PhaseShift   Phase shift for the output pulse (default: 0.0)
 *
 * @input clk_in   Input clock signal
 * @input resetn   Active-low reset signal
 * @input clear    Asynchronous clear signal
 *
 * @output pulse_out Generated pulse output signal
 *
 * This module generates a pulse signal with a specified frequency and optional phase shift. It includes:
 * - A clock divider to generate the desired pulse frequency
 * - A phase shift mechanism to adjust the output pulse phase
 * - Synchronization of the asynchronous clear signal to the input clock domain
 *
 * Internal signals include:
 * - `counter`: Counter for pulse generation
 *
 * The module uses an always_ff block to handle the clock division and pulse generation logic. The clear signal is
 * synchronized to the input clock domain to ensure safe operation.
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
    logic sync_clear;

    // Instantiate a synchronizer for the clear signal
    synchronizer sync_clear_inst (
        .clk(clk_in),
        .resetn(resetn),
        .async_signal(clear),
        .sync_signal(sync_clear)
    );

    // Pulse generation logic
    always_ff @(posedge clk_in or negedge resetn) begin
        if (!resetn) begin
            counter   <= ShiftOffset;
            pulse_out <= 0;
        end else if (sync_clear) begin
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
