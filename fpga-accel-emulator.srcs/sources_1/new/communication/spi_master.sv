/**
 * @module spi_master
 * @param ClkFreq   Clock frequency in Hz (default: 100,000,000)
 * @param SclkFreq  SPI serial clock frequency in Hz (default: 1,000,000)
 *
 * @input clk            System clock signal
 * @input resetn         Active-low reset signal
 * @input start_tx       Signal to start SPI transmission
 * @input data_out_read  Signal indicating that data_out has been read
 * @input miso           Master In Slave Out signal
 * @input [7:0] data_in  8-bit data input
 *
 * @output mosi            Master Out Slave In signal
 * @output sclk            SPI serial clock signal
 * @output csn             Chip select signal (active low)
 * @output [7:0] data_out  8-bit data output
 * @output data_out_ready  Signal indicating data_out is ready to be read
 * @output read_data_in    Signal indicating that we read data_in
 * @output data_error      Signal indicating an error in data transmission
 *
 * This module implements a SPI master with the following features:
 * - Synchronizes the `data_out_read` and `start_tx` signals to the system clock
 * - Uses a state machine to manage the SPI transmission process
 * - Generates the SPI clock signal according to the specified frequency
 * - Handles the SPI protocol including chip select, data shifting, and clocking
 * - Outputs received data and status signals
 *
 * The state machine has four states:
 * - IDLE: Waits for a start transmission signal
 * - START: Prepares for data transmission
 * - DATA: Shifts data bits in and out
 * - STOP: Finalizes the transmission and sets the output signals
 *
 * Internal signals include:
 * - `sclk_clear`: Clears the SPI clock generator
 * - `bit_counter`: Counts the number of transmitted/received data bits
 * - `shift_reg`: Shift register for data bits
 * - `prev_sclk`: Previous state of the SPI clock signal
 * - `sync_data_out_read`: Synchronized `data_out_read` signal
 * - `sync_start_tx`: Synchronized `start_tx` signal
 *
 * The module instantiates a clock generator for the SPI clock and synchronizers for the `data_out_read` and `start_tx`
 * signals.
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
    input logic data_out_read,

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
    output logic read_data_in,
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
    logic sclk_clear;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;
    logic sync_start_tx;
    logic sync_data_out_read;

    // Instantiate a clock generator for the SPI clock
    clock_generator #(
        .ClkInFreq (ClkFreq),
        .ClkOutFreq(SclkFreq)
    ) sclk_freq_clock_gen (
        .clk_in (clk),
        .resetn (resetn),
        .clear  (sclk_clear),
        .clk_out(sclk)
    );

    // Instantiate a synchronizer for start_tx
    synchronizer sync_start_tx_inst (
        .clk(clk),
        .resetn(resetn),
        .async_signal(start_tx),
        .sync_signal(sync_start_tx)
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
                // Start transmission requested and previous data has been read
                if (sync_start_tx && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                if (read_data_in) begin
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
            sclk_clear <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            prev_sclk <= 1;
            mosi <= 0;
            csn <= 1;
            data_out <= 0;
            data_out_ready <= 0;
            read_data_in <= 0;
            data_error <= 0;
        end else begin
            if (sync_data_out_read) begin
                data_out <= 0;
                data_out_ready <= 0;
                data_error <= 0;
            end

            case (current_state)
                IDLE: begin
                    // Keep the clock and chip disabled while idle
                    sclk_clear <= 1;
                    prev_sclk <= 1;
                    mosi <= 0;
                    csn <= 1;
                    if (sync_start_tx && data_out_ready) begin
                        // New data detected but previous data hasn't been read
                        data_error <= 1;
                    end
                end
                START: begin
                    // Enable clock and chip
                    sclk_clear <= 0;
                    prev_sclk <= ~sclk;  // Set inverse so first bit is sent immediately
                    bit_counter <= 0;
                    csn <= 0;

                    // Store input data and ack that is has been read
                    shift_reg <= data_in;
                    read_data_in <= 1;
                end
                DATA: begin
                    // Clear signal now that it has been read
                    read_data_in <= 0;

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
