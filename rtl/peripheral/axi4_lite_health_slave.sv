// REGISTER MAP (offsets from HEALTH_BASE = 0x2000_2000)
//
//   Offset   Name              Access   Description
//   0x000    ECC_CORR_CNT      R        IMEM+DMEM single-bit corrections
//   0x004    ECC_DET_CNT       R        IMEM+DMEM double-bit detections
//   0x008    TMR_PC_CNT        R        PC TMR voter mismatches
//   0x00C    TMR_FSM_CNT       R        FSM TMR voter mismatches
//   0x010    TMR_RF_CNT        R        Regfile TMR voter mismatches
//   0x014    TMR_IR_CNT        R        IR TMR voter mismatches
//   0x018    STATUS            R        Live fault signal values (bit-packed)
//   0x01C    IRQ_MASK          R/W      Bit[n]=1 enables event n to fire IRQ
//   0x020    IRQ_STATUS        R/W1C    Latched event flags, write 1 to clear
//   0x024    CTRL              W        Bit[0]=1 clears all counters (pulse)
//

module axi4_lite_health_slave (
    input  logic clk,
    input  logic rst_n,
    input  logic [31:0] s_awaddr,
    input  logic        s_awvalid,
    output logic        s_awready,

    input  logic [31:0] s_wdata,
    input  logic [3:0]  s_wstrb,
    input  logic        s_wvalid,
    output logic        s_wready,

    output logic [1:0]  s_bresp,
    output logic        s_bvalid,
    input  logic        s_bready,

    input  logic [31:0] s_araddr,
    input  logic        s_arvalid,
    output logic        s_arready,

    output logic [31:0] s_rdata,
    output logic [1:0]  s_rresp,
    output logic        s_rvalid,
    input  logic        s_rready,

    // Fault inputs — wire directly to CPU outputs in soc_top
    input  logic        imem_corrected,
    input  logic        imem_detected,
    input  logic        dmem_corrected,
    input  logic        dmem_detected,
    input  logic        tmr_pc_error,
    input  logic        tmr_fsm_error,
    input  logic        tmr_rf_error,
    input  logic        tmr_ir_error,

    // Interrupt output
    output logic        health_irq
);
import axi4_lite_pkg::*;

logic [31:0] irq_mask_reg;   // IRQ_MASK — which events trigger interrupt

logic [31:0] ecc_corr_cnt, ecc_det_cnt;
logic [31:0] tmr_pc_cnt, tmr_fsm_cnt, tmr_rf_cnt, tmr_ir_cnt;
logic [31:0] status_wire, irq_status_wire;
logic        irq_clear_pulse;
logic [31:0] irq_clear_bits;
logic        cnt_clear_pulse;


health_monitor u_health (
    .clk              (clk),
    .rst_n            (rst_n),

    .imem_corrected   (imem_corrected),
    .imem_detected    (imem_detected),
    .dmem_corrected   (dmem_corrected),
    .dmem_detected    (dmem_detected),
    .tmr_pc_error     (tmr_pc_error),
    .tmr_fsm_error    (tmr_fsm_error),
    .tmr_rf_error     (tmr_rf_error),
    .tmr_ir_error     (tmr_ir_error),

    .ecc_corr_cnt_o   (ecc_corr_cnt),
    .ecc_det_cnt_o    (ecc_det_cnt),
    .tmr_pc_cnt_o     (tmr_pc_cnt),
    .tmr_fsm_cnt_o    (tmr_fsm_cnt),
    .tmr_rf_cnt_o     (tmr_rf_cnt),
    .tmr_ir_cnt_o     (tmr_ir_cnt),
    .status_o         (status_wire),
    .irq_status_o     (irq_status_wire),

    .irq_mask_i       (irq_mask_reg),
    .irq_clear_i      (irq_clear_pulse),
    .irq_clear_bits_i (irq_clear_bits),
    .cnt_clear_i      (cnt_clear_pulse),

    .health_irq       (health_irq)
);

typedef enum logic [1:0] {
    WR_IDLE,
    WR_EXEC,
    WR_RESP
} wr_state_t;

wr_state_t   wr_state;
logic [31:0] aw_addr_r;
logic [31:0] wd_r;
logic        aw_recv;
logic        w_recv;
logic        _unused_write_inputs;

