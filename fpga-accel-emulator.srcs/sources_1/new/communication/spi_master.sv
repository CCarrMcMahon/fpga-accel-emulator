/**
 * @module spi_master
 * @brief SPI Master Module
 *
 * This module implements a SPI master that communicates with SPI slave devices. It transmits data from `data_in` to the
 * `mosi` output and receives data from the `miso` input, outputting the received byte on `data_out`. The module
 * operates at a configurable SPI clock frequency and system clock frequency.
 *
 * @param ClkFreq  The frequency of the input clock in Hz (default: 100 MHz).
 * @param SclkFreq The desired SPI serial clock frequency in Hz (default: 1 MHz).
 *
 * @input clk          The system clock input.
 * @input resetn       Active-low reset signal.
 * @input start_tx     Signal to start the SPI transmission.
 * @input data_out_ack Acknowledgment signal indicating that the data has been read.
 * @input miso         SPI Master In Slave Out data input.
 * @input data_in      The byte of data to be transmitted.
 *
 * @output mosi           SPI Master Out Slave In data output.
 * @output sclk           SPI serial clock output.
 * @output csn            Chip select (active low) output.
 * @output data_out       The received byte of data.
 * @output data_out_ready Indicates that a new byte of data is available.
 * @output data_in_stored Indicates that the input data has been stored for transmission.
 * @output data_error     Indicates an error in the data transmission or reception.
 *
 * The module uses a state machine to manage the transmission process, which includes the following states:
 * - IDLE: Waiting for the start signal.
 * - START: Preparing for data transmission.
 * - DATA: Transmitting and receiving data bits.
 * - STOP: Finalizing the transmission and outputting the received byte.
 *
 * The module also includes internal logic for synchronizing the `start_tx` and `data_out_ack` signals, and a clock
 * generator for generating the SPI clock.
 */
module spi_master #(
    parameter int ClkFreq = 100_000_000,  // Input clock frequency in Hz
    parameter int SclkFreq = 1_000_000  // SPI serial clock frequency in Hz
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic start_tx,
    input logic data_out_ack,

    // SPI Interface
    output logic mosi,
    input  logic miso,
    output logic sclk,
    output logic csn,

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
    logic clear_sclk_clock_gen;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;
    logic synced_start_tx;
    logic synced_data_out_ack;

    // Instantiate a clock generator for the SPI clock
    clock_generator #(
        .ClkInFreq (ClkFreq),
        .ClkOutFreq(SclkFreq)
    ) sclk_freq_clock_generator_inst_1 (
        .clk_in (clk),
        .resetn (resetn),
        .clear  (clear_sclk_clock_gen),
        .clk_out(sclk)
    );

    // Instantiate a synchronizer for start_tx
    synchronizer start_tx_synchronizer_inst_1 (
        .clk(clk),
        .resetn(resetn),
        .async_signal(start_tx),
        .sync_signal(synced_start_tx)
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
                // Start transmission requested and previous data has been read
                if (synced_start_tx && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (data_in_stored) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                // Wait for a clock transition from high to low after all bits have been transferred
                if (prev_sclk == !sclk && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                if (data_out_ready) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // SPI Master Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            clear_sclk_clock_gen <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            prev_sclk <= 1;
            mosi <= 0;
            csn <= 1;
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
                    // Keep the clock and chip disabled while idle
                    clear_sclk_clock_gen <= 1;
                    prev_sclk <= 1;
                    mosi <= 0;
                    csn <= 1;
                    if (synced_start_tx && data_out_ready) begin
                        // New data detected but previous data hasn't been read
                        data_error <= 1;
                    end
                end
                START: begin
                    // Enable clock and chip
                    clear_sclk_clock_gen <= 0;
                    prev_sclk <= ~sclk;  // Set inverse so first bit is sent immediately
                    bit_counter <= 0;
                    csn <= 0;

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
                    data_out <= shift_reg;
                    data_out_ready <= 1;
                end
                default: data_error <= 1;
            endcase
        end
    end
endmodule
