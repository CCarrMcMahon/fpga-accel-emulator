`timescale 1ns / 1ps
/**
 * @module fpga_accel_emulator
 *
 * @input clk100mhz    100 MHz system clock signal
 * @input cpu_resetn   Active-low reset signal
 * @input uart_txd_in  UART transmit data input
 * @input btnc         Button input for data read
 *
 * @output [7:0] ja    General-purpose output signals
 * @output [5:0] jb    General-purpose output signals
 * @output [15:0] led  LED output signals
 *
 * This top-level module is a work in progress which currently integrates a UART receiver and an SPI master to test
 * transforming incoming UART data to SPI data. It includes:
 * - Instantiation of the `uart_receiver` module for UART communication
 * - Instantiation of the `spi_master` module for SPI communication
 * - Instantiation of the `spi_slave` module for SPI communication
 * - Final assignments to output signals for debugging and status indication
 *
 * Internal signals include:
 * - UART signals: `uart_data_out`, `uart_data_out_ready`, `uart_data_error`
 * - SPI signals: `mosi`, `miso`, `sclk`, `csn`
 * - SPI master signals: `spi_master_data_out_read`, `spi_master_data_out_reg`, `spi_master_data_out`,
 *   `spi_master_data_out_ready`, `spi_master_read_data_in`, `spi_master_data_error`
 * - SPI slave signals: `spi_slave_data_out_read`, `spi_slave_data_out_reg`, `spi_slave_data_out`,
 *   `spi_slave_data_out_ready`, `spi_slave_read_data_in`, `spi_slave_data_error`
 *
 * The module connects the UART receiver output to the SPI master input, which then passes the data along to the SPI
 * slave where it saves the data and passes it back to the master. The output of both SPI modules are displayed on the
 * LEDs.
 */
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    input logic btnc,
    output logic [7:0] ja,
    output logic [5:0] jb,
    output logic [15:0] led
);
    // UART signals
    logic [7:0] uart_data_out;
    logic uart_data_out_ready;
    logic uart_data_error;

    // SPI signals
    logic mosi;
    logic miso;
    logic sclk;
    logic csn;

    // SPI master signals
    logic spi_master_data_out_read;
    logic [7:0] spi_master_data_out_reg;
    logic [7:0] spi_master_data_out;
    logic spi_master_data_out_ready;
    logic spi_master_read_data_in;
    logic spi_master_data_error;

    // SPI slave signals
    logic spi_slave_data_out_read;
    logic [7:0] spi_slave_data_out_reg;
    logic [7:0] spi_slave_data_out;
    logic spi_slave_data_out_ready;
    logic spi_slave_read_data_in;
    logic spi_slave_data_error;


    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_out_read(spi_master_read_data_in),
        .rx(uart_txd_in),
        .data_out(uart_data_out),
        .data_out_ready(uart_data_out_ready),
        .data_error(uart_data_error)
    );

    // Instantiate the spi_master module
    spi_master #(
        .ClkFreq (100_000_000),
        .SclkFreq(9600)
    ) spi_master_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start_tx(uart_data_out_ready),
        .data_out_read(spi_master_data_out_read),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .csn(csn),
        .data_in(uart_data_out),
        .data_out(spi_master_data_out),
        .data_out_ready(spi_master_data_out_ready),
        .read_data_in(spi_master_read_data_in),
        .data_error(spi_master_data_error)
    );

    // Instantiate the spi_slave module
    spi_slave #(
        .ClkFreq(100_000_000)
    ) spi_slave_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_out_read(spi_slave_data_out_read),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .csn(csn),
        .data_in(spi_slave_data_out_reg),
        .data_out(spi_slave_data_out),
        .data_out_ready(spi_slave_data_out_ready),
        .read_data_in(spi_slave_read_data_in),
        .data_error(spi_slave_data_error)
    );

    // Send received spi data back to master and clear master data
    always @(posedge clk100mhz or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            spi_master_data_out_read <= 0;
            spi_master_data_out_reg  <= 0;
            spi_slave_data_out_read  <= 0;
            spi_slave_data_out_reg   <= 0;
        end else if (spi_master_data_out_ready) begin
            spi_master_data_out_reg  <= spi_master_data_out;
            spi_master_data_out_read <= 1;
        end else if (spi_slave_data_out_ready) begin
            spi_slave_data_out_reg  <= spi_slave_data_out;
            spi_slave_data_out_read <= 1;
        end else begin
            spi_master_data_out_read <= 0;
            spi_slave_data_out_read  <= 0;
        end
    end

    // Final Assignments
    assign ja = {csn, sclk, miso, mosi, btnc, uart_data_error, uart_data_out_ready, uart_txd_in};
    assign jb = {
        spi_slave_data_error,
        spi_slave_read_data_in,
        spi_slave_data_out_ready,
        spi_master_data_error,
        spi_master_read_data_in,
        spi_master_data_out_ready
    };
    assign led = {spi_master_data_out_reg, spi_slave_data_out_reg};
endmodule
