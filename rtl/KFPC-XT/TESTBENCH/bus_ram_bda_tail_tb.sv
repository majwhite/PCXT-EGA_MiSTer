`timescale 1ns/1ps
// Replay actual first-key MEMW bytes through the motherboard address latch,
// KF8288, BUS_ARBITER, RAM and KFSDRAM. DMA is idle; substitute only the 8237.
module KF8237 (
    input logic clock, cpu_ce_posedge, cpu_ce_negedge, reset, chip_select_n,
    input logic ready, hold_acknowledge,
    input logic [3:0] dma_request,
    input logic [7:0] data_bus_in,
    output logic [7:0] data_bus_out,
    input logic io_read_n_in,
    output logic io_read_n_out, io_read_n_io,
    input logic io_write_n_in,
    output logic io_write_n_out, io_write_n_io,
    input logic end_of_process_n_in,
    output logic end_of_process_n_out,
    input logic [3:0] address_in,
    output logic [15:0] address_out,
    output logic output_highst_address, hold_request,
    output logic [3:0] dma_acknowledge,
    output logic address_enable, address_strobe, memory_read_n, memory_write_n
);
    always_comb begin
        data_bus_out = 0;
        io_read_n_out = 1; io_read_n_io = 1;
        io_write_n_out = 1; io_write_n_io = 1;
        end_of_process_n_out = 1;
        address_out = 0; output_highst_address = 0; hold_request = 0;
        dma_acknowledge = 4'b1111; address_enable = 0; address_strobe = 0;
        memory_read_n = 1; memory_write_n = 1;
    end
endmodule

module bus_ram_bda_tail_tb;
    logic clock = 0, reset = 1, clk_select_load = 0;
    logic [1:0] clk_select = 0;
    wire cpu_clk_pin, cpu_ce_posedge, cpu_ce_negedge, peripheral_ce;
    wire cycle_accrate, shift_read_timing;
    wire [7:0] clock_cycle_counter_division_ratio, clock_cycle_counter_decrement_value;
    wire [1:0] ram_read_wait_cycle, ram_write_wait_cycle;
    logic [19:0] cpu_ad_out = 0, cpu_address = 0;
    logic [7:0] cpu_data_bus = 0;
    logic [2:0] processor_status = 3'b111;
    wire [19:0] address;
    wire [7:0] internal_data_bus;
    wire address_latch_enable, memory_read_n, memory_write_n, no_command_state;
    wire initialized_sdram;
    logic [6:0] map_ems [0:3];

    always #10 clock = ~clock;
    XT_CE_Generator u_XT_CE_Generator (
        .clock(clock), .reset(reset), .clk_select_load(clk_select_load),
        .clk_select(clk_select), .cpu_clk_pin(cpu_clk_pin),
        .cpu_ce_posedge(cpu_ce_posedge), .cpu_ce_negedge(cpu_ce_negedge),
        .peripheral_ce(peripheral_ce), .cycle_accrate(cycle_accrate),
        .clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing(shift_read_timing),
        .ram_read_wait_cycle(ram_read_wait_cycle), .ram_write_wait_cycle(ram_write_wait_cycle)
    );
    BUS_ARBITER u_BUS_ARBITER (
        .clock(clock), .cpu_ce_posedge(cpu_ce_posedge), .cpu_ce_negedge(cpu_ce_negedge),
        .reset(reset), .cpu_address(cpu_address), .cpu_data_bus(cpu_data_bus),
        .processor_status(processor_status), .processor_lock_n(1'b1),
        .processor_transmit_or_receive_n(), .dma_ready(1'b1), .dma_wait_n(),
        .interrupt_acknowledge_n(), .dma_chip_select_n(1'b1), .dma_page_chip_select_n(1'b1),
        .address(address), .address_ext(20'h00000), .address_direction(),
        .data_bus_ext(8'hFF), .internal_data_bus(internal_data_bus), .data_bus_direction(),
        .address_latch_enable(address_latch_enable),
        .io_read_n(), .io_read_n_ext(1'b1), .io_read_n_direction(),
        .io_write_n(), .io_write_n_ext(1'b1), .io_write_n_direction(),
        .memory_read_n(memory_read_n), .memory_read_n_ext(1'b1), .memory_read_n_direction(),
        .memory_write_n(memory_write_n), .memory_write_n_ext(1'b1), .memory_write_n_direction(),
        .no_command_state(no_command_state), .ext_access_request(1'b0),
        .dma_request(4'b0000), .dma_acknowledge_n(), .address_enable_n(), .terminal_count_n()
    );
    // Exact motherboard latch: do not feed a predecoded address into RAM.
    always @(posedge clock)
        if (address_latch_enable) cpu_address <= cpu_ad_out;

    RAM u_RAM (
        .clock(clock), .reset(reset), .enable_sdram(1'b1),
        .initilized_sdram(initialized_sdram), .address(address),
        .internal_data_bus(internal_data_bus), .data_bus_out(),
        .memory_read_n(memory_read_n), .memory_write_n(memory_write_n),
        .no_command_state(no_command_state), .memory_access_ready(), .ram_address_select_n(),
        .sdram_address(), .sdram_cke(), .sdram_cs(), .sdram_ras(), .sdram_cas(),
        .sdram_we(), .sdram_ba(), .sdram_dq_in(16'h0000), .sdram_dq_out(),
        .sdram_dq_io(), .sdram_ldqm(), .sdram_udqm(),
        .map_ems(map_ems), .ems_b1(1'b0), .ems_b2(1'b0), .ems_b3(1'b0), .ems_b4(1'b0),
        .umb_enabled(1'b1), .bios_protect_flag(3'b000),
        .wait_count_clk_en(cpu_ce_posedge),
        .ram_read_wait_cycle(ram_read_wait_cycle), .ram_write_wait_cycle(ram_write_wait_cycle),
        .word_read_request(1'b0), .word_write_request(1'b0), .data_bus_in_word(16'h0000),
        .data_bus_out_word(), .clk_select(clk_select)
    );

    // Passive simulator probes replace the old synthesised RAM trace ports.
    // Count acceptance and SDRAM issue separately; stale POST writes cannot
    // satisfy a later key-event assertion. No probe feeds production RTL.
    integer accepted_count [0:3];
    integer issued_count [0:3];
    logic [7:0] accepted_data [0:3];
    logic [7:0] issued_data [0:3];
    integer index;
    always @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                accepted_count[i] <= 0; issued_count[i] <= 0;
                accepted_data[i] <= 0; issued_data[i] <= 0;
            end
        end else begin
            if (u_RAM.state == u_RAM.IDLE && u_RAM.write_command &&
                address >= 20'h0041C && address <= 20'h0041F) begin
                index = int'(address - 20'h0041C);
                accepted_count[index] <= accepted_count[index] + 1;
                accepted_data[index] <= internal_data_bus;
            end
            if (u_RAM.state == u_RAM.RAM_WRITE_1 && u_RAM.write_flag &&
                u_RAM.latch_address >= 22'h0041C && u_RAM.latch_address <= 22'h0041F) begin
                index = int'(u_RAM.latch_address - 22'h0041C);
                issued_count[index] <= issued_count[index] + 1;
                issued_data[index] <= u_RAM.access_data_in[7:0];
            end
        end
    end

    task automatic issue_mem_write(input logic [19:0] write_address,
                                    input logic [7:0] write_data);
        @(posedge cpu_clk_pin); #1;
        cpu_ad_out = write_address;
        cpu_data_bus = write_data;
        processor_status = 3'b110;
        @(negedge memory_write_n);
        if (address !== write_address || internal_data_bus !== write_data)
            $fatal(1, "bus arbiter did not present requested MEMW transaction");
        @(posedge cpu_clk_pin); #1 processor_status = 3'b111;
        @(posedge memory_write_n); #1;
        // Poison both buses immediately on command release.
        cpu_ad_out = 20'hFFFFF; cpu_data_bus = 8'hF4;
        @(posedge cpu_clk_pin);
    endtask

    task automatic run_speed_mode(input logic [1:0] speed);
        integer accepted_base [0:3];
        integer issued_base [0:3];
        logic [7:0] expected [0:3];
        reset = 1;
        processor_status = 3'b111; cpu_ad_out = 0; cpu_data_bus = 0;
        clk_select = speed; clk_select_load = 1;
        repeat (8) @(posedge clock);
        @(negedge clock); reset = 0;
        @(posedge clock); #1 clk_select_load = 0;
        wait (initialized_sdram === 1'b1);
        issue_mem_write(20'h0041C, 8'h1E);
        issue_mem_write(20'h0041D, 8'h00);
        issue_mem_write(20'h0041E, 8'h00);
        issue_mem_write(20'h0041F, 8'h00);
        wait (issued_count[0] == 1 && issued_count[1] == 1 &&
              issued_count[2] == 1 && issued_count[3] == 1);
        for (int i = 0; i < 4; i++) begin
            accepted_base[i] = accepted_count[i]; issued_base[i] = issued_count[i];
        end
        expected[0] = 8'h20; expected[1] = 8'h00;
        expected[2] = 8'h61; expected[3] = 8'h1E;
        for (int i = 0; i < 4; i++) begin
            issue_mem_write(20'h0041C + 20'(i), expected[i]);
            wait (issued_count[i] > issued_base[i]);
        end
        // Include transaction completion/recovery before checking final counts.
        repeat (32) @(posedge clock);
        for (int i = 0; i < 4; i++) begin
            if (accepted_count[i] != accepted_base[i] + 1 ||
                issued_count[i] != issued_base[i] + 1 ||
                accepted_data[i] !== expected[i] || issued_data[i] !== expected[i])
                $fatal(1, "CLKSEL=%0d byte %0d: CPU=%02h SDRAM=%02h counts=%0d/%0d",
                       speed, i, accepted_data[i], issued_data[i],
                       accepted_count[i], issued_count[i]);
        end
        $display("PASS: CLKSEL=%0d committed tail 001E -> 0020 and queue 61:1E", speed);
    endtask

    initial begin
        for (int i = 0; i < 4; i++) map_ems[i] = 0;
        $dumpfile("bus_ram_bda_tail.vcd");
        $dumpvars(0, bus_ram_bda_tail_tb);
        for (int i = 0; i < 4; i++) run_speed_mode(2'(i));
        $display("PASS: all CLKSEL modes committed first-key BDA transactions through SDRAM");
        $finish;
    end
    initial begin
        #10000000;
        $fatal(1, "timeout waiting for BDA tail integration regression");
    end
endmodule
