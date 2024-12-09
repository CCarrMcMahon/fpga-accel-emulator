/**
 * @module spi_slave
 * @param ClkFreq  Clock frequency in Hz (default: 100,000,000)
 *
 * @input clk            System clock signal
 * @input resetn         Active-low reset signal
 * @input data_out_read  Signal indicating that data_out has been read
 * @input mosi           Master Out Slave In signal
 * @input sclk           SPI serial clock signal from master
 * @input csn            Chip select signal from master (active low)
 * @input [7:0] data_in  8-bit data input
 *
 * @output miso            Master In Slave Out signal
 * @output [7:0] data_out  8-bit data output
 * @output data_out_ready  Signal indicating data_out is ready to be read
 * @output read_data_in    Signal indicating that we read data_in
 * @output data_error      Signal indicating an error in data transmission
 *
 * This module implements a basic SPI slave with the following features:
 * - Receives data from the SPI master and outputs it
 * - Sends data to the SPI master
 * - Uses a state machine to manage the SPI reception and transmission process
 */
module spi_slave #(
    parameter int ClkFreq = 100_000_000  // Input clock frequency in Hz
) (
    // Clock and Reset
    input logic clk,
    input logic resetn,

    // Control Signals
    input logic data_out_read,

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
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;
    logic prev_sclk;
    logic sync_data_out_read;

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
                // Request to start receiving and previous data has been read
                if (!csn && !data_out_ready) begin
                    next_state = START;
                end
            end
            START: begin
                next_state = DATA;
            end
            DATA: begin
                if (prev_sclk == !sclk && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                next_state = IDLE;
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
                    read_data_in <= 1;
                end
                DATA: begin
                    // Clear ack now that it has been read
                    read_data_in <= 0;

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
