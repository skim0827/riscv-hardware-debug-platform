`timescale 1ns/1ps
module progbuf (
    input  logic clk, 
    input  logic rst_n,

    // Control signals from DM 
    input  logic pb_start, 
    input  logic pb_halt_req, 
    output logic pb_done, 
    output logic pb_exception, 

    // Instruction interface
    output logic [31:0] pb_instr, 
    output logic        pb_exec, 
    input  logic        hart_progbuf_done, 

    // Memory interface
    input  logic [3:0]  pb_addr,  // from DM 
    input  logic [31:0] pb_wdata, // from Debugger 
    input  logic        pb_we,  
    output logic [31:0] pb_rdata, // to debugger *
    input  logic        pb_re
 );

// Program counter FSM 

 typedef enum logic [2:0] { 
    PROGBUF_IDLE    = 3'h0, 
    PROGBUF_FETCH   = 3'h1, 
    PROGBUF_EXEC    = 3'h2,
    PROGBUF_DONE    = 3'h3, 
    PROGBUF_ERROR   = 3'h4
} progbuf_state_t;

// Internal Registers 
logic [31:0]     progbuf[0:15]; // instr memory 
logic [3:0]      progbuf_pc, progbuf_pc_next;
progbuf_state_t  progbuf_state, progbuf_state_next;

// Control Signals 
logic [31:0]     progbuf_instr_current; 
logic            is_ebreak; 
logic            is_last_pb_instr; 
logic            progbuf_exec_d; // One-cycle delay.


// Comb logic - Instruction decode 
always_comb begin : decode_progbuf_instr
    progbuf_instr_current = progbuf[progbuf_pc];
    is_ebreak             = (progbuf_instr_current == 32'h00100073);
    is_last_pb_instr      = (progbuf_pc == 4'd15);
end 

// Comb logic - progbuf read 
always_comb begin : progbuf_read 
    pb_rdata              = 32'h0;
    if (pb_re) pb_rdata   = progbuf[pb_addr]; 
end 

// FSM - Progbuf execution 
always_comb begin : progbuf_fsm 
    progbuf_state_next    = progbuf_state; 

    progbuf_pc_next       = progbuf_pc; 
    if(pb_halt_req) begin
        progbuf_state_next = PROGBUF_IDLE; 
        progbuf_pc_next    = 4'h0;
    end else begin 
        case (progbuf_state) 
            PROGBUF_IDLE : begin 
                if (pb_start) begin 
                    progbuf_state_next = PROGBUF_FETCH;
                    progbuf_pc_next    = 4'h0; 
                end 
            end 

            PROGBUF_FETCH : progbuf_state_next = PROGBUF_EXEC;

            PROGBUF_EXEC : begin
                if (hart_progbuf_done) progbuf_state_next = PROGBUF_DONE;
            end 

            PROGBUF_DONE : begin 
                if (is_ebreak || is_last_pb_instr) begin
                    progbuf_state_next = PROGBUF_IDLE;
                    progbuf_pc_next    = 4'h0; 
                end else begin 
                    progbuf_pc_next = progbuf_pc + 4'h1;
                    progbuf_state_next = PROGBUF_FETCH;
                end
            end 


            PROGBUF_ERROR : begin 
                progbuf_state_next = PROGBUF_IDLE; 
                progbuf_pc_next    = 4'h0;
            end 


            default : progbuf_state_next = PROGBUF_IDLE;
        endcase 
    end 
end 

// Comb logic - outputs 
always_comb begin : output_logic
    pb_instr     = progbuf_instr_current; 
    pb_exec      = (progbuf_state == PROGBUF_EXEC && !progbuf_exec_d); // one-cycle pulse
    pb_done      = (progbuf_state == PROGBUF_DONE && progbuf_state_next == PROGBUF_IDLE);
    pb_exception = 1'b0; // Exceptions not implemented yet.
end 

// Seq logic - state update 
always_ff @(posedge clk or negedge rst_n) begin 
    if (!rst_n) begin 
        progbuf_state <= PROGBUF_IDLE;
        progbuf_pc <= 4'h0;
        progbuf_exec_d <= 1'b0; 

        for (int i = 0; i < 16; i ++) begin 
            progbuf[i] <= 32'h0; 
        end  
    end else begin 
        progbuf_state <= progbuf_state_next;
        progbuf_pc <= progbuf_pc_next;
        progbuf_exec_d <= pb_exec;

        if (pb_we) progbuf[pb_addr] <= pb_wdata;
    end 
end 


endmodule : progbuf 
