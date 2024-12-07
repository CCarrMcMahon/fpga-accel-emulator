module pulse_generator #(
    parameter int ClkInFreq        = 100_000_000,  // Input clock frequency: 100 MHz
    parameter int PulseOutFreq     = 1_000_000,    // Output pulse frequency: 1 MHz
    parameter bit HalfPeriodOffset = 0             // Half-period offset flag
) (
    input logic clk_in,  // Input clock
    input logic reset,  // Reset signal
    input logic clear,  // Clear signal
    output logic pulse_out  // Generated output pulse
);
    localparam int Divider = ClkInFreq / PulseOutFreq;
    localparam int CounterBits = $clog2(Divider);

    logic [CounterBits-1:0] counter;

    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
            counter   <= HalfPeriodOffset ? Divider / 2 : 0;
            pulse_out <= 0;
        end else if (clear) begin
            counter   <= HalfPeriodOffset ? Divider / 2 : 0;
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
