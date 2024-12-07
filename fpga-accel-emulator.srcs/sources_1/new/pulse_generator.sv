module pulse_generator #(
    parameter int  ClkInFreq    = 100_000_000,  // Input clock frequency: 100 MHz
    parameter int  PulseOutFreq = 1_000_000,    // Output pulse frequency: 1 MHz
    parameter real PhaseShift   = 0.0           // Phase offset as a fraction of the period (e.g., 0.5 for half-period)
) (
    input logic clk_in,  // Input clock
    input logic reset,  // Reset signal
    input logic clear,  // Clear signal
    output logic pulse_out  // Generated output pulse
);
    localparam int Divider = ClkInFreq / PulseOutFreq;
    localparam int CounterBits = $clog2(Divider);
    localparam real ValidPhaseShift = (PhaseShift < 0.0) ? 0.0 : (PhaseShift > 1.0) ? 1.0 : PhaseShift;
    localparam int ShiftOffset = Divider - $rtoi(Divider * ValidPhaseShift);

    logic [CounterBits-1:0] counter;

    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
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
