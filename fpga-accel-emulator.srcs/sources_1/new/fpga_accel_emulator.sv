`timescale 1ns / 1ps
/**
 * FPGA accelerator emulator.
 *
 * This module is a work in progress and currently receives data through a UART interface
 * and displays the received data on LEDs. It uses a `uart_receiver` module to handle
 * the UART communication.
 *
 * ## Inputs
 * - `clk100mhz` (logic): 100 MHz input clock signal.
 * - `cpu_resetn` (logic): Active-low reset signal.
 * - `uart_txd_in` (logic): UART transmit data input.
 *
 * ## Outputs
 * - `ja` (logic [0:0]): Output signal indicating data readiness.
 * - `led` (logic [7:0]): Output LEDs displaying the received data.
 *
 * The module instantiates a `uart_receiver` to receive data at a baud rate of 9600.
 * The received data is then output to the LEDs, and a signal indicates when data is ready.
 */
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    output logic [0:0] ja,
    output logic [7:0] led
);
    /* Signals */
    logic data_ready;
    logic [7:0] data_out;
    assign ja  = data_ready;
    assign led = data_out;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst (
        .clk(clk100mhz),
        .reset(~cpu_resetn),
        .rx(uart_txd_in),
        .data_ready(data_ready),
        .data_out(data_out)
    );
endmodule
