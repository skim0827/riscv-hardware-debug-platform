module tap_fsm (
    input logic tck,
    input logic tms,

    output logic capture_ir,
    output logic shift_ir,
    output logic update_ir,

    output logic capture_dr,
    output logic shift_dr,
    output logic update_dr
); 

import riscv_pkg::tap_t;
tap_t state, next_state;

initial state = TEST_LOGIC_RESET;
always_ff @(posedge tck) begin
    state <= next_state;
end
always_comb begin
    case (state) 
        TEST_LOGIC_RESET : 
            next_state = (tms) ? TEST_LOGIC_RESET : RUN_TEST_IDLE;
        RUN_TEST_IDLE : 
            next_state = (tms) ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        SELECT_DR_SCAN : 
            next_state = (tms) ? SELECT_IR_SCAN : CAPTURE_DR ; 
        SELECT_IR_SCAN : 
            next_state = (tms) ? TEST_LOGIC_RESET : CAPTURE_IR;
        CAPTURE_DR : 
            next_state = (tms) ? EXIT1_DR : SHIFT_DR ; 
        CAPTURE_IR : 
            next_state = (tms) ? EXIT1_IR : SHIFT_IR;
        SHIFT_DR : 
            next_state = (tms) ? EXIT1_DR : SHIFT_DR;
        SHIFT_IR : 
            next_state = (tms) ? EXIT1_IR : SHIFT_IR;
        EXIT1_DR : 
            next_state = (tms) ? UPDATE_DR : PAUSE_DR;
        EXIT1_IR : 
            next_state = (tms) ? UPDATE_IR : PAUSE_IR;
        PAUSE_DR : 
            next_state = (tms) ? EXIT2_DR : PAUSE_DR;
        PAUSE_IR :
            next_state = (tms) ? EXIT2_IR : PAUSE_IR;
        EXIT2_DR : 
            next_state = (tms) ? UPDATE_DR : SHIFT_DR;
        EXIT2_IR : 
            next_state = (tms) ? UPDATE_IR : SHIFT_IR;
        UPDATE_DR : 
            next_state = (tms) ? SELECT_DR_SCAN : RUN_TEST_IDLE;
        UPDATE_IR :  
            next_state = (tms) ? SELECT_IR_SCAN : RUN_TEST_IDLE;
        default : next_state = TEST_LOGIC_RESET;
    endcase 
end 

assign shift_ir   = (state == SHIFT_IR);
assign capture_ir = (state == CAPTURE_IR);
assign update_ir  = (state == UPDATE_IR);

assign shift_dr   = (state == SHIFT_DR);
assign capture_dr = (state == CAPTURE_DR);
assign update_dr  = (state == UPDATE_DR);

endmodule