assign irq_clear_pulse = (wr_state == WR_EXEC) &&
                         (aw_addr_r[11:0] == HEALTH_IRQ_STATUS);
assign irq_clear_bits  = wd_r;
// CTRL bit[0]: clear all counters pulse
assign cnt_clear_pulse = (wr_state == WR_EXEC) &&
                         (aw_addr_r[11:0] == HEALTH_CTRL) &&
                         wd_r[0];
assign _unused_write_inputs = |s_wstrb | |aw_addr_r[31:12];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_state    <= WR_IDLE;
        aw_addr_r   <= '0;
        wd_r        <= '0;
        aw_recv     <= 1'b0;
        w_recv      <= 1'b0;
        irq_mask_reg<= '0;     // all interrupts masked by default — safe startup
    end else begin
        case (wr_state)
            WR_IDLE: begin
                if (s_awvalid && s_awready) begin
                    aw_addr_r <= s_awaddr;
                    aw_recv   <= 1'b1;
                end
                if (s_wvalid && s_wready) begin
                    wd_r   <= s_wdata;
                    w_recv <= 1'b1;
                end
                if ((aw_recv || (s_awvalid && s_awready)) &&
                    (w_recv  || (s_wvalid  && s_wready)))
                    wr_state <= WR_EXEC;
            end
            WR_EXEC: begin
                case (aw_addr_r[11:0] & 12'hFFF)
                    HEALTH_IRQ_MASK:   irq_mask_reg <= wd_r;
                    HEALTH_IRQ_STATUS: ; // handled by irq_clear_pulse above
                    HEALTH_CTRL:       ; // handled by cnt_clear_pulse above
                    default:           ; // read-only — ignore
                endcase
                wr_state <= WR_RESP;
                aw_recv  <= 1'b0;
                w_recv   <= 1'b0;
            end
            WR_RESP: begin
                if (s_bvalid && s_bready)
                    wr_state <= WR_IDLE;
            end

            default: wr_state <= WR_IDLE;
        endcase
    end
end

assign s_awready = (wr_state == WR_IDLE) && !aw_recv;
assign s_wready  = (wr_state == WR_IDLE) && !w_recv;
assign s_bvalid  = (wr_state == WR_RESP);
assign s_bresp   = AXI_RESP_OKAY;

typedef enum logic [1:0] {
    RD_IDLE,
    RD_LATCH,
    RD_RESP
} rd_state_t;

rd_state_t   rd_state;
logic [31:0] rdata_r;
logic [31:0] ar_addr_r;
logic        _unused_read_addr;

assign _unused_read_addr = |ar_addr_r[31:12];

function automatic logic [31:0] reg_read(input logic [11:0] offset);
    case (offset)
        HEALTH_ECC_CORR_CNT : return ecc_corr_cnt;
        HEALTH_ECC_DET_CNT  : return ecc_det_cnt;
        HEALTH_TMR_PC_CNT   : return tmr_pc_cnt;
        HEALTH_TMR_FSM_CNT  : return tmr_fsm_cnt;
        HEALTH_TMR_RF_CNT   : return tmr_rf_cnt;
        HEALTH_TMR_IR_CNT   : return tmr_ir_cnt;
        HEALTH_STATUS       : return status_wire;
        HEALTH_IRQ_MASK     : return irq_mask_reg;
        HEALTH_IRQ_STATUS   : return irq_status_wire;
        default             : return 32'b0;
    endcase
endfunction

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_state  <= RD_IDLE;
        rdata_r   <= '0;
        ar_addr_r <= '0;
    end else begin
        case (rd_state)
            RD_IDLE: begin
                if (s_arvalid && s_arready) begin
                    ar_addr_r <= s_araddr;
                    rd_state  <= RD_LATCH;
                end
            end
            RD_LATCH: begin
                rdata_r  <= reg_read(ar_addr_r[11:0]);
                rd_state <= RD_RESP;
            end
            RD_RESP: begin
                if (s_rvalid && s_rready)
                    rd_state <= RD_IDLE;
            end
            default: rd_state <= RD_IDLE;
        endcase
    end
end

assign s_arready = (rd_state == RD_IDLE);
assign s_rvalid  = (rd_state == RD_RESP);
assign s_rdata   = rdata_r;
assign s_rresp   = AXI_RESP_OKAY;

endmodule
