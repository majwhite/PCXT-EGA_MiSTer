
module i8088
  (
    input               CORE_CLK,

    input               CLK,
    input               RESET,

    input               READY,
    input               INTR,
    input               NMI,

    output [19:0]       ad_out,
    output [7:0]    		dout,
    input  [7:0]        din,

    output              lock_n,
    output              s6_3_mux,
    output [2:0]        s2_s0_out,
    output [2:0]        SEGMENT,

    output              biu_done,
    input               cycle_accrate,
    input  [7:0]        clock_cycle_counter_division_ratio,
    input  [7:0]        clock_cycle_counter_decrement_value,
    input               shift_read_timing
`ifdef PC3086_POST_TRACE
    , output            DEBUG_NMI_CAUGHT
    , output [15:0]     DEBUG_CS
    , output [15:0]     DEBUG_PFQ_ADDR
    , output [15:0]     DEBUG_EU_BIU_DATAOUT
    , output [15:0]     DEBUG_EU_AX
    , output [15:0]     DEBUG_EU_BX
    , output [15:0]     DEBUG_EU_CX
    , output [15:0]     DEBUG_EU_DX
    , output [15:0]     DEBUG_BIU_DATA_LATCH
    , output [7:0]      DEBUG_BIU_STATE
    , output [12:0]     DEBUG_EU_DATAOUT_UADDR
    , output [15:0]     DEBUG_EU_DATAOUT_ALU
    , output [19:0]     DEBUG_BIU_WRITE_ADDRESS
    , output [7:0]      DEBUG_BIU_WRITE_CODE
    , output [15:0]     DEBUG_BIU_WRITE_REQUEST_DATA
    , output [15:0]     DEBUG_BIU_WRITE_T1_DATA
    , output [12:0]     DEBUG_BIU_WRITE_EU_UADDR
    , output [15:0]     DEBUG_BIU_WRITE_EU_ALU
    , output [15:0]     DEBUG_BIU_WRITE_EU_AX
    , output [15:0]     DEBUG_BIU_WRITE_EU_BX
`endif

  );

//------------------------------------------------------------------------
// Internal Signals

wire t_eu_prefix_lock;
wire t_eu_flag_i;
wire t_pfq_empty;
wire t_biu_done;
wire t_biu_clk_counter_zero;
wire t_biu_ad_oe;
wire t_biu_nmi_caught;
wire t_biu_nmi_debounce;
wire t_biu_intr;
wire [15:0] t_eu_biu_command;
wire [15:0] t_eu_biu_dataout;
wire [15:0] t_eu_register_r3;
`ifdef PC3086_POST_TRACE
wire [15:0] t_eu_ax;
wire [15:0] t_eu_bx;
wire [15:0] t_eu_cx;
wire [15:0] t_eu_dx;
wire [15:0] t_biu_data_latch;
wire [7:0]  t_biu_state;
wire [12:0] t_eu_dataout_uaddr;
wire [15:0] t_eu_dataout_alu;
wire [19:0] t_biu_write_address;
wire [7:0]  t_biu_write_code;
wire [15:0] t_biu_write_request_data;
wire [15:0] t_biu_write_t1_data;
wire [12:0] t_biu_write_eu_uaddr;
wire [15:0] t_biu_write_eu_alu;
wire [15:0] t_biu_write_eu_ax;
wire [15:0] t_biu_write_eu_bx;
`endif
wire [7:0]  t_pfq_top_byte;
wire [15:0] t_pfq_addr_out;
wire [15:0] t_biu_register_es;
wire [15:0] t_biu_register_ss;
wire [15:0] t_biu_register_cs;
wire [15:0] t_biu_register_ds;
wire [15:0] t_biu_register_rm;
wire [15:0] t_biu_register_reg;
wire [15:0] t_biu_return_data;

//------------------------------------------------------------------------
// Outputs
//------------------------------------------------------------------------

assign dout = ad_out[7:0];
assign biu_done = t_biu_done;
`ifdef PC3086_POST_TRACE
assign DEBUG_NMI_CAUGHT = t_biu_nmi_caught;
assign DEBUG_CS = t_biu_register_cs;
assign DEBUG_PFQ_ADDR = t_pfq_addr_out;
// The write datum before the BIU multiplexes it onto AD[7:0]. This is a
// debug-only observation point for the PC3086 RAM-write investigation.
assign DEBUG_EU_BIU_DATAOUT = t_eu_biu_dataout;
assign DEBUG_EU_AX = t_eu_ax;
assign DEBUG_EU_BX = t_eu_bx;
assign DEBUG_EU_CX = t_eu_cx;
assign DEBUG_EU_DX = t_eu_dx;
assign DEBUG_BIU_DATA_LATCH = t_biu_data_latch;
assign DEBUG_BIU_STATE = t_biu_state;
assign DEBUG_EU_DATAOUT_UADDR = t_eu_dataout_uaddr;
assign DEBUG_EU_DATAOUT_ALU = t_eu_dataout_alu;
assign DEBUG_BIU_WRITE_ADDRESS = t_biu_write_address;
assign DEBUG_BIU_WRITE_CODE = t_biu_write_code;
assign DEBUG_BIU_WRITE_REQUEST_DATA = t_biu_write_request_data;
assign DEBUG_BIU_WRITE_T1_DATA = t_biu_write_t1_data;
assign DEBUG_BIU_WRITE_EU_UADDR = t_biu_write_eu_uaddr;
assign DEBUG_BIU_WRITE_EU_ALU = t_biu_write_eu_alu;
assign DEBUG_BIU_WRITE_EU_AX = t_biu_write_eu_ax;
assign DEBUG_BIU_WRITE_EU_BX = t_biu_write_eu_bx;
`endif

