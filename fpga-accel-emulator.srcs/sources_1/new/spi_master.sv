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
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;

    // Instantiate a clock generator for the SPI clock
    clock_generator #(
        .ClkInFreq (ClkFreq),
        .ClkOutFreq(SclkFreq)
    ) sclk_freq_clock_gen (
        .clk_in (clk),
        .resetn (resetn),
        .clear  (sclk_clear),
        .clk_out(sclk)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= IDLE;
        end else if (data_read != 1) begin  // Don't update state while data_read is being held high
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
                // Wait for a clock transition from high to low after all bits have been transferred
                if (prev_sclk == !sclk && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // SPI Master Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            sclk_clear <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            prev_sclk <= 1;
            mosi <= 0;
            csn <= 1;
            data_out <= 0;
            data_ready <= 0;
            ack_data_read <= 0;
            data_error <= 0;
        end else begin
            if (data_read) begin
                data_out   <= 0;
                data_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
                IDLE: begin
                    // Keep the clock and chip disabled while idle
                    sclk_clear <= 1;
                    prev_sclk <= 1;
                    mosi <= 0;
                    csn <= 1;
                    if (start_tx && data_ready) begin
                        // New data detected but previous data hasn't been acked
                        data_error <= 1;
                    end
                end
                START: begin
                    // Enable clock and chip
                    sclk_clear <= 0;
                    prev_sclk <= ~sclk;  // Set inverse so first bit is sent immediately
                    bit_counter <= 0;
                    csn <= 0;

                    // Store input data and ack that is has been read
                    shift_reg <= data_in;
                    ack_data_read <= 1;
                end
                DATA: begin
                    // Clear ack now that it has been read
                    ack_data_read <= 0;

                    // Wait for clock transition (first bit should be sent immediately)
                    if (sclk != prev_sclk && bit_counter < 8) begin
                        prev_sclk <= sclk;

                        if (sclk) begin
                            // Shift miso into LSB when clk transitions from low to high
                            shift_reg   <= {shift_reg[6:0], miso};
                            bit_counter <= bit_counter + 1;
                        end else begin
                            // Output MSB of mosi when clk transitions from high to low
                            mosi <= shift_reg[7];
                        end
                    end
                end
                STOP: begin
                    // Output received data and indicate it is ready
                    data_out   <= shift_reg;
                    data_ready <= 1;
                end
                default: data_error <= 1;
            endcase
        end
    end
endmodule
