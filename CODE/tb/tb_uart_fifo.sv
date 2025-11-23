`timescale 1ns / 1ps

interface uart_fifo_interface;
    logic       clk;
    logic       rst;
    logic       rx;
    logic       tx;
    logic [7:0] rx_data;
    logic       rx_trigger;
endinterface

class transaction;
    rand bit [7:0] data;
    bit      [7:0] rx_popdata;
    bit            rx_trigger;

    task display(string tag);
        $display("%0t [%s] data = 0x%h, rx_popdata = 0x%h, trigger = %0d", $time,
                 tag, data, rx_popdata, rx_trigger);
    endtask
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox, gen2scb_mbox;
    event gen_next_event;

    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) gen2scb_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen2scb_mbox   = gen2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            total_count++;
            tr = new();
            assert (tr.randomize())
            else $error("%0t [GEN] tr.randomize() error!!!", $time);

            gen2drv_mbox.put(tr);
            gen2scb_mbox.put(tr);
            tr.display("GEN");
            @(gen_next_event);
        end
    endtask
endclass

class driver;
    parameter BAUD_RATE = 9600;
    parameter CLOCK_PERIOD_NS = 10;  // 100 Mhz
    parameter BITPERCLOCK = 10416;  //100_000_000 / 9600
    parameter BIT_PERIOD = BITPERCLOCK * CLOCK_PERIOD_NS; // number of clock * 10

    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    virtual uart_fifo_interface uart_fifo_if;
    //event driver_data_event;
     
    
    function new(mailbox#(transaction) gen2drv_mbox,
                 virtual uart_fifo_interface uart_fifo_if
                 /*,event driver_data_event*/);
        this.gen2drv_mbox = gen2drv_mbox;
        this.uart_fifo_if = uart_fifo_if;
        //this.driver_data_event = driver_data_event;
    endfunction  //new()

    task reset();
        uart_fifo_if.clk = 0;
        uart_fifo_if.rst = 1;
        uart_fifo_if.rx  = 1;

        repeat (2) @(posedge uart_fifo_if.clk);
        uart_fifo_if.rst = 0;
        repeat (2) @(posedge uart_fifo_if.clk);
        $display("%0t [DRV] reset done!", $time);
    endtask

    task send(input logic [7:0] data2send);
        $display("%0t [DRV] send data : 0x%h", $time, data2send);

        // start bit
        uart_fifo_if.rx = 0;
        #(BIT_PERIOD);

        // data bit
        for (int i = 0; i < 8; i++) begin
            
            uart_fifo_if.rx = data2send[i];
            $display("%0t [DRV-RX] (%0d) %0d", $time, i, uart_fifo_if.rx);
            #(BIT_PERIOD);
            
        end

        // stop bit
        uart_fifo_if.rx = 1;
        // DUT  
        #(BIT_PERIOD * 2);

    endtask

    task run();
        forever begin
            #1;
            gen2drv_mbox.get(tr);
            //->driver_data_event;
            tr.display("DRV");
            send(tr.data);

        end
    endtask

    
endclass

class monitor;
    parameter BAUD_RATE = 9600;
    parameter CLOCK_PERIOD_NS = 10;  // 100 Mhz
    parameter BITPERCLOCK = 10416;  //100_000_000 / 9600
    parameter BIT_PERIOD = BITPERCLOCK * CLOCK_PERIOD_NS; // number of clock * 10

    transaction tr;
    virtual uart_fifo_interface uart_fifo_if;
    mailbox #(transaction) mon2scb_mbox;
    //    event mon_next_event;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_fifo_interface uart_fifo_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_fifo_if = uart_fifo_if;
    endfunction  //new()

    task run();
        logic [7:0] received_data;
        forever begin
            wait (uart_fifo_if.tx == 1);
            @(posedge uart_fifo_if.clk);
            wait (uart_fifo_if.tx == 0);

            $display("%0t [MON] start bit", $time);

            #(BIT_PERIOD / 2);
            for (int i = 0; i < 8; i++) begin
                #(BIT_PERIOD);
                $display("%0t [MON-TX] (%0d) %0d", $time, i, uart_fifo_if.tx);
                received_data[i] = uart_fifo_if.tx;     
            end
            #(BIT_PERIOD);

            if (uart_fifo_if.tx != 1) begin
                $error("%0t [MON] stop bit not found!", $time);
            end
            $display("%0t [MON] receive data: 0x%h", $time, received_data);
            tr = new();
            tr.rx_popdata = received_data;
            mon2scb_mbox.put(tr);

            @(posedge uart_fifo_if.clk);


        end
    endtask
endclass

class scoreboard;
    transaction tr_exp, tr_act;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;
    event gen_next_event;

    int pass_count = 0, fail_count = 0;

    function new(mailbox#(transaction) gen2scb_mbox,
                 mailbox#(transaction) mon2scb_mbox, event gen_next_event);
        this.gen2scb_mbox   = gen2scb_mbox;
        this.mon2scb_mbox   = mon2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run();
        forever begin
            gen2scb_mbox.get(tr_exp);
            $display("%0t [SCB] expected data 0x%h received", $time, tr_exp.data);

            mon2scb_mbox.get(tr_act);

            if (tr_exp.data == tr_act.rx_popdata) begin
                pass_count++;
                $display("%0t [SCB] -> PASS: Expected 0x%h, Got 0x%h", $time, tr_exp.data,
                         tr_act.rx_popdata);
            end else begin
                fail_count++;
                $error("%0t [SCB] -> FAIL: Expected 0x%h, Got 0x%h", $time, tr_exp.data,
                       tr_act.rx_popdata);
            end

            ->gen_next_event;
        end

    endtask
endclass

class environment;
    int                    count           = 1200;

    generator              gen;
    driver                 drv;
    monitor                mon;
    scoreboard             scb;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) gen2scb_mbox;
    mailbox #(transaction) mon2scb_mbox;

    event                  gen_next_event;


    function new(virtual uart_fifo_interface uart_fifo_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        gen2scb_mbox = new();
        gen = new(gen2drv_mbox, gen2scb_mbox, gen_next_event);
        drv = new(gen2drv_mbox, uart_fifo_if);
        mon = new(mon2scb_mbox, uart_fifo_if);
        scb = new(gen2scb_mbox, mon2scb_mbox, gen_next_event);
    endfunction  //new()

    task report();
        $display("==========================================");
        $display("=============== test report ==============");
        $display("==========================================");
        $display("==           Total test : %4d ==", gen.total_count);
        $display("==           Pass test  : %4d ==", scb.pass_count);
        $display("==           Fail test  : %4d ==", scb.fail_count);
        $display("==========================================");
        $display("==        Test bench is finish          ==");
        $display("==========================================");
    endtask

    task reset();
        drv.reset();
    endtask


    task run();
        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run();
        join_none
        wait (scb.pass_count + scb.fail_count == count) #1000;
        report();
        $display("finished");
        $stop;
    endtask

endclass  //environment


module tb_uart_fifo ();
    uart_fifo_interface uart_fifo_if ();
    environment env;

    uart_top dut (
        .clk(uart_fifo_if.clk),
        .rst(uart_fifo_if.rst),
        .rx(uart_fifo_if.rx),
        .tx(uart_fifo_if.tx),
        .o_rx_popdata(uart_fifo_if.rx_data),
        .rx_trigger(uart_fifo_if.rx_trigger)
    );

    always #5 uart_fifo_if.clk = ~uart_fifo_if.clk;

    initial begin
        env = new(uart_fifo_if);
        env.reset();
        env.run();
    end

endmodule
