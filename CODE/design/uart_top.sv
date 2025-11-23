`timescale 1ns / 1ps

module uart_top (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    output logic       tx,
    output logic [7:0] o_rx_popdata,
    output logic       rx_trigger
);

    logic w_b_tick;
    logic [7:0] rx_data, rx_fifo_popdata, tx_fifo_popdata;
    logic rx_done;
    logic tx_busy;
    logic rx_fifo_empty, tx_fifo_full, tx_fifo_empty;

    assign o_rx_popdata = rx_fifo_popdata;
    assign rx_trigger   = ~rx_fifo_empty;

    baud_tick_gen U_BAUD_TICK (
        .clk(clk),
        .rst(rst),
        .o_b_tick(w_b_tick)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .b_tick(w_b_tick),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    fifo_top U_FIFO_RX (
        .clk  (clk),
        .rst  (rst),
        .wData(rx_data),          // push data
        .wr   (rx_done),          // PUSH
        .rd   (~tx_fifo_full),    // POP
        .rData(rx_fifo_popdata),  // pop data
        .full (),
        .empty(rx_fifo_empty)
    );

    fifo_top U_FIFO_TX (
        .clk  (clk),
        .rst  (rst),
        .wData(rx_fifo_popdata),  // push data
        .wr   (~rx_fifo_empty),   // PUSH
        .rd   (~tx_busy),         // POP
        .rData(tx_fifo_popdata),  //pop data
        .full (tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .clk(clk),
        .rst(rst),
        .tx_start(~tx_fifo_empty),
        .tx_data(tx_fifo_popdata),
        .b_tick(w_b_tick),
        .tx_busy(tx_busy),
        .tx(tx)
    );




endmodule


module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        RX_START = 2'b01,
        RX_DATA  = 2'b10,
        RX_STOP  = 2'b11
    } rx_state_e;

    rx_state_e state_reg, next_state;
    logic [7:0] rx_buf_reg, rx_buf_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;
    logic rx_done_reg, rx_done_next;

    assign rx_data = rx_buf_reg;
    assign rx_done = rx_done_reg;

    always_ff @(posedge clk, posedge rst) begin
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

    always_comb begin

        next_state      = state_reg;
        rx_buf_next     = rx_buf_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_done_next    = rx_done_reg;

        case (state_reg)
            IDLE: begin
                rx_done_next = 1'b0;
                if (!rx) begin
                    next_state = RX_START;
                    b_tick_cnt_next = 0;
                end
            end
            RX_START: begin
                if (b_tick == 1) begin
                    if (b_tick_cnt_reg == 8) begin
                        b_tick_cnt_next = 0;
                        bit_cnt_next = 0;
                        next_state = RX_DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            RX_DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_buf_next = {rx, rx_buf_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
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
                    if (b_tick_cnt_reg == 23) begin
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
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    input  logic       b_tick,
    output logic       tx_busy,
    output logic       tx
);
    typedef enum logic [1:0] {
        IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_e;  // enum style로 통일
    tx_state_e state_reg, next_state;

    logic tx_busy_reg, tx_busy_next;
    logic tx_reg, tx_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic [3:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [2:0] bit_cnt_reg, bit_cnt_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always_ff @(posedge clk, posedge rst) begin
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
    always_comb begin
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
                        next_state   = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end
endmodule

module baud_tick_gen (
    input  logic clk,
    input  logic rst,
    output logic o_b_tick
);
    // 100_000_000 / BAUD*16
    parameter BAUD = 9600;
    parameter BAUD_TICK_COUNT = 100_000_000 / BAUD / 16;

    logic [$clog2(BAUD_TICK_COUNT)-1:0] counter_reg;
    logic b_tick_reg;

    assign o_b_tick = b_tick_reg;

    always_ff @(posedge clk, posedge rst) begin
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
