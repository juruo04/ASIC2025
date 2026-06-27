`timescale 1ns/1ps

module ms_counter_service_tb;
    localparam integer TB_CLK_HZ = 50000000;
    localparam integer MS_TICK_CYCLES = TB_CLK_HZ / 1000;
    localparam integer CLEAR_PERIOD_CYCLES = 3 * MS_TICK_CYCLES;

    reg clk;
    reg rst_n;
    reg counter_clr;
    reg counter_en;

    wire [15:0] ms_counter;

    integer i;

    ms_counter_service #(
        .CLK_HZ(TB_CLK_HZ),
        .COUNTER_W(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .counter_clr(counter_clr),
        .counter_en(counter_en),
        .ms_counter(ms_counter)
    );

    always #10 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        counter_clr = 1'b0;
        counter_en = 1'b1;

        repeat (10) @(posedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 8; i = i + 1) begin
            repeat (CLEAR_PERIOD_CYCLES) @(posedge clk);
            @(negedge clk);
            counter_clr <= 1'b1;
            @(negedge clk);
            counter_clr <= 1'b0;
        end

        repeat (20) @(posedge clk);
        $finish;
    end
endmodule
