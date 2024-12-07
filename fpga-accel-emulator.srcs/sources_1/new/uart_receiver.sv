/**
 * Receives UART data and outputs the received byte.
 *
 * This module implements a UART receiver that takes an input clock signal and
 * a serial data input (rx) and outputs the received byte along with a data ready
 * signal. The baud rate for the UART communication is defined by the `BaudRate`
 * parameter.
 *
 * ## Parameters
 * - `ClkFreq` (int): Input clock frequency in Hz (default: 100 MHz).
 * - `BaudRate` (int): Baud rate for UART communication (default: 9600).
 *
 * ## Inputs
 * - `clk` (logic): Input clock signal.
 * - `resetn` (logic): Active-low reset signal to initialize the state machine and outputs.
 * - `rx` (logic): Serial data input.
 *
 * ## Outputs
 * - `valid` (logic): Indicates that a byte has been received and is ready to be read.
 * - `data_out` (logic [7:0]): The received byte.
 *
 * The module uses a state machine to handle the UART protocol, including start,
 * data, and stop bits. A pulse generator is instantiated to generate the baud
 * rate clock.
 */
module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic rx,
    output logic valid,
    output logic [7:0] data_out
);
    // States
    typedef enum logic [1:0] {
        UART_IDLE,
        UART_START,
        UART_DATA,
        UART_STOP
    } uart_state_t;
    uart_state_t uart_state, uart_next_state;

    // Internal signals
    logic baud_clear;
    logic baud_pulse_out;
    logic [2:0] bit_counter;

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
            uart_state <= UART_IDLE;
        end else begin
            uart_state <= uart_next_state;
        end
    end

    // UART Receiver Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            uart_next_state <= UART_IDLE;
            baud_clear <= 1;
            bit_counter <= 0;
            valid <= 0;
            data_out <= 0;
        end else begin
            case (uart_state)
                UART_IDLE: begin
                    baud_clear <= 1;
                    bit_counter <= 0;
                    valid <= 0;

                    // Start bit detected (rx pulled low)
                    if (rx == 0) begin
                        uart_next_state <= UART_START;
                    end
                end
                UART_START: begin
                    baud_clear <= 0;

                    if (baud_pulse_out) begin
                        if (rx == 0) begin
                            uart_next_state <= UART_DATA;
                        end else begin
                            uart_next_state <= UART_IDLE;
                        end
                    end
                end
                UART_DATA: begin
                    if (baud_pulse_out) begin
                        data_out[bit_counter] <= rx;

                        if (bit_counter < 7) begin
                            bit_counter <= bit_counter + 1;
                        end else begin
                            uart_next_state <= UART_STOP;
                        end
                    end
                end
                UART_STOP: begin
                    if (baud_pulse_out) begin
                        // Stop bit detected (rx pulled high)
                        if (rx == 1) begin
                            valid <= 1;
                        end
                        uart_next_state <= UART_IDLE;
                    end
                end
                default: uart_next_state <= UART_IDLE;
            endcase
        end
    end
endmodule