//------------------------------------------------------------------------
// BIU Core
//------------------------------------------------------------------------ 
biu_max                     BIU_CORE
  (
    .CORE_CLK_INT           (CORE_CLK),
    .RESET_INT              (RESET),
    .CLK                    (CLK),
    .READY_IN               (READY),
    .NMI                    (NMI),
    .INTR                   (INTR),
    .AD_OE                  (t_biu_ad_oe),
    .AD_OUT                 (ad_out),
    .AD_IN                  (din),
    .LOCK_n                 (lock_n),
    .S6_3_MUX               (s6_3_mux),
    .S2_S0_OUT              (s2_s0_out),
    .EU_BIU_COMMAND         (t_eu_biu_command),
    .EU_BIU_DATAOUT         (t_eu_biu_dataout),
    .EU_REGISTER_R3         (t_eu_register_r3),
    .EU_PREFIX_LOCK         (t_eu_prefix_lock),
    .BIU_DONE               (t_biu_done),
    .BIU_CLK_COUNTER_ZERO   (t_biu_clk_counter_zero),
    .BIU_SEGMENT            (SEGMENT),
    .BIU_NMI_CAUGHT         (t_biu_nmi_caught),
    .BIU_NMI_DEBOUNCE       (t_biu_nmi_debounce),
    .BIU_INTR               (t_biu_intr),
    .PFQ_TOP_BYTE           (t_pfq_top_byte),
    .PFQ_EMPTY              (t_pfq_empty),
    .PFQ_ADDR_OUT           (t_pfq_addr_out),
    .BIU_REGISTER_ES        (t_biu_register_es),
    .BIU_REGISTER_SS        (t_biu_register_ss),
    .BIU_REGISTER_CS        (t_biu_register_cs),
    .BIU_REGISTER_DS        (t_biu_register_ds),
    .BIU_REGISTER_RM        (t_biu_register_rm),
    .BIU_REGISTER_REG       (t_biu_register_reg),
    .BIU_RETURN_DATA        (t_biu_return_data),

    .clock_cycle_counter_division_ratio     (clock_cycle_counter_division_ratio),
    .clock_cycle_counter_decrement_value    (clock_cycle_counter_decrement_value),
    .shift_read_timing                      (shift_read_timing)
`ifdef PC3086_POST_TRACE
    ,.DEBUG_EU_DATAOUT_UADDR                (t_eu_dataout_uaddr)
    ,.DEBUG_EU_DATAOUT_ALU                  (t_eu_dataout_alu)
    ,.DEBUG_EU_AX                           (t_eu_ax)
    ,.DEBUG_EU_BX                           (t_eu_bx)
    ,.DEBUG_DATA_OUT_LATCH                  (t_biu_data_latch)
    ,.DEBUG_STATE                           (t_biu_state)
    ,.DEBUG_WRITE_ADDRESS                   (t_biu_write_address)
    ,.DEBUG_WRITE_CODE                      (t_biu_write_code)
    ,.DEBUG_WRITE_REQUEST_DATA              (t_biu_write_request_data)
    ,.DEBUG_WRITE_T1_DATA                   (t_biu_write_t1_data)
    ,.DEBUG_WRITE_EU_UADDR                  (t_biu_write_eu_uaddr)
    ,.DEBUG_WRITE_EU_ALU                    (t_biu_write_eu_alu)
    ,.DEBUG_WRITE_EU_AX                     (t_biu_write_eu_ax)
    ,.DEBUG_WRITE_EU_BX                     (t_biu_write_eu_bx)
`endif
  );

//------------------------------------------------------------------------
// EU Core
//------------------------------------------------------------------------

mcl86_eu_core               EU_CORE
  (
    .CORE_CLK_INT           (CORE_CLK),
    .RESET_INT              (RESET),
    .TEST_N_INT             (1'b0),
    .EU_BIU_COMMAND         (t_eu_biu_command),
    .EU_BIU_DATAOUT         (t_eu_biu_dataout),
    .EU_REGISTER_R3         (t_eu_register_r3),
    .EU_PREFIX_LOCK         (t_eu_prefix_lock),
    .EU_FLAG_I              (t_eu_flag_i),
`ifdef PC3086_POST_TRACE
    .DEBUG_EU_AX            (t_eu_ax),
    .DEBUG_EU_BX            (t_eu_bx),
    .DEBUG_EU_CX            (t_eu_cx),
    .DEBUG_EU_DX            (t_eu_dx),
    .DEBUG_EU_DATAOUT_UADDR (t_eu_dataout_uaddr),
    .DEBUG_EU_DATAOUT_ALU   (t_eu_dataout_alu),
`endif
    .BIU_DONE               (t_biu_done),
    .BIU_CLK_COUNTER_ZERO   (cycle_accrate ? t_biu_clk_counter_zero : 1'b1),
    .BIU_NMI_CAUGHT         (t_biu_nmi_caught),
    .BIU_NMI_DEBOUNCE       (t_biu_nmi_debounce),
    .BIU_INTR               (t_biu_intr),
    .PFQ_TOP_BYTE           (t_pfq_top_byte),
    .PFQ_EMPTY              (t_pfq_empty),
    .PFQ_ADDR_OUT           (t_pfq_addr_out),
    .BIU_REGISTER_ES        (t_biu_register_es),
    .BIU_REGISTER_SS        (t_biu_register_ss),
    .BIU_REGISTER_CS        (t_biu_register_cs),
    .BIU_REGISTER_DS        (t_biu_register_ds),
    .BIU_REGISTER_RM        (t_biu_register_rm),
    .BIU_REGISTER_REG       (t_biu_register_reg),
    .BIU_RETURN_DATA        (t_biu_return_data)
  );



endmodule
