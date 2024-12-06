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
    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        STOP,
        DONE
    } state_t;

    /* Signals */
    logic [BaudRateCounterBits-1:0] baud_rate_counter;
    logic [2:0] data_bit_counter;
    logic enable_baud_rate_counter;
    state_t state, next_state;

    // Baud Rate Generator
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            baud_rate_counter <= 0;
        end else if (enable_baud_rate_counter && baud_rate_counter < BaudRateCounterMax) begin
            baud_rate_counter <= baud_rate_counter + 1;
        end else begin
            baud_rate_counter <= 0;
        end
    end

    // State Machine
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (rx == 0) begin  // Start bit detected (rx pulled low)
                    enable_baud_rate_counter = 1;
                    data_ready = 0;
                    next_state = START;
                end else begin
                    enable_baud_rate_counter = 0;
                end
            end
            START: begin
                if (baud_rate_counter == BaudRateCounterMax / 2) begin
                    next_state = DATA;
                    data_bit_counter = 0;
                end
            end
            DATA: begin
                if (baud_rate_counter == BaudRateCounterMax) begin
                    data_out[data_bit_counter] = rx;
                    if (data_bit_counter == 7) begin
                        next_state = STOP;
                    end else begin
                        data_bit_counter = data_bit_counter + 1;
                    end
                end
            end
            STOP: begin
                if (baud_rate_counter == BaudRateCounterMax) begin
                    if (rx == 1) begin  // Stop bit detected
                        next_state = DONE;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DONE: begin
                data_ready = 1;
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule
