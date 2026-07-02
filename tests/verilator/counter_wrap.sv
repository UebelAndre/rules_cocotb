// Wraps `counter_reg` from a separate `verilog_library`. Exercises the
// transitive-deps walk in `collect_hdl_sources` — cocotb must stage BOTH
// `counter_wrap.sv` (the top) AND the dep `counter_reg.sv` for
// elaboration to succeed.
module counter_wrap (
    input        clk,
    input        rst,
    input        enable,
    output [7:0] count
);
    counter_reg u_counter_reg (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .count(count)
    );
endmodule
