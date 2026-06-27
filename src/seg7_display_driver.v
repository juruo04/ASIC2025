`timescale 1ns/1ps

module seg7_display_driver #(
    parameter integer CLK_HZ = 50000000,
    parameter integer DIGIT_SCAN_HZ = 1000,
    parameter         SEG_ON_LEVEL = 1'b0,
    parameter         DIG_ON_LEVEL = 1'b1
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [2:0]  state,
    input  wire [1:0]  fail_code,
    input  wire [12:0] reaction_time_ms,
    input  wire [12:0] avg_time_ms,
    input  wire        hist_available,

    output reg         seg_a,
    output reg         seg_b,
    output reg         seg_c,
    output reg         seg_d,
    output reg         seg_e,
    output reg         seg_f,
    output reg         seg_g,
    output reg         seg_dp,
    output reg         dig1,
    output reg         dig2,
    output reg         dig3,
    output reg         dig4
);

    localparam [2:0] ST_IDLE    = 3'd0;
    localparam [2:0] ST_PREPARE = 3'd1;
    localparam [2:0] ST_WAIT    = 3'd2;
    localparam [2:0] ST_REACT   = 3'd3;
    localparam [2:0] ST_FINISH  = 3'd4;
    localparam [2:0] ST_AVG     = 3'd5;
    localparam [2:0] ST_FAIL    = 3'd6;

    localparam integer SCAN_DIV = (CLK_HZ / (DIGIT_SCAN_HZ * 4));
    localparam integer SCAN_DIV_SAFE = (SCAN_DIV < 1) ? 1 : SCAN_DIV;
    localparam integer SCAN_W = (SCAN_DIV_SAFE <= 1) ? 1 : $clog2(SCAN_DIV_SAFE);

    reg [SCAN_W-1:0] scan_cnt;
    reg [1:0]        scan_idx;

    reg [7:0] glyph_d1;
    reg [7:0] glyph_d2;
    reg [7:0] glyph_d3;
    reg [7:0] glyph_d4;
    reg [7:0] glyph_thousands;
    reg [7:0] glyph_hundreds;
    reg [7:0] glyph_tens;
    reg [7:0] glyph_ones;

    reg [7:0] glyph_cur;
    reg [3:0] dig_on;
    reg [7:0] glyph_next;
    reg [3:0] dig_next;

    reg [13:0] value_clamped;
    reg [3:0] v_thousands;
    reg [3:0] v_hundreds;
    reg [3:0] v_tens;
    reg [3:0] v_ones;

    wire [12:0] value_src;

    assign value_src = (state == ST_FINISH) ? reaction_time_ms : avg_time_ms;

    localparam [7:0] GLYPH_BLANK = 8'b00000000;
    localparam [7:0] GLYPH_0     = 8'b00111111;
    localparam [7:0] GLYPH_1     = 8'b00000110;
    localparam [7:0] GLYPH_2     = 8'b01011011;
    localparam [7:0] GLYPH_3     = 8'b01001111;
    localparam [7:0] GLYPH_4     = 8'b01100110;
    localparam [7:0] GLYPH_5     = 8'b01101101;
    localparam [7:0] GLYPH_6     = 8'b01111101;
    localparam [7:0] GLYPH_7     = 8'b00000111;
    localparam [7:0] GLYPH_8     = 8'b01111111;
    localparam [7:0] GLYPH_9     = 8'b01101111;
    localparam [7:0] GLYPH_DASH  = 8'b01000000;
    localparam [7:0] GLYPH_F     = 8'b01110001;
    localparam [7:0] GLYPH_A     = 8'b01110111;
    localparam [7:0] GLYPH_I     = 8'b00000110;
    localparam [7:0] GLYPH_L     = 8'b00111000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scan_cnt <= {SCAN_W{1'b0}};
            scan_idx <= 2'd0;
        end else begin
            if (scan_cnt == SCAN_DIV_SAFE - 1) begin
                scan_cnt <= {SCAN_W{1'b0}};
                scan_idx <= scan_idx + 2'd1;
            end else begin
                scan_cnt <= scan_cnt + 1'b1;
            end
        end
    end

    always @(*) begin
        value_clamped = {1'b0, value_src};

        v_thousands = value_clamped / 14'd1000;
        v_hundreds  = (value_clamped / 14'd100) % 14'd10;
        v_tens      = (value_clamped / 14'd10) % 14'd10;
        v_ones      = value_clamped % 14'd10;
    end

    always @(*) begin
        if (v_thousands == 4'd0) begin
            glyph_thousands = GLYPH_0;
        end else if (v_thousands == 4'd1) begin
            glyph_thousands = GLYPH_1;
        end else if (v_thousands == 4'd2) begin
            glyph_thousands = GLYPH_2;
        end else if (v_thousands == 4'd3) begin
            glyph_thousands = GLYPH_3;
        end else if (v_thousands == 4'd4) begin
            glyph_thousands = GLYPH_4;
        end else if (v_thousands == 4'd5) begin
            glyph_thousands = GLYPH_5;
        end else if (v_thousands == 4'd6) begin
            glyph_thousands = GLYPH_6;
        end else if (v_thousands == 4'd7) begin
            glyph_thousands = GLYPH_7;
        end else if (v_thousands == 4'd8) begin
            glyph_thousands = GLYPH_8;
        end else if (v_thousands == 4'd9) begin
            glyph_thousands = GLYPH_9;
        end else begin
            glyph_thousands = GLYPH_BLANK;
        end

        if (v_hundreds == 4'd0) begin
            glyph_hundreds = GLYPH_0;
        end else if (v_hundreds == 4'd1) begin
            glyph_hundreds = GLYPH_1;
        end else if (v_hundreds == 4'd2) begin
            glyph_hundreds = GLYPH_2;
        end else if (v_hundreds == 4'd3) begin
            glyph_hundreds = GLYPH_3;
        end else if (v_hundreds == 4'd4) begin
            glyph_hundreds = GLYPH_4;
        end else if (v_hundreds == 4'd5) begin
            glyph_hundreds = GLYPH_5;
        end else if (v_hundreds == 4'd6) begin
            glyph_hundreds = GLYPH_6;
        end else if (v_hundreds == 4'd7) begin
            glyph_hundreds = GLYPH_7;
        end else if (v_hundreds == 4'd8) begin
            glyph_hundreds = GLYPH_8;
        end else if (v_hundreds == 4'd9) begin
            glyph_hundreds = GLYPH_9;
        end else begin
            glyph_hundreds = GLYPH_BLANK;
        end

        if (v_tens == 4'd0) begin
            glyph_tens = GLYPH_0;
        end else if (v_tens == 4'd1) begin
            glyph_tens = GLYPH_1;
        end else if (v_tens == 4'd2) begin
            glyph_tens = GLYPH_2;
        end else if (v_tens == 4'd3) begin
            glyph_tens = GLYPH_3;
        end else if (v_tens == 4'd4) begin
            glyph_tens = GLYPH_4;
        end else if (v_tens == 4'd5) begin
            glyph_tens = GLYPH_5;
        end else if (v_tens == 4'd6) begin
            glyph_tens = GLYPH_6;
        end else if (v_tens == 4'd7) begin
            glyph_tens = GLYPH_7;
        end else if (v_tens == 4'd8) begin
            glyph_tens = GLYPH_8;
        end else if (v_tens == 4'd9) begin
            glyph_tens = GLYPH_9;
        end else begin
            glyph_tens = GLYPH_BLANK;
        end

        if (v_ones == 4'd0) begin
            glyph_ones = GLYPH_0;
        end else if (v_ones == 4'd1) begin
            glyph_ones = GLYPH_1;
        end else if (v_ones == 4'd2) begin
            glyph_ones = GLYPH_2;
        end else if (v_ones == 4'd3) begin
            glyph_ones = GLYPH_3;
        end else if (v_ones == 4'd4) begin
            glyph_ones = GLYPH_4;
        end else if (v_ones == 4'd5) begin
            glyph_ones = GLYPH_5;
        end else if (v_ones == 4'd6) begin
            glyph_ones = GLYPH_6;
        end else if (v_ones == 4'd7) begin
            glyph_ones = GLYPH_7;
        end else if (v_ones == 4'd8) begin
            glyph_ones = GLYPH_8;
        end else if (v_ones == 4'd9) begin
            glyph_ones = GLYPH_9;
        end else begin
            glyph_ones = GLYPH_BLANK;
        end
    end

    always @(*) begin
        glyph_d1 = GLYPH_BLANK;
        glyph_d2 = GLYPH_BLANK;
        glyph_d3 = GLYPH_BLANK;
        glyph_d4 = GLYPH_BLANK;

        if (state == ST_IDLE) begin
            glyph_d1 = GLYPH_0;
            glyph_d2 = GLYPH_0;
            glyph_d3 = GLYPH_0;
            glyph_d4 = GLYPH_0;
        end else if ((state == ST_PREPARE) || (state == ST_WAIT)) begin
            glyph_d1 = GLYPH_DASH;
            glyph_d2 = GLYPH_DASH;
            glyph_d3 = GLYPH_DASH;
            glyph_d4 = GLYPH_DASH;
        end else if (state == ST_REACT) begin
            glyph_d1 = GLYPH_1;
            glyph_d2 = GLYPH_1;
            glyph_d3 = GLYPH_1;
            glyph_d4 = GLYPH_1;
        end else if (state == ST_FINISH) begin
            glyph_d1 = glyph_thousands;
            glyph_d2 = glyph_hundreds;
            glyph_d3 = glyph_tens;
            glyph_d4 = glyph_ones;
        end else if (state == ST_AVG) begin
            if (hist_available) begin
                glyph_d1 = glyph_thousands;
                glyph_d2 = glyph_hundreds;
                glyph_d3 = glyph_tens;
                glyph_d4 = glyph_ones;
            end else begin
                glyph_d1 = GLYPH_0;
                glyph_d2 = GLYPH_0;
                glyph_d3 = GLYPH_0;
                glyph_d4 = GLYPH_0;
            end
        end else if (state == ST_FAIL) begin
            glyph_d1 = GLYPH_F;
            glyph_d2 = GLYPH_A;
            glyph_d3 = GLYPH_I;
            glyph_d4 = GLYPH_L;
        end else begin
            glyph_d1 = GLYPH_BLANK;
            glyph_d2 = GLYPH_BLANK;
            glyph_d3 = GLYPH_BLANK;
            glyph_d4 = GLYPH_BLANK;
        end
    end

    always @(*) begin
        glyph_next = GLYPH_BLANK;
        dig_next = 4'b0000;

        if ((state == ST_PREPARE) || (state == ST_WAIT)) begin
            glyph_next = GLYPH_DASH;
            dig_next = 4'b1111;
        end else if (state == ST_REACT) begin
            glyph_next = GLYPH_1;
            dig_next = 4'b1111;
        end else if (scan_idx == 2'd0) begin
            glyph_next = glyph_d1;
            dig_next = 4'b1000;
        end else if (scan_idx == 2'd1) begin
            glyph_next = glyph_d2;
            dig_next = 4'b0100;
        end else if (scan_idx == 2'd2) begin
            glyph_next = glyph_d3;
            dig_next = 4'b0010;
        end else begin
            glyph_next = glyph_d4;
            dig_next = 4'b0001;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            glyph_cur <= GLYPH_BLANK;
            dig_on <= 4'b0000;
        end else begin
            glyph_cur <= glyph_next;
            dig_on <= dig_next;
        end
    end

    always @(*) begin
        seg_a  = glyph_cur[0] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_b  = glyph_cur[1] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_c  = glyph_cur[2] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_d  = glyph_cur[3] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_e  = glyph_cur[4] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_f  = glyph_cur[5] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_g  = glyph_cur[6] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;
        seg_dp = glyph_cur[7] ? SEG_ON_LEVEL : ~SEG_ON_LEVEL;

        dig1 = dig_on[3] ? DIG_ON_LEVEL : ~DIG_ON_LEVEL;
        dig2 = dig_on[2] ? DIG_ON_LEVEL : ~DIG_ON_LEVEL;
        dig3 = dig_on[1] ? DIG_ON_LEVEL : ~DIG_ON_LEVEL;
        dig4 = dig_on[0] ? DIG_ON_LEVEL : ~DIG_ON_LEVEL;
    end

endmodule