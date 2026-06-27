`timescale 1ns/1ps

module lfsr_random_service #(
    parameter integer WAIT_MIN_MS = 500,
    parameter integer WAIT_MAX_MS = 5000,
    parameter [15:0] LFSR_SEED    = 16'h1A2B
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        req_random,
    output reg         random_valid,
    output reg [12:0]  random_delay_ms
);

    localparam integer WAIT_SPAN = WAIT_MAX_MS - WAIT_MIN_MS + 1;

    reg [15:0] lfsr;
    reg [31:0] entropy_counter;
    reg        req_seen;
    wire [15:0] lfsr_next;
    wire [15:0] current_random;

    assign lfsr_next = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

    function [15:0] nonzero16;
        input [15:0] value;
        begin
            if (value != 16'd0) begin
                nonzero16 = value;
            end else if (LFSR_SEED != 16'd0) begin
                nonzero16 = LFSR_SEED;
            end else begin
                nonzero16 = 16'h0001;
            end
        end
    endfunction

    function [15:0] mix_entropy;
        input [15:0] lfsr_value;
        input [31:0] entropy_value;
        reg [15:0] folded_entropy;
        begin
            folded_entropy = entropy_value[15:0]
                           ^ entropy_value[31:16]
                           ^ {entropy_value[7:0], entropy_value[15:8]};
            mix_entropy = nonzero16(lfsr_value ^ folded_entropy);
        end
    endfunction

    assign current_random = mix_entropy(lfsr_next, entropy_counter);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr            <= nonzero16(LFSR_SEED);
            entropy_counter <= 32'd1;
            req_seen        <= 1'b0;
            random_valid    <= 1'b0;
            random_delay_ms <= WAIT_MIN_MS[12:0];
        end else begin
            random_valid    <= 1'b0;
            entropy_counter <= entropy_counter + 32'd1;
            lfsr            <= lfsr_next;

            if (!req_random) begin
                req_seen <= 1'b0;
            end

            if (req_random && !req_seen) begin
                req_seen       <= 1'b1;
                lfsr           <= current_random;
                random_delay_ms <= (current_random % WAIT_SPAN) + WAIT_MIN_MS;
                random_valid    <= 1'b1;
            end
        end
    end
endmodule
