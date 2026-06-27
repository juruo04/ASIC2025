`timescale 1ns/1ps

module score_history_avg_tb;
    reg clk;
    reg rst_n;
    reg push_valid;
    reg [12:0] push_time_ms;

    wire avg_valid;
    wire [12:0] avg_time_ms;

    reg [12:0] expected_h0;
    reg [12:0] expected_h1;
    reg [12:0] expected_h2;
    reg [1:0] expected_count;
    reg [14:0] expected_sum;
    reg [14:0] expected_round_sum;
    reg [12:0] expected_avg_time_ms;
    wire expected_avg_valid;
    wire avg_mismatch;

    integer i;
    integer random_seed;
    integer random_raw;
    reg [12:0] random_time_ms;

    assign expected_avg_valid = (expected_count != 2'd0);
    assign avg_mismatch = (avg_valid !== expected_avg_valid) ||
                          (avg_time_ms !== expected_avg_time_ms);

    score_history_avg dut (
        .clk(clk),
        .rst_n(rst_n),
        .push_valid(push_valid),
        .push_time_ms(push_time_ms),
        .avg_valid(avg_valid),
        .avg_time_ms(avg_time_ms)
    );

    always #10 clk = ~clk;

    always @(*) begin
        expected_sum = expected_h0 + expected_h1 + expected_h2;
        expected_round_sum = 15'd0;
        expected_avg_time_ms = 13'd0;

        case (expected_count)
            2'd0: expected_avg_time_ms = 13'd0;
            2'd1: expected_avg_time_ms = expected_h0;
            2'd2: begin
                expected_round_sum = expected_h0 + expected_h1 + 15'd1;
                expected_avg_time_ms = expected_round_sum[14:1];
            end
            2'd3: begin
                expected_round_sum = expected_sum + 15'd1;
                expected_avg_time_ms = expected_round_sum / 15'd3;
            end
            default: expected_avg_time_ms = 13'd0;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            expected_h0 <= 13'd0;
            expected_h1 <= 13'd0;
            expected_h2 <= 13'd0;
            expected_count <= 2'd0;
        end else if (push_valid) begin
            expected_h2 <= expected_h1;
            expected_h1 <= expected_h0;
            expected_h0 <= push_time_ms;

            if (expected_count < 2'd3) begin
                expected_count <= expected_count + 2'd1;
            end
        end
    end

    task make_random_time;
        begin
            random_raw = $random(random_seed);
            if (random_raw < 0) begin
                random_raw = -random_raw;
            end
            random_time_ms = 13'd100 + (random_raw % 900);
        end
    endtask

    task drive_score_sample;
        input write_enable;
        begin
            make_random_time;
            @(negedge clk);
            push_time_ms <= random_time_ms;
            push_valid <= write_enable;
            @(negedge clk);
            push_valid <= 1'b0;
            push_time_ms <= 13'd0;
            repeat (6) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        push_valid = 1'b0;
        push_time_ms = 13'd0;
        random_seed = 32'h20260628;
        random_raw = 0;
        random_time_ms = 13'd0;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        for (i = 0; i < 3; i = i + 1) begin
            drive_score_sample(1'b1);
        end

        for (i = 0; i < 2; i = i + 1) begin
            drive_score_sample(1'b0);
        end

        for (i = 0; i < 6; i = i + 1) begin
            drive_score_sample(1'b1);
        end

        for (i = 0; i < 3; i = i + 1) begin
            drive_score_sample(1'b0);
        end

        rst_n <= 1'b0;
        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
        repeat (5) @(posedge clk);

        for (i = 0; i < 4; i = i + 1) begin
            drive_score_sample(1'b1);
        end

        repeat (10) @(posedge clk);
        $finish;
    end
endmodule
