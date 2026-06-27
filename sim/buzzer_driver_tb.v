`timescale 1ns/1ps

module buzzer_driver_tb;
    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_PREPARE = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REACT   = 3'd3;
    localparam [2:0] ST_AVG     = 3'd5;
    localparam [2:0] ST_FINISH  = 3'd4;
    localparam [2:0] ST_FAIL    = 3'd6;

    reg clk;
    reg rst_n;
    reg [2:0] state;
    reg [1:0] fail_code;

    wire buzzer;

    buzzer_driver #(
        .CLK_HZ(1000),
        .BUZZER_ON_LEVEL(1'b0)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .fail_code(fail_code),
        .buzzer(buzzer)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        state = ST_IDLE;
        fail_code = 2'd0;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        // Hold same state: should stay silent (inactive level).
        repeat (120) @(posedge clk);

        // Each state jump should trigger one continuous active-low beep window.
        state <= ST_PREPARE;
        repeat (160) @(posedge clk);

        state <= ST_WAIT;
        repeat (160) @(posedge clk);

        // Keep same state again: no new beep should be generated.
        repeat (120) @(posedge clk);

        state <= ST_REACT;
        repeat (160) @(posedge clk);

        state <= ST_FINISH;
        repeat (160) @(posedge clk);

        state <= ST_AVG;
        repeat (160) @(posedge clk);

        state <= ST_FAIL;
        fail_code <= 2'd3;
        repeat (160) @(posedge clk);

        state <= ST_IDLE;
        fail_code <= 2'd0;
        repeat (160) @(posedge clk);

        $finish;
    end
endmodule
