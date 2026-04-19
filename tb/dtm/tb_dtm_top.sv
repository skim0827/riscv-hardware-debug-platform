// ============================================================================
// Debug Transport Module (DTM) - JTAG Top Level
// ============================================================================
// Test Coverage:
//   - JTAG TAP state machine integration
//   - IR (Instruction Register) operations
//   - DR (Data Register) operations for all instructions
//   - IDCODE instruction (0x01)
//   - DTMCS instruction (0x10) - DTM Control and Status
//   - DMI instruction (0x11) - Debug Module Interface Access
//   - BYPASS instruction (0x1f)
//   - DMI read/write operations
//   - TDO output multiplexing
//   - State transitions
//   - Reset behaviour
// ============================================================================
 

`timescale 1ns/1ps
module tb_dtm_top;
import dmi_pkg::*;

localparam TCK_PERIOD = 20; // 20ns = 50MHz

// IR instruction codes (from spec table 6.1)
localparam [4:0] IR_IDCODE  = 5'h01;
localparam [4:0] IR_DTMCS   = 5'h10;
localparam [4:0] IR_DMI     = 5'h11;
localparam [4:0] IR_BYPASS  = 5'h1f;

localparam [31:0] IDCODE_VALUE = 32'h12345678;


// JTAG Signals
logic tck;
logic tdi;
logic tdo;
 
// TAP control signals
logic capture_ir;
logic shift_ir;
logic update_ir;
logic capture_dr;
logic shift_dr;
logic update_dr;



// DMI Interface
logic [6:0]  dmi_addr;
logic [31:0] dmi_wdata;
logic        dmi_we;
logic        dmi_re;
logic [31:0] dmi_rdata;
 
// DTMCS status signals
logic        dtmcs_dmihardreset;
logic        dtmcs_dmireset;
logic [2:0]  dtmcs_idle;
logic [1:0]  dtmcs_dmistat;
logic [5:0]  dtmcs_abits;


// Test signals
logic [40:0] tdi_shift_data;  
logic [40:0] tdo_shift_data;   
logic test_error;
int test_count;
int pass_count;
int fail_count;


dtm_top #(
    .WIDTH          (32),
    .DTMCS_WIDTH    (32),
    .DMI_WIDTH      (41),
    .IDCODE_WIDTH   (32)
) dut (
    .tck                (tck),
    .tdi                (tdi),
    .tdo                (tdo),
    
    .capture_ir         (capture_ir),
    .shift_ir           (shift_ir),
    .update_ir          (update_ir),
    .capture_dr         (capture_dr),
    .shift_dr           (shift_dr),
    .update_dr          (update_dr),
    
    .dmi_addr           (dmi_addr),
    .dmi_wdata          (dmi_wdata),
    .dmi_we             (dmi_we),
    .dmi_re             (dmi_re),
    .dmi_rdata          (dmi_rdata),
    
    .dtmcs_dmihardreset (dtmcs_dmihardreset),
    .dtmcs_dmireset     (dtmcs_dmireset),
    .dtmcs_idle         (dtmcs_idle),
    .dtmcs_dmistat      (dtmcs_dmistat),
    .dtmcs_abits        (dtmcs_abits)
);
 
initial begin
    tck = 1'b0;
    forever #(TCK_PERIOD/2) tck = ~tck;
end

// ============================================================================
// HELPER TASKS
// ============================================================================

task automatic jtag_init();
    tdi = 1'b0;
    capture_ir = 1'b0;
    shift_ir = 1'b0;
    update_ir = 1'b0;
    capture_dr = 1'b0;
    shift_dr = 1'b0;
    update_dr = 1'b0;
    dmi_rdata = 32'h0;
    dtmcs_idle = 3'b000;
    dtmcs_dmistat = 2'b00; // DMI_IDLE 
    dtmcs_abits = 6'd7; // 7-bit address space
endtask : jtag_init


task jtag_shift_ir(input logic [4:0] ir_value);
    $display("[JTAG] Shifting IR with value 0x%01x", ir_value);
    @(posedge tck);
    capture_ir = 1'b1;
    @(posedge tck); 
    capture_ir = 1'b0;

    @(posedge tck);
    shift_ir = 1'b1;
    for (int i = 0; i < 5; i++) begin
        tdi = ir_value[i];
        @(posedge tck); 
    end
    shift_ir = 1'b0;
    @(posedge tck);


    @(posedge tck);
    update_ir = 1'b1;
    @(posedge tck);
    update_ir = 1'b0;
    @(posedge tck);

endtask : jtag_shift_ir


task automatic jtag_shift_dr(input logic [40:0] dr_in,
                            input int length,
                            output logic [40:0] dr_out);

    logic captured_bit;

    $display("[JTAG] Shifting DR, length=%0d bits", length);

    @(posedge tck);
    capture_dr = 1'b1;
    @(posedge tck);
    capture_dr = 1'b0;

    @(posedge tck);
    shift_dr = 1'b1;
    dr_out = 41'b0; // Clear output before shifting


    for (int i = 0; i < length; i++) begin
        
        tdi = dr_in[i]; // LMB first
        @(negedge tck); 
        captured_bit = tdo;
        dr_out[i] = captured_bit;
        @(posedge tck);
    end

    shift_dr = 1'b0;

    @(posedge tck);
    update_dr = 1'b1;
    @(posedge tck);
    update_dr = 1'b0;
    @(posedge tck);
endtask : jtag_shift_dr

task automatic jtag_idcode_read(output logic [31:0] idcode);
    logic [40:0] dr_out;
    $display("[JTAG] IDCODE Read Sequence");

    jtag_shift_ir(IR_IDCODE); // Shift IDCODE instruction into IR
    repeat(10) @(posedge tck);
    jtag_shift_dr(41'h0, 32, dr_out);

    idcode = dr_out[31:0];
    $display("[JTAG]   IDCODE = 0x%08x", idcode);

endtask : jtag_idcode_read

task automatic jtag_dtmcs_read(output logic [31:0] dtmcs);
    logic [40:0] dr_out;

    jtag_shift_ir(IR_DTMCS); // Shift DTMCS instruction into IR
    jtag_shift_dr(41'h0, 32, dr_out);
    dtmcs = dr_out[31:0];   
    $display("[JTAG]   DTMCS = 0x%08x", dtmcs);
endtask : jtag_dtmcs_read


task automatic jtag_dtmcs_write(input logic dmihardreset, input logic dmireset);
    logic [31:0] dtmcs_value;
    logic [40:0] dr_in;
    logic [40:0] dr_out;
    $display("[JTAG] DTMCS Write Sequence (dmihardreset=%b, dmireset=%b)", 
             dmihardreset, dmireset);
    jtag_shift_ir(IR_DTMCS);

    dtmcs_value = 32'h0;
    dtmcs_value[17] = dmihardreset;
    dtmcs_value[16] = dmireset;

    dr_in = {9'b0, dtmcs_value};
    jtag_shift_dr(dr_in, 32, dr_out);    
endtask : jtag_dtmcs_write

task automatic jtag_dmi_read(input logic [6:0] addr, output logic [31:0] rdata);
    logic [40:0] dr_in; 
    logic [40:0] dr_out;

    $display("[JTAG] DMI Read Sequence (addr=0x%02x)", addr);

    jtag_shift_ir(IR_DMI);

    dr_in = 41'h0;
    dr_in[1:0] = 2'b01;   // Read Op 
    dr_in[40:34] = addr; 


    jtag_shift_dr(dr_in, 41, dr_out);
    rdata = dr_out[33:2];
    $display("[JTAG]   Read Data = 0x%08x", rdata);
endtask : jtag_dmi_read


task automatic jtag_dmi_write(input logic [6:0] addr, input logic [31:0] wdata);
    logic [40:0] dr_in; 
    logic [40:0] dr_out;

    $display("[JTAG] DMI Write Sequence (addr=0x%02x, data=0x%08x)", addr, wdata);

    jtag_shift_ir(IR_DMI);

    dr_in = 41'h0;
    dr_in[1:0] = 2'b10; // write
    dr_in[40:34] = addr;
    dr_in[33:2] = wdata;

    jtag_shift_dr(dr_in, 41, dr_out);
endtask : jtag_dmi_write

task automatic jtag_bypass();
    logic [40:0] dr_in;
    logic [40:0] dr_out; 

    $display("[JTAG] BYPASS Instruction");

    jtag_shift_ir(IR_BYPASS);
    jtag_shift_dr(41'h0, 1, dr_out);

endtask : jtag_bypass



task automatic assert_equal(input logic [31:0] actual, input logic [31:0] expected, input string test_name);

    if (actual == expected) begin 
        $display("[PASS] %s: Expected 0x%08x, got 0x%08x", test_name, expected, actual);
        pass_count++;
    end else begin 
        $display("[❌FAIL] %s - Expected: 0x%08x, Got: 0x%08x", test_name, expected, actual);
        fail_count++;
        test_error = 1;
    end 
    test_count++;
endtask : assert_equal

task automatic assert_equal_masked(input logic [31:0] actual, 
                                   input logic [31:0] expected,
                                   input logic [31:0] mask,
                                   input string test_name);
    logic [31:0] masked_actual;
    logic [31:0] masked_expected;

    masked_actual = actual & mask;
    masked_expected = expected & mask;

    if (masked_actual == masked_expected) begin 
        $display("[PASS] %s - Expected: 0x%08x (mask 0x%08x)", test_name, expected, mask);
        pass_count++;

    end else begin 
        $display("[❌FAIL] %s - Expected: 0x%08x, Got: 0x%08x (mask 0x%08x)", 
                 test_name, masked_expected, masked_actual, mask);
        fail_count++;
        test_error = 1; 

    end 
    test_count++;

endtask : assert_equal_masked

// ============================================================================
// TEST 1: JTAG IDCODE read
// ============================================================================
task automatic test_idcode_read();
    logic [31:0] idcode;
    $display("\n=== TEST 1: JTAG IDCODE Read ===");

    jtag_idcode_read(idcode);
    assert_equal(idcode, IDCODE_VALUE, "IDCODE Read");
endtask : test_idcode_read


// ============================================================================
// TEST 2: DTMCS register read
// ============================================================================
 
task automatic test_dtmcs_read();
    logic [31:0] dtmcs;
    $display("\n=== TEST 2: DTMCS Register Read ===");

    jtag_dtmcs_read(dtmcs);
    // Verify version field (bits [3:0] should be 0x1 for v0.13)
    assert_equal_masked(dtmcs, 32'h0000_0001, 32'h0000_000F, "DTMCS version field");
    // Verify abits field (bits [9:4] should be 7 for 7-bit address)
    assert_equal_masked(dtmcs, 32'h0000_0070, 32'h0000_03F0, "DTMCS abits field");

endtask : test_dtmcs_read


// ============================================================================
// TEST 3: DTMCS DMI reset
// ============================================================================
task automatic test_dtmcs_dmireset();
    logic [31:0] dtmcs_value;
    logic [40:0] dr_in;
    $display("\n=== TEST 3: DTMCS DMI Reset ===");

    $display("[JTAG] DTMCS Write Sequence (dmihardreset=%b, dmireset=%b)", 
             0, 1);
    jtag_shift_ir(IR_DTMCS);

    dtmcs_value = 32'h0;
    dtmcs_value[17] = 0; // dmihardreset=0
    dtmcs_value[16] = 1; // dmireset=1
    dr_in = {9'b0, dtmcs_value};

    @(posedge tck); capture_dr = 1;
    @(posedge tck); capture_dr = 0;
    @(posedge tck); shift_dr = 1;
    for (int i=0; i<32; i++) begin
        tdi = dr_in[i];
        @(posedge tck);
    end
    shift_dr = 0;
    update_dr = 1;
    @(posedge tck);

    assert_equal(32'(dtmcs_dmireset), 32'b1, "dtmcs_dmireset signal asserted");
    // After update_dr, signal should deassert
    update_dr = 0;
    @(posedge tck);
    assert_equal(32'(dtmcs_dmireset), 32'b0, "dtmcs_dmireset signal deasserted");
endtask : test_dtmcs_dmireset

// ============================================================================
// TEST 4: DTMCS DMI hard reset
// ============================================================================
task automatic test_dtmcs_dmihardreset();
    
    logic [31:0] dtmcs_value;
    logic [40:0] dr_in;
    $display("\n=== TEST 4: DTMCS DMI Hard Reset ===");
    $display("[JTAG] DTMCS Write Sequence (dmihardreset=%b, dmireset=%b)", 
             1, 0);
    jtag_shift_ir(IR_DTMCS);

    dtmcs_value = 32'h0;
    dtmcs_value[17] = 1; // dmihardreset=1
    dtmcs_value[16] = 0; // dmireset=0
    dr_in = {9'b0, dtmcs_value};

    @(posedge tck); capture_dr = 1;
    @(posedge tck); capture_dr = 0;
    @(posedge tck); shift_dr = 1;
    for (int i=0; i<32; i++) begin
        tdi = dr_in[i];
        @(posedge tck);
    end
    shift_dr = 0;
    update_dr = 1;
    @(posedge tck);

    assert_equal(32'(dtmcs_dmihardreset), 32'b1, "dtmcs_dmihardreset signal asserted");
    // After update_dr, signal should deassert
    update_dr = 0;
    @(posedge tck);
    assert_equal(32'(dtmcs_dmihardreset), 32'b0, "dtmcs_dmihardreset signal deasserted");


endtask : test_dtmcs_dmihardreset


// ============================================================================
// TEST 5: DMI write operation
// ============================================================================
task test_dmi_write();
    logic [6:0] write_addr;
    logic [31:0] write_data;
    $display("\n=== TEST 5: DMI Write Operation ===");

    write_addr = DMI_DATA0;
    write_data = 32'hDEADBEEF;

    jtag_dmi_write(write_addr, write_data);

    assert_equal(32'(dmi_addr), 32'(write_addr), "DMI address matches");
    assert_equal(32'(dmi_wdata), 32'(write_data), "DMI write data matches");

endtask : test_dmi_write
// ============================================================================
// TEST 6: DMI read operation
// ============================================================================
task automatic test_dmi_read();
    logic [6:0] read_addr;
    logic [31:0] read_data;
    logic [31:0] expected_data;

    $display("\n=== TEST 6: DMI Read Operation ===");
    read_addr = DMI_DMSTATUS;
    expected_data = 32'hCAFECAFE;

    dmi_rdata = expected_data; // preset dmi_rdata for this read 
    jtag_dmi_read(read_addr, read_data);

    assert_equal(32'(dmi_addr), 32'(read_addr), "DMI address matches");
    assert_equal(read_data, expected_data, "DMI read data matches");

endtask : test_dmi_read

// ============================================================================
// TEST 7: IR instruction decoding
// ============================================================================
task automatic test_ir_decoding();
    logic [40:0] dr_out;

    $display("\n=== TEST 7: IR Instruction Decoding ===");

    // Select IDCODE (0x01)
    jtag_shift_ir(IR_IDCODE);
    jtag_shift_dr(41'h0, 32, dr_out);
    assert_equal(dr_out[31:0], IDCODE_VALUE, "IDCODE selected via IR");

    // Select BYPASS (0x1f)
    jtag_shift_ir(IR_BYPASS);
    jtag_shift_dr(41'h0, 1, dr_out);

    assert_equal(32'(dr_out[0]), 32'b0, "BYPASS captures 0");



endtask : test_ir_decoding
// ============================================================================
// TEST 8: Consecutive DMI operations
// ============================================================================
task automatic test_consecutive_dmi_operations();
    logic [31:0] rdata;
    $display("\n=== TEST 8: Consecutive DMI Operations ===");

    for (int i =0; i < 4; i ++ ) begin
        jtag_dmi_write(7'(DMI_DATA0 + i), {8'(8'h10 + i), 24'h0});
        repeat(2) @(posedge tck);

    end


    for (int i=0; i < 4; i++) begin
        @(posedge tck); dmi_rdata = {8'(8'h20 + i), 24'h0}; // fake returned data
        jtag_dmi_read(7'(DMI_DATA0 + i), rdata);
        assert_equal(32'(rdata), {8'(8'h20 + i), 24'h0}, $sformatf("DMI read %0d", i));

    end
endtask : test_consecutive_dmi_operations 


// ============================================================================
// TEST 9: TDO output during IR shift
// ============================================================================
task automatic test_tdo_ir_shift();
    logic [4:0] old_ir; 
    logic [4:0] new_ir;
    logic tdo_bit; 

    $display("\n=== TEST 9: TDO Output During IR Shift ===");
    old_ir = 5'b00101;
    new_ir = 5'b10101; 

    jtag_shift_ir(old_ir);

    shift_ir = 1'b1;
    for (int i =0; i < 5; i++) begin 
        
        tdi = new_ir[i];
        @(negedge tck);

        tdo_bit = tdo;
        @(posedge tck);
        assert_equal(32'(tdo_bit), 32'(old_ir[i]), $sformatf("TDO IR bit %0d", i));
    end 
    shift_ir = 1'b0;

endtask : test_tdo_ir_shift
// ============================================================================
// TEST 10: DMI Command Decode (Address / Write Data)
// ============================================================================

task automatic test_dmi_command_decode();
    logic [6:0] test_addr;
    logic [31:0] test_data;
 

    $display("\n=== TEST 10: DMI Command Decode ===");

    test_addr = 7'h04; // a dummy placeholder
    test_data = 32'h11223344;

    $display("[INFO] Testing DMI operation codes");
    $display("       NOP (00), READ (01), WRITE (10)");

    // op=WRITE (10)
    jtag_dmi_write(test_addr, test_data);
    assert_equal(32'(dmi_addr),  32'(test_addr), "DMI write address matches");
    assert_equal(dmi_wdata, test_data, "DMI write data matches");


endtask : test_dmi_command_decode


// ============================================================================
// MAIN TEST SEQUENCE
// ============================================================================
 
initial begin 
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    test_error = 0;

    jtag_init();

    $display("\n");
    $display("╔════════════════════════════════════════════════════════╗");
    $display("║     JTAG DEBUG TRANSPORT MODULE (DTM) TESTBENCH        ║");
    $display("║     RISC-V External Debug v0.13.2                      ║");
    $display("║     TAP Controller Simulation                          ║");
    $display("╚════════════════════════════════════════════════════════╝");
    $display("\n");


    repeat(10) @(posedge tck); // Wait for a few cycles before starting tests

    // Execute test suite
    test_idcode_read();
    test_dtmcs_read();
    test_dtmcs_dmireset();
    test_dtmcs_dmihardreset();
    test_dmi_write();
    test_dmi_read();
    test_ir_decoding();
    test_consecutive_dmi_operations();
    test_tdo_ir_shift();
    test_dmi_command_decode();


    $display("\n");
    $display("╔════════════════════════════════════════════════════════╗");
    $display("║                    TEST SUMMARY                        ║");
    $display("╚════════════════════════════════════════════════════════╝");
    $display("Total Tests:  %0d", test_count);
    $display("Passed:       %0d", pass_count);
    $display("Failed:       %0d", fail_count);
    

    #100 $finish;

end 
endmodule : tb_dtm_top