// CPU-side maximum-mode transaction replay for the PC3086 keyboard BDA tail.
//
// This is intentionally an integration test, not another CPU unit test.  It
// replays the four real first-key 8088 MEMW cycles through KF8288,
// BUS_ARBITER, RAM and KFSDRAM. The CPU regression proves the 8088 emits the
// cycles; this proves that the system-side path accepts and commits the BDA
// tail and translated queue word after the CPU bus has released them.
//
// The 8237 is electrically idle for this CPU-owned cycle.  Icarus Verilog
// cannot elaborate a few unpacked-array assignments in the production 8237,
// so this testbench provides a deliberately inert replacement with its exact
// interface.  BUS_ARBITER, including its CPU/KF8288 command path, remains the
// production RTL under test.
module KF8237 (
    input logic clock, input logic cpu_ce_posedge, input logic cpu_ce_negedge,
    input logic reset, input logic chip_select_n, input logic ready,
    input logic hold_acknowledge, input logic [3:0] dma_request,
    input logic [7:0] data_bus_in, output logic [7:0] data_bus_out,
    input logic io_read_n_in, output logic io_read_n_out,
    output logic io_read_n_io, input logic io_write_n_in,
    output logic io_write_n_out, output logic io_write_n_io,
    input logic end_of_process_n_in, output logic end_of_process_n_out,
    input logic [3:0] address_in, output logic [15:0] address_out,
    output logic output_highst_address, output logic hold_request,
    output logic [3:0] dma_acknowledge, output logic address_enable,
    output logic address_strobe, output logic memory_read_n,
    output logic memory_write_n
);
    always_comb begin
        data_bus_out = 8'h00;
        io_read_n_out = 1'b1;
        io_read_n_io = 1'b1;
        io_write_n_out = 1'b1;
        io_write_n_io = 1'b1;
        end_of_process_n_out = 1'b1;
        address_out = 16'h0000;
        output_highst_address = 1'b0;
        hold_request = 1'b0;
        dma_acknowledge = 4'b1111;
        address_enable = 1'b0;
        address_strobe = 1'b0;
        memory_read_n = 1'b1;
        memory_write_n = 1'b1;
    end
endmodule

