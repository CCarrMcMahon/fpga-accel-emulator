`timescale 1ns / 1ps
/**
 * @module fpga_accel_emulator
 * @brief FPGA Accelerator Emulator Top-Level Module
 *
 * This module serves as the top-level module for an FPGA-based accelerometer emulator. It integrates UART and SPI
 * communication interfaces and provides control and status signals for external connections.
 *
 * @input clk100mhz   The 100 MHz system clock input.
 * @input cpu_resetn  Active-low reset signal for the CPU.
 * @input uart_txd_in UART transmit data input.
 * @input btnc        Button input for additional control.
 *
 * @output ja  General-purpose output signals (8 bits).
 * @output jb  General-purpose output signals (6 bits).
 * @output led Status LEDs (16 bits).
 *
 * The module instantiates the following submodules:
 * - `uart_receiver`: Receives data from the UART interface.
 * - `spi_master`: Acts as an SPI master to communicate with SPI slave devices.
 * - `spi_slave`: Acts as an SPI slave to communicate with an SPI master device.
 *
 * The module also includes logic to handle data transfer between the SPI master and SPI slave, and to update the status
 * signals for external monitoring.
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
    logic spi_master_data_out_ack;
    logic [7:0] spi_master_data_out_reg;
    logic [7:0] spi_master_data_out;
    logic spi_master_data_out_ready;
    logic spi_master_data_in_stored;
    logic spi_master_data_error;

    // SPI slave signals
    logic spi_slave_data_out_ack;
    logic [7:0] spi_slave_data_out_reg;
    logic [7:0] spi_slave_data_out;
    logic spi_slave_data_out_ready;
    logic spi_slave_data_in_stored;
    logic spi_slave_data_error;

    // Instantiate the uart_receiver module
    uart_receiver #(
        .ClkFreq (100_000_000),
        .BaudRate(9600)
    ) uart_receiver_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_out_ack(spi_master_data_in_stored),
        .rx(uart_txd_in),
        .data_out(uart_data_out),
        .data_out_ready(uart_data_out_ready),
        .data_error(uart_data_error)
    );

    // Instantiate the spi_master module
    spi_master #(
        .ClkFreq (100_000_000),
        .SclkFreq(9600)
    ) spi_master_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .start_tx(uart_data_out_ready),
        .data_out_ack(spi_master_data_out_ack),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .csn(csn),
        .data_in(uart_data_out),
        .data_out(spi_master_data_out),
        .data_out_ready(spi_master_data_out_ready),
        .data_in_stored(spi_master_data_in_stored),
        .data_error(spi_master_data_error)
    );

    // Instantiate the spi_slave module
    spi_slave #(
        .ClkFreq(100_000_000)
    ) spi_slave_inst_1 (
        .clk(clk100mhz),
        .resetn(cpu_resetn),
        .data_out_ack(spi_slave_data_out_ack),
        .mosi(mosi),
        .miso(miso),
        .sclk(sclk),
        .csn(csn),
        .data_in(spi_slave_data_out_reg),
        .data_out(spi_slave_data_out),
        .data_out_ready(spi_slave_data_out_ready),
        .data_in_stored(spi_slave_data_in_stored),
        .data_error(spi_slave_data_error)
    );

    // Send received spi data back to master and clear master data
    always @(posedge clk100mhz or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            spi_master_data_out_ack <= 0;
            spi_master_data_out_reg <= 0;
            spi_slave_data_out_ack  <= 0;
            spi_slave_data_out_reg  <= 0;
        end else if (spi_master_data_out_ready) begin
            spi_master_data_out_reg <= spi_master_data_out;
            spi_master_data_out_ack <= 1;
        end else if (spi_slave_data_out_ready) begin
            spi_slave_data_out_reg <= spi_slave_data_out;
            spi_slave_data_out_ack <= 1;
        end else begin
            spi_master_data_out_ack <= 0;
            spi_slave_data_out_ack  <= 0;
        end
    end

    // Final Assignments
    assign ja = {csn, sclk, miso, mosi, btnc, uart_data_error, uart_data_out_ready, uart_txd_in};
    assign jb = {
        spi_slave_data_error,
        spi_slave_data_in_stored,
        spi_slave_data_out_ready,
        spi_master_data_error,
        spi_master_data_in_stored,
        spi_master_data_out_ready
    };
    assign led = {spi_master_data_out_reg, spi_slave_data_out_reg};
endmodule
