module uart_transmitter #(
    parameter int ClkFreq  = 100_000_000,
    parameter int BaudRate = 9600
) (
    input logic clk,
    input logic resetn,
    input logic start,
    input logic [7:0] data_in,
    output logic data_in_ack,
    output logic busy,
    output logic tx
);
    // States
    typedef enum logic [2:0] {
        IDLE,
        LOAD_DATA,
        START_BIT,
        DATA_BITS,
        STOP_BITS
    } state_t;
    state_t current_state, next_state;

    // Internal signals
    logic clear_baud_gen;
    logic baud_pulse;
    logic synced_start;
    logic [3:0] data_counter;
    logic [7:0] shift_reg;

    // Instantiate a pulse generator for the baud rate clock
    pulse_generator #(
        .ClkInFreq(ClkFreq),
        .PulseOutFreq(BaudRate),
        .PhaseShift(0.5)
    ) baud_gen (
        .clk_in(clk),
        .resetn(resetn),
        .clear(clear_baud_gen),
        .pulse_out(baud_pulse)
    );

    // Instantiate a synchronizer for the start signal
    synchronizer start_sync (
        .clk(clk),
        .resetn(resetn),
        .async_signal(start),
        .sync_signal(synced_start)
    );

    // State Machine Transitions
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // State Machine Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (synced_start) begin
                    next_state = LOAD_DATA;
                end
            end
            LOAD_DATA: begin
                next_state = START_BIT;
            end
            START_BIT: begin
                if (baud_pulse) begin
                    next_state = DATA_BITS;
                end
            end
            DATA_BITS: begin
                if (baud_pulse && data_counter == 8) begin
                    next_state = STOP_BITS;
                end
            end
            STOP_BITS: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // UART Transmitter Logic
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            data_in_ack <= 0;
            busy <= 0;
            tx <= 1;
            clear_baud_gen <= 1;
            data_counter <= 0;
            shift_reg <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    // Set default state of signals
                    data_in_ack <= 0;
                    busy <= 0;
                    tx <= 1;
                    clear_baud_gen <= 1;
                    data_counter <= 0;
                    shift_reg <= 0;
                end
                LOAD_DATA: begin
                    // Store data in the shift register to avoid it changing
                    shift_reg <= data_in;

                    // Indicate status and start the baud clock
                    data_in_ack <= 1;
                    busy <= 1;
                    clear_baud_gen <= 0;
                end
                START_BIT: begin
                    // Clear data_in_ack since we have stored the data
                    data_in_ack <= 0;
                    if (baud_pulse) begin
                        tx <= 0;  // Start bit
                    end
                end
                DATA_BITS: begin
                    if (baud_pulse && data_counter < 8) begin
                        tx <= shift_reg[0];  // Transmit LSB
                        shift_reg <= {1'b0, shift_reg[7:1]};  // Shift out LSB (right shift)
                        data_counter <= data_counter + 1;
                    end
                end
                STOP_BITS: begin
                    tx <= 1;  // Stop bit
                end
                default: tx <= 1;
            endcase
        end
    end
endmodule
