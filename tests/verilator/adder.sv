module adder (
    input  [7:0] x,
    input  [7:0] y,
    input        carry_in,
    output       carry_output_bit,
    output [7:0] sum
);
    logic [8:0] result;
    /* verilator lint_off WIDTH */
    assign result           = x + y + carry_in;
    /* verilator lint_on WIDTH */
    assign sum              = result[7:0];
    assign carry_output_bit = result[8];
endmodule
