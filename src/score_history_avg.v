`timescale 1ns/1ps

module score_history_avg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        push_valid,
    input  wire [12:0] push_time_ms,

    output wire        avg_valid,
    output wire [12:0] avg_time_ms
);

    reg [12:0] h0;
    reg [12:0] h1;
    reg [12:0] h2;
    reg [1:0]  count;

    reg [14:0] sum;
    reg [14:0] round_sum;
    reg [12:0] avg_calc;

    assign avg_valid = (count != 2'd0);
    assign avg_time_ms = avg_calc;

    always @(*) begin
        sum = h0 + h1 + h2;
        avg_calc = 13'd0;
        round_sum = 15'd0;

        case (count)
            2'd0: avg_calc = 13'd0;
            2'd1: avg_calc = h0;
            2'd2: begin
                round_sum = h0 + h1 + 15'd1;
                avg_calc = round_sum[14:1];
            end
            2'd3: begin
                round_sum = sum + 15'd1;
                avg_calc = round_sum / 15'd3;
            end
            default: avg_calc = 13'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0 <= 13'd0;
            h1 <= 13'd0;
            h2 <= 13'd0;
            count <= 2'd0;
        end else if (push_valid) begin
            // Keep strict recency ordering: h0 newest, h2 oldest.
            h2 <= h1;
            h1 <= h0;
            h0 <= push_time_ms;

            if (count < 2'd3) begin
                count <= count + 2'd1;
            end
        end
    end
endmodule
