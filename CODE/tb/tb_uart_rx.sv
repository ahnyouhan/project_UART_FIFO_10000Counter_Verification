`timescale 1ns / 1ps

interface uart_rx_interface;
    logic       clk;
    logic       rst;
    logic       rx;
    logic       tx;
    logic [7:0] rx_data;
    logic       rx_trigger;
endinterface

class transaction;
    rand logic [7:0] send_data;
    logic      [7:0] rx_data;
    logic            rx;
    logic            rx_trigger;

    task display(string tag);
        $display("%0t[%s] send data = %0d, rx_data = %0d",
                 $time, tag, send_data, rx_data);
    endtask
endclass

class generator;
    transaction tr;
    mailbox #(transaction) gen2drv_mbox;
    event gen_next_event;

    int total_count = 0;

    function new(mailbox#(transaction) gen2drv_mbox, event gen_next_event);
        this.gen2drv_mbox   = gen2drv_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run(int count);
        repeat (count) begin
            total_count++;
            tr = new();
            assert (tr.randomize())
            else $display("[GEN] tr.randmize() error !!! ");
            gen2drv_mbox.put(tr);
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
    mailbox #(transaction) drv2scb_mbox;
    virtual uart_rx_interface uart_rx_if;
    //event driver_data_event;

    function new(mailbox#(transaction) gen2drv_mbox,
                 mailbox#(transaction) drv2scb_mbox,
                 virtual uart_rx_interface uart_rx_if/* event driver_data_event*/);
        this.gen2drv_mbox = gen2drv_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        this.uart_rx_if = uart_rx_if;
        //this.driver_data_event = driver_data_event;
    endfunction  //new()

    task reset();
        uart_rx_if.clk = 0;
        uart_rx_if.rst = 1;
        uart_rx_if.rx  = 1;
        #10;
        repeat (2) @(posedge uart_rx_if.clk);
        uart_rx_if.rst = 0;
        repeat (2) @(posedge uart_rx_if.clk);
        $display("[DRV] reset done!");
    endtask

    task send(input logic [7:0] data2send);
        $display("[DRV] send data : 0x%h", data2send);

        // start bit
        uart_rx_if.rx = 0;
        #(BIT_PERIOD);

        // data bit
        for (int i = 0; i < 8; i++) begin
            uart_rx_if.rx = data2send[i];
            #(BIT_PERIOD);
        end

        // stop bit
        uart_rx_if.rx = 1;
        // DUT  
        #(BIT_PERIOD * 2);
    endtask

    task run();
        forever begin
            #1;
            gen2drv_mbox.get(tr);
            
            drv2scb_mbox.put(tr);
            //->driver_data_event;
            tr.display("DRV");
            send(tr.send_data);
            
        

        end
    endtask
endclass

class monitor;
    transaction tr;
    virtual uart_rx_interface uart_rx_if;
    mailbox #(transaction) mon2scb_mbox;

    function new(mailbox#(transaction) mon2scb_mbox,
                 virtual uart_rx_interface uart_rx_if);
        this.mon2scb_mbox = mon2scb_mbox;
        this.uart_rx_if   = uart_rx_if;
    endfunction  //new()

    task run();
        forever begin
            @(posedge uart_rx_if.rx_trigger);
            tr = new();
            tr.rx_data = uart_rx_if.rx_data;
            tr.display("MON");
            mon2scb_mbox.put(tr);
            @(posedge uart_rx_if.clk);
        end
    endtask
endclass

class scoreboard;
    transaction tr_act;
    transaction tr_exp;

    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;
    event gen_next_event;

    int pass_count = 0, fail_count = 0;

    function new(mailbox#(transaction) mon2scb_mbox,
                 mailbox#(transaction) drv2scb_mbox, event gen_next_event
    );
        this.mon2scb_mbox = mon2scb_mbox;
        this.drv2scb_mbox = drv2scb_mbox;
        this.gen_next_event = gen_next_event;
    endfunction  //new()

    task run();
        forever begin
            drv2scb_mbox.get(tr_exp);
            mon2scb_mbox.get(tr_act);
            $display("[SCB] : Expected Data : %0d", tr_exp.send_data);
            $display("[SCB] : Actual Data   : %0d", tr_act.rx_data);
           


            if(tr_act.rx_data == tr_exp.send_data) begin
                pass_count++;
                $display("[SCB] Pass !!!");
            end else begin
                fail_count++;
                $display("[SCB] Fail ...");
            end

            ->gen_next_event;
        end
    endtask
endclass

class environment;
    int count;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;
    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;
    mailbox #(transaction) drv2scb_mbox;

    event gen_next_event;
    //event driver_data_event;
 
    function new(virtual uart_rx_interface uart_rx_if);
        gen2drv_mbox = new();
        mon2scb_mbox = new();
        drv2scb_mbox = new();
        gen = new(gen2drv_mbox, gen_next_event);
        drv = new(gen2drv_mbox, drv2scb_mbox, uart_rx_if/*driver_data_event*/);
        mon = new(mon2scb_mbox, uart_rx_if);
        scb = new(mon2scb_mbox,drv2scb_mbox, gen_next_event);
    endfunction //new()

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
    endtask  //

    task reset();
        drv.reset();
    endtask

    task run();
        count=50;
        fork
            gen.run(count);
            drv.run();
            mon.run();
            scb.run();
        join_none
        wait(gen.total_count == count && scb.pass_count + scb.fail_count == count) #10;
        report();
        $display("finished");
        $stop;
    endtask
endclass //environment


module tb_uart_rx ();
    uart_rx_interface uart_rx_if ();
    environment env;

    uart_top dut(
        .clk(uart_rx_if.clk),
        .rst(uart_rx_if.rst),
        .rx(uart_rx_if.rx),
        .tx(uart_rx_if.tx),
        .o_rx_popdata(uart_rx_if.rx_data),
        .rx_trigger(uart_rx_if.rx_trigger)
    );

    always #5 uart_rx_if.clk = ~uart_rx_if.clk;

    initial begin
        env = new(uart_rx_if);
        env.reset();
        env.run();
    end
    
endmodule
