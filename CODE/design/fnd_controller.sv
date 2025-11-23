`timescale 1ns / 1ps

module fnd_controller (
    input         clk,
    input         rst,
    input  [13:0] counter,
    output [ 3:0] fnd_com,
    output [ 7:0] fnd_data
);
    wire [3:0] w_digit_1, w_digit_10, w_digit_100, w_digit_1000;
    wire [1:0] w_sel;
    wire [3:0] w_bcd;
    wire w_clk_1khz;

    decoder_2x4 DECODER_2x4(
        .sel(w_sel),
        .fnd_com(fnd_com)
    );

    counter_4 COUNTER_4(
        .clk(w_clk_1khz),
        .rst(rst),
        .sel(w_sel)
    );
    
    clk_div_1khz U_CLK_DIV_1KHZ (
        .clk(clk), 
        .rst(rst),
        .o_clk_1khz(w_clk_1khz)
    );

    mux_4x1 U_MUX_4x1(
        .sel(w_sel),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000),
        .bcd(w_bcd)
    );

    digit_splitter U_DIGIT_SPLITTER(
        .counter(counter),
        .digit_1(w_digit_1),
        .digit_10(w_digit_10),
        .digit_100(w_digit_100),
        .digit_1000(w_digit_1000)
    );

    bcd_decoder U_BCD_DECODER (
        .bcd(w_bcd),
        .fnd_data(fnd_data)
    );

endmodule


module clk_div_1khz (
    input clk,
    input rst,
    output o_clk_1khz
);
    parameter F_COUNT = 100_000_000/1000;
    reg [$clog2(F_COUNT)-1:0] r_counter;
    reg r_clk_1khz;
    
    assign o_clk_1khz = r_clk_1khz;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            r_counter <= 0;
            r_clk_1khz <= 1'b0;
        end else begin
            if(r_counter == F_COUNT-1) begin
                r_counter <= 0;
                r_clk_1khz <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_clk_1khz <= 1'b0;
            end
        end
    end
    
endmodule

module counter_4 (
    input clk,
    input rst,
    output [1:0] sel
);
    reg [1:0] counter_reg;

    assign sel = counter_reg;

    always @(posedge clk, posedge rst) begin
        if(rst) begin
            counter_reg <= 0;
        end else begin
            counter_reg <= counter_reg + 1;
        end
    end
    
endmodule


module decoder_2x4 (
    input  [1:0] sel,
    output [3:0] fnd_com
);
    assign fnd_com = (sel == 2'b00) ? 4'b1110 :
                     (sel == 2'b01) ? 4'b1101 :
                     (sel == 2'b10) ? 4'b1011 :
                     (sel == 2'b11) ? 4'b0111 : 4'b1111;

endmodule



module digit_splitter (
    input [13:0] counter,
    output [3:0] digit_1,
    output [3:0] digit_10,
    output [3:0] digit_100,
    output [3:0] digit_1000
);

    assign digit_1 = counter % 10;
    assign digit_10 = (counter / 10) % 10;
    assign digit_100 = (counter / 100) % 10;
    assign digit_1000 = (counter / 1000) % 10;

endmodule

module mux_4x1 (
    input [1:0] sel,
    input [3:0] digit_1,
    input [3:0] digit_10,
    input [3:0] digit_100,
    input [3:0] digit_1000,
    output [3:0] bcd
);
    reg [3:0] r_bcd;
    assign bcd = r_bcd;
    always @(*) begin
        case (sel)
            2'b00: r_bcd = digit_1;
            2'b01: r_bcd = digit_10;
            2'b10: r_bcd = digit_100;
            2'b11: r_bcd = digit_1000;
            default: r_bcd = digit_1;
        endcase
    end
endmodule


module bcd_decoder (
    input      [3:0] bcd,
    output reg [7:0] fnd_data
);

    always @(bcd) begin
        case (bcd)
            4'b0000: fnd_data = 8'hc0;
            4'b0001: fnd_data = 8'hF9;
            4'b0010: fnd_data = 8'hA4;
            4'b0011: fnd_data = 8'hB0;
            4'b0100: fnd_data = 8'h99;
            4'b0101: fnd_data = 8'h92;
            4'b0110: fnd_data = 8'h82;
            4'b0111: fnd_data = 8'hF8;
            4'b1000: fnd_data = 8'h80;
            4'b1001: fnd_data = 8'h90;
            4'b1010: fnd_data = 8'h88;
            4'b1011: fnd_data = 8'h83;
            4'b1100: fnd_data = 8'hc6;
            4'b1101: fnd_data = 8'ha1;
            4'b1110: fnd_data = 8'hB6; //B6 
            4'b1111: fnd_data = 8'h8e;  
            default: fnd_data = 8'hff;
        endcase

    end
endmodule
