`timescale 1ns/1ps
/* verilator lint_off DECLFILENAME */
module cpu(
    input logic clk, 
    input logic rst_n, 

    // hart interface 
    input  logic hart_halt_req,
    input  logic hart_resume_req,
    input  logic hart_reset_req, // for multi hart system 
    output logic hart_halted,

    input  logic [4:0]  hart_regfile_addr,
    input  logic [31:0] hart_regfile_wdata,
    input  logic        hart_regfile_we, 
    output logic [31:0] hart_regfile_rdata,

    input  logic [31:0] hart_pc_wdata,
    input  logic        hart_pc_we,
    output logic [31:0] hart_pc_rdata,

    // program buffer interface 
    input  logic [31:0] progbuf_instr, 
    input  logic        progbuf_exec,
    output logic        progbuf_done,
    output logic        progbuf_exception,

    // tmr error telemetry
    output logic        tmr_pc_error,
    output logic        tmr_fsm_error,
    output logic        tmr_rf_error, 
    output logic        tmr_ir_error,

    // AXI4-Lite master port — instruction fetch
    output logic [31:0] imem_araddr,
    output logic        imem_arvalid,
    input  logic        imem_arready,
    input  logic [31:0] imem_rdata,
    input  logic [1:0]  imem_rresp,
    input  logic        imem_rvalid,
    output logic        imem_rready,

    // AXI4-Lite master port — data read/write
    output logic [31:0] m_awaddr,
    output logic        m_awvalid,
    input  logic        m_awready,
    output logic [31:0] m_wdata,
    output logic [3:0]  m_wstrb,
    output logic        m_wvalid,
    input  logic        m_wready,
    input  logic [1:0]  m_bresp,
    input  logic        m_bvalid,
    output logic        m_bready,
    output logic [31:0] m_araddr,
    output logic        m_arvalid,
    input  logic        m_arready,
    input  logic [31:0] m_rdata,
    input  logic [1:0]  m_rresp,
    input  logic        m_rvalid,
    output logic        m_rready
);
import riscv_pkg::*;

// ==================================================================
// control signals 
// ==================================================================
logic [31:0] PCNext, pc;
logic PCWrite, PCWrite_gated, RegWrite, MemWrite, MemRead, IRWrite, Zero;
logic [1:0] ResultSrc, ALUSrcB, ALUSrcA;
logic [2:0] ImmSrc;



alu_control_t ALUControl;
logic stall; // asserted while an AXI transaction is in progress.
logic _unused_hart_reset_req;



logic [31:0] instruction; 
logic [6:0] op;
logic [2:0] funct3;
logic funct7_5;

assign op     = instruction[6:0];
assign funct3 = instruction[14:12];
assign funct7_5 = instruction[30];
assign _unused_hart_reset_req = hart_reset_req;


// ==================================================================
// datapath wires 
// ==================================================================
logic [31:0] imem_addr;
logic [31:0] dmem_addr;
logic [31:0] mem_wdata;
assign mem_wdata = register_b_in;
assign imem_addr = pc; 
assign dmem_addr = alu_result_reg;

// =============================================================================
// Read data sign/zero extension
//
// The AXI slave now returns a full 32-bit word for all reads.
//
// funct3 encoding for loads:
//   3'b000 LB  sign-extend byte     3'b100 LBU zero-extend byte
//   3'b001 LH  sign-extend halfword 3'b101 LHU zero-extend halfword
//   3'b010 LW  full word (no change)
//
// dmem_addr[1:0] selects the byte/halfword within the returned word.
// =============================================================================
function automatic logic [31:0] extend_rdata (
    input logic [31:0] data,
    input logic [2:0]  f3,
    input logic [1:0]  addr
);
    case (f3)
        3'b000: begin // LB — sign-extend byte
            case (addr)
                2'b00: return {{24{data[7]}},  data[7:0]};
                2'b01: return {{24{data[15]}}, data[15:8]};
                2'b10: return {{24{data[23]}}, data[23:16]};
                2'b11: return {{24{data[31]}}, data[31:24]};
                default: return data;
            endcase
        end
        3'b001: // LH — sign-extend halfword
            return addr[1] ? {{16{data[31]}}, data[31:16]}
                           : {{16{data[15]}}, data[15:0]};
        3'b100: begin // LBU — zero-extend byte
            case (addr)
                2'b00: return {24'b0, data[7:0]};
                2'b01: return {24'b0, data[15:8]};
                2'b10: return {24'b0, data[23:16]};
                2'b11: return {24'b0, data[31:24]};
                default: return data;
            endcase
        end
        3'b101: // LHU — zero-extend halfword
            return addr[1] ? {16'b0, data[31:16]}
                           : {16'b0, data[15:0]};
        default: return data; // LW (3'b010) — no extension
    endcase
endfunction



// dmem_rdata: sign/zero extended, ready for writeback into the register file
logic [31:0] dmem_rdata;
assign dmem_rdata = extend_rdata(m_rdata, funct3, dmem_addr[1:0]);

// =============================================================================
// WSTRB — write byte enables
//
// AXI4-Lite uses WSTRB to select which bytes to write. We derive it from
// funct3[1:0] (access width) and dmem_addr[1:0] (byte position in word).
//
//   SW funct3=010  all bytes         4'b1111
//   SH funct3=001  upper halfword    4'b1100
//                  lower halfword    4'b0011
//   SB funct3=000  byte 3            4'b1000
//                  byte 2            4'b0100
//                  byte 1            4'b0010
//                  byte 0            4'b0001
// =============================================================================
function automatic logic [3:0] make_wstrb (
    input logic [1:0] f3,
    input logic [1:0] addr
);
    case (f3)
        2'b10:   return 4'b1111;
        2'b01:   return addr[1] ? 4'b1100 : 4'b0011;
        default: return 4'b0001 << addr;  // SB
    endcase
endfunction

logic [31:0] ALUResult;
logic [31:0] rd1, rd2;
logic [31:0] writeback_data;
logic [31:0] srcA, srcB;
logic [31:0] ImmExt;

// ==================================================================
// Architectural pipeline registers
// ==================================================================
logic [31:0] register_a_in;             // Holds RD1 data (read from regfile)
logic [31:0] register_b_in;             // Holds RD2 data (read from regfile)
logic [31:0] alu_result_reg;            // Holds ALU output
logic [31:0] mem_data_reg;              // Holds memory read data
logic [31:0] pc_old;                    // Holds PC for JAL/JALR



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        register_a_in <= 32'b0;
        register_b_in <= 32'b0;
    end
    else if (!stall) begin
        register_a_in <= rd1;
        register_b_in <= rd2;
    end 
end 



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) alu_result_reg <= 32'b0;
    else if (!stall) alu_result_reg <= ALUResult; 
end



// mem_data_reg: CHANGED — capture only when DMEM read data is valid.
// Phase 1: captured every cycle from memory.sv combinatorial output.
// Phase 2: captured only on dmem_read_done to avoid latching stale AXI data.
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)              mem_data_reg <= 32'b0;
    else if (dmem_read_done) mem_data_reg <= dmem_rdata;
end



// pc_old: CHANGED — capture on fetch_done instead of IRWrite.
// Phase 1: IRWrite fired in the same cycle memory returned data.
// Phase 2: fetch_done fires when the AXI R handshake completes.
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          pc_old <= 32'b0;
    else if (fetch_done) pc_old <= pc;
end



// ==================================================================
// combinational mux 
// ==================================================================
assign srcA = (ALUSrcA == 2'b00) ? pc :
              (ALUSrcA == 2'b01) ? pc_old :
              (ALUSrcA == 2'b10) ? register_a_in : 
                                   32'b0;

assign srcB = (ALUSrcB == 2'b00) ? register_b_in : 
              (ALUSrcB == 2'b01) ? ImmExt :
              (ALUSrcB == 2'b10) ? 32'd4 : 
                                   32'b0;
assign writeback_data = (ResultSrc == 2'b00) ? alu_result_reg :
                        (ResultSrc == 2'b01) ? mem_data_reg : 
                                               ALUResult;
// No exception detection yet
assign progbuf_exception = 1'b0;
assign PCNext = (ResultSrc == 2'b00) ? alu_result_reg : 
                (ResultSrc == 2'b01) ? mem_data_reg : 
                ALUResult;
// =============================================================================
// PCWrite gating
//
// In S_FETCH the main FSM asserts PCUpdate=1 → PCWrite=1 every cycle.
// Without gating the PC would advance on every stall cycle while waiting
// for the AXI fetch to complete — the CPU would skip instructions.
//
// Solution: gate PCWrite with !stall.
//
// In all non-fetch states (JAL, JALR, branch) stall=0 so PCWrite passes
// through unchanged.
// =============================================================================
assign PCWrite_gated = PCWrite && !stall;

// =============================================================================
// Instruction register TMR
//
// Three replicated instruction registers hold the fetched/progbuf instruction.
// The CPU decodes the majority-voted value, while tmr_ir_error reports any
// mismatch between replicas.
// =============================================================================
logic [31:0] ir_0, ir_1, ir_2;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)             ir_0 <= 32'b0;
    else if (progbuf_exec)  ir_0 <= progbuf_instr;
    else if (fetch_done)    ir_0 <= imem_rdata;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)             ir_1 <= 32'b0;
    else if (progbuf_exec)  ir_1 <= progbuf_instr;
    else if (fetch_done)    ir_1 <= imem_rdata;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)             ir_2 <= 32'b0;
    else if (progbuf_exec)  ir_2 <= progbuf_instr;
    else if (fetch_done)    ir_2 <= imem_rdata;
end

assign instruction  = (ir_0 & ir_1) | (ir_0 & ir_2) | (ir_1 & ir_2);
assign tmr_ir_error = |(ir_0 ^ ir_1) | |(ir_1 ^ ir_2);
// =============================================================================
// IMEM fetch FSM
//
// Manages the AXI4-Lite AR and R channels for instruction fetch.
//
// Triggered when IRWrite is asserted by the main FSM (S_FETCH state).
// Produces:
//   fetch_done  — one-cycle pulse when instruction data is valid and latched
//   fetch_stall — held high while waiting for the AXI transaction to complete
//
// States:
//   IFETCH_IDLE  waiting for IRWrite
//   IFETCH_AR    arvalid asserted, waiting for arready
//   IFETCH_R     AR accepted, rready asserted, waiting for rvalid
//
// Timing example (slave responds in 2 cycles):
//   Cycle 1: S_FETCH, IRWrite=1, IFETCH_IDLE→IFETCH_AR, arvalid=1, stall=1
//   Cycle 2: IFETCH_AR, arready=1 → IFETCH_R
//   Cycle 3: IFETCH_R, rvalid=1, fetch_done=1, stall=0 → FSM advances
//   Cycle 4: S_DECODE, ir_0/1/2 latched the instruction
// =============================================================================
typedef enum logic [1:0] {
    IFETCH_IDLE,
    IFETCH_AR,
    IFETCH_R
} ifetch_state_t;

ifetch_state_t ifetch_state;
logic          fetch_done;
logic          fetch_stall;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ifetch_state <= IFETCH_IDLE;
    end else begin
        case (ifetch_state)
            IFETCH_IDLE: begin
                // Start a new fetch whenever the main FSM requests one
                if (IRWrite) ifetch_state <= IFETCH_AR;
            end
            IFETCH_AR: begin
                // Hold arvalid until the slave accepts the address
                if (imem_arready) ifetch_state <= IFETCH_R;
            end
            IFETCH_R: begin
                // Hold rready until the slave returns data
                if (imem_rvalid && imem_rready) ifetch_state <= IFETCH_IDLE;
            end
            default: ifetch_state <= IFETCH_IDLE;
        endcase
    end
end

// arvalid: asserted from the cycle IRWrite fires until arready is received
assign imem_arvalid = (ifetch_state == IFETCH_IDLE && IRWrite) ||
                      (ifetch_state == IFETCH_AR);
assign imem_araddr  = imem_addr;   // = pc
assign imem_rready  = (ifetch_state == IFETCH_R);

assign fetch_done  = (ifetch_state == IFETCH_R) && imem_rvalid && imem_rready;
assign fetch_stall = IRWrite && !fetch_done;

// imem_rresp not acted on yet — future work: trap on DECERR
// Suppress unused-signal warning
logic _unused_imem_rresp;
assign _unused_imem_rresp = |imem_rresp;
// =============================================================================
// DMEM access FSM
//
// Manages AXI4-Lite write (AW+W+B) and read (AR+R) channels for loads
// and stores.
//
// Triggered when MemWrite (store) or MemRead (load) is asserted by the FSM.
// MemWrite comes from the main FSM (S_MEMWRITE state).
// MemRead  is the new output added to main_fsm (S_MEMREAD state).
//
// Produces:
//   dmem_write_done — one-cycle pulse when B response received
//   dmem_read_done  — one-cycle pulse when R data received
//   mem_stall       — held high while transaction is in progress
//
// States:
//   DMEM_IDLE      idle
//   DMEM_WR_ADDR   AW+W asserted, tracking handshakes independently
//   DMEM_WR_RESP   both AW+W done, waiting for B response
//   DMEM_RD_ADDR   AR asserted, waiting for arready
//   DMEM_RD_DATA   AR accepted, rready asserted, waiting for rvalid
// =============================================================================
typedef enum logic [2:0] {
    DMEM_IDLE,
    DMEM_WR_ADDR,
    DMEM_WR_RESP,
    DMEM_RD_ADDR,
    DMEM_RD_DATA
} dmem_state_t;

dmem_state_t dmem_state;
logic        aw_done_r, w_done_r;
logic        dmem_write_done;
logic        dmem_read_done;
logic        mem_stall;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dmem_state <= DMEM_IDLE;
        aw_done_r  <= 1'b0;
        w_done_r   <= 1'b0;
    end else begin
        case (dmem_state)
            DMEM_IDLE: begin
                if (MemWrite)      dmem_state <= DMEM_WR_ADDR;
                else if (MemRead)  dmem_state <= DMEM_RD_ADDR;
            end

            DMEM_WR_ADDR: begin
                if (m_awvalid && m_awready) aw_done_r <= 1'b1;
                if (m_wvalid  && m_wready)  w_done_r  <= 1'b1;

                if ((aw_done_r || (m_awvalid && m_awready)) &&
                    (w_done_r  || (m_wvalid  && m_wready))) begin
                    dmem_state <= DMEM_WR_RESP;
                    aw_done_r  <= 1'b0;
                    w_done_r   <= 1'b0;
                end
            end

            DMEM_WR_RESP: begin
                if (m_bvalid && m_bready) dmem_state <= DMEM_IDLE;
            end

            DMEM_RD_ADDR: begin
                if (m_arvalid && m_arready) dmem_state <= DMEM_RD_DATA;
            end

            DMEM_RD_DATA: begin
                if (m_rvalid && m_rready) dmem_state <= DMEM_IDLE;
            end

            default: dmem_state <= DMEM_IDLE;
        endcase
    end
end

assign m_awvalid = (dmem_state == DMEM_WR_ADDR) && !aw_done_r;
assign m_awaddr  = dmem_addr;
assign m_wvalid  = (dmem_state == DMEM_WR_ADDR) && !w_done_r;
assign m_wdata   = mem_wdata;
assign m_wstrb   = make_wstrb(funct3[1:0], dmem_addr[1:0]);
assign m_bready  = (dmem_state == DMEM_WR_RESP);
assign m_arvalid = (dmem_state == DMEM_RD_ADDR);
assign m_araddr  = dmem_addr;
assign m_rready  = (dmem_state == DMEM_RD_DATA);

assign dmem_write_done = (dmem_state == DMEM_WR_RESP) && m_bvalid && m_bready;
assign dmem_read_done  = (dmem_state == DMEM_RD_DATA)  && m_rvalid && m_rready;

assign mem_stall = (MemWrite && !dmem_write_done) ||
                   (MemRead  && !dmem_read_done);

// m_bresp / m_rresp not acted on yet — future: trap on SLVERR/DECERR
logic _unused_resps;
assign _unused_resps = |m_bresp | |m_rresp;

assign stall = fetch_stall || mem_stall;

control u_control(
    .clk(clk),
    .rst_n(rst_n),
    .Zero(Zero),
    .op(op),
    .funct3(funct3),
    .funct7_5(funct7_5),

    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .MemRead  (MemRead), 
    .IRWrite(IRWrite),
    .PCWrite(PCWrite),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .ALUControl(ALUControl),
    .ImmSrc(ImmSrc),

    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted),

    .progbuf_exec   (progbuf_exec),
    .progbuf_done   (progbuf_done),
    .tmr_fsm_error(tmr_fsm_error),

    .stall          (stall) 
);


tmr_pc u_pc (
    .clk(clk),
    .rst_n(rst_n),
    .PCNext(PCNext),
    .PCWrite(PCWrite_gated),

    .hart_pc_we(hart_pc_we),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_rdata(hart_pc_rdata),
    .pc(pc),
    .tmr_error(tmr_pc_error)
);

signext u_signext (
    .raw(instruction[31:7]),
    .ImmSrc(ImmSrc),
    .ImmExt(ImmExt)
);

alu u_alu (
    .srcA(srcA),
    .srcB(srcB),
    .ALUControl(ALUControl),
    .ALUResult(ALUResult), 
    .Zero(Zero)
);

tmr_regfile u_regfile(
    .clk(clk),
    .rst_n(rst_n),

    .a1(instruction[19:15]),
    .a2(instruction[24:20]),
    .a3(instruction[11:7]),
    .wd3(writeback_data),
    .we3(RegWrite),

    .hart_regfile_we(hart_regfile_we),
    .hart_regfile_addr(hart_regfile_addr),
    .hart_regfile_wdata(hart_regfile_wdata),
    .rd1(rd1),
    .rd2(rd2),
    .hart_regfile_rdata(hart_regfile_rdata),
    .tmr_error(tmr_rf_error)
);


endmodule : cpu
/* verilator lint_on DECLFILENAME */
