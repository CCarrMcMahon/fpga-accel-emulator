module synchronizer (
    input  logic clk,
    input  logic resetn,
    input  logic async_signal,
    output logic sync_signal
);
    logic stage1, stage2;

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            stage1 <= 1'b0;
            stage2 <= 1'b0;
        end else begin
            stage1 <= async_signal;
            stage2 <= stage1;
        end
    end

    assign sync_signal = stage2;
endmodule