module bus_ram_bda_tail_tb;
    logic           clock = 1'b0;
    logic           reset = 1'b1;
    logic           clk_select_load;
    logic   [1:0]   clk_select;

    logic           cpu_clk_pin;
    logic           cpu_ce_posedge;
    logic           cpu_ce_negedge;
    logic           peripheral_ce;
    logic           cycle_accrate;
    logic   [7:0]   clock_cycle_counter_division_ratio;
    logic   [7:0]   clock_cycle_counter_decrement_value;
    logic           shift_read_timing;
    logic   [1:0]   ram_read_wait_cycle;
    logic   [1:0]   ram_write_wait_cycle;

    logic   [19:0]  cpu_ad_out;
    logic   [19:0]  cpu_address;
    logic   [7:0]   cpu_data_bus;
    logic   [2:0]   processor_status;
    logic           processor_transmit_or_receive_n;
    logic           dma_wait_n;
    logic           interrupt_acknowledge_n;
    logic   [19:0]  address;
    logic   [7:0]   internal_data_bus;
    logic           memory_read_n;
    logic           memory_write_n;
    logic           no_command_state;
    logic           address_enable_n;
    logic           address_latch_enable;

    logic           initialized_sdram;
    logic   [7:0]   data_bus_out;
    logic           memory_access_ready;
    logic           ram_address_select_n;
    logic   [12:0]  sdram_address;
    logic           sdram_cke;
    logic           sdram_cs;
    logic           sdram_ras;
    logic           sdram_cas;
    logic           sdram_we;
    logic   [1:0]   sdram_ba;
    logic   [15:0]  sdram_dq_out;
    logic           sdram_dq_io;
    logic           sdram_ldqm;
    logic           sdram_udqm;
    logic   [6:0]   map_ems [0:3];

    logic   [7:0]   debug_tail_write_cpu_low;
    logic   [7:0]   debug_tail_write_cpu_high;
    logic   [7:0]   debug_tail_write_sdram_low;
    logic   [7:0]   debug_tail_write_sdram_high;
    logic   [7:0]   debug_tail_write_queue_cpu_low;
    logic   [7:0]   debug_tail_write_queue_cpu_high;
    logic   [7:0]   debug_tail_write_queue_sdram_low;
    logic   [7:0]   debug_tail_write_queue_sdram_high;
    logic   [1:0]   debug_tail_write_cpu_valid;
    logic   [1:0]   debug_tail_write_sdram_valid;
    logic   [1:0]   debug_tail_write_queue_cpu_valid;
    logic   [1:0]   debug_tail_write_queue_sdram_valid;
    logic   [3:0]   debug_tail_write_cpu_low_count;
    logic   [3:0]   debug_tail_write_cpu_high_count;
    logic   [3:0]   debug_tail_write_queue_cpu_low_count;
    logic   [3:0]   debug_tail_write_queue_cpu_high_count;
    logic   [3:0]   debug_tail_write_sdram_low_count;
    logic   [3:0]   debug_tail_write_sdram_high_count;
    logic   [3:0]   debug_tail_write_queue_sdram_low_count;
    logic   [3:0]   debug_tail_write_queue_sdram_high_count;

    // MiSTer chipset clock is 50 MHz.
    always #10 clock = ~clock;

    XT_CE_Generator u_XT_CE_Generator (
        .clock                              (clock),
        .reset                              (reset),
        .clk_select_load                    (clk_select_load),
        .clk_select                         (clk_select),
        .cpu_clk_pin                        (cpu_clk_pin),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .peripheral_ce                      (peripheral_ce),
        .cycle_accrate                      (cycle_accrate),
        .clock_cycle_counter_division_ratio (clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing                  (shift_read_timing),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle)
    );

    BUS_ARBITER u_BUS_ARBITER (
        .clock                              (clock),
        .cpu_ce_posedge                     (cpu_ce_posedge),
        .cpu_ce_negedge                     (cpu_ce_negedge),
        .reset                              (reset),
        .cpu_address                        (cpu_address),
        .cpu_data_bus                       (cpu_data_bus),
        .processor_status                   (processor_status),
        .processor_lock_n                   (1'b1),
        .processor_transmit_or_receive_n    (processor_transmit_or_receive_n),
        .dma_ready                          (1'b1),
        .dma_wait_n                         (dma_wait_n),
        .interrupt_acknowledge_n            (interrupt_acknowledge_n),
        .dma_chip_select_n                  (1'b1),
        .dma_page_chip_select_n             (1'b1),
        .address                            (address),
        .address_ext                        (20'h00000),
        .address_direction                  (),
        .data_bus_ext                       (8'hFF),
        .internal_data_bus                  (internal_data_bus),
        .data_bus_direction                 (),
        .address_latch_enable               (address_latch_enable),
        .io_read_n                          (),
        .io_read_n_ext                      (1'b1),
        .io_read_n_direction                (),
        .io_write_n                         (),
        .io_write_n_ext                     (1'b1),
        .io_write_n_direction               (),
        .memory_read_n                      (memory_read_n),
        .memory_read_n_ext                  (1'b1),
        .memory_read_n_direction            (),
        .memory_write_n                     (memory_write_n),
        .memory_write_n_ext                 (1'b1),
        .memory_write_n_direction           (),
        .no_command_state                   (no_command_state),
        .ext_access_request                 (1'b0),
        .dma_request                        (4'b0000),
        .dma_acknowledge_n                  (),
        .address_enable_n                   (address_enable_n),
        .terminal_count_n                   ()
    );

    // This is the live CPU address latch from PCXT-EGA.sv.  The regression
    // drives cpu_ad_out, rather than bypassing this latch with a predecoded
    // address, so the checked path includes the motherboard boundary.
    always @(posedge clock)
    begin
        if (address_latch_enable)
            cpu_address <= cpu_ad_out;
        else
            cpu_address <= cpu_address;
    end

    RAM u_RAM (
        .clock                              (clock),
        .reset                              (reset),
        .enable_sdram                       (1'b1),
        .initilized_sdram                   (initialized_sdram),
        .address                            (address),
        .internal_data_bus                  (internal_data_bus),
        .data_bus_out                       (data_bus_out),
        .memory_read_n                      (memory_read_n),
        .memory_write_n                     (memory_write_n),
        .no_command_state                   (no_command_state),
        .memory_access_ready                (memory_access_ready),
        .ram_address_select_n               (ram_address_select_n),
        .sdram_address                      (sdram_address),
        .sdram_cke                          (sdram_cke),
        .sdram_cs                           (sdram_cs),
        .sdram_ras                          (sdram_ras),
        .sdram_cas                          (sdram_cas),
        .sdram_we                           (sdram_we),
        .sdram_ba                           (sdram_ba),
        .sdram_dq_in                        (16'h0000),
        .sdram_dq_out                       (sdram_dq_out),
        .sdram_dq_io                        (sdram_dq_io),
        .sdram_ldqm                         (sdram_ldqm),
        .sdram_udqm                         (sdram_udqm),
        .map_ems                            (map_ems),
        .ems_b1                             (1'b0),
        .ems_b2                             (1'b0),
        .ems_b3                             (1'b0),
        .ems_b4                             (1'b0),
        .umb_enabled                        (1'b1),
        .bios_protect_flag                  (3'b000),
        .wait_count_clk_en                  (cpu_ce_posedge),
        .ram_read_wait_cycle                (ram_read_wait_cycle),
        .ram_write_wait_cycle               (ram_write_wait_cycle),
        .debug_tail_write_cpu_low           (debug_tail_write_cpu_low),
        .debug_tail_write_cpu_high          (debug_tail_write_cpu_high),
        .debug_tail_write_sdram_low         (debug_tail_write_sdram_low),
        .debug_tail_write_sdram_high        (debug_tail_write_sdram_high),
        .debug_tail_write_queue_cpu_low     (debug_tail_write_queue_cpu_low),
        .debug_tail_write_queue_cpu_high    (debug_tail_write_queue_cpu_high),
        .debug_tail_write_queue_sdram_low   (debug_tail_write_queue_sdram_low),
        .debug_tail_write_queue_sdram_high  (debug_tail_write_queue_sdram_high),
        .debug_tail_write_cpu_valid         (debug_tail_write_cpu_valid),
        .debug_tail_write_sdram_valid       (debug_tail_write_sdram_valid),
        .debug_tail_write_queue_cpu_valid   (debug_tail_write_queue_cpu_valid),
        .debug_tail_write_queue_sdram_valid (debug_tail_write_queue_sdram_valid),
        .debug_tail_write_cpu_low_count     (debug_tail_write_cpu_low_count),
        .debug_tail_write_cpu_high_count    (debug_tail_write_cpu_high_count),
        .debug_tail_write_queue_cpu_low_count(debug_tail_write_queue_cpu_low_count),
        .debug_tail_write_queue_cpu_high_count(debug_tail_write_queue_cpu_high_count),
        .debug_tail_write_sdram_low_count   (debug_tail_write_sdram_low_count),
        .debug_tail_write_sdram_high_count  (debug_tail_write_sdram_high_count),
        .debug_tail_write_queue_sdram_low_count(debug_tail_write_queue_sdram_low_count),
        .debug_tail_write_queue_sdram_high_count(debug_tail_write_queue_sdram_high_count)
    );

    // Drive a complete maximum-mode memory-write bus cycle at normal XT
    // timing.  The bus is deliberately poisoned as soon as MEMW releases;
    // success therefore proves RAM froze the correct address and data.
    task automatic issue_mem_write(input logic [19:0] write_address,
                                   input logic [7:0] write_data);
        begin
            @(posedge cpu_clk_pin);
            #1;
            cpu_ad_out       = write_address;
            cpu_data_bus     = write_data;
            processor_status = 3'b110;

            @(negedge memory_write_n);
            $display("MEMW asserted addr=%05h data=%02h", address, internal_data_bus);
            if (address !== write_address || internal_data_bus !== write_data)
                $fatal(1, "bus arbiter did not present requested MEMW transaction");

            // Restore passive status in time for the following falling CPU
            // edge, which releases the 8288 write command.
            @(posedge cpu_clk_pin);
            #1 processor_status = 3'b111;
            @(posedge memory_write_n);
            #1;
            cpu_ad_out   = 20'hFFFFF;
            cpu_data_bus = 8'hF4;

            // Complete the passive T4/recovery phase before another bus
            // cycle.  The motherboard latch is intentionally only open in
            // that cycle's ALE window; the real 8088 likewise cannot launch
            // the following status cycle at the same edge that MEMW releases.
            @(posedge cpu_clk_pin);
        end
    endtask

    task automatic check_first_key_result(
        input logic [1:0] speed,
        input logic [3:0] cpu_low_base,
        input logic [3:0] cpu_high_base,
        input logic [3:0] queue_cpu_low_base,
        input logic [3:0] queue_cpu_high_base,
        input logic [3:0] sdram_low_base,
        input logic [3:0] sdram_high_base,
        input logic [3:0] queue_sdram_low_base,
        input logic [3:0] queue_sdram_high_base
    );
        begin
            if (debug_tail_write_cpu_valid !== 2'b11 ||
                debug_tail_write_cpu_low !== 8'h20 ||
                debug_tail_write_cpu_high !== 8'h00 ||
                debug_tail_write_sdram_low !== 8'h20 ||
                debug_tail_write_sdram_high !== 8'h00 ||
                debug_tail_write_queue_cpu_valid !== 2'b11 ||
                debug_tail_write_queue_cpu_low !== 8'h61 ||
                debug_tail_write_queue_cpu_high !== 8'h1E ||
                debug_tail_write_queue_sdram_valid !== 2'b11 ||
                debug_tail_write_queue_sdram_low !== 8'h61 ||
                debug_tail_write_queue_sdram_high !== 8'h1E ||
                debug_tail_write_cpu_low_count != cpu_low_base + 4'd1 ||
                debug_tail_write_cpu_high_count != cpu_high_base + 4'd1 ||
                debug_tail_write_queue_cpu_low_count != queue_cpu_low_base + 4'd1 ||
                debug_tail_write_queue_cpu_high_count != queue_cpu_high_base + 4'd1 ||
                debug_tail_write_sdram_low_count != sdram_low_base + 4'd1 ||
                debug_tail_write_sdram_high_count != sdram_high_base + 4'd1 ||
                debug_tail_write_queue_sdram_low_count != queue_sdram_low_base + 4'd1 ||
                debug_tail_write_queue_sdram_high_count != queue_sdram_high_base + 4'd1)
                $fatal(1, "speed %0d post-handshake first-key mismatch: tail CPU=%02h/%02h SDRAM=%02h/%02h queue=%02h/%02h",
                       speed, debug_tail_write_cpu_low, debug_tail_write_cpu_high,
                       debug_tail_write_sdram_low, debug_tail_write_sdram_high,
                       debug_tail_write_queue_cpu_low, debug_tail_write_queue_cpu_high);
        end
    endtask

    // Test every synthesised clock-selection mode without recompiling an RBF.
    // Resetting here intentionally clears RAM's trace probes between rows, so
    // each mode has an independent one-write-per-byte assertion.
    task automatic run_speed_mode(input logic [1:0] speed);
        logic [3:0] cpu_low_base;
        logic [3:0] cpu_high_base;
        logic [3:0] queue_cpu_low_base;
        logic [3:0] queue_cpu_high_base;
        logic [3:0] sdram_low_base;
        logic [3:0] sdram_high_base;
        logic [3:0] queue_sdram_low_base;
        logic [3:0] queue_sdram_high_base;
        begin
            reset = 1'b1;
            processor_status = 3'b111;
            cpu_ad_out = 20'h00000;
            cpu_data_bus = 8'h00;
            clk_select = speed;
            clk_select_load = 1'b1;
            repeat (8) @(posedge clock);
            @(negedge clock);
            reset = 1'b0;
            @(posedge clock);
            #1 clk_select_load = 1'b0;

            // The complete SDRAM power-up sequence is exercised for each
            // independent mode run, rather than assuming an already-idle RAM.
            wait (initialized_sdram === 1'b1);
            // Reproduce the real boot condition: the BDA addresses have
            // already been written before the first user key arrives. The
            // diagnostic must use a baseline at the keyboard handshake, not
            // the sticky "seen since reset" flags.
            issue_mem_write(20'h0041C, 8'h1E);
            issue_mem_write(20'h0041D, 8'h00);
            issue_mem_write(20'h0041E, 8'h00);
            issue_mem_write(20'h0041F, 8'h00);
            wait (debug_tail_write_sdram_valid == 2'b11 &&
                  debug_tail_write_queue_sdram_valid == 2'b11);
            cpu_low_base = debug_tail_write_cpu_low_count;
            cpu_high_base = debug_tail_write_cpu_high_count;
            queue_cpu_low_base = debug_tail_write_queue_cpu_low_count;
            queue_cpu_high_base = debug_tail_write_queue_cpu_high_count;
            sdram_low_base = debug_tail_write_sdram_low_count;
            sdram_high_base = debug_tail_write_sdram_high_count;
            queue_sdram_low_base = debug_tail_write_queue_sdram_low_count;
            queue_sdram_high_base = debug_tail_write_queue_sdram_high_count;

            $display("SDRAM initialised; replaying post-handshake first keyboard word at CLKSEL=%0d", speed);

            issue_mem_write(20'h0041C, 8'h20);
            wait (debug_tail_write_sdram_low_count != sdram_low_base);
            issue_mem_write(20'h0041D, 8'h00);
            wait (debug_tail_write_sdram_high_count != sdram_high_base);
            issue_mem_write(20'h0041E, 8'h61);
            wait (debug_tail_write_queue_sdram_low_count != queue_sdram_low_base);
            issue_mem_write(20'h0041F, 8'h1E);
            wait (debug_tail_write_queue_sdram_high_count != queue_sdram_high_base);
            check_first_key_result(speed, cpu_low_base, cpu_high_base,
                                   queue_cpu_low_base, queue_cpu_high_base,
                                   sdram_low_base, sdram_high_base,
                                   queue_sdram_low_base, queue_sdram_high_base);
            $display("PASS: CLKSEL=%0d ignored stale BDA stores and committed tail 001E -> 0020 and queue 61:1E", speed);
        end
    endtask

    initial begin
        map_ems[0] = 7'h00;
        map_ems[1] = 7'h00;
        map_ems[2] = 7'h00;
        map_ems[3] = 7'h00;
        cpu_ad_out = 20'h00000;
        cpu_address = 20'h00000;
        cpu_data_bus = 8'h00;
        processor_status = 3'b111;
        clk_select = 2'b00;
        clk_select_load = 1'b0;

        $dumpfile("bus_ram_bda_tail.vcd");
        $dumpvars(0, bus_ram_bda_tail_tb);

        run_speed_mode(2'b00);
        run_speed_mode(2'b01);
        run_speed_mode(2'b10);
        run_speed_mode(2'b11);
        $display("PASS: all CLKSEL modes committed first-key BDA transaction through KF8288 -> BUS_ARBITER -> RAM -> KFSDRAM");
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "timeout waiting for BDA tail integration regression");
    end
endmodule
