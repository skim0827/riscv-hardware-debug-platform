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


// INTERNAL REGISTERS - table 3.8
// ======================================================================
dmstatus_t              dmstatus_reg;
dmcontrol_t             dmcontrol_reg;
abstractcs_t            abstractcs_reg;
command_t               command_reg;
cmd_access_register_t   cmd_access_reg;

logic [31:0]    data_regs[0:11];
logic [31:0]    progbuf[0:15];

// STATE MACHINE for DM 
// ======================================================================
typedef enum logic [3:0] { 
    CMD_IDLE        = 4'h0, 
    CMD_START       = 4'h1,
    CMD_TRANSFER    = 4'h2, // transferring data to/from hart 
    CMD_PROGBUF     = 4'h3, // only if postexe = 1
    CMD_WAIT_HART   = 4'h4, // waiting for hart to complete 
    CMD_DONE        = 4'h5, 
    CMD_ERROR       = 4'h6
} cmd_state_t;

cmd_state_t cmd_state, cmd_state_next; 


// INTERNAL STATE & HELPER SIGNALS 
// ======================================================================
logic hart_halted_r; 
logic hart_halted_sticky;
logic hart_resuming;

logic [4:0] gpr_addr; 
logic is_gpr_access; 
logic is_pc_access; 
logic is_csr_access; 

// COMB LOGIC - REGISTER READS 
// ======================================================================
always_comb begin : read_path 
    dmi_rdata = 32'h0; 

    if (dmi_re) begin 
        case(dmi_addr)   
            DMI_DMSTATUS    : dmi_rdata = dmstatus_reg; 
            DMI_DMCONTROL   : dmi_rdata = dmcontrol_reg;
            DMI_HARTINFO    : dmi_rdata = 32'h0000_0c00; // dataaddr = 0 (hardcoded), datasize = 12, nscratch = 0 section 3.12.3

            DMI_ABSTRACTCS  : dmi_rdata = abstractcs_reg;
            DMI_COMMAND     : dmi_rdata = command_reg;

            // Data registers (0x04-0x0f)
            DMI_DATA0: dmi_rdata = data_regs[0];
            DMI_DATA1: dmi_rdata = data_regs[1];
            DMI_DATA2: dmi_rdata = data_regs[2];
            DMI_DATA3: dmi_rdata = data_regs[3];
            DMI_DATA4: dmi_rdata = data_regs[4];
            DMI_DATA5: dmi_rdata = data_regs[5];
            DMI_DATA6: dmi_rdata = data_regs[6];
            DMI_DATA7: dmi_rdata = data_regs[7];
            DMI_DATA8: dmi_rdata = data_regs[8];
            DMI_DATA9: dmi_rdata = data_regs[9];
            DMI_DATA10: dmi_rdata = data_regs[10];
            DMI_DATA11: dmi_rdata = data_regs[11];
            // Program buffer (0x20-0x2f)
            DMI_PROGBUF0:  dmi_rdata = progbuf[0];
            DMI_PROGBUF1:  dmi_rdata = progbuf[1];
            DMI_PROGBUF2:  dmi_rdata = progbuf[2];
            DMI_PROGBUF3:  dmi_rdata = progbuf[3];
            DMI_PROGBUF4:  dmi_rdata = progbuf[4];
            DMI_PROGBUF5:  dmi_rdata = progbuf[5];
            DMI_PROGBUF6:  dmi_rdata = progbuf[6];
            DMI_PROGBUF7:  dmi_rdata = progbuf[7];
            DMI_PROGBUF8:  dmi_rdata = progbuf[8];
            DMI_PROGBUF9:  dmi_rdata = progbuf[9];
            DMI_PROGBUF10: dmi_rdata = progbuf[10];
            DMI_PROGBUF11: dmi_rdata = progbuf[11];
            DMI_PROGBUF12: dmi_rdata = progbuf[12];
            DMI_PROGBUF13: dmi_rdata = progbuf[13];
            DMI_PROGBUF14: dmi_rdata = progbuf[14];
            DMI_PROGBUF15: dmi_rdata = progbuf[15];

            default: dmi_rdata = 32'h0;
        endcase
    end 
    
