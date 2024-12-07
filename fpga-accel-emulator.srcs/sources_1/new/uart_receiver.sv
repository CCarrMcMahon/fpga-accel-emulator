module uart_receiver #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic rx,
    output logic [7:0] data_out,
    output logic data_ready,
    input logic data_read
);
    // States
    typedef enum logic [1:0] {
        IDLE,
        START,
        DATA,
        STOP
    } state_t;
    state_t state, next_state;

    // Internal signals
    logic baud_clear;
    logic baud_pulse_out;
    logic [3:0] bit_counter;
    logic [7:0] shift_reg;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_rate_pulse_gen (
        .clk_in(clk),
        .resetn(resetn),
        .clear(baud_clear),
        .pulse_out(baud_pulse_out)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                // Start bit detected (rx pulled low)
                if (rx == 0) begin
                    next_state = START;
                end
            end
            START: begin
                if (baud_pulse_out) begin
                    if (rx == 0) begin
                        next_state = DATA;
                    end else begin
                        next_state = IDLE;
                    end
                end
            end
            DATA: begin
                if (baud_pulse_out && bit_counter == 8) begin
                    next_state = STOP;
                end
            end
            STOP: begin
                if (baud_pulse_out) begin
                    next_state = IDLE;
                end
            end
            default: next_state = IDLE;
        endcase
    end

    // UART Receiver Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            baud_clear <= 1;
            bit_counter <= 0;
            shift_reg <= 0;
            data_out <= 0;
        end else begin
            case (state)
                IDLE: baud_clear <= 1;
                START: begin
                    baud_clear  <= 0;
                    bit_counter <= 0;
                end
                DATA: begin
                    if (baud_pulse_out && bit_counter < 8) begin
                        shift_reg   <= {rx, shift_reg[7:1]};
                        bit_counter <= bit_counter + 1;
                    end
                end
                STOP: begin
                    // Stop bit detected (rx pulled high)
                    if (baud_pulse_out && rx == 1) begin
                        data_out <= shift_reg;
                    end
                end
                default: baud_clear <= 1;
            endcase
        end
    end

    // Clear data_ready after it is read
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            data_ready <= 0;
        end else if (data_read) begin
            data_ready <= 0;
        end else begin
            case (state)
                STOP: begin
                    if (baud_pulse_out && rx == 1) begin
                        data_ready <= 1;
                    end
                end
                default: data_ready <= data_ready;
            endcase
        end
    end
endmodule
