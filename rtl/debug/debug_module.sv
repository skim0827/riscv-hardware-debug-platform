// "RISC-V External Debug Support Version 0.13.2"
`timescale 1ns/1ps
module debug_module(
    input  logic        clk,
    input  logic        rst_n,
    
    input  logic [6:0]   dmi_addr,
    input  logic [31:0]  dmi_wdata,
    input  logic         dmi_we,
    input  logic         dmi_re, 
    output logic [31:0]  dmi_rdata,
    input  logic         dmi_valid,


    // Hart Interface (to CPU Core)    
    input  logic        hart_halted,
    output logic        hart_halt_req,
    output logic        hart_resume_req,
    output logic        hart_reset_req,

    input  logic [31:0] hart_regfile_rdata,
    output logic [31:0] hart_regfile_wdata,
    output logic [4:0]  hart_regfile_addr, // 32 GPRs 
    output logic        hart_regfile_we,


    input  logic [31:0] hart_pc_rdata,
    output logic [31:0] hart_pc_wdata,
    output logic        hart_pc_we,

    output logic [31:0] progbuf_instr,
    output logic        progbuf_exec,
    input  logic        progbuf_done,
    input  logic        progbuf_exception

);

import dmi_pkg::*;
import riscv_pkg::*;

// ======================================================================
// INTERNAL REGISTERS - table 3.8
// ======================================================================
dmstatus_t              dmstatus_reg;
dmcontrol_t             dmcontrol_reg;
abstractcs_t            abstractcs_reg;
command_t               command_reg;
cmd_access_register_t   cmd_access_reg;

logic [31:0]    data_regs[0:11];

// ======================================================================
// STATE MACHINE for DM 
// ======================================================================
typedef enum logic [3:0] { 
    CMD_IDLE        = 4'h0, 
    CMD_DECODE      = 4'h1,   // validate cmd + confirm hart halted
    CMD_REG_SETUP   = 4'h2,   // drive addr, let comb read settle
    CMD_REG_SAMPLE  = 4'h3,   // capture rdata (reads)
    CMD_REG_WRITE   = 4'h4,   // pulse we (writes)
    CMD_PROGBUF     = 4'h5,   // wait for pb_done event
    CMD_DONE        = 4'h6, 
    CMD_ERROR       = 4'h7
} cmd_state_t;

cmd_state_t cmd_state, cmd_state_next; 

// ======================================================================
// Internal Control Signal 
// ======================================================================
logic           hart_halted_r; 
logic           hart_halted_sticky;
logic           hart_resuming;

logic [4:0]     gpr_addr; 
logic           is_gpr_access; 
logic           is_pc_access; 
logic           is_csr_access; 
 

logic           pb_we; 
logic           pb_re; 
logic [31:0]    pb_rdata; 
logic           pb_start;
logic           pb_halt_req;
logic           pb_done; 
logic           pb_exception;


// ======================================================================
// Comb logic - Progbuf addr decoding  
// ======================================================================
wire            dmi_addr_is_progbuf = (dmi_addr >= 7'h20) && (dmi_addr <= 7'h2f);

// ======================================================================
// Comb logic - DMI regs read 
// ======================================================================
always_comb begin : dmi_read_path 
    dmi_rdata = 32'h0; 

    if (dmi_re) begin 
        case(dmi_addr)   
            DMI_DMSTATUS    : dmi_rdata = dmstatus_reg; 
            DMI_DMCONTROL   : dmi_rdata = dmcontrol_reg;
            DMI_HARTINFO    : dmi_rdata = 32'h0000_0c00; // dataaddr = 0 (hardcoded), datasize = 12, nscratch = 0 section 3.12.3
            DMI_ABSTRACTCS  : dmi_rdata = abstractcs_reg;
            DMI_COMMAND     : dmi_rdata = command_reg;

            // Data registers (0x04-0x0f)
            DMI_DATA0       : dmi_rdata = data_regs[0];
            DMI_DATA1       : dmi_rdata = data_regs[1];
            DMI_DATA2       : dmi_rdata = data_regs[2];
            DMI_DATA3       : dmi_rdata = data_regs[3];
            DMI_DATA4       : dmi_rdata = data_regs[4];
            DMI_DATA5       : dmi_rdata = data_regs[5];
            DMI_DATA6       : dmi_rdata = data_regs[6];
            DMI_DATA7       : dmi_rdata = data_regs[7];
            DMI_DATA8       : dmi_rdata = data_regs[8];
            DMI_DATA9       : dmi_rdata = data_regs[9];
            DMI_DATA10      : dmi_rdata = data_regs[10];
            DMI_DATA11      : dmi_rdata = data_regs[11];

            default: dmi_rdata = pb_rdata; // progbuf 
        endcase
    end  
end

// ======================================================================
// Comb logic - status regs updates 
// ======================================================================
always_comb begin : update_dmstatus 
        dmstatus_reg.version         = DMSTATUS_VERSION_0_13;
        dmstatus_reg.confstrptrvalid = 1'b0;
        dmstatus_reg.hasresethaltreq = 1'b0;
        dmstatus_reg.authbusy        = 1'b0;
        dmstatus_reg.authenticated   = 1'b1;
        dmstatus_reg.anyhalted       = hart_halted;
        dmstatus_reg.allhalted       = hart_halted;
        dmstatus_reg.anyrunning      = ~hart_halted;
        dmstatus_reg.allrunning      = ~hart_halted;
        dmstatus_reg.anyunavail      = 1'b0;
        dmstatus_reg.allunavail      = 1'b0;
        dmstatus_reg.anynonexist     = 1'b0;
        dmstatus_reg.allnonexist     = 1'b0;
        dmstatus_reg.anyresumeack    = ~hart_halted & hart_resuming;
        dmstatus_reg.allresumeack    = ~hart_halted & hart_resuming;
        dmstatus_reg.anyhavereset    = hart_halted_sticky;
        dmstatus_reg.allhavereset    = hart_halted_sticky;
        dmstatus_reg.reserved2       = 2'b0;
        dmstatus_reg.impebreak       = 1'b1;
        dmstatus_reg.reserved        = 9'b0;
end 

always_comb begin : update_abstractcs
    abstractcs_reg.reserved1   = 3'b0;
    abstractcs_reg.progbufsize = 5'h4;     // 16 words
    abstractcs_reg.reserved2   = 11'b0;
    // abstractcs_reg.busy handled in sequential
    abstractcs_reg.reserved3   = 1'b0;
    // abstractcs_reg.cmderr handled in sequential
    abstractcs_reg.reserved4   = 4'b0;
    abstractcs_reg.datacount   = 4'd12;     // 12 data registers 
end 

// ======================================================================
// Comb logic - command decoding table 4.1
// ======================================================================
always_comb begin : decode_command
    // cmd_access_reg = command_reg;
    gpr_addr = cmd_access_reg.regno[4:0];
    // (Spec Table 3.3)
    is_gpr_access = (cmd_access_reg.regno >= 16'h1000) && 
                    (cmd_access_reg.regno <= 16'h101f);  // x0-x31
    is_pc_access = (cmd_access_reg.regno == 16'h7b1);    // DPC
    is_csr_access = (cmd_access_reg.regno <= 16'h0fff);  // CSRs -- do i have this ?
    gpr_addr = cmd_access_reg.regno[4:0];
end 

// ======================================================================
// State Machine - Command execution 
// ======================================================================
always_comb begin : cmd_state_fsm
    cmd_state_next = cmd_state;

    case (cmd_state) 
        CMD_IDLE : begin 
            if (dmi_valid && dmi_we && dmi_addr == DMI_COMMAND && !abstractcs_reg.busy)
                cmd_state_next = CMD_DECODE;
        end 

        CMD_DECODE : begin 
            // Event: hart must be halted before any register access
            if (!hart_halted) begin
                cmd_state_next = CMD_DECODE;
            end else begin
                case (cmd_access_reg.cmdtype)
                    8'h00 : begin  // access register
                        if (!cmd_access_reg.transfer) begin
                            // transfer=0: skip reg access entirely
                            cmd_state_next = cmd_access_reg.postexec ? CMD_PROGBUF : CMD_DONE;
                        end else begin
                            cmd_state_next = CMD_REG_SETUP;
                        end
                    end
                    default : cmd_state_next = CMD_ERROR;
                endcase
            end
        end 

        CMD_REG_SETUP : begin
            cmd_state_next = cmd_access_reg.write ? CMD_REG_WRITE : CMD_REG_SAMPLE;
        end

        CMD_REG_SAMPLE : begin
            cmd_state_next = cmd_access_reg.postexec ? CMD_PROGBUF : CMD_DONE;
        end

        CMD_REG_WRITE : begin
            cmd_state_next = cmd_access_reg.postexec ? CMD_PROGBUF : CMD_DONE;
        end

        CMD_PROGBUF : begin 
            if (pb_done)
                cmd_state_next = pb_exception ? CMD_ERROR : CMD_DONE;
        end  

        CMD_DONE  : cmd_state_next = CMD_IDLE;
        CMD_ERROR : cmd_state_next = CMD_IDLE;
        default   : cmd_state_next = CMD_IDLE;
    endcase
end

// ======================================================================
// Comb logic - Hart interface control 
// ======================================================================
always_comb begin : hart_control 
    hart_regfile_we    = 1'b0;
    hart_regfile_addr  = 5'h0;
    hart_regfile_wdata = 32'h0;
    hart_pc_we         = 1'b0;
    hart_pc_wdata      = 32'h0;

    if (is_gpr_access) begin
        // Always drive addr so comb read is valid during CMD_REG_SETUP/SAMPLE
        hart_regfile_addr = gpr_addr;

        if (cmd_state == CMD_REG_WRITE) begin
            hart_regfile_we    = 1'b1;
            hart_regfile_wdata = data_regs[0];
        end
    end else if (is_pc_access) begin
        if (cmd_state == CMD_REG_WRITE) begin
            hart_pc_we    = 1'b1;
            hart_pc_wdata = data_regs[0];
        end
    end
end
// ======================================================================
// Comb logic - program buffer control 
// ======================================================================
always_comb begin : progbuf_control 
    pb_we       = dmi_valid && dmi_we && dmi_addr_is_progbuf; 
    pb_re       = dmi_valid && dmi_re && dmi_addr_is_progbuf; 
    pb_start    = (cmd_state == CMD_PROGBUF);
    pb_halt_req = hart_halt_req;
end 


// ======================================================================
// Program buffer instantiation 
// ======================================================================
progbuf u_progbuf (
    .clk(clk), 
    .rst_n(rst_n),

    // Control signals from DM 
    .pb_start(pb_start), 
    .pb_halt_req(pb_halt_req), 
    .pb_done(pb_done), 
    .pb_exception(pb_exception), 

    // instructtion interface 
    .pb_instr(progbuf_instr), 
    .pb_exec(progbuf_exec), 
    .hart_progbuf_done(progbuf_done), 

    // memory interface 
    .pb_addr(dmi_addr[3:0]),  // from DM 
    .pb_wdata(dmi_wdata), // from Debugger 
    .pb_we(pb_we),  
    .pb_rdata(pb_rdata), // to debugger 
    .pb_re(pb_re)
);

// ======================================================================
// Seq Logic - update block 
// ======================================================================

always_ff @(posedge clk or negedge rst_n ) begin : sequential_updates
    if (!rst_n) begin

            dmcontrol_reg           <= 32'h0;
            abstractcs_reg.cmderr   <= CMDERR_NONE;
            abstractcs_reg.busy     <= 1'b0;
            command_reg             <= 32'h0;

            hart_halt_req           <= 1'b0;  
            hart_resume_req         <= 1'b0;     
            hart_reset_req          <= 1'b0; 
            
            hart_halted_r           <= 1'b0;
            hart_halted_sticky      <= 1'b0;
            hart_resuming           <= 1'b0;
            
            cmd_state               <= CMD_IDLE;
            
            for (int i = 0; i < 12; i++) begin
                data_regs[i]        <= 32'h0;
            end  
    end else begin 

    // ================================================================
    // hart status tracking 
    // ================================================================
        hart_halted_r <= hart_halted;

        if (hart_halted && !hart_halted_r) begin
            hart_halted_sticky <= 1'b1;
        end
        
        // Clear havereset on ackhavereset command
        if (dmi_valid && dmi_we && dmi_addr == DMI_DMCONTROL && dmcontrol_reg.ackhavereset) begin
                hart_halted_sticky <= 1'b0;
            end

        // DATA CAPTURE 
        if (!hart_halted && hart_halted_r) begin 
            hart_resuming <= 1'b1;
        end else if (hart_halted ) begin 
            hart_resuming <= 1'b0;
        end 


        // ================================================================
        // DMCONTROL register handling (0x10) pg 23
        // ================================================================
        if (dmi_valid && dmi_we && dmi_addr == DMI_DMCONTROL) begin 
            hart_halt_req       <= dmi_wdata[31]; // hartreq 
            if (dmi_wdata[30]) begin 
                hart_resume_req <= 1'b1; // resumereq
            end else begin 
                hart_resume_req <= 1'b0;
            end 
            hart_reset_req      <= dmi_wdata[29];
            dmcontrol_reg[0]    <= 1'b1; // dmactive always 1 
            dmcontrol_reg[31:1] <= dmi_wdata[31:1];
        end else begin 
            hart_resume_req <= 1'b0;
        end 

        // ================================================================
        // COMMAND regs
        // ================================================================
        if (dmi_valid && dmi_we && dmi_addr == DMI_COMMAND) begin 

            if (abstractcs_reg.busy) begin 
                abstractcs_reg.cmderr   <= CMDERR_BUSY; 

            end else begin 
                command_reg             <= dmi_wdata;
                cmd_access_reg          <= dmi_wdata;
                abstractcs_reg.busy     <= 1'b1;
                abstractcs_reg.cmderr   <= CMDERR_NONE;
                
            end 
        end
        // ================================================================
        // ABSTRACTCS regs 
        // ================================================================
        if (dmi_valid && dmi_we && dmi_addr == DMI_ABSTRACTCS) begin 
            abstractcs_reg.cmderr <= abstractcs_reg.cmderr & ~dmi_wdata[10:8]; // CLEAR ERROR
        end 
        // ================================================================
        // DATA REGISTERS (0x04-0x0f) - Write handling
        // ================================================================
        if (dmi_valid && dmi_we) begin
            case (dmi_addr)
                DMI_DATA0:  data_regs[0] <= dmi_wdata;
                DMI_DATA1:  data_regs[1] <= dmi_wdata;
                DMI_DATA2:  data_regs[2] <= dmi_wdata;
                DMI_DATA3:  data_regs[3] <= dmi_wdata;
                DMI_DATA4:  data_regs[4] <= dmi_wdata;
                DMI_DATA5:  data_regs[5] <= dmi_wdata;
                DMI_DATA6:  data_regs[6] <= dmi_wdata;
                DMI_DATA7:  data_regs[7] <= dmi_wdata;
                DMI_DATA8:  data_regs[8] <= dmi_wdata;
                DMI_DATA9:  data_regs[9] <= dmi_wdata;
                DMI_DATA10: data_regs[10] <= dmi_wdata;
                DMI_DATA11: data_regs[11] <= dmi_wdata;
                default: ;
            endcase
        end
        // ================================================================
        // COMMAND REGISTER (0x17) - Abstract command execution
        // ================================================================
        cmd_state <= cmd_state_next;

        // Inside the always_ff block, replace the old CMD_WAIT_HART read:
        if (cmd_state == CMD_REG_SAMPLE && !cmd_access_reg.write) begin
            if (is_gpr_access)
                data_regs[0] <= hart_regfile_rdata;
            else if (is_pc_access)
                data_regs[0] <= hart_pc_rdata;
        end


        // busy / error tracking stays the same, just update state names:
        if (cmd_state == CMD_DONE || cmd_state == CMD_ERROR)
            abstractcs_reg.busy <= 1'b0;

        if (cmd_state == CMD_ERROR)
            abstractcs_reg.cmderr <= CMDERR_NOT_SUPPORTED;

 
        // In the sequential block, replace the commented $display:
        // $display("[DM] clk=%0t state=%s hart_halted=%0b is_gpr=%0b gpr_addr=%0h rdata=%0h data0=%0h",
        //     $time, cmd_state.name(), hart_halted, is_gpr_access, 
        //     gpr_addr, hart_regfile_rdata, data_regs[0]);
     end
end 
endmodule