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
    output logic [1:0] led,
    output logic [1:0] ja
);
    // UART signals
    logic [7:0] rx_data_out;
    logic tx_to_rx_data_ack;
    logic rx_data_out_ready;
    logic uart_data_error;
    logic uart_busy;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_out_ack(tx_to_rx_data_ack),
        .rx(uart_txd_in),
        .data_out(rx_data_out),
        .data_out_ready(rx_data_out_ready),
        .data_error(uart_data_error)
    );

    uart_transmitter #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_transmitter_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start(rx_data_out_ready),
        .data_in(rx_data_out),
        .data_in_ack(tx_to_rx_data_ack),
        .busy(uart_busy),
        .tx(uart_rxd_out)
    );

    assign led = {uart_busy, uart_data_error};
    assign ja  = {uart_rxd_out, uart_txd_in};
endmodule
