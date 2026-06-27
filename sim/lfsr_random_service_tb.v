`timescale 1ns/1ps

module lfsr_random_service_tb;
    localparam integer TB_WAIT_MIN_MS = 500;
    localparam integer TB_WAIT_MAX_MS = 5000;
    localparam integer REQ_PERIOD_CYCLES = 1000;

    reg clk;
    reg rst_n;
    reg req_random;
    reg [3:0] req_index;

    wire random_valid;
    wire [12:0] random_delay_ms;

    integer i;

    lfsr_random_service #(
        .WAIT_MIN_MS(TB_WAIT_MIN_MS),
        .WAIT_MAX_MS(TB_WAIT_MAX_MS),
        .LFSR_SEED(16'hACE1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_random(req_random),
        .random_valid(random_valid),
        .random_delay_ms(random_delay_ms)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        req_random = 1'b0;
        req_index = 4'd0;

        repeat (10) @(posedge clk);
        rst_n <= 1'b1;

        for (i = 0; i < 10; i = i + 1) begin
            repeat (REQ_PERIOD_CYCLES) @(posedge clk);
            @(negedge clk);
            req_random <= 1'b1;
            req_index <= i[3:0] + 4'd1;
            @(negedge clk);
            req_random <= 1'b0;
        end

        repeat (200) @(posedge clk);
        $finish;
    end
endmodule
