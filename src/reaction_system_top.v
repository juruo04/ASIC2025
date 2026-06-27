`timescale 1ns/1ps

module reaction_system_top #(
    parameter integer WAIT_MIN_MS       = 500,
    parameter integer WAIT_MAX_MS       = 5000,
    parameter integer REACT_MIN_MS      = 100,
    parameter integer REACT_MAX_MS      = 5000,
    parameter integer MS_COUNTER_W      = $clog2(((WAIT_MAX_MS > REACT_MAX_MS) ? WAIT_MAX_MS : REACT_MAX_MS) + 2),
    parameter [15:0]  RNG_SEED          = 16'h1A2B,
    parameter integer DEBOUNCE_STABLE_N = 20,
    parameter         BUTTON_ACTIVE_LEVEL = 1'b1,
    parameter integer CORE_CLK_HZ       = 50000000,
    parameter integer DISP_CLK_HZ       = 50000000,
    parameter integer DISP_DIGIT_SCAN_HZ = 1000,
    parameter         SEG_ON_LEVEL       = 1'b1,
    parameter         DIG_ON_LEVEL       = 1'b0,
    parameter integer BUZZER_CLK_HZ     = 50000000,
    parameter         BUZZER_ON_LEVEL    = 1'b0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        btn_start_raw,
    input  wire        btn_react_raw,

    output wire        seg_a,
    output wire        seg_b,
    output wire        seg_c,
    output wire        seg_d,
    output wire        seg_e,
    output wire        seg_f,
    output wire        seg_g,
    output wire        seg_dp,
    output wire        dig1,
    output wire        dig2,
    output wire        dig3,
    output wire        dig4,
    output wire        buzzer
);

    wire [2:0]  state;
    wire [1:0]  fail_code;
    wire [12:0] reaction_time_ms;
    wire [12:0] avg_time_ms;
    wire        hist_available;
    wire        ready;
    wire        start_btn_pressed;
    wire        react_btn_pressed;

    wire start_pulse;
    wire react_pulse;

    button_debounce_pulse #(
        .STABLE_N(DEBOUNCE_STABLE_N),
        .ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_start_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .btn_raw(btn_start_raw),
        .btn_pressed(start_btn_pressed),
        .btn_press_pulse(start_pulse)
    );

    button_debounce_pulse #(
        .STABLE_N(DEBOUNCE_STABLE_N),
        .ACTIVE_LEVEL(BUTTON_ACTIVE_LEVEL)
    ) u_react_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .btn_raw(btn_react_raw),
        .btn_pressed(react_btn_pressed),
        .btn_press_pulse(react_pulse)
    );

    reaction_core #(
        .CLK_HZ(CORE_CLK_HZ),
        .WAIT_MIN_MS(WAIT_MIN_MS),
        .WAIT_MAX_MS(WAIT_MAX_MS),
        .REACT_MIN_MS(REACT_MIN_MS),
        .REACT_MAX_MS(REACT_MAX_MS),
        .MS_COUNTER_W(MS_COUNTER_W),
        .RNG_SEED(RNG_SEED)
    ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .start_pulse(start_pulse),
        .react_pulse(react_pulse),
        .state(state),
        .fail_code(fail_code),
        .reaction_time_ms(reaction_time_ms),
        .avg_time_ms(avg_time_ms),
        .hist_available(hist_available),
        .ready(ready)
    );

    seg7_display_driver #(
        .CLK_HZ(DISP_CLK_HZ),
        .DIGIT_SCAN_HZ(DISP_DIGIT_SCAN_HZ),
        .SEG_ON_LEVEL(SEG_ON_LEVEL),
        .DIG_ON_LEVEL(DIG_ON_LEVEL)
    ) u_seg7 (
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

    buzzer_driver #(
        .CLK_HZ(BUZZER_CLK_HZ),
        .BUZZER_ON_LEVEL(BUZZER_ON_LEVEL)
    ) u_buzzer (
        .clk(clk),
        .rst_n(rst_n),
        .state(state),
        .fail_code(fail_code),
        .buzzer(buzzer)
    );
endmodule