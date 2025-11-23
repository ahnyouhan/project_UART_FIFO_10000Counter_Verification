`timescale 1ns / 1ps

module uart_top (
    input        clk,
    input        rst,
    input        rx,
    output       tx,
    output [7:0] o_rx_data,
    output       o_rx_done      
    //output o_tx_busy,
    //output o_rx_done

);
    wire w_b_tick;
    wire [7:0] rx_data;
    wire rx_done;
    wire tx_busy;

    assign o_rx_data = rx_data;
    assign o_rx_done = rx_done;


    //assign o_tx_busy = tx_busy;
    //assign o_rx_done = rx_done;

    baud_tick_gen U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .o_b_tick(w_b_tick)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(rx_done),
        .tx_data(rx_data),
        .b_tick(w_b_tick),
        .tx_busy(tx_busy),
        .tx(tx)
    );

    uart_rx U_UART_RX(
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    
    

    


endmodule


module uart_rx (
    input clk,
    input rst,
    input rx,
    input b_tick,
    output [7:0] rx_data,
    output rx_done
);
    localparam [1:0] IDLE = 2'b00, RX_START = 2'b01, RX_DATA = 2'b10, RX_STOP = 2'b11;
    reg [1:0] state_reg, next_state;
    reg [7:0] rx_buf_reg, rx_buf_next;
    reg [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;
    reg rx_done_reg, rx_done_next;

    assign rx_data = rx_buf_reg;
    assign rx_done = rx_done_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg <= IDLE;
            rx_buf_reg <= 8'h00;
            b_tick_cnt_reg <= 5'b00000;
            bit_cnt_reg <= 3'b000;
            rx_done_reg <= 1'b0;
        end else begin
            state_reg      <= next_state;
            rx_buf_reg     <= rx_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_done_reg    <= rx_done_next;    
        end
    end
        
    always @(*) begin
        
        next_state      = state_reg;
        rx_buf_next     = rx_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_done_next    = rx_done_reg;

        case (state_reg)
            IDLE: begin
                rx_done_next = 1'b0;
                if(!rx) begin
                    next_state = RX_START;
                    b_tick_cnt_next = 0;
                end
            end
            RX_START: begin
                if(b_tick==1) begin
                    if(b_tick_cnt_reg==8) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        next_state = RX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end 
            end
            RX_DATA: begin
                if(b_tick) begin
                    if(b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_buf_next = {rx,rx_buf_reg[7:1]};
                        if(bit_cnt_reg == 7) begin
                            next_state = RX_STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end     
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            RX_STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg ==23) begin
                        b_tick_cnt_next = 0;
                        rx_done_next = 1'b1;
                        next_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end 
            end
        endcase
    end
endmodule

module uart_tx (
    input        clk,
    input        rst,
    input        tx_start,
    input  [7:0] tx_data,
    input        b_tick,
    output       tx_busy,
    output       tx
);
    localparam [1:0] IDLE = 2'b00, TX_START = 2'b01, TX_DATA = 2'b10, TX_STOP = 2'b11;
    reg [1:0] state_reg, next_state;
    reg tx_busy_reg, tx_busy_next;
    reg tx_reg, tx_next;
    reg [7:0] data_buf_reg, data_buf_next;
    reg [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    reg [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            tx_busy_reg    <= 1'b0;
            tx_reg         <= 1'b1;
            data_buf_reg   <= 8'h00;
            b_tick_cnt_reg <= 4'b0000;
            bit_cnt_reg    <= 3'b000;
        end else begin
            state_reg      <= next_state;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
            data_buf_reg   <= data_buf_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
        end
    end

    //next
    always @(*) begin
        next_state      = state_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        data_buf_next   = data_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        case (state_reg)
            IDLE: begin
                tx_next = 1'b1;
                
                if (tx_start) begin
                    b_tick_cnt_next = 0;
                    data_buf_next = tx_data;
                    next_state = TX_START;
                end
            end
            TX_START: begin
                tx_next = 1'b0;
                tx_busy_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        next_state = TX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        if (bit_cnt_reg == 7) begin
                            next_state = TX_STOP;
                        end else begin
                            bit_cnt_next  = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            TX_STOP: begin
                tx_next = 1'b1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        tx_busy_next = 1'b0;
                        next_state = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick_gen (
    input  clk,
    input  rst,
    output o_b_tick
);
    // 100_000_000 / BAUD*16
    parameter BAUD = 9600;
    parameter BAUD_TICK_COUNT = 100_000_000 / BAUD / 16;
    reg [$clog2(BAUD_TICK_COUNT)-1:0] counter_reg;
    reg b_tick_reg;

    assign o_b_tick = b_tick_reg;

    always @(posedge clk, posedge rst) begin
        if (rst) begin
            counter_reg <= 0;
            b_tick_reg  <= 1'b0;
        end else begin
            if (counter_reg == BAUD_TICK_COUNT) begin
                counter_reg <= 0;
                b_tick_reg  <= 1'b1;
            end else begin
                counter_reg <= counter_reg + 1;
                b_tick_reg  <= 1'b0;
            end
        end
    end
endmodule
