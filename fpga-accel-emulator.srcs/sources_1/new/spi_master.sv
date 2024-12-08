module spi_master #(
    parameter int ClkFreq = 100_000_000,  // Input clock frequency in Hz
    parameter int SclkFreq = 1_000_000  // SPI serial clock frequency in Hz
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic start_tx,
    input logic data_read,

    // SPI Interface
    output logic mosi,
    input  logic miso,
    output logic sclk,
    output logic csn,

    // Data Signals
    input  logic [7:0] data_in,
    output logic [7:0] data_out,

    // Status Signals
    output logic data_ready,
    output logic ack_data_read,
    output logic data_error
);
    // States
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;
    state_t current_state, next_state;

    // Internal Signals
    logic sclk_clear;
    logic sclk_out;
    logic [2:0] bit_counter;
    logic [7:0] shift_reg;

    // Instantiate a clock generator for the SPI clock
    clock_generator #(
        .ClkInFreq (ClkFreq),
        .ClkOutFreq(SclkFreq)
    ) sclk_freq_clock_gen (
        .clk_in (clk),
        .resetn (resetn),
        .clear  (sclk_clear),
        .clk_out(sclk_out)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start_tx && !data_ready) begin
                    next_state = START;
                end
            end
            START: begin
                next_state = DATA;
            end
            DATA: begin
                if (bit_counter == 7) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Final Assignments
    assign sclk = sclk_out;
endmodule
