/**
 * @module spi_master
 * @brief SPI Master Module
 *
 * This module implements an SPI master that communicates with an SPI slave device. It supports a configurable clock
 * frequency and data transfer rate.
 *
 * @param ClkFreq  The frequency of the input clock in Hz (default: 100 MHz).
 * @param SclkFreq The desired SPI clock frequency in Hz (default: 1 MHz).
 *
 * @input clk          The system clock input.
 * @input resetn       Active-low reset signal.
 * @input start        Signal to start the SPI transfer.
 * @input data_in      The byte of data to be transmitted.
 * @input miso         Master In Slave Out data signal.
 * @input data_out_ack Acknowledgment signal indicating that the data has been read.
 *
 * @output data_out    The received byte of data.
 * @output mosi        Master Out Slave In data signal.
 * @output sclk        SPI clock signal.
 * @output csn         Chip select signal (active low).
 * @output data_in_ack Acknowledgment signal indicating that the data has been stored.
 * @output valid       Indicates that a new byte of data is available.
 * @output error       Indicates an error in the SPI transfer.
 *
 * The module uses a state machine to manage the SPI communication process. The states include:
 * - RESET: Initializes the internal signals and prepares the module for operation.
 * - IDLE: Waits for a start signal to begin the SPI transfer.
 * - START: Prepares for data transfer by asserting the chip select signal and initializing the shift register.
 * - TRANSFER: Handles the actual data transfer, shifting data into and out of the shift register with the SPI clock.
 * - DONE: Indicates that the data transfer is complete and prepares to output the received data.
 * - TRANSFER_OUT_ACKED: Clears the output data and status signals after the data has been acknowledged.
 * - ERROR: Handles any errors that occur during the SPI transfer.
 *
 * The module also includes internal logic for synchronizing the `start` and `data_out_ack` signals, sand a clock
 * generator for generating the SPI clock.
 */
module spi_master #(
    parameter int ClkFreq  = 100_000_000,
    parameter int SclkFreq = 1_000_000
) (
    // Control Signals
    input logic clk,
    input logic resetn,
    input logic start,

    // Data Input Signals
    input logic [7:0] data_in,
    input logic data_out_ack,

    // SPI Interface Signals
    input  logic miso,
    output logic mosi,
    output logic sclk,
    output logic csn,

    // Data Output Signals
    output logic [7:0] data_out,
    output logic data_in_ack,

    // Status Signals
    output logic valid,
    output logic error
);
    // States
    typedef enum logic [2:0] {
        RESET,
        IDLE,
        START,
        TRANSFER,
        DONE,
        TRANSFER_OUT_ACKED,
        ERROR
    } state_t;
    state_t state, next_state;

    // Internal Signals
    logic clear_sclk_gen;
    logic start_synced;
    logic data_out_ack_synced;
    logic [3:0] data_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;

    // Instantiate a clock generator for the SPI clock
    clock_generator #(
        .ClkInFreq (ClkFreq),
        .ClkOutFreq(SclkFreq)
    ) sclk_gen (
        .clk_in (clk),
        .resetn (resetn),
        .clear  (clear_sclk_gen),
        .clk_out(sclk)
    );

    // Instantiate a synchronizer for the start signal
    synchronizer start_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(start),
        .sync_signal(start_synced)
    );

    // Instantiate a synchronizer for data_out_ack
    synchronizer data_out_ack_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(data_out_ack),
        .sync_signal(data_out_ack_synced)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= RESET;
        end else begin
            state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = state;
        case (state)
            RESET: begin
                next_state = IDLE;
            end
            IDLE: begin
                if (start_synced) begin
                    // Previous data has been processed
                    if (!valid) begin
                        next_state = START;
                    end else begin
                        next_state = ERROR;
                    end
                end else if (data_out_ack_synced) begin  // Give processing priority
                    next_state = TRANSFER_OUT_ACKED;
                end
            end
            START: begin
                next_state = TRANSFER;
            end
            TRANSFER: begin
                if (data_counter == 8) begin
                    next_state = DONE;
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            TRANSFER_OUT_ACKED: begin
                next_state = IDLE;
            end
            ERROR: begin
                next_state = IDLE;
            end
            default: next_state = ERROR;
        endcase
    end

    // SPI Master Logic
    always_ff @(posedge clk) begin
        case (state)
            RESET: begin
                mosi <= 0;
                csn <= 1;
                data_out <= 0;
                data_in_ack <= 0;
                valid <= 0;
                error <= 0;
                clear_sclk_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
                prev_sclk <= 0;
            end
            IDLE: begin
                mosi <= 0;
                csn <= 1;
                data_in_ack <= 0;
                clear_sclk_gen <= 1;
                data_counter <= 0;
                shift_reg <= 0;
                prev_sclk <= 0;
            end
            START: begin
                // Enable clock and chip
                csn <= 0;
                clear_sclk_gen <= 0;

                // Set inverse so first bit is sent immediately
                prev_sclk <= ~sclk;

                // Store input data and ack that is has been read
                shift_reg <= data_in;
                data_in_ack <= 1;
            end
            TRANSFER: begin
                // Clear signal now that it has been read
                data_in_ack <= 0;

                // Wait for clock transition (first bit should be sent immediately)
                if (sclk != prev_sclk) begin
                    prev_sclk <= sclk;

                    if (sclk) begin
                        // Shift miso into LSB when clk transitions from low to high
                        shift_reg <= {shift_reg[6:0], miso};
                        data_counter <= data_counter + 1;
                    end else begin
                        // Output MSB of mosi when clk transitions from high to low
                        mosi <= shift_reg[7];
                    end
                end
            end
            DONE: begin
                // Output received data and indicate it is ready
                data_out <= shift_reg;
                valid <= 1;
            end
            TRANSFER_OUT_ACKED: begin
                // Clear data_out and reset status signals
                data_out <= 0;
                valid <= 0;
                error <= 0;
            end
            ERROR: begin
                error <= 1;
            end
            default: error <= 1;
        endcase
    end
endmodule
