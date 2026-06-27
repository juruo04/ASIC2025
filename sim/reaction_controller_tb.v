`timescale 1ns/1ps

module reaction_controller_tb;
    localparam integer TB_WAIT_MIN_MS  = 500;
    localparam integer TB_WAIT_MAX_MS  = 5000;
    localparam integer TB_REACT_MIN_MS = 100;
    localparam integer TB_REACT_MAX_MS = 5000;
    localparam integer TB_MS_W         = 14;

    localparam [TB_MS_W-1:0] TB_MS_STEP        = 14'd10;
    localparam [TB_MS_W-1:0] TB_WAIT_FIXED_MS  = 14'd1234;
    localparam [TB_MS_W-1:0] TB_REACT_NORMAL   = 14'd340;
    localparam [TB_MS_W-1:0] TB_WAIT_EARLY     = 14'd300;
    localparam [TB_MS_W-1:0] TB_REACT_TOO_FAST = 14'd50;
    localparam [TB_MS_W-1:0] TB_REACT_TIMEOUT  = 14'd5020;

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_PREPARE = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REACT   = 3'd3;
    localparam [2:0] ST_FINISH  = 3'd4;
    localparam [2:0] ST_AVG     = 3'd5;
    localparam [2:0] ST_FAIL    = 3'd6;

    reg clk;
    reg rst_n;
    reg start_pulse;
    reg react_pulse;
    reg [TB_MS_W-1:0] ms_counter;
    reg random_valid;
    reg [12:0] wait_delay_ms_in;

    wire req_random;
    wire counter_clr;
    wire counter_en;
    wire score_push_valid;
    wire [12:0] score_push_time_ms;
    wire [2:0] state;
    wire [1:0] fail_code;
    wire [12:0] reaction_time_ms;
    wire ready;

    reaction_controller #(
        .WAIT_MIN_MS(TB_WAIT_MIN_MS),
        .WAIT_MAX_MS(TB_WAIT_MAX_MS),
        .REACT_MIN_MS(TB_REACT_MIN_MS),
        .REACT_MAX_MS(TB_REACT_MAX_MS),
        .MS_COUNTER_W(TB_MS_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start_pulse(start_pulse),
        .react_pulse(react_pulse),
        .ms_counter(ms_counter),
        .random_valid(random_valid),
        .wait_delay_ms_in(wait_delay_ms_in),
        .req_random(req_random),
        .counter_clr(counter_clr),
        .counter_en(counter_en),
        .score_push_valid(score_push_valid),
        .score_push_time_ms(score_push_time_ms),
        .state(state),
        .fail_code(fail_code),
        .reaction_time_ms(reaction_time_ms),
        .ready(ready)
    );

    always #10 clk = ~clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ms_counter <= {TB_MS_W{1'b0}};
        end else if (counter_clr) begin
            ms_counter <= {TB_MS_W{1'b0}};
        end else if (counter_en) begin
            ms_counter <= ms_counter + TB_MS_STEP;
        end
    end

    task pulse_start;
        begin
            @(negedge clk);
            start_pulse <= 1'b1;
            @(negedge clk);
            start_pulse <= 1'b0;
        end
    endtask

    task pulse_react;
        begin
            @(negedge clk);
            react_pulse <= 1'b1;
            @(negedge clk);
            react_pulse <= 1'b0;
        end
    endtask

    task wait_state;
        input [2:0] target_state;
        begin
            wait (state == target_state);
            @(posedge clk);
        end
    endtask

    task wait_counter_at_least;
        input [TB_MS_W-1:0] target_ms;
        begin
            wait (ms_counter >= target_ms);
            @(posedge clk);
        end
    endtask

    task give_random_wait;
        input [TB_MS_W-1:0] wait_ms;
        begin
            wait_delay_ms_in <= wait_ms[12:0];
            wait_state(ST_PREPARE);
            wait (req_random == 1'b1);
            @(negedge clk);
            random_valid <= 1'b1;
            @(negedge clk);
            random_valid <= 1'b0;
            wait_state(ST_WAIT);
        end
    endtask

    task start_new_round_from_avg;
        begin
            wait_state(ST_AVG);
            pulse_start;
            wait_state(ST_PREPARE);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        start_pulse = 1'b0;
        react_pulse = 1'b0;
        random_valid = 1'b0;
        wait_delay_ms_in = TB_WAIT_FIXED_MS[12:0];

        repeat (10) @(posedge clk);
        rst_n <= 1'b1;
        wait_state(ST_IDLE);

        pulse_start;
        give_random_wait(TB_WAIT_FIXED_MS);
        wait_counter_at_least(TB_WAIT_FIXED_MS);
        wait_state(ST_REACT);
        wait_counter_at_least(TB_REACT_NORMAL);
        pulse_react;
        wait_state(ST_FINISH);

        pulse_start;
        start_new_round_from_avg;
        give_random_wait(TB_WAIT_FIXED_MS);
        wait_counter_at_least(TB_WAIT_EARLY);
        pulse_react;
        wait_state(ST_FAIL);

        pulse_start;
        start_new_round_from_avg;
        give_random_wait(TB_WAIT_FIXED_MS);
        wait_counter_at_least(TB_WAIT_FIXED_MS);
        wait_state(ST_REACT);
        wait_counter_at_least(TB_REACT_TOO_FAST);
        pulse_react;
        wait_state(ST_FAIL);

        pulse_start;
        start_new_round_from_avg;
        give_random_wait(TB_WAIT_FIXED_MS);
        wait_counter_at_least(TB_WAIT_FIXED_MS);
        wait_state(ST_REACT);
        wait_counter_at_least(TB_REACT_TIMEOUT);
        wait_state(ST_FAIL);

        pulse_start;
        wait_state(ST_AVG);
        pulse_start;
        wait_state(ST_PREPARE);

        repeat (10) @(posedge clk);
        $finish;
    end
endmodule
