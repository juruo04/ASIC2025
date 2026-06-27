`timescale 1ns/1ps

module reaction_core #(
    parameter integer CLK_HZ       = 50000000,
    parameter integer WAIT_MIN_MS  = 500,
    parameter integer WAIT_MAX_MS  = 5000,
    parameter integer REACT_MIN_MS = 100,
    parameter integer REACT_MAX_MS = 5000,
    parameter integer MS_COUNTER_W = $clog2(((WAIT_MAX_MS > REACT_MAX_MS) ? WAIT_MAX_MS : REACT_MAX_MS) + 2),
    parameter [15:0] RNG_SEED      = 16'h1A2B
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_pulse,
    input  wire        react_pulse,

    output wire [2:0]  state,
    output wire [1:0]  fail_code,
    output wire [12:0] reaction_time_ms,
    output wire [12:0] avg_time_ms,
    output wire        hist_available,
    output wire        ready
);

    wire [MS_COUNTER_W-1:0] ms_counter;
    wire                    counter_clr;
    wire                    counter_en;

    wire        req_random;
    wire        random_valid;
    wire [12:0] wait_delay_ms_in;

    wire        score_push_valid;
    wire [12:0] score_push_time_ms;
    wire        hist_avg_valid;
    wire [12:0] hist_avg_time_ms;

    assign avg_time_ms = hist_avg_time_ms;
    assign hist_available = hist_avg_valid;

    ms_counter_service #(
        .CLK_HZ(CLK_HZ),
        .COUNTER_W(MS_COUNTER_W)
    ) u_ms_counter (
        .clk(clk),
        .rst_n(rst_n),
        .counter_clr(counter_clr),
        .counter_en(counter_en),
        .ms_counter(ms_counter)
    );

    lfsr_random_service #(
        .WAIT_MIN_MS(WAIT_MIN_MS),
        .WAIT_MAX_MS(WAIT_MAX_MS),
        .LFSR_SEED(RNG_SEED)
    ) u_rng (
        .clk(clk),
        .rst_n(rst_n),
        .req_random(req_random),
        .random_valid(random_valid),
        .random_delay_ms(wait_delay_ms_in)
    );

    score_history_avg u_hist (
        .clk(clk),
        .rst_n(rst_n),
        .push_valid(score_push_valid),
        .push_time_ms(score_push_time_ms),
        .avg_valid(hist_avg_valid),
        .avg_time_ms(hist_avg_time_ms)
    );

    reaction_controller #(
        .WAIT_MIN_MS(WAIT_MIN_MS),
        .WAIT_MAX_MS(WAIT_MAX_MS),
        .REACT_MIN_MS(REACT_MIN_MS),
        .REACT_MAX_MS(REACT_MAX_MS),
        .MS_COUNTER_W(MS_COUNTER_W)
    ) u_controller (
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
endmodule
