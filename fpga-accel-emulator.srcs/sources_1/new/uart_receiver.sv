module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,  // Default clock frequency: 100 MHz
    parameter int BaudRate = 9600          // Default baud rate: 9600
) (
    input logic clk,
    input logic reset,
    input logic rx,
    output logic [7:0] data_out,
    output logic data_ready
);
    /* Constants */
    localparam int BaudRateCounterMax = ClkFreq / BaudRate;
    localparam int BaudRateCounterBits = $clog2(BaudRateCounterMax + 1);

    /* State Machine States */
    typedef enum logic {
        BAUD_DISABLED,
        BAUD_ENABLED
    } baud_state_t;

    typedef enum logic [2:0] {
        UART_IDLE,
        UART_START,
        UART_DATA,
        UART_STOP,
        UART_DONE
    } uart_state_t;

    /* Signals */
    logic [BaudRateCounterBits-1:0] baud_rate_counter;
    baud_state_t baud_state;
    uart_state_t uart_state, uart_next_state;
    logic [2:0] data_bit_counter;


    // Baud Rate Generator
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_rate_counter <= 0;
        end else begin
            case (baud_state)
                BAUD_DISABLED: begin
                    baud_rate_counter <= 0;
                end
                BAUD_ENABLED: begin
                    if (baud_rate_counter < BaudRateCounterMax) begin
                        baud_rate_counter <= baud_rate_counter + 1;
                    end
                end
                default baud_rate_counter <= 0;
            endcase
        end
    end

    // UART Receiver Logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_state <= BAUD_DISABLED;
            uart_state <= UART_IDLE;
            uart_next_state <= UART_IDLE;
            data_bit_counter <= 0;
            data_out <= 0;
            data_ready <= 0;
        end else begin
            uart_state <= uart_next_state;
            case (uart_state)
                UART_IDLE: begin
                    if (rx == 0) begin  // Start bit detected (rx pulled low)
                        data_ready <= 0;
                        baud_state <= BAUD_ENABLED;
                        uart_next_state <= UART_START;
                    end else begin
                        baud_state <= BAUD_DISABLED;
                        uart_next_state <= UART_IDLE;
                    end
                end
                UART_START: begin
                    if (baud_rate_counter == BaudRateCounterMax / 2) begin
                        if (rx == 0) begin
                            data_bit_counter <= 0;
                            uart_next_state  <= UART_DATA;
                        end else begin
                            uart_next_state <= UART_IDLE;
                        end
                    end else begin
                        uart_next_state <= UART_START;
                    end
                end
                UART_DATA: begin
                    if (baud_rate_counter == BaudRateCounterMax) begin
                        data_out[data_bit_counter] <= rx;
                        if (data_bit_counter == 7) begin
                            uart_next_state <= UART_STOP;
                        end else begin
                            data_bit_counter <= data_bit_counter + 1;
                        end
                    end else begin
                        uart_next_state <= UART_DATA;
                    end
                end
                UART_STOP: begin
                    if (baud_rate_counter == BaudRateCounterMax) begin
                        if (rx == 1) begin  // Stop bit detected (rx pulled high)
                            uart_next_state <= UART_DONE;
                        end else begin
                            uart_next_state <= UART_IDLE;
                        end
                    end else begin
                        uart_next_state <= UART_STOP;
                    end
                end
                UART_DONE: begin
                    data_ready <= 1;
                    uart_next_state <= UART_IDLE;
                end
                default: uart_state <= UART_IDLE;
            endcase
        end
    end
endmodule
