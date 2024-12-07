module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,  // Default clock frequency: 100 MHz
    parameter int BaudRate = 9600          // Default baud rate: 9600
) (
    input logic clk,
    input logic reset,
    input logic rx,
    output logic data_ready,
    output logic [7:0] data_out
);
    /* States */
    typedef enum logic [1:0] {
        UART_IDLE,
        UART_START,
        UART_DATA,
        UART_STOP
    } uart_state_t;
    uart_state_t uart_state, uart_next_state;

    /* Signals */
    logic baud_clear;
    logic baud_pulse_out;
    logic [2:0] data_bit_counter;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_rate_pulse_gen (
        .clk_in(clk),
        .reset(reset),
        .clear(baud_clear),
        .pulse_out(baud_pulse_out)
    );

    // State Machine Transitions
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_state <= UART_IDLE;
        end else begin
            uart_state <= uart_next_state;
        end
    end

    // UART Receiver Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            uart_next_state <= UART_IDLE;
            baud_clear <= 1;
            data_bit_counter <= 0;
            data_ready <= 0;
            data_out <= 0;
        end else begin
            case (uart_state)
                UART_IDLE: begin
                    baud_clear <= 1;
                    data_bit_counter <= 0;
                    data_ready <= 0;

                    // Start bit detected (rx pulled low)
                    if (rx == 0) begin
                        uart_next_state <= UART_START;
                    end
                end
                UART_START: begin
                    baud_clear <= 0;

                    if (baud_pulse_out) begin
                        if (rx == 0) begin
                            uart_next_state <= UART_DATA;
                        end else begin
                            uart_next_state <= UART_IDLE;
                        end
                    end
                end
                UART_DATA: begin
                    if (baud_pulse_out) begin
                        data_out[data_bit_counter] <= rx;

                        if (data_bit_counter < 7) begin
                            data_bit_counter <= data_bit_counter + 1;
                        end else begin
                            uart_next_state <= UART_STOP;
                        end
                    end
                end
                UART_STOP: begin
                    if (baud_pulse_out) begin
                        // Stop bit detected (rx pulled high)
                        if (rx == 1) begin
                            data_ready <= 1;
                        end
                        uart_next_state <= UART_IDLE;
                    end
                end
                default: uart_next_state <= UART_IDLE;
            endcase
        end
    end
endmodule
