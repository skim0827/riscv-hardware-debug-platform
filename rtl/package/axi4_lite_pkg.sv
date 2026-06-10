/* verilator lint_off UNUSEDPARAM */
package axi4_lite_pkg;
    // Response codes
    localparam [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR   = 2'b10;
    localparam [1:0] AXI_RESP_DECERR   = 2'b11;

    localparam [31:0] IMEM_BASE   = 32'h0000_0000;
    localparam [31:0] DMEM_BASE   = 32'h1000_0000;
    localparam [31:0] UART_BASE   = 32'h2000_0000;
    localparam [31:0] TIMER_BASE  = 32'h2000_1000;
    localparam [31:0] HEALTH_BASE = 32'h2000_2000;
    localparam [31:0] DMA_BASE = 32'h2000_3000;
    localparam [31:0] FIR_BASE = 32'h2000_4000;

    // Decode masks
    localparam [31:0] REGION_MASK = 32'hF000_0000; // keeps only the top 4 bits of an address.
    localparam [31:0] PAGE_MASK   = 32'hFFFF_F000; // big memory region

    localparam int NUM_SLAVES = 5;

    localparam int SLV_IMEM   = 0;
    localparam int SLV_DMEM   = 1;
    localparam int SLV_UART   = 2;
    localparam int SLV_TIMER  = 3;
    localparam int SLV_HEALTH = 4;

    // UART (base: UART_BASE)
    localparam [11:0] UART_TX_DATA = 12'h000; // W: write byte to transmit
    localparam [11:0] UART_STATUS  = 12'h004; // R: bit[0] = tx_busy

    // Timer/WDT (base: TIMER_BASE)
    localparam [11:0] TIMER_CTRL    = 12'h000; // R/W: bit[0]=enable, bit[1]=wdt_en
    localparam [11:0] TIMER_COUNT   = 12'h004; // R:   current counter value
    localparam [11:0] TIMER_TIMEOUT = 12'h008; // R/W: IRQ threshold
    localparam [11:0] TIMER_STATUS  = 12'h00C; // R/W: bit[0]=irq_pending, bit[1]=wdt_fired
                                                //      write 1 to bit[0] to clear irq_pending

    // Health Monitor / Fault Telemetry (base: HEALTH_BASE)
    // All counters are saturating (stop at 0xFFFF_FFFF, do not wrap)
    localparam [11:0] HEALTH_ECC_CORR_CNT  = 12'h000; // R: single-bit corrections (IMEM+DMEM)
    localparam [11:0] HEALTH_ECC_DET_CNT   = 12'h004; // R: double-bit detections (uncorrectable)
    localparam [11:0] HEALTH_TMR_PC_CNT    = 12'h008; // R: PC TMR voter mismatches
    localparam [11:0] HEALTH_TMR_FSM_CNT   = 12'h00C; // R: FSM TMR voter mismatches
    localparam [11:0] HEALTH_TMR_RF_CNT    = 12'h010; // R: regfile TMR voter mismatches
    localparam [11:0] HEALTH_TMR_IR_CNT    = 12'h014; // R: instruction register TMR voter mismatches
    localparam [11:0] HEALTH_STATUS        = 12'h018; // R: live wire values of all fault signals
    localparam [11:0] HEALTH_IRQ_MASK      = 12'h01C; // R/W: which events trigger an interrupt
    localparam [11:0] HEALTH_IRQ_STATUS    = 12'h020; // R/W1C: which events have fired
    localparam [11:0] HEALTH_CTRL          = 12'h024; // W: bit[0]=clear all counters





endpackage
/* verilator lint_on UNUSEDPARAM */