end

// COMB LOGIC - COMMAND DECODING table 4.1
// ======================================================================
always_comb begin : decode_command
    cmd_access_reg = command_reg;
    gpr_addr = cmd_access_reg.regno[4:0];
    // (Spec Table 3.3)
    is_gpr_access = (cmd_access_reg.regno >= 16'h1000) && 
                    (cmd_access_reg.regno <= 16'h101f);  // x0-x31
    is_pc_access = (cmd_access_reg.regno == 16'h7b1);   // DPC
    is_csr_access = (cmd_access_reg.regno <= 16'h0fff);  // CSRs
    gpr_addr = cmd_access_reg.regno[4:0];
end 

// COMB LOGIC - DMSTATUS REG UPDATE 
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

// COMB LOGIC - ABSTRACTS REG FIELDS 
// ======================================================================
always_comb begin : set_abstracts_fields
    abstractcs_reg.reserved1   = 3'b0;
    abstractcs_reg.progbufsize = 5'h4;     // 16 words
    abstractcs_reg.reserved2   = 11'b0;
    // abstractcs_reg.busy handled in sequential
    abstractcs_reg.reserved3   = 1'b0;
    // abstractcs_reg.cmderr handled in sequential
    abstractcs_reg.reserved4   = 4'b0;
    abstractcs_reg.datacount   = 4'd12;     // 12 data registers 
end 

// SEQ LOGIC - REG UPDATES 
// ======================================================================

always_ff @(posedge clk or negedge rst_n ) begin : sequential_updates
    if (!rst_n) begin

            dmcontrol_reg <= 32'h0;
            abstractcs_reg.cmderr <= CMDERR_NONE;
            abstractcs_reg.busy <= 1'b0;
            command_reg <= 32'h0;

            
            hart_halted_r <= 1'b0;
            hart_halted_sticky <= 1'b0;
            hart_resuming <= 1'b0;
            
            cmd_state <= CMD_IDLE;
            
            for (int i = 0; i < 12; i++) begin
                data_regs[i] <= 32'h0;
            end
            for (int i = 0; i < 16; i++) begin
                progbuf[i] <= 32'h0;
            end


            data_regs[0] <= 32'h0;

// ======================================================================  
    end else begin 

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

        // DMCONTROL register handling (0x10) pg 23
        if (dmi_valid && dmi_we && dmi_addr == DMI_DMCONTROL) begin 
            hart_halt_req <= dmi_wdata[31]; // hartreq 
            if (dmi_wdata[30]) begin 
                hart_resume_req <= 1'b1; // resumereq
            end else begin 
                hart_resume_req <= 1'b0;
            end 
            hart_reset_req <= dmi_wdata[29];
            dmcontrol_reg[0] <= 1'b1; // dmactive always 1 
            dmcontrol_reg[31:1] <= dmi_wdata[31:1];
        end else begin 
            hart_resume_req <= 1'b0;
        end 



        // DATA REGISTERS (0x04-0x0f) - Write handling
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
        

        // PROGRAM BUFFER (0x20-0x2f) - Write handling
        if (dmi_valid && dmi_we) begin
            case (dmi_addr)
                DMI_PROGBUF0:  progbuf[0] <= dmi_wdata;
                DMI_PROGBUF1:  progbuf[1] <= dmi_wdata;
                DMI_PROGBUF2:  progbuf[2] <= dmi_wdata;
                DMI_PROGBUF3:  progbuf[3] <= dmi_wdata;
                DMI_PROGBUF4:  progbuf[4] <= dmi_wdata;
                DMI_PROGBUF5:  progbuf[5] <= dmi_wdata;
                DMI_PROGBUF6:  progbuf[6] <= dmi_wdata;
                DMI_PROGBUF7:  progbuf[7] <= dmi_wdata;
                DMI_PROGBUF8:  progbuf[8] <= dmi_wdata;
                DMI_PROGBUF9:  progbuf[9] <= dmi_wdata;
                DMI_PROGBUF10: progbuf[10] <= dmi_wdata;
                DMI_PROGBUF11: progbuf[11] <= dmi_wdata;
                DMI_PROGBUF12: progbuf[12] <= dmi_wdata;
                DMI_PROGBUF13: progbuf[13] <= dmi_wdata;
                DMI_PROGBUF14: progbuf[14] <= dmi_wdata;
                DMI_PROGBUF15: progbuf[15] <= dmi_wdata;
                default: ;
            endcase
        end




        // COMMAND REGISTER (0x17) - Abstract command execution
        if (dmi_valid && dmi_we && dmi_addr == DMI_COMMAND) begin 

            if (abstractcs_reg.busy) begin 
                abstractcs_reg.cmderr <= CMDERR_BUSY; 

            end else begin 
                command_reg  <= dmi_wdata;
                abstractcs_reg.busy <= 1'b1;
                abstractcs_reg.cmderr <= CMDERR_NONE;
                cmd_state  <= CMD_START;
            end 
        end
             



        // ABSTRACTCS register updates section 3.12.6
        if (dmi_valid && dmi_we && dmi_addr == DMI_ABSTRACTCS) begin 
            abstractcs_reg.cmderr <= abstractcs_reg.cmderr & ~dmi_wdata[10:8]; // CLEAR ERROR
        end 


        if (cmd_state == CMD_TRANSFER && cmd_access_reg.transfer && !cmd_access_reg.write && abstractcs_reg.busy) begin 

            if (is_gpr_access) data_regs[0] <= hart_regfile_rdata;
            else if (is_pc_access) data_regs[0] <= hart_pc_rdata;
        end 


        // STATE MACHINE 
        cmd_state <=  cmd_state_next;

        if (cmd_state == CMD_DONE || cmd_state == CMD_ERROR) begin 
            abstractcs_reg.busy <= 1'b0;
        end 

        if (cmd_state == CMD_ERROR) begin 
            abstractcs_reg.cmderr <= CMDERR_NOT_SUPPORTED;
        end 
     end
end 

// STATE MACHINE - command exe control 
// ======================================================================
always_comb begin 
    cmd_state_next = cmd_state;
    case (cmd_state) 
        CMD_IDLE : begin 
        end 

        CMD_START : begin 
            case (cmd_access_reg.cmdtype)
                8'h00 : cmd_state_next = CMD_TRANSFER;
                default : cmd_state_next = CMD_ERROR;
            endcase
        end 

        CMD_TRANSFER: begin
            if (cmd_access_reg.postexec) cmd_state_next = CMD_PROGBUF; 
            else cmd_state_next = CMD_DONE;
        end

        CMD_PROGBUF : begin 
            if (progbuf_done) begin 
                if (progbuf_exception) cmd_state_next = CMD_ERROR; 
                else cmd_state_next = CMD_DONE;
            end
        end  

        CMD_DONE : cmd_state_next = CMD_IDLE;
        CMD_ERROR : cmd_state_next = CMD_IDLE;
        default : cmd_state_next = CMD_IDLE;
    endcase
end 




// HART INTERFACE - ABSTRACT COMMAND EXECUTION
// ======================================================================
always_comb begin 
    hart_regfile_we = 1'b0;
    hart_regfile_addr = 5'h0;
    hart_regfile_wdata = 32'h0;
    hart_pc_we = 1'b0;
    hart_pc_wdata = 32'h0;
    progbuf_exec = 1'b0;
    progbuf_instr = 32'h0;

    if (abstractcs_reg.busy && cmd_state == CMD_TRANSFER) begin 
        if (cmd_access_reg.transfer) begin   
            hart_regfile_addr = gpr_addr;

            if (cmd_access_reg.write) begin 
                hart_regfile_we = 1'b1;
                hart_regfile_wdata = data_regs[0];

            end 
        end 
    end 


    if (abstractcs_reg.busy && cmd_state == CMD_PROGBUF) begin 
        progbuf_exec = 1'b1;
        progbuf_instr = progbuf[0];
    end 
end



endmodule 