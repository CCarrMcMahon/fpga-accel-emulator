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
 * @input data_out_ack Acknowledgment signal indicating that the data has been read.
 * @input rx           UART receive data input.
 *
 * @output data_out       The received byte of data.
 * @output data_out_ready Indicates that a new byte of data is available.
 * @output data_error     Indicates an error in the received data (e.g., framing error).
 *
 * The module uses a state machine to manage the reception process, which includes the following states:
 * - IDLE: Waiting for the start bit.
 * - START: Validating the start bit.
 * - DATA: Receiving the data bits.
 * - STOP: Validating the stop bit and outputting the received byte.
 *
 * The module also includes internal logic for synchronizing the `rx` and `data_out_ack` signals, and a pulse generator
 * for generating the baud rate clock.
 */
module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic data_out_ack,

    // UART Interface
    input logic rx,

    // Data Signals
    output logic [7:0] data_out,

    // Status Signals
    output logic data_out_ready,
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
    logic clear_baud_pulse_gen;
    logic baud_rate_pulse;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic synced_rx;
    logic synced_data_out_ack;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_rate_pulse_generator_inst_1 (
        .clk_in(clk),
        .resetn(resetn),
        .clear(clear_baud_pulse_gen),
        .pulse_out(baud_rate_pulse)
    );

    // Instantiate a synchronizer for rx
    synchronizer rx_synchronizer_inst_1 (
        .clk(clk),
        .resetn(resetn),
        .async_signal(rx),
        .sync_signal(synced_rx)
    );

    // Instantiate a synchronizer for data_out_ack
    synchronizer data_out_ack_synchronizer_inst_1 (
        .clk(clk),
        .resetn(resetn),
        .async_signal(data_out_ack),
        .sync_signal(synced_data_out_ack)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= IDLE;
        end else if (!synced_data_out_ack) begin  // Only update state when data_out is not being read
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                // Start bit detected and any previous data has been read
                if (!synced_rx && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (baud_rate_pulse) begin
                    // Check for a valid start bit at the given baud rate
                    if (!synced_rx) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DATA: begin
                // Move on once all data bits have been read
                if (baud_rate_pulse && bit_counter == 8) begin
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
            clear_baud_pulse_gen <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            data_out <= 0;
            data_out_ready <= 0;
            data_error <= 0;
        end else begin
            if (synced_data_out_ack) begin
                data_out <= 0;
                data_out_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
                IDLE: begin
                    clear_baud_pulse_gen <= 1;
                    if (!synced_rx && data_out_ready) begin
                        // Start bit detected but previous data hasn't been read
                        data_error <= 1;
                    end
                end
                START: begin
                    // Start the baud timer and reset counted data bits
                    clear_baud_pulse_gen <= 0;
                    bit_counter <= 0;
                end
                DATA: begin
                    // Shift all data bits into shift register
                    if (baud_rate_pulse && bit_counter < 8) begin
                        shift_reg   <= {synced_rx, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                STOP: begin
                    if (synced_rx) begin
                        // Stop bit detected
                        data_out <= shift_reg;
                        data_out_ready <= 1;
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
