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
    output logic [2:0] ja,
    output logic [7:0] led
);
    // Internal Signals
    logic [7:0] data_out;
    logic data_ready;
    logic data_error;
    logic debug_baud_pulse_out;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .rx(uart_txd_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .data_read(btnc),
        .data_error(data_error),
    );

    // Final Assignments
    assign ja  = {data_error, data_ready, uart_txd_in};
    assign led = data_out;
endmodule
