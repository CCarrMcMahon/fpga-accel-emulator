`timescale 1ns / 1ps
/**
 * @module fpga_accel_emulator
 * @brief FPGA Accelerator Emulator Top-Level Module
 *
 * This module serves as the top-level module for an FPGA-based accelerometer emulator.
 *
 * @input clk100mhz    The 100 MHz system clock input.
 * @input cpu_resetn   Active-low reset signal for the CPU.
 * @input uart_txd_in  UART transmit data input.
 * @input uart_rxd_out UART transmit data output.
 */
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    output logic uart_rxd_out,
    output logic [7:0] ja,
    output logic [4:0] jb
);
    // UART Signals
    logic [7:0] rx_data_out;
    logic tx_to_spi_data_ack;
    logic rx_valid;
    logic rx_error;
    logic tx_busy;

    // SPI Signals
    logic mosi;
    logic miso = 0;
    logic sclk;
    logic csn;
    logic [7:0] spi_data_out;
    logic spi_to_rx_data_ack;
    logic spi_valid;
    logic spi_error;


    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .rx(uart_txd_in),
        .data_out_ack(spi_to_rx_data_ack),
        .data_out(rx_data_out),
        .valid(rx_valid),
        .error(rx_error)
    );

    spi_master #(
        .ClkFreq (100_000_000),
        .SclkFreq(9600)
    ) spi_master_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start(rx_valid),
        .data_in(rx_data_out),
        .data_out_ack(tx_to_spi_data_ack),
        .miso(miso),
        .mosi(mosi),
        .sclk(sclk),
        .csn(csn),
        .data_out(spi_data_out),
        .data_in_ack(spi_to_rx_data_ack),
        .valid(spi_valid),
        .error(spi_error)
    );

    uart_transmitter #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_transmitter_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start(spi_valid),
        .data_in(spi_data_out),
        .tx(uart_rxd_out),
        .data_in_ack(tx_to_spi_data_ack),
        .busy(tx_busy)
    );

    assign ja = {csn, sclk, miso, mosi, spi_to_rx_data_ack, rx_valid, rx_error, uart_txd_in};
    assign jb = {uart_rxd_out, tx_busy, tx_to_spi_data_ack, spi_valid, spi_error};
endmodule
