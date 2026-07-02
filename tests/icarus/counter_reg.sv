`timescale 1ns/1ps

module counter_reg (
    input        clk,
    input        rst,
    input        enable,
    output [7:0] count
);
    logic [7:0] count_reg;

    always_ff @(posedge clk) begin
        if (rst) begin
            count_reg <= 8'd0;
        end else if (enable) begin
            count_reg <= count_reg + 8'd1;
        end
    end

    assign count = count_reg;
endmodule
