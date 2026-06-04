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

    // AXI4-Lite instruction fetch port.
    output logic [31:0] imem_araddr,
    output logic        imem_arvalid,
    input  logic        imem_arready,
    input  logic [31:0] imem_rdata,
    input  logic [1:0]  imem_rresp,
    input  logic        imem_rvalid,
    output logic        imem_rready,

    // AXI4-Lite data port.
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

// control signals 
logic [31:0] PCNext, pc;
logic PCWrite, PCWrite_gated, RegWrite, MemWrite, MemRead, Zero;
logic [1:0] ResultSrc, ALUSrcB, ALUSrcA;
logic [2:0] ImmSrc;

alu_control_t ALUControl;
logic stall; // asserted while an AXI transaction is in progress.
logic _unused_hart_reset_req;

logic [31:0] instruction; 
logic [6:0] op;
logic [2:0] funct3;
logic funct7_5;

assign op               = instruction[6:0];
assign funct3           = instruction[14:12];
assign funct7_5         = instruction[30];
assign _unused_hart_reset_req = hart_reset_req;

// datapath wires 
logic [31:0] imem_addr;
logic [31:0] dmem_addr;
logic [31:0] mem_wdata;
assign mem_wdata = register_b_in;
assign imem_addr = pc; 
assign dmem_addr = alu_result_reg;

// Read data sign/zero extension
function automatic logic [31:0] extend_rdata (
    input logic [31:0] data,
    input logic [2:0]  f3,
    input logic [1:0]  addr
);
    case (f3)
        3'b000: begin // LB: sign-extend byte
            case (addr)
                2'b00: return {{24{data[7]}},  data[7:0]};
                2'b01: return {{24{data[15]}}, data[15:8]};
                2'b10: return {{24{data[23]}}, data[23:16]};
                2'b11: return {{24{data[31]}}, data[31:24]};
                default: return data;
            endcase
        end
        3'b001: // LH: sign-extend halfword
            return addr[1] ? {{16{data[31]}}, data[31:16]}
                           : {{16{data[15]}}, data[15:0]};
        3'b100: begin // LBU: zero-extend byte
            case (addr)
                2'b00: return {24'b0, data[7:0]};
                2'b01: return {24'b0, data[15:8]};
                2'b10: return {24'b0, data[23:16]};
                2'b11: return {24'b0, data[31:24]};
                default: return data;
            endcase
        end
        3'b101: // LHU: zero-extend halfword
            return addr[1] ? {16'b0, data[31:16]}
                           : {16'b0, data[15:0]};
        default: return data; // LW: no extension
    endcase
endfunction

logic [31:0] dmem_rdata;
assign dmem_rdata = extend_rdata(m_rdata, funct3, dmem_addr[1:0]);

// WSTRB write byte enables.
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

// Architectural pipeline registers
logic [31:0] register_a_in;
logic [31:0] register_b_in;
logic [31:0] alu_result_reg;
logic [31:0] mem_data_reg;
logic [31:0] pc_old;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        register_a_in <= 32'b0;
        register_b_in <= 32'b0;
    end else if (!stall) begin
        register_a_in <= rd1;
        register_b_in <= rd2;
    end 
end 

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) alu_result_reg <= 32'b0;
    else if (!stall) alu_result_reg <= ALUResult; 
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)              mem_data_reg <= 32'b0;
    else if (dmem_read_done) mem_data_reg <= dmem_rdata;
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)          pc_old <= 32'b0;
    else if (fetch_done) pc_old <= pc;
end

// Combinational mux
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
assign progbuf_exception = 1'b0;

assign PCNext = (ResultSrc == 2'b00) ? alu_result_reg : 
                (ResultSrc == 2'b01) ? mem_data_reg : 
                                       ALUResult;

// Gate PCWrite while AXI fetch/data access stalls.
assign PCWrite_gated = PCWrite && !stall;

// Instruction register TMR
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

// IMEM fetch FSM. in_fetch_r is registered to avoid reset-time handshakes.
typedef enum logic [1:0] {
    IFETCH_IDLE,
    IFETCH_AR,
    IFETCH_R
} ifetch_state_t;

ifetch_state_t ifetch_state;
logic          fetch_done;
logic          fetch_stall;

// in_fetch_r drives fetch start; fetch_done releases S_FETCH.
logic in_fetch_r;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ifetch_state <= IFETCH_IDLE;
    end else begin
        case (ifetch_state)
            IFETCH_IDLE: begin
                if (in_fetch_r) ifetch_state <= IFETCH_AR;
            end
            IFETCH_AR: begin
                if (imem_arready) ifetch_state <= IFETCH_R;
            end
            IFETCH_R: begin
                if (imem_rvalid && imem_rready) ifetch_state <= IFETCH_IDLE;
            end
            default: ifetch_state <= IFETCH_IDLE;
        endcase
    end
end

assign imem_arvalid = (ifetch_state == IFETCH_IDLE && in_fetch_r) ||
                      (ifetch_state == IFETCH_AR);
assign imem_araddr  = imem_addr;   // = pc
assign imem_rready  = (ifetch_state == IFETCH_R);

assign fetch_done  = (ifetch_state == IFETCH_R) && imem_rvalid && imem_rready;
assign fetch_stall = in_fetch_r && !fetch_done;

logic _unused_imem_rresp;
assign _unused_imem_rresp = |imem_rresp;

// DMEM access FSM
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

logic _unused_resps;
assign _unused_resps = |m_bresp | |m_rresp;

assign stall = fetch_stall || mem_stall;

// Control connects fetch_done and in_fetch_r.
control u_control(
    .clk(clk),
    .rst_n(rst_n),
    .Zero(Zero),
    .op(op),
    .funct3(funct3),
    .funct7_5(funct7_5),

    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .MemRead(MemRead),
    .PCWrite(PCWrite),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .ALUControl(ALUControl),
    .ImmSrc(ImmSrc),

    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted),

    .progbuf_exec(progbuf_exec),
    .progbuf_done(progbuf_done),
    .tmr_fsm_error(tmr_fsm_error),

    .stall(stall),
    .fetch_done(fetch_done),
    .in_fetch_r(in_fetch_r)
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
