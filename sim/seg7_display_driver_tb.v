`timescale 1ns/1ps

module seg7_display_driver_tb;
    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_PREPARE = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REACT   = 3'd3;
    localparam [2:0] ST_FINISH  = 3'd4;
    localparam [2:0] ST_AVG     = 3'd5;
    localparam [2:0] ST_FAIL    = 3'd6;

    reg clk;
    reg rst_n;
    reg [2:0] state;
    reg [1:0] fail_code;
    reg [12:0] reaction_time_ms;
    reg [12:0] avg_time_ms;
    reg hist_available;
    reg [3:0] state_step;

    wire seg_a;
    wire seg_b;
    wire seg_c;
    wire seg_d;
    wire seg_e;
    wire seg_f;
    wire seg_g;
    wire seg_dp;
    wire dig1;
    wire dig2;
    wire dig3;
    wire dig4;

    seg7_display_driver #(
        .CLK_HZ(400),
        .DIGIT_SCAN_HZ(25),
        .SEG_ON_LEVEL(1'b0),
        .DIG_ON_LEVEL(1'b1)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .fail_code(fail_code),
        .reaction_time_ms(reaction_time_ms),
        .avg_time_ms(avg_time_ms),
        .hist_available(hist_available),
        .seg_a(seg_a),
        .seg_b(seg_b),
        .seg_c(seg_c),
        .seg_d(seg_d),
        .seg_e(seg_e),
        .seg_f(seg_f),
        .seg_g(seg_g),
        .seg_dp(seg_dp),
        .dig1(dig1),
        .dig2(dig2),
        .dig3(dig3),
        .dig4(dig4)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        state = ST_IDLE;
        fail_code = 2'd0;
        reaction_time_ms = 13'd1234;
        avg_time_ms = 13'd567;
        hist_available = 1'b0;
        state_step = 4'd0;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        state_step = 4'd1;
        state = ST_IDLE;
        repeat (80) @(posedge clk);

        state_step = 4'd2;
        state = ST_PREPARE;
        repeat (80) @(posedge clk);

        state_step = 4'd3;
        state = ST_WAIT;
        repeat (80) @(posedge clk);

        state_step = 4'd4;
        state = ST_REACT;
        repeat (80) @(posedge clk);

        state_step = 4'd5;
        state = ST_FINISH;
        reaction_time_ms = 13'd1234;
        repeat (160) @(posedge clk);

        state_step = 4'd6;
        state = ST_FINISH;
        reaction_time_ms = 13'd89;
        repeat (160) @(posedge clk);

        state_step = 4'd7;
        state = ST_AVG;
        hist_available = 1'b0;
        repeat (160) @(posedge clk);

        state_step = 4'd8;
        state = ST_AVG;
        hist_available = 1'b1;
        avg_time_ms = 13'd567;
        repeat (160) @(posedge clk);

        state_step = 4'd9;
        state = ST_FAIL;
        fail_code = 2'd1;
        repeat (120) @(posedge clk);

        state_step = 4'd10;
        state = ST_FAIL;
        fail_code = 2'd3;
        repeat (120) @(posedge clk);

        state_step = 4'd11;
        state = ST_IDLE;
        fail_code = 2'd0;
        repeat (80) @(posedge clk);

        $finish;
    end
endmodule
