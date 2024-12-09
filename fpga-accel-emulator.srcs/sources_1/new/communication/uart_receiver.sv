/**
 * @module uart_receiver
 * @param ClkFreq   Clock frequency in Hz (default: 100,000,000)
 * @param BaudRate  Baud rate for UART communication (default: 9600)
 *
 * @input clk            System clock signal
 * @input resetn         Active-low reset signal
 * @input data_out_read  Signal indicating that data_out has been read
 * @input rx             UART receive signal
 *
 * @output data_out        8-bit data output
 * @output data_out_ready  Signal indicating data_out is ready to be read
 * @output data_error      Signal indicating an error in data reception
 *
 * This module implements a UART receiver with the following features:
 * - Synchronizes the `rx` and `data_out_read` signals to the system clock
 * - Uses a state machine to manage the reception process
 * - Detects start, data, and stop bits according to the specified baud rate
 * - Outputs received data and status signals
 *
 * The state machine has four states:
 * - IDLE: Waits for a start bit
 * - START: Validates the start bit
 * - DATA: Shifts in the data bits
 * - STOP: Validates the stop bit and sets the output signals
 *
 * Internal signals include:
 * - `baud_clear`: Clears the baud rate pulse generator
 * - `baud_pulse_out`: Pulse output from the baud rate pulse generator
 * - `bit_counter`: Counts the number of received data bits
 * - `shift_reg`: Shift register for received data bits
 * - `sync_rx`: Synchronized `rx` signal
 * - `sync_data_out_read`: Synchronized `data_out_read` signal
 *
 * The module instantiates a pulse generator for the baud rate clock and synchronizers for the `rx` and `data_out_read`
 * signals.
 */
module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic data_out_read,

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
    logic baud_clear;
    logic baud_pulse_out;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic sync_rx;
    logic sync_data_out_read;

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

    // Instantiate a synchronizer for rx
    synchronizer sync_rx_inst (
        .clk(clk),
        .resetn(resetn),
        .async_signal(rx),
        .sync_signal(sync_rx)
    );

    // Instantiate a synchronizer for data_out_read
    synchronizer sync_data_out_read_inst (
        .clk(clk),
        .resetn(resetn),
        .async_signal(data_out_read),
        .sync_signal(sync_data_out_read)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= IDLE;
        end else if (!sync_data_out_read) begin  // Only update state when data_out is not being read
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                // Start bit detected and any previous data has been read
                if (sync_rx == 0 && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (baud_pulse_out) begin
                    // Check for a valid start bit at the given baud rate
                    if (sync_rx == 0) begin
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
            data_out_ready <= 0;
            data_error <= 0;
        end else begin
            if (sync_data_out_read) begin
                data_out <= 0;
                data_out_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
                IDLE: begin
                    baud_clear <= 1;
                    if (sync_rx == 0 && data_out_ready) begin
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
                        shift_reg   <= {sync_rx, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                STOP: begin
                    if (sync_rx == 1) begin
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
