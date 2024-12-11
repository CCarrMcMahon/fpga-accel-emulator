/**
 * @module uart_transmitter
 * @brief UART Transmitter Module
 *
 * This module implements a UART transmitter that sends serial data through the `tx` output. The module operates at a
 * configurable baud rate and clock frequency.
 *
 * @param ClkFreq  The frequency of the input clock in Hz (default: 100 MHz).
 * @param BaudRate The desired baud rate for UART communication (default: 9600 Hz).
 *
 * @input clk     The system clock input.
 * @input resetn  Active-low reset signal.
 * @input start   Signal to start the transmission.
 * @input data_in The byte of data to be transmitted.
 *
 * @output data_in_ack Acknowledgment signal indicating that the data has been stored.
 * @output busy        Indicates that the transmitter is busy.
 * @output tx          UART transmit data output.
 *
 * The module uses a state machine to manage the transmission process, which includes the following states:
 * - RESET: Initial state, waiting for the `rx` signal to be high.
 * - IDLE: Waiting for the start signal.
 * - STORE_DATA: Storing the data to be transmitted.
 * - START_BIT: Sending the start bit.
 * - DATA_BITS: Transmitting the data bits.
 * - STOP_BITS: Sending the stop bit.
 *
 * The module also includes internal logic for synchronizing the `start` signal and a pulse generator for generating the
 * clock for the baud rate.
 */
module uart_transmitter #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic [7:0] data_in,
    output logic data_in_ack,
    output logic busy,
    output logic tx
);
    // States
    typedef enum logic [2:0] {
        RESET,
        IDLE,
        STORE_DATA,
        START_BIT,
        DATA_BITS,
        STOP_BITS
    } state_t;
    state_t current_state, next_state;

    // Internal signals
    logic clear_baud_gen;
    logic baud_pulse;
    logic synced_start;
    logic [3:0] data_counter;
    logic [7:0] shift_reg;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.0)
    ) baud_gen (
        .clk_in(clk),
        .resetn(resetn),
        .clear(clear_baud_gen),
        .pulse_out(baud_pulse)
    );

    // Instantiate a synchronizer for the start signal
    synchronizer start_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(start),
        .sync_signal(synced_start)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= RESET;
        end else begin
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            RESET: begin
                next_state = IDLE;
            end
            IDLE: begin
                if (synced_start) begin
                    next_state = STORE_DATA;
                end
            end
            STORE_DATA: begin
                next_state = START_BIT;
            end
            START_BIT: begin
                next_state = DATA_BITS;
            end
            DATA_BITS: begin
                if (baud_pulse && data_counter == 8) begin
                    next_state = STOP_BITS;
                end
            end
            STOP_BITS: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // UART Transmitter Logic
    always_ff @(posedge clk) begin
        case (current_state)
            RESET: begin
                data_in_ack <= 0;
                busy <= 0;
                tx <= 1;
                clear_baud_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
            end
            IDLE: begin
                // Set default state of signals
                data_in_ack <= 0;
                busy <= 0;
                tx <= 1;
                clear_baud_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
            end
            STORE_DATA: begin
                // Store data in the shift register to avoid it changing
                shift_reg <= data_in;

                // Indicate status and start the baud clock
                data_in_ack <= 1;
                busy <= 1;
                clear_baud_gen <= 0;
            end
            START_BIT: begin
                // Clear data_in_ack since we have stored the data
                data_in_ack <= 0;
                tx <= 0;  // Start bit
            end
            DATA_BITS: begin
                if (baud_pulse) begin
                    tx <= shift_reg[0];  // Transmit LSB
                    shift_reg <= {1'b0, shift_reg[7:1]};  // Shift out LSB (right shift)
                    data_counter <= data_counter + 1;
                end
            end
            STOP_BITS: begin
                tx <= 1;  // Stop bit
            end
            default: tx <= 1;
        endcase
    end
endmodule
