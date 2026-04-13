module cmd_cdc_bridge(
    input logic tck,
    input logic clk,
    input logic rst_n,
    // from DTM 
    input logic cmd_valid_tck,
    input debug_cmd_t cmd_opcode_tck, 
    input logic [23:0] cmd_data_tck,

    //to debug module
    output logic cmd_valid_clk,
    output debug_cmd_t cmd_opcode_clk,
    output logic [31:0] cmd_data_clk 
);

debug_cmd_t opcode_reg;
logic [31:0] data_reg; 
logic toggle_tck;
always_ff @(posedge tck or negedge rst_n) begin 
    if (!rst_n) begin 
        toggle_tck <= 0;
    end else if (tck) begin 
        opcode_reg <= cmd_opcode_tck;
        data_reg   <= cmd_data_tck;
        toggle_tck <= ~toggle_tck;
    end 
end 

logic sync1, sync2;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        sync1 <= 0;
        sync2 <= 0;
    end else begin 
        sync1 <= toggle_tck;
        sync2 <= sync1;
    end 
end 

logic last_toggle;
always_ff @(posedge clk or negedge rst_n)begin
    if (!rst_n) begin
        last_toggle <= 0;
        cmd_valid_clk <= 0; 
    end else begin 
        cmd_valid_clk <= (sync2 != last_toggle);
        last_toggle <= sync2;
    end 
end 

assign cmd_opcode_clk = opcode_reg;
assign cmd_data_clk   = data_reg;

endmodule 