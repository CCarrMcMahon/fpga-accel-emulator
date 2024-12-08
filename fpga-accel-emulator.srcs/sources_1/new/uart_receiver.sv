/**
 * UART Receiver Module
 *
 * This module implements a UART receiver that reads serial data from the `rx` input, processes it according to the
 * specified baud rate, and outputs the received data on `data_out` when `data_ready` is asserted. It then waits to read
 * more data until `data_read` has been acked. If more data is received before then, the `data_error` signal will be
 * asserted and the incoming bytes will be ignored. The `data_error` signal will also be set when an invalid start or
 * stop bit is detected.
 *
 * Parameters:
 *     ClkFreq (int): The frequency of the input clock in Hz (default: 100,000,000).
 *     BaudRate (int): The desired baud rate for UART communication (default: 9600).
 *
 * Inputs:
 *     clk (logic): The input clock signal.
 *     resetn (logic): Active-low reset signal.
 *     rx (logic): The UART receive data input.
 *     data_read (logic): Acknowledges that data_out has been read.
 *
 * Outputs:
 *     data_out (logic [7:0]): The 8-bit data output.
 *     data_ready (logic): Indicates that valid data is available on data_out.
 *     data_error (logic): Indicates an error in data reception.
 */
module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic data_read,

    // UART Interface
    input logic rx,

    // Data Signals
    output logic [7:0] data_out,

    // Status Signals
    output logic data_ready,
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

    // Internal signals
    logic baud_clear;
    logic baud_pulse_out;
    logic [3:0] bit_counter;
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
            current_state <= IDLE;
        end else if (data_read == 0) begin  // Only update state when not being acked
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
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
                if (baud_pulse_out && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                // Always go back to IDLE state
                next_state = IDLE;
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
        end else begin
            if (data_read) begin
                data_out   <= 0;
                data_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
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
                    if (baud_pulse_out && bit_counter < 8) begin
                        shift_reg   <= {rx, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                STOP: begin
                    if (rx == 1) begin
                        // Stop bit detected
                        data_out   <= shift_reg;
                        data_ready <= 1;
                    end else begin
                        // Invalid stop bit
                        data_error <= 1;
                    end
                end
                default: data_error <= 1;
            endcase
        end
    end
endmodule
