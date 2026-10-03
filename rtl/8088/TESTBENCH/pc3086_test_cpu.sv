`timescale 1ns/1ps
// Simulation-only facade for the historical PC3086 fixtures. The production
// wrapper stays free of trace ports; all probes below are passive observations.
module pc3086_test_cpu (
    input CORE_CLK, CLK, RESET, READY, INTR, NMI,
    output [19:0] ad_out,
    output [7:0] dout,
    input [7:0] din,
    output lock_n, s6_3_mux,
    output [2:0] s2_s0_out, SEGMENT,
    output biu_done,
    input cycle_accrate,
    input [7:0] clock_cycle_counter_division_ratio,
    input [7:0] clock_cycle_counter_decrement_value,
    input shift_read_timing,
    output DEBUG_NMI_CAUGHT,
    output [15:0] DEBUG_CS, DEBUG_PFQ_ADDR, DEBUG_EU_BIU_DATAOUT,
    output [15:0] DEBUG_EU_AX, DEBUG_EU_BX, DEBUG_EU_CX, DEBUG_EU_DX,
    output reg [12:0] DEBUG_EU_DATAOUT_UADDR,
    output reg [15:0] DEBUG_EU_DATAOUT_ALU,
    output [15:0] DEBUG_BIU_DATA_LATCH,
    output [7:0] DEBUG_BIU_STATE,
    output reg [19:0] DEBUG_BIU_WRITE_ADDRESS,
    output reg [7:0] DEBUG_BIU_WRITE_CODE,
    output reg [15:0] DEBUG_BIU_WRITE_REQUEST_DATA, DEBUG_BIU_WRITE_T1_DATA,
    output reg [12:0] DEBUG_BIU_WRITE_EU_UADDR,
    output reg [15:0] DEBUG_BIU_WRITE_EU_ALU,
    output reg [15:0] DEBUG_BIU_WRITE_EU_AX, DEBUG_BIU_WRITE_EU_BX
);
    i8088 cpu (
        .CORE_CLK(CORE_CLK), .CLK(CLK), .RESET(RESET), .READY(READY),
        .INTR(INTR), .NMI(NMI), .ad_out(ad_out), .dout(dout), .din(din),
        .lock_n(lock_n), .s6_3_mux(s6_3_mux), .s2_s0_out(s2_s0_out),
        .SEGMENT(SEGMENT), .biu_done(biu_done), .cycle_accrate(cycle_accrate),
        .clock_cycle_counter_division_ratio(clock_cycle_counter_division_ratio),
        .clock_cycle_counter_decrement_value(clock_cycle_counter_decrement_value),
        .shift_read_timing(shift_read_timing),
        .is8086(1'b0), .fake286_flags(1'b0), .word_read_request(),
        .word_write_request(), .data_bus_word_out(), .data_bus_word(16'h0000),
        .word_access_possible(1'b0)
    );
    assign DEBUG_NMI_CAUGHT = cpu.t_biu_nmi_caught;
    assign DEBUG_CS = cpu.t_biu_register_cs;
    assign DEBUG_PFQ_ADDR = cpu.t_pfq_addr_out;
    assign DEBUG_EU_BIU_DATAOUT = cpu.t_eu_biu_dataout;
    assign DEBUG_EU_AX = cpu.u_eu_core.eu_register_ax;
    assign DEBUG_EU_BX = cpu.u_eu_core.eu_register_bx;
    assign DEBUG_EU_CX = cpu.u_eu_core.eu_register_cx;
    assign DEBUG_EU_DX = cpu.u_eu_core.eu_register_dx;
    // This is the current operand, not a claim that the BIU has latched it.
    assign DEBUG_BIU_DATA_LATCH = cpu.t_eu_biu_dataout;
    assign DEBUG_BIU_STATE = cpu.u_biu_core.biu_state;

    always @(posedge CORE_CLK) begin
        if (RESET) begin
            DEBUG_EU_DATAOUT_UADDR <= 0;
            DEBUG_EU_DATAOUT_ALU <= 0;
            DEBUG_BIU_WRITE_ADDRESS <= 0;
            DEBUG_BIU_WRITE_CODE <= 0;
            DEBUG_BIU_WRITE_REQUEST_DATA <= 0;
            DEBUG_BIU_WRITE_T1_DATA <= 0;
            DEBUG_BIU_WRITE_EU_UADDR <= 0;
            DEBUG_BIU_WRITE_EU_ALU <= 0;
            DEBUG_BIU_WRITE_EU_AX <= 0;
            DEBUG_BIU_WRITE_EU_BX <= 0;
        end else begin
            if (!cpu.u_eu_core.eu_stall_pipeline &&
                cpu.u_eu_core.eu_opcode_type >= 3'h2 &&
                cpu.u_eu_core.eu_opcode_dst_sel == 4'hF) begin
                DEBUG_EU_DATAOUT_UADDR <= cpu.u_eu_core.eu_rom_address;
                DEBUG_EU_DATAOUT_ALU <= cpu.u_eu_core.eu_alu_out[15:0];
            end
            if (cpu.u_biu_core.biu_state == 8'h02 &&
                cpu.u_biu_core.s_bits == 3'b110) begin
                DEBUG_BIU_WRITE_ADDRESS <= cpu.u_biu_core.addr_out_temp_base +
                                           cpu.u_biu_core.addr_out_temp_offset;
                DEBUG_BIU_WRITE_CODE <= cpu.u_biu_core.eu_biu_req_code;
                DEBUG_BIU_WRITE_REQUEST_DATA <= cpu.t_eu_biu_dataout;
                DEBUG_BIU_WRITE_T1_DATA <= cpu.t_eu_biu_dataout;
                DEBUG_BIU_WRITE_EU_UADDR <= DEBUG_EU_DATAOUT_UADDR;
                DEBUG_BIU_WRITE_EU_ALU <= DEBUG_EU_DATAOUT_ALU;
                DEBUG_BIU_WRITE_EU_AX <= DEBUG_EU_AX;
                DEBUG_BIU_WRITE_EU_BX <= DEBUG_EU_BX;
            end
        end
    end
endmodule
