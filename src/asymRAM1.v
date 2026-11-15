module asymmetric_ram #(
    parameter pLatency  = 1,
    parameter WIDTHA    = 2,
    parameter DEPTHA    = 16384,
    parameter WIDTHB    = 4,
    parameter DEPTHB    = 8192,
    // Microchip (Synplify Pro) RAM inference types: "lsram", "uram", or "registers"
    parameter RAM_TYPE  = "lsram" 
)
(
    input  wire clkA, 
    input  wire clkB, 
    input  wire weA, 
    input  wire enA, 
    input  wire [$clog2(DEPTHA)-1:0] addrA,
    input  wire [$clog2(DEPTHB)-1:0] addrB,
    input  wire renB,
    input  wire [WIDTHA-1:0] diA,
    output reg  [WIDTHB-1:0] doB
);

`define max(a,b) {(a) > (b) ? (a) : (b)}
`define min(a,b) {(a) < (b) ? (a) : (b)}

localparam maxSIZE   = `max(DEPTHA, DEPTHB);
localparam maxWIDTH  = `max(WIDTHA, WIDTHB);
localparam minWIDTH  = `min(WIDTHA, WIDTHB);
localparam RATIO     = maxWIDTH / minWIDTH;
localparam log2RATIO = $clog2(RATIO);

// Pass the parameter to the Synplify Pro synthesis attribute
(* syn_ramstyle = RAM_TYPE *)
reg [minWIDTH-1:0] RAM [0:maxSIZE-1];

// Configuration Checks
generate
    if (DEPTHA*WIDTHA != DEPTHB*WIDTHB) begin : gen_param_check
        $error(1, "Configuration Error: DEPTHA*WIDTHA must be equal to DEPTHB*WIDTHB");
    end
    
    if (pLatency != 1 && pLatency != 2) begin : gen_lat_check
        $error(1, "Configuration Error: pLatency must be 1 or 2");
    end
endgenerate

// Port A: Write logic
always @(posedge clkA) begin
    if (enA & weA)
        RAM[addrA] <= diA;
end

// Port B: Configurable Read Logic (Latency 1 or 2)
genvar i;
generate
    //---------------------------------------------------------
    // LATENCY = 1
    //---------------------------------------------------------
    if (pLatency == 1) begin : gen_lat1
        for (i = 0; i < RATIO; i = i+1) begin : ramread
            localparam [log2RATIO-1:0] lsbaddr = i;
            always @(posedge clkB) begin
                if (renB) begin
                    doB[(i+1)*minWIDTH-1:i*minWIDTH] <= RAM[{addrB, lsbaddr}];
                end
            end
        end
    end
    
    //---------------------------------------------------------
    // LATENCY = 2
    //---------------------------------------------------------
    else if (pLatency == 2) begin : gen_lat2
        reg [WIDTHB-1:0] doB_int;
        reg renB_reg;
        
        // Pipeline the read-enable signal
        always @(posedge clkB) begin
            renB_reg <= renB;
        end
        
        // Stage 1: Read from RAM into internal pipeline register
        for (i = 0; i < RATIO; i = i+1) begin : ramread
            localparam [log2RATIO-1:0] lsbaddr = i;
            always @(posedge clkB) begin
                if (renB) begin
                    doB_int[(i+1)*minWIDTH-1:i*minWIDTH] <= RAM[{addrB, lsbaddr}];
                end
            end
        end
        
        // Stage 2: Register the internal data out to the module port
        always @(posedge clkB) begin
            if (renB_reg) begin
                doB <= doB_int;
            end
        end
    end
endgenerate

endmodule