module tdpram #(
    parameter WIDTH = 8,             // Width of the read/write data
    parameter DEPTH = 256            // Number of memory locations
) (
    input  wire                     clk0,
    input  wire                     clk1,
    input  wire                     we0,
    input  wire                     we1,
    input  wire [$clog2(DEPTH)-1:0] waddr0,
    input  wire [$clog2(DEPTH)-1:0] waddr1,
    input  wire [WIDTH-1:0]         data0,
    input  wire [WIDTH-1:0]         data1,
    output wire [WIDTH-1:0]         q0,
    output wire [WIDTH-1:0]         q1
);

    // Internal registers for registered read addresses
    reg [$clog2(DEPTH)-1:0] reg_addr0;
    reg [$clog2(DEPTH)-1:0] reg_addr1;

    // Memory array declaration
    reg [WIDTH-1:0] mem [0:DEPTH-1] /* synthesis syn_ramstyle="no_rw_check" */; 

    // Continuous assignment for output data
    assign q0 = mem[reg_addr0];
    assign q1 = mem[reg_addr1]; 

    // Port 0: Synchronous read/write operations
    always @(posedge clk0) begin 
        reg_addr0 <= waddr0;
        if (we0) begin
            mem[waddr0] <= data0;
        end
    end 

    // Port 1: Synchronous read/write operations
    always @(posedge clk1) begin
        reg_addr1 <= waddr1;
        if (we1) begin
            mem[waddr1] <= data1;
        end
    end 

endmodule