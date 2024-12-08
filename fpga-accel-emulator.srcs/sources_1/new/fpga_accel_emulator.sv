`timescale 1ns / 1ps
/**
 * @module fpga_accel_emulator
 *
 * @input clk100mhz  100 MHz system clock signal
 * @input cpu_resetn Active-low reset signal
 * @input uart_txd_in UART transmit data input
 * @input btnc       Button input for data read
 *
 * @output [7:0] ja  General-purpose output signals
 * @output [1:0] jb  General-purpose output signals
 * @output [7:0] led LED output signals
 *
 * This top-level module is a work in progress which currently integrates a UART receiver and an SPI master to test
 * transforming incoming UART data to SPI data. It includes:
 * - Instantiation of the `uart_receiver` module for UART communication
 * - Instantiation of the `spi_master` module for SPI communication
 * - Final assignments to output signals for debugging and status indication
 *
 * Internal signals include:
 * - UART signals: `uart_data_out`, `uart_data_ready`, `uart_data_error`
 * - SPI signals: `mosi`, `miso`, `sclk`, `csn`, `spi_data_out`, `spi_data_ready`, `spi_ack_data_read`, `spi_data_error`
 *
 * The module connects the UART receiver output to the SPI master input, and uses the button input to acknowledge data
 * read.
 */
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    input logic btnc,
    output logic [7:0] ja,
    output logic [1:0] jb,
    output logic [7:0] led
);
    // UART signals
    logic [7:0] uart_data_out;
    logic uart_data_ready;
    logic uart_data_error;

    // SPI signals
    logic mosi;
    logic miso = 0;
    logic sclk;
    logic csn;
    logic [7:0] spi_data_out;
    logic spi_data_ready;
    logic spi_ack_data_read;
    logic spi_data_error;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_read(spi_ack_data_read),
        .rx(uart_txd_in),
        .data_out(uart_data_out),
        .data_ready(uart_data_ready),
        .data_error(uart_data_error)
    );

    // Instantiate the spi_master module
    spi_master #(
        .ClkFreq (100_000_000),
        .SclkFreq(1_000_000)
    ) spi_master_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start_tx(uart_data_ready),
        .data_read(btnc),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .csn(csn),
        .data_in(uart_data_out),
        .data_out(spi_data_out),
        .data_ready(spi_data_ready),
        .ack_data_read(spi_ack_data_read),
        .data_error(spi_data_error)
    );

    // Final Assignments
    assign ja  = {spi_data_ready, csn, sclk, miso, mosi, spi_ack_data_read, uart_data_ready, uart_txd_in};
    assign jb  = {spi_data_error, uart_data_error};
    assign led = {spi_data_out};
endmodule
