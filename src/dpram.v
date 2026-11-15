module dpram #(
    parameter pLatency  = 1,                 // Read latency (1 or 2)
    parameter WIDTH     = 32,                // Width of the read/write data
    parameter DEPTH     = 256,               // Number of memory locations
    // Microchip (Synplify Pro) RAM inference types. 
    // Pass "lsram", "uram", or "lsram,no_rw_check" to ignore read-during-write collisions
    parameter RAM_TYPE  = "lsram,no_rw_check" 
) (
    input  wire                     read_clk,
    input  wire                     write_clk,
    input  wire                     rd_en,
    input  wire                     wr_en,
    input  wire [$clog2(DEPTH)-1:0] read_address,
    input  wire [$clog2(DEPTH)-1:0] write_address,
    input  wire [WIDTH-1:0]         data_in,
    output reg  [WIDTH-1:0]         data_out 
);

    // Memory array declaration with Synplify Pro synthesis attribute
    (* syn_ramstyle = RAM_TYPE *)
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // Parameter validation
    generate
        if (pLatency != 1 && pLatency != 2) begin : gen_lat_check
            $error(1, "Configuration Error: pLatency must be 1 or 2");
        end
    endgenerate

    // Write operation block (synchronous to write_clk)
    always @(posedge write_clk) begin
        if (wr_en) begin
            mem[write_address] <= data_in;
        end
    end

    // Read operation block (synchronous to read_clk)
    generate
        //---------------------------------------------------------
        // LATENCY = 1
        //---------------------------------------------------------
        if (pLatency == 1) begin : gen_lat1
            always @(posedge read_clk) begin
                if (rd_en) begin
                    data_out <= mem[read_address];
                end
            end
        end
        
        //---------------------------------------------------------
        // LATENCY = 2
        //---------------------------------------------------------
        else if (pLatency == 2) begin : gen_lat2
            reg [WIDTH-1:0] data_out_int;
            reg             rd_en_reg;
            
            // Pipeline the read-enable signal
            always @(posedge read_clk) begin
                rd_en_reg <= rd_en;
            end
            
            // Stage 1: Read from memory into internal pipeline register
            always @(posedge read_clk) begin
                if (rd_en) begin
                    data_out_int <= mem[read_address];
                end
            end
            
            // Stage 2: Register the internal data out to the module port
            always @(posedge read_clk) begin
                if (rd_en_reg) begin
                    data_out <= data_out_int;
                end
            end
        end
    endgenerate

endmodule