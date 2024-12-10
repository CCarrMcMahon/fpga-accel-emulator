/**
 * @module uart_receiver
 * @brief UART Receiver Module
 *
 * This module implements a UART receiver that reads serial data from the `rx` input and outputs the received byte on
 * `data_out`. The module operates at a configurable baud rate and clock frequency.
 *
 * @param ClkFreq  The frequency of the input clock in Hz (default: 100 MHz).
 * @param BaudRate The desired baud rate for UART communication (default: 9600).
 *
 * @input clk          The system clock input.
 * @input resetn       Active-low reset signal.
 * @input rx           UART receive data input.
 * @input data_out_ack Acknowledgment signal indicating that the data has been read.
 *
 * @output data_out       The received byte of data.
 * @output data_out_ready Indicates that a new byte of data is available.
 * @output data_error     Indicates an error in the received data (e.g., framing error).
 *
 * The module uses a state machine to manage the reception process, which includes the following states:
 * - RESET: Waiting for the `rx` signal to be high after a reset condition.
 * - IDLE: Waiting for the start bit.
 * - START_BIT: Validating the start bit.
 * - DATA_BITS: Receiving the data bits.
 * - STOP_BITS: Validating the stop bit.
 * - OUTPUT_DATA: Outputting the received byte.
 * - DATA_OUT_ACKED: Clearing the output data and any error signals.
 * - ERROR: Handling error conditions.
 *
 * The module also includes internal logic for synchronizing the `rx` and `data_out_ack` signals, and a pulse generator
 * for generating the baud rate clock.
 */
module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic rx,
    input logic data_out_ack,
    output logic [7:0] data_out,
    output logic data_out_ready,
    output logic error
);
    // States
    typedef enum logic [2:0] {
        RESET,
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BITS,
        OUTPUT_DATA,
        DATA_OUT_ACKED,
        ERROR
    } state_t;
    state_t current_state, next_state;

    // Internal signals
    logic clear_baud_gen;
    logic baud_pulse;
    logic [3:0] data_counter;
    logic [7:0] shift_reg;
    logic synced_rx;
    logic synced_data_out_ack;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_gen (
        .clk_in(clk),
        .resetn(resetn),
        .clear(clear_baud_gen),
        .pulse_out(baud_pulse)
    );

    // Instantiate a synchronizer for rx
    synchronizer rx_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(rx),
        .sync_signal(synced_rx)
    );

    // Instantiate a synchronizer for data_out_ack
    synchronizer data_out_ack_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(data_out_ack),
        .sync_signal(synced_data_out_ack)
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
                // Wait for rx to be set high
                if (synced_rx == 1'b1) begin
                    next_state = IDLE;
                end
            end
            IDLE: begin
                // Start bit detected
                if (synced_rx == 1'b0) begin
                    // Previous data has been processed
                    if (data_out_ready == 1'b0) begin
                        next_state = START_BIT;
                    end else begin
                        next_state = ERROR;
                    end
                end else if (synced_data_out_ack == 1'b1) begin  // Give processing priority
                    next_state = DATA_OUT_ACKED;
                end
            end
            START_BIT: begin
                if (baud_pulse) begin
                    // Valid start bit detected
                    if (synced_rx == 1'b0) begin
                        next_state = DATA_BITS;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end
            DATA_BITS: begin
                // Wait for all data bits to be processed before moving on
                if (baud_pulse && data_counter == 7) begin
                    next_state = STOP_BITS;
                end
            end
            STOP_BITS: begin
                if (baud_pulse) begin
                    // Valid stop bit detected
                    if (synced_rx == 1'b1) begin
                        next_state = OUTPUT_DATA;
                    end else begin
                        next_state = ERROR;
                    end
                end
            end
            OUTPUT_DATA: begin
                next_state = IDLE;
            end
            DATA_OUT_ACKED: begin
                next_state = IDLE;
            end
            ERROR: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // UART Receiver Logic
    always_ff @(posedge clk) begin
        case (current_state)
            RESET: begin
                data_out <= 0;
                data_out_ready <= 0;
                error <= 0;
                clear_baud_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
            end
            IDLE: begin
                clear_baud_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
            end
            START_BIT: begin
                // Start the baud pulse generator
                clear_baud_gen <= 0;
            end
            DATA_BITS: begin
                // Shift all data bits into shift register
                if (baud_pulse) begin
                    shift_reg <= {synced_rx, shift_reg[7:1]};  // Use right shift to first bit becomes LSB
                    data_counter <= data_counter + 1;
                end
            end
            STOP_BITS: begin
                data_counter <= 0;
            end
            OUTPUT_DATA: begin
                data_out <= shift_reg;
                data_out_ready <= 1;
            end
            DATA_OUT_ACKED: begin
                data_out <= 0;
                data_out_ready <= 0;
                error <= 0;
            end
            ERROR: begin
                error <= 1;
            end
            default: error <= 1;
        endcase
    end
endmodule
