module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic rx,
    output logic [7:0] data_out,
    output logic data_ready,
    input logic data_read,
    output logic data_error,
    output logic debug_baud_pulse_out
);
    // States
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;
    state_t state, next_state;

    // Internal signals
    logic baud_clear;
    logic baud_pulse_out;
    logic [2:0] bit_counter;
    logic [7:0] shift_reg;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_rate_pulse_gen (
        .clk_in(clk),
        .resetn(resetn),
        .clear(baud_clear),
        .pulse_out(baud_pulse_out)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                // Start bit detected and any previous data has been read
                if (rx == 0 && !data_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (baud_pulse_out) begin
                    // Check for a valid start bit at the given baud rate
                    if (rx == 0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DATA: begin
                // Move on once all data bits have been read
                if (baud_pulse_out && bit_counter == 7) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                // Always go back to IDLE state
                if (baud_pulse_out) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // UART Receiver Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            baud_clear <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            data_out <= 0;
            data_ready <= 0;
            data_error <= 0;
        end else if (data_read) begin
            data_out   <= 0;
            data_ready <= 0;
            data_error <= 0;
        end else begin
            case (state)
                IDLE: begin
                    baud_clear <= 1;
                    if (rx == 0 && data_ready) begin
                        // Start bit detected but previous data hasn't been read
                        data_error <= 1;
                    end
                end
                START: begin
                    // Start the baud timer and reset counted data bits
                    baud_clear  <= 0;
                    bit_counter <= 0;
                end
                DATA: begin
                    // Shift all data bits into shift register
                    if (baud_pulse_out) begin
                        shift_reg <= {rx, shift_reg[7:1]};
                        if (bit_counter < 7) begin
                            bit_counter <= bit_counter + 1;
                        end
                    end
                end
                STOP: begin
                    if (baud_pulse_out) begin
                        if (rx == 1) begin
                            // Stop bit detected
                            data_out   <= shift_reg;
                            data_ready <= 1;
                        end else begin
                            // Invalid stop bit
                            data_error <= 1;
                        end
                    end
                end
                default: data_error <= 1;
            endcase
        end
    end

    // Final Assignments
    assign debug_baud_pulse_out = baud_pulse_out;
endmodule
