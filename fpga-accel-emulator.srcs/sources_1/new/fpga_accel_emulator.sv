`timescale 1ns / 1ps
/**
 * FPGA Accelerator Emulator.
 *
 * This module is a work in progress which currently receives data through a UART interface and displays the received
 * data on LEDs. It uses a `uart_receiver` module to handle the UART communication.
 *
 * Inputs:
 *     clk100mhz (logic): 100 MHz input clock signal.
 *     cpu_resetn (logic): Active-low reset signal.
 *     uart_txd_in (logic): UART transmit data input.
 *     btnc (logic): A button used to indicate data has been read.
 *
 * Outputs:
 *     ja (logic [2:0]): Output signal indicating data state.
 *     led (logic [7:0]): Output LEDs displaying the received data.
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
    // UART
    logic [7:0] uart_data_out;
    logic uart_data_ready;
    logic uart_data_error;

    // SPI
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
