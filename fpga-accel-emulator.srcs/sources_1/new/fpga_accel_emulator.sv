`timescale 1ns / 1ps
module fpga_accel_emulator (
    input logic clk100mhz,
    input logic cpu_resetn,
    input logic uart_txd_in,
    output logic [8:0] led,
    output logic [3:0] ja,
    output logic [7:0] jb
);
    logic [7:0] data_out;
    logic data_ready;

    logic debug_baud_pulse_out;
    logic [1:0] debug_uart_state;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst (
        .clk(clk100mhz),
        .reset(~cpu_resetn),
        .rx(uart_txd_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .debug_baud_pulse_out(debug_baud_pulse_out),
        .debug_uart_state(debug_uart_state)
    );

    assign ja = {debug_uart_state, debug_baud_pulse_out, uart_txd_in};
    assign jb = data_out;

    always_ff @(posedge clk100mhz or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            led <= 9'b0;
        end else begin
            led <= {data_ready, data_out};
        end
    end
endmodule