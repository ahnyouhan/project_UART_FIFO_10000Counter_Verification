`timescale 1ns / 1ps

module counter_top (
    input clk,
    input rst,
    input btn_L,  // clear
    input btn_R,  // Run
    input btn_U,  // mode - up/down
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    input rx,
    output tx
    
);
    wire w_tick_10hz;
    wire [13:0] w_counter;
    wire w_btn_L, w_btn_R, w_btn_U;
    wire w_enable, w_clear, w_mode;
    wire [7:0] rx_data;
    wire rx_done; // rx_trigger

    uart_top U_UART_TOP(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .tx(tx),
        .o_rx_popdata(rx_data),
        .rx_trigger(rx_done)
    );

    button_debounce U_BD_CLEAR(
        .clk(clk),
        .rst(rst),
        .i_btn(btn_L),
        .o_btn(w_btn_L)
    );

    button_debounce U_BD_ENABLE(
        .clk(clk),
        .rst(rst),
        .i_btn(btn_R),
        .o_btn(w_btn_R)
    );

    button_debounce U_BD_MODE(
        .clk(clk),
        .rst(rst),
        .i_btn(btn_U),
        .o_btn(w_btn_U)
    );

    tick_gen_10hz U_TICK_GEN_10HZ (
        .clk(clk),
        .rst(rst),
        .o_clk_10hz(w_tick_10hz)
    );

    counter_control U_COUNTER_CTRL (
        .clk(clk),
        .rst(rst),
        .btn_L(w_btn_L),
        .btn_R(w_btn_R),
        .btn_U(w_btn_U),
        .command(rx_data),
        .rx_done(rx_done),
        .o_enable(w_enable),
        .o_clear(w_clear),
        .o_mode(w_mode)
    );
    counter_10000 U_COUNTER_10000_DataPath (
        .i_tick(w_tick_10hz),
        .clk(clk),
        .rst(rst),
        .clear(w_clear),
        .enable(w_enable),
        .mode(w_mode),
        .counter(w_counter)
    );
    fnd_controller U_FND_CTRL (
        .clk(clk),
        .rst(rst),
        .counter(w_counter),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );

endmodule

module counter_control (
    input  clk,
    input  rst,
    input  btn_L,
    input  btn_R,
    input  btn_U,
    input  [7:0] command,
    input  rx_done,
    output o_enable,
    output o_clear,
    output o_mode
);

    parameter CMD = 0;
    reg c_state, n_state;
    reg enable_reg, enable_next;
    reg clear_reg, clear_next;
    reg mode_reg, mode_next;

    assign o_enable = enable_reg;
    assign o_clear  = clear_reg;
    assign o_mode   = mode_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state    <= CMD;
            enable_reg <= 0;
            clear_reg  <= 0;
            mode_reg   <= 0;
        end else begin
            c_state <= n_state;
            enable_reg <= enable_next;
            clear_reg <= clear_next;
            mode_reg <= mode_next;
        end
    end

    always @(*) begin
        n_state = c_state;
        enable_next = enable_reg;
        clear_next = 1'b0;
        mode_next = mode_reg;

        case (c_state)
            CMD: begin
                if (btn_L || (rx_done && command == 8'h63)) clear_next = 1'b1;
                else if (btn_R || (rx_done && command == 8'h72)) enable_next = ~enable_reg;
                else if (btn_U || (rx_done && command == 8'h6D)) mode_next = ~mode_reg;
                n_state = CMD;
            end
        endcase
    end


endmodule

module counter_10000 (
    input i_tick,
    input clk,
    input rst,
    input clear,  // clear
    input enable,  // enable 0 run/ 1 stop 
    input mode,  // mode up/down 
    output [13:0] counter
);

    reg [13:0] r_counter;
    assign counter = r_counter;

    always @(posedge clk, posedge rst) begin
        if (rst | clear) begin
            r_counter <= 0;
        end else begin
            if(i_tick) begin
                if (!enable) begin  // Run
                    if (!mode) begin
                        if (r_counter == 10_000 - 1) begin
                            r_counter <= 0;
                        end else begin
                            r_counter <= r_counter + 1;
                        end
                    end else begin
                        if (r_counter == 0) begin
                            r_counter <= 9999;
                        end else begin
                            r_counter <= r_counter - 1;
                        end
                    end
                end else begin
                    r_counter <= r_counter;
                end
            end
        end
    end
endmodule


module tick_gen_10hz (
    input  clk,
    input  rst,
    output o_clk_10hz
);
    parameter TIME_COUNT = 10_000_000;  //   10Mhz -> 10hz, (100M/10M) = 10hz
    reg [$clog2(TIME_COUNT)-1:0] r_counter;
    reg r_tick;
    assign o_clk_10hz = r_tick;


    always @(posedge clk, posedge rst) begin
        if (rst) begin
            r_counter <= 0;
            r_tick <= 1'b0;
        end else begin
            if (r_counter == TIME_COUNT - 1) begin
                r_counter <= 0;
                r_tick <= 1'b1;
            end else begin
                r_counter <= r_counter + 1;
                r_tick <= 1'b0;
            end
        end

    end

endmodule



