`timescale 1ns/1ps

module reaction_controller #(
    parameter integer WAIT_MIN_MS  = 500,
    parameter integer WAIT_MAX_MS  = 5000,
    parameter integer REACT_MIN_MS = 100,
    parameter integer REACT_MAX_MS = 5000,
    parameter integer MS_COUNTER_W = $clog2(((WAIT_MAX_MS > REACT_MAX_MS) ? WAIT_MAX_MS : REACT_MAX_MS) + 2)
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     start_pulse,
    input  wire                     react_pulse,
    input  wire [MS_COUNTER_W-1:0]  ms_counter,

    input  wire                     random_valid,
    input  wire [12:0]              wait_delay_ms_in,

    output wire                     req_random,
    output wire                     counter_clr,
    output wire                     counter_en,
    output reg                      score_push_valid,
    output reg  [12:0]              score_push_time_ms,

    output reg  [2:0]               state,
    output reg  [1:0]               fail_code,
    output reg  [12:0]              reaction_time_ms,
    output wire                     ready
);

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_PREPARE = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REACT   = 3'd3;
    localparam [2:0] ST_FINISH  = 3'd4;
    localparam [2:0] ST_AVG     = 3'd5;
    localparam [2:0] ST_FAIL    = 3'd6;

    localparam [1:0] FAIL_NONE  = 2'd0;
    localparam [1:0] FAIL_EARLY = 2'd1;
    localparam [1:0] FAIL_SHORT = 2'd2;
    localparam [1:0] FAIL_SLOW  = 2'd3;

    localparam integer DELTA_W = (MS_COUNTER_W > 13) ? MS_COUNTER_W : 13;
    localparam [12:0] TIME_SAT_MAX = 13'd8191;

    reg [2:0] next_state;
    reg [12:0] wait_target_ms;

    wire [DELTA_W-1:0] ms_counter_ext;
    wire enter_wait;
    wire enter_react;

    assign ms_counter_ext = {{(DELTA_W - MS_COUNTER_W){1'b0}}, ms_counter};

    // Controller-owned reaction-time output. Keep 13-bit display domain with saturation.
    function [12:0] sat_time13;
        input [DELTA_W-1:0] t;
        begin
            if (t > TIME_SAT_MAX) begin
                sat_time13 = TIME_SAT_MAX;
            end else begin
                sat_time13 = t[12:0];
            end
        end
    endfunction

    // 1) State register process
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // 2) Next-state combinational process
    always @(*) begin
        next_state = state;

        case (state)
            ST_IDLE: begin
                if (start_pulse) begin
                    next_state = ST_PREPARE;
                end
            end

            ST_PREPARE: begin
                if (random_valid) begin
                    next_state = ST_WAIT;
                end
            end

            ST_WAIT: begin
                if (react_pulse) begin
                    next_state = ST_FAIL;
                end else if (ms_counter_ext >= wait_target_ms) begin
                    next_state = ST_REACT;
                end
            end

            ST_REACT: begin
                if (react_pulse) begin
                    if (ms_counter_ext < REACT_MIN_MS) begin
                        next_state = ST_FAIL;
                    end else if (ms_counter_ext > REACT_MAX_MS) begin
                        next_state = ST_FAIL;
                    end else begin
                        next_state = ST_FINISH;
                    end
                end else if (ms_counter_ext > REACT_MAX_MS) begin
                    next_state = ST_FAIL;
                end
            end

            ST_FINISH: begin
                if (start_pulse) begin
                    next_state = ST_AVG;
                end
            end

            ST_FAIL: begin
                if (start_pulse) begin
                    next_state = ST_AVG;
                end
            end

            ST_AVG: begin
                if (start_pulse) begin
                    next_state = ST_PREPARE;
                end
            end

            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // 3) Output/control combinational process
    // Enter-pulses are derived from current and next state.
    assign enter_wait = (state == ST_PREPARE) && (next_state == ST_WAIT);
    assign enter_react = (state == ST_WAIT) && (next_state == ST_REACT);

    assign req_random = (state == ST_PREPARE);
    assign counter_clr = enter_wait || enter_react;
    assign counter_en = (state == ST_WAIT) || (state == ST_REACT);
    assign ready = (state == ST_IDLE) || (state == ST_FINISH) || (state == ST_FAIL) || (state == ST_AVG);

    // Datapath register updates (non-state registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fail_code          <= FAIL_NONE;
            reaction_time_ms   <= 13'd0;
            wait_target_ms     <= WAIT_MIN_MS[12:0];
            score_push_valid   <= 1'b0;
            score_push_time_ms <= 13'd0;
        end else begin
            score_push_valid <= 1'b0;

            // Clear visible fail code whenever returning to IDLE.
            if (state == ST_IDLE) begin
                fail_code <= FAIL_NONE;
            end

            if (enter_wait) begin
                reaction_time_ms <= 13'd0;
            end

            if (state == ST_PREPARE && random_valid) begin
                wait_target_ms <= wait_delay_ms_in;
            end

            if (state == ST_WAIT && react_pulse) begin
                fail_code       <= FAIL_EARLY;
                reaction_time_ms <= 13'd0;
            end

            if (state == ST_REACT) begin
                if (react_pulse) begin
                    reaction_time_ms <= sat_time13(ms_counter_ext);

                    if (ms_counter_ext < REACT_MIN_MS) begin
                        fail_code <= FAIL_SHORT;
                    end else if (ms_counter_ext > REACT_MAX_MS) begin
                        fail_code <= FAIL_SLOW;
                    end else begin
                        fail_code          <= FAIL_NONE;
                        score_push_valid   <= 1'b1;
                        score_push_time_ms <= sat_time13(ms_counter_ext);
                    end
                end else if (ms_counter_ext > REACT_MAX_MS) begin
                    fail_code       <= FAIL_SLOW;
                    reaction_time_ms <= sat_time13(ms_counter_ext);
                end
            end

            if (state == ST_AVG && start_pulse) begin
                fail_code <= FAIL_NONE;
            end
        end
    end
endmodule
