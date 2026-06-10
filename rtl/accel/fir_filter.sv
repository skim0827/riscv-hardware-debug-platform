module fir_filter #(
    parameter int TAPS        = 8,
    parameter signed [15:0] COEFF_0 = -16'sd53, // signed decimal 
    parameter signed [15:0] COEFF_1 =  16'sd0,
    parameter signed [15:0] COEFF_2 =  16'sd1995,
    parameter signed [15:0] COEFF_3 =  16'sd4096,
    parameter signed [15:0] COEFF_4 =  16'sd4096,
    parameter signed [15:0] COEFF_5 =  16'sd1995,
    parameter signed [15:0] COEFF_6 =  16'sd0,
    parameter signed [15:0] COEFF_7 = -16'sd53
)(
    input  logic        clk,
    input  logic        rst_n,
 
    // Input handshake
    input  logic signed [15:0] data_in,
    input  logic               valid_in,
    output logic               ready_out,   // always 1 (no backpressure)
 
    // Output handshake
    output logic signed [15:0] data_out,
    output logic               valid_out
);
 
// holds the last TAPS samples
logic signed [15:0] shift_reg [0:TAPS-1];

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (int i = 0; i < TAPS; i++) shift_reg[i] <= '0;
    end else if (valid_in) begin
        shift_reg[0] <= data_in;
        for (int i = 1; i < TAPS; i++)
            shift_reg[i] <= shift_reg[i-1];
    end
end

logic signed [31:0] products [0:TAPS-1]; // Each tap:  product[i] = h[i] * x[n-i]   (32-bit signed)
logic signed [31:0] acc; // Sum

assign products[0] = COEFF_0 * shift_reg[0];
assign products[1] = COEFF_1 * shift_reg[1];
assign products[2] = COEFF_2 * shift_reg[2];
assign products[3] = COEFF_3 * shift_reg[3];
assign products[4] = COEFF_4 * shift_reg[4];
assign products[5] = COEFF_5 * shift_reg[5];
assign products[6] = COEFF_6 * shift_reg[6];
assign products[7] = COEFF_7 * shift_reg[7];

logic signed [31:0] sum_l1 [0:3];
logic signed [31:0] sum_l2 [0:1];
assign sum_l1[0] = products[0] + products[1];
assign sum_l1[1] = products[2] + products[3];
assign sum_l1[2] = products[4] + products[5];
assign sum_l1[3] = products[6] + products[7];
assign sum_l2[0] = sum_l1[0] + sum_l1[1];
assign sum_l2[1] = sum_l1[2] + sum_l1[3];
assign acc = sum_l2[0] + sum_l2[1];

// output reg
/*
| acc[31:30] | Meaning                     |
| ---------- | --------------------------- |
| `00`       | valid positive value (< +1) |
| `11`       | valid negative value (> -1) |
| `01`       | positive overflow           |
| `10`       | negative overflow           |

*/
logic signed [15:0] acc_truncated;

always_comb begin
    if (acc[31] == 1'b0 && acc[30] == 1'b1)
        acc_truncated = 16'sh7FFF; 
    else if (acc[31] == 1'b1 && acc[30] == 1'b0)
        acc_truncated = 16'sh8000;
    else
        acc_truncated = acc[30:15]; // Q2.30  -->  Q1.15
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out  <= '0;
        valid_out <= 1'b0;
    end else begin
        data_out  <= acc_truncated;
        valid_out <= valid_in;       // 1-cycle latency
    end
end

assign ready_out = 1'b1;
endmodule