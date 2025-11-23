`timescale 1ns / 1ps

module tb_counter();
    reg clk, rst;
    reg btn_L, btn_R, btn_U;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;
    reg [7:0] command;
    integer i;
    reg rx;
    wire tx;

    parameter MS = 100_000*10;

    counter_top dut(
        .clk(clk),
        .rst(rst),
        .btn_L(btn_L),  // clear
        .btn_R(btn_R),  // Run
        .btn_U(btn_U),  // mode - up/down
        .fnd_com(fnd_com),
        .fnd_data(fnd_data),
        .rx(rx),
        .tx(tx)

    );
    always #5 clk = ~clk;

    initial begin
        #0;
        clk = 0;
        rst = 1;
        btn_L = 0;
        btn_R = 0;
        btn_U = 0;
        #10;
        rst = 0;
        #(500*MS);

        //  btn_L = 1;
        //  #(500*MS);
        //  btn_L = 0;
        //  #(500*MS); // 1sec

        //  btn_R = 1;
        //  #(500*MS); // 1sec
        //  btn_R = 0;
        //  #(500*MS); // 1sec

        //  btn_U = 1;
        //  #(500*MS); // 1sec
        //  btn_U = 0;
        //  #(500*MS); // 1sec


        //  btn_R = 1;
        //  #(500*MS); // 1sec
        //  btn_R = 0;
        //  #(500*MS); // 1sec

        dut.U_COUNTER_CTRL.command = 8'h72;
        #(500*MS);
        btn_L=0;
        #(500*MS);
        
        
        //#100000000 100ms
    
        
        for(i=0; i<100; i=i+1) begin
            wait(dut.U_FND_CTRL.w_clk_1khz);
        end
        $stop;

    end

endmodule
