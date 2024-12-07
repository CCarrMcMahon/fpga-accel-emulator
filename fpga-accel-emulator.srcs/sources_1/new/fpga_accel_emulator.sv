`timescale 1ns / 1ps
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    output logic [0:0] ja,
    output logic [7:0] led
);
    logic data_ready;
    logic [7:0] data_out;

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

    assign ja[0]  = data_ready;
    assign led = data_out;
endmodule
