`timescale 1ns / 1ps

module fifo_top (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] wData,
    input  logic       wr,     // PUSH
    input  logic       rd,     // POP
    output logic [7:0] rData,
    output logic       full,
    output logic       empty
);
    wire [2:0] wAddr, rAddr;
    wire wr_en;

    assign wr_en = ~full & wr;
    
    register_file U_REG_FILE (
        .*,
        .wr(wr_en)
    );
    fifo_control_unit U_FIFO_CU (.*);
    // register_file U_REG_FILE (
    //     .clk(clk),
    //     .wData(wData),
    //     .wAddr(wAddr),
    //     .rAddr(rAddr),
    //     .wr(~full & wr),
    //     .rData(rData)
    // );

    // fifo_control_unit U_FIFO_CU (
    //     .clk(clk),
    //     .rst(rst),
    //     .wr(wr),
    //     .rd(rd),
    //     .wAddr(wAddr),
    //     .rAddr(rAddr),
    //     .full(full),
    //     .empty(empty)
    // );


endmodule

module register_file #(
    parameter AWIDTH = 3
) (
    input  logic              clk,
    input  logic              wr,
    input  logic [       7:0] wData,
    input  logic [AWIDTH-1:0] wAddr,
    input  logic [AWIDTH-1:0] rAddr,
    output logic [       7:0] rData
);
    // 16 x 8bit memory
    logic [7:0] register_file[0:2**AWIDTH - 1];
    assign rData = register_file[rAddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            register_file[wAddr] <= wData;
        end
    end

endmodule

module fifo_control_unit #(
    parameter AWIDTH = 3
) (
    input  logic              clk,
    input  logic              rst,
    input  logic              wr,
    input  logic              rd,
    output logic [AWIDTH-1:0] wAddr,
    output logic [AWIDTH-1:0] rAddr,
    output logic              full,
    output logic              empty
);

    logic [AWIDTH-1:0] wAddr_reg, wAddr_next;
    logic [AWIDTH-1:0] rAddr_reg, rAddr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign wAddr = wAddr_reg;
    assign rAddr = rAddr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            wAddr_reg <= 0;
            rAddr_reg <= 0;
            full_reg  <= 1'b0;
            empty_reg <= 1'b1;
        end else begin
            wAddr_reg <= wAddr_next;
            rAddr_reg <= rAddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        wAddr_next = wAddr_reg;
        rAddr_next = rAddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;

        case ({wr, rd})
            2'b01: begin  // pop
                full_next = 1'b0;
                if (!empty) begin
                    rAddr_next = rAddr_reg + 1;
                    if (rAddr_next == wAddr_reg) empty_next = 1'b1;
                end
            end
            2'b10: begin  // push
                empty_next = 1'b0;
                if (!full_reg) begin
                    wAddr_next = wAddr_reg + 1;
                    if (wAddr_next == rAddr_reg) full_next = 1'b1;
                end
            end

            2'b11: begin
                if (full_reg) begin
                    rAddr_next = rAddr_reg + 1;
                    full_next  = 1'b0;
                end else if (empty) begin
                    wAddr_next = wAddr_reg + 1;
                    empty_next = 1'b0;
                end else begin
                    wAddr_next = wAddr_reg + 1;
                    rAddr_next = rAddr_reg + 1;
                end
            end
        endcase
    end

endmodule
