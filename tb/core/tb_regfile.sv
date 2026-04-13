module tb_regfile;

logic clk; 
logic rst_n;

logic [4:0] a1;
logic [4:0] a2;
logic [4:0] a3; 
logic [31:0] wd3;
logic we3;

logic dbg_reg_we;
logic [4:0] dbg_addr;
logic [31:0] dbg_wdata;

logic [31:0] rd1;
logic [31:0] rd2;
logic [31:0] dbg_rdata;
regfile dut (
    .clk(clk),
    .rst_n(rst_n),
    .a1(a1),
    .a2(a2),
    .a3(a3),
    .wd3(wd3),
    .we3(we3),
    .dbg_reg_we(dbg_reg_we),
    .dbg_addr(dbg_addr),
    .dbg_wdata(dbg_wdata),
    .rd1(rd1),
    .rd2(rd2),
    .dbg_rdata(dbg_rdata)
);

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(1, tb_regfile);
end

always #3 clk = ~clk;

initial begin 
    clk = 0;
    rst_n = 1;
    we3 = 1; // to initialise 
    dbg_reg_we = 0;

    a1 = 0;
    a2 = 0;
    a3 = 0;
    dbg_addr = 0;
    dbg_wdata = 0;


    repeat(2) @(posedge clk);
    //set register 
    for (int i=0; i < 32; i ++) begin 
        a3 = 5'(i);
        if (i == 0) wd3 = 0;
        else wd3 = 2*i + 5;
        @(posedge clk);
    end 
    we3 = 0;

    repeat(2) @(posedge clk);
    for (int i =0; i < 1000; i ++) begin
        logic [4:0] addr1 = 5'($urandom_range(1,31));
        logic [4:0] addr2 = 5'($urandom_range(1,31));
        logic [4:0] addr3 = 5'($urandom_range(1,31));
        logic [4:0] dbg_addr_random = 5'($urandom_range(1,31));
        logic [31:0] value = $urandom;
        logic [31:0] dbg_value = $urandom;

        a1 = addr1;
        a2 = addr2; 
        dbg_addr = dbg_addr_random;

        #1;

        assert (rd1 == 2*addr1 + 5)
            else $error ("❌ read mismatch addr = %0d", addr1);
        assert (rd2 == 2*addr2 + 5)
            else $error ("❌ read mismatch addr = %d", addr2);
        assert (dbg_rdata == 2*dbg_addr_random + 5)
            else $error ("❌ dbg read mismatch addr = %d", addr2);           
        

        @(negedge clk);
        a3 = addr3;
        wd3 = value;
        we3 = 1;
        a1 = addr3;
        @(posedge clk);
        we3 = 0;
        #1;

        assert (rd1 == value)
            else $error("❌ write data is wrong");
        
        
        @(negedge clk); 
        dbg_reg_we = 1;
        dbg_wdata = dbg_value; 

        @(posedge clk);
        dbg_reg_we = 0;

        @(posedge clk);
        assert (dbg_rdata == dbg_value)
            else $error ("❌dbg read mismatch addr = %0d", dbg_addr);
        dbg_reg_we = 0;

    end 

    // Test x0 register
    @(negedge clk);
    a1 = 0;
    a3 = 0;
    wd3 = 32'hAEAEAEAE;
    we3 = 1;

    repeat(2) @(posedge clk);
    we3 = 0;
    assert (rd1 == 0)
        else $error("❌ x0 register modified");

    $display("✅ All regfile tests passed");
    $finish; 

end 
endmodule 