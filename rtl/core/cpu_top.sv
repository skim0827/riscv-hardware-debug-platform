`timescale 1ns/1ps
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
    output logic        progbuf_exception
);

// ==================================================================
// control signals 
// ==================================================================
logic [31:0] PCNext, pc;
logic PCWrite, RegWrite, MemWrite, IRWrite, AdrSrc, Zero; 
logic [1:0] ResultSrc, ALUSrcB, ALUSrcA, ImmSrc;
logic Branch;
logic PCUpdate;
alu_control_t ALUControl;
logic [31:0] instruction; 
logic [6:0] op;
logic [2:0] funct3;
logic [6:0] funct7;

assign op     = instruction[6:0];
assign funct3 = instruction[14:12];
assign funct7 = instruction[31:25];



control u_control(
    .clk(clk),
    .rst_n(rst_n),
    .Zero(Zero),
    .op(op),
    .funct3(funct3),
    .funct7_5(funct7[5]),

    .RegWrite(RegWrite),
    .MemWrite(MemWrite),
    .IRWrite(IRWrite),
    .PCWrite(PCWrite),
    .ResultSrc(ResultSrc),
    .ALUSrcB(ALUSrcB),
    .ALUSrcA(ALUSrcA),
    .AdrSrc(AdrSrc),
    .ALUControl(ALUControl),
    .ImmSrc(ImmSrc),

    .hart_halt_req(hart_halt_req),
    .hart_resume_req(hart_resume_req),
    .hart_halted(hart_halted),

    .progbuf_exec   (progbuf_exec),
    .progbuf_done   (progbuf_done) // from FSM 
);

// ==================================================================
// Instruction register
// Progbuf path has priority over normal IRWrite from memory so that
// the injected instruction is visible at S_DECODE on the very next cycle.
// ==================================================================
always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) instruction <= 32'b0;
    else if (progbuf_exec) instruction <= progbuf_instr;
    else if (IRWrite) instruction <= mem_rdata;
end 


// ==================================================================
// datapath wires 
// ==================================================================
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
assign mem_wdata = register_b_in;
logic [31:0] mem_rdata;
logic [31:0] ALUResult;
logic [31:0] rd1, rd2;
logic [31:0] writeback_data;
logic [31:0] srcA, srcB;
logic [31:0] dbg_rdata, dbg_wdata;
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
    else begin
        register_a_in <= rd1;
        register_b_in <= rd2;
    end 
end 



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) alu_result_reg <= 32'b0;
    else alu_result_reg <= ALUResult; 
end



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) mem_data_reg <= 32'b0;
    else        mem_data_reg <= mem_rdata;
end



always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)  pc_old <= 32'b0;
    else if (IRWrite)         pc_old <= pc; // only in S_FETCH
end


// ==================================================================
// combinational mux 
// ==================================================================
assign mem_addr = AdrSrc ? alu_result_reg : pc;

assign srcA = (ALUSrcA == 2'b00) ? pc :
              (ALUSrcA == 2'b01) ? pc_old :
                                   register_a_in;
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
 
// ==================================================================
// MEM 
// ==================================================================

memory#(
    .mem_init("../tb/test_memory.hex")
) u_memory (
    .clk(clk),
    .rst_n(rst_n), 
    .a(mem_addr),
    .wd(mem_wdata),
    .we(MemWrite),
    .rd(mem_rdata)
);

program_counter u_pc (
    .clk(clk),
    .rst_n(rst_n),
    .PCNext(PCNext),
    .PCWrite(PCWrite),

    .hart_pc_we(hart_pc_we),
    .hart_pc_wdata(hart_pc_wdata),
    .hart_pc_rdata(hart_pc_rdata),
    .pc(pc)
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

regfile u_regfile(
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
    .hart_regfile_rdata(hart_regfile_rdata)
);


endmodule : cpu