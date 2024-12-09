/**
 * @module spi_slave
 * @brief SPI Slave Module
 *
 * This module implements a SPI slave that communicates with a SPI master device. It receives data from the `mosi` input
 * and transmits data on the `miso` output, outputting the received byte on `data_out`. The module operates at a
 * configurable system clock frequency.
 *
 * @param ClkFreq The frequency of the input clock in Hz (default: 100 MHz).
 *
 * @input clk          The system clock input.
 * @input resetn       Active-low reset signal.
 * @input data_out_ack Acknowledgment signal indicating that the data has been read.
 * @input mosi         SPI Master Out Slave In data input.
 * @input sclk         SPI serial clock input.
 * @input csn          Chip select (active low) input.
 * @input data_in      The byte of data to be transmitted.
 *
 * @output miso           SPI Master In Slave Out data output.
 * @output data_out       The received byte of data.
 * @output data_out_ready Indicates that a new byte of data is available.
 * @output data_in_stored Indicates that the input data has been stored for transmission.
 * @output data_error     Indicates an error in the data transmission or reception.
 *
 * The module uses a state machine to manage the reception and transmission process, which includes the following states:
 * - IDLE: Waiting for the chip select signal.
 * - START: Preparing for data reception.
 * - DATA: Receiving and transmitting data bits.
 * - STOP: Finalizing the reception and outputting the received byte.
 *
 * The module also includes internal logic for synchronizing the `data_out_ack` signal.
 */
module spi_slave #(
    parameter int ClkFreq = 100_000_000  // Input clock frequency in Hz
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic data_out_ack,

    // SPI Interface
    input  logic mosi,
    output logic miso,
    input  logic sclk,
    input  logic csn,

    // Data Signals
    input  logic [7:0] data_in,
    output logic [7:0] data_out,

    // Status Signals
    output logic data_out_ready,
    output logic data_in_stored,
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
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;
    logic synced_data_out_ack;

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
                // Request to start receiving and previous data has been read
                if (!csn && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (data_in_stored) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if (prev_sclk == !sclk && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                // Return to idle once csn is released
                // NOTE: Will have to be adjusted if multi-byte transfer is implemented
                if (csn) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // SPI Slave Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            bit_counter <= 0;
            shift_reg <= 0;
            prev_sclk <= 1;
            miso <= 0;
            data_out <= 0;
            data_out_ready <= 0;
            data_in_stored <= 0;
            data_error <= 0;
        end else begin
            if (synced_data_out_ack) begin
                data_out <= 0;
                data_out_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
                IDLE: begin
                    prev_sclk <= 1;
                    miso <= 0;
                    if (!csn && data_out_ready) begin
                        // Chip enabled but previous data hasn't been read
                        data_error <= 1;
                    end
                end
                START: begin
                    prev_sclk <= ~sclk;  //  Set inverse so first bit is sent immediately
                    bit_counter <= 0;

                    // Store input data and ack that is has been read
                    shift_reg <= data_in;
                    data_in_stored <= 1;
                end
                DATA: begin
                    // Clear signal now that it has been read
                    data_in_stored <= 0;

                    // Wait for clock transition (first bit should be sent immediately)
                    if (sclk != prev_sclk && bit_counter < 8) begin
                        prev_sclk <= sclk;

                        if (sclk) begin
                            // Shift mosi into LSB when clk transitions from low to high
                            shift_reg   <= {shift_reg[6:0], mosi};
                            bit_counter <= bit_counter + 1;
                        end else begin
                            // Output MSB of miso when clk transitions from high to low
                            miso <= shift_reg[7];
                        end
                    end
                end
                STOP: begin
                    // Output received data and indicate it is ready
                    data_out <= shift_reg;
                    data_out_ready <= 1;
                end
                default: data_error <= 1;
            endcase
        end
    end
endmodule
