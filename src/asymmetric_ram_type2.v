module asymmetric_ram_type2 #(
    parameter pLatency  = 1,
    parameter WIDTHA    = 32,
    parameter DEPTHA    = 256,
    parameter WIDTHB    = 16,
    parameter DEPTHB    = 512,
    // Microchip (Synplify Pro) RAM inference types: "lsram", "uram", or "registers"
    parameter RAM_TYPE  = "lsram" 
)
(
    input  wire clkA,
    input  wire clkB,
    input  wire enA,
    input  wire enB,
    input  wire renB,
    input  wire weA,
    input  wire [$clog2(DEPTHA)-1:0] addrA,
    input  wire [$clog2(DEPTHB)-1:0] addrB,
    input  wire [WIDTHA-1:0] diA,
    output reg  [WIDTHB-1:0] doB
);

    function automatic bit checkint_power_of_two (input int unsigned value);
        return (value != 0) && ((value & (value - 1)) == 0);
    endfunction

    localparam lp_ratio = DEPTHB / DEPTHA;
    localparam bit RATIO_OK = checkint_power_of_two(lp_ratio);

    // Pass the parameter to the Synplify Pro synthesis attribute
    (* syn_ramstyle = RAM_TYPE *)
    reg [WIDTHA-1:0] RAM [0:DEPTHA-1];

    generate
        if (DEPTHA*WIDTHA != DEPTHB*WIDTHB) begin : gen_param_check
            $error("Configuration Error: DEPTHA*WIDTHA %d must be equal to DEPTHB*WIDTHB %d", DEPTHA*WIDTHA, DEPTHB*WIDTHB);
        end
        if (DEPTHB < DEPTHA) begin : gen_param_check2
            $error("Configuration Error: DEPTHA %d must be smaller than DEPTHB %d ", DEPTHA, DEPTHB);
        end
        if (!RATIO_OK) begin : ratio_checker
            $error("Configuration Error: DEPTHA/DEPTHB must be a power of 2 DEPTHA=%d DEPTHB=%d \n", DEPTHA, DEPTHB);
        end
        if (pLatency != 1 && pLatency != 2) begin : gen_lat_check
            $error("Configuration Error: pLatency must be 1 or 2");
        end
    endgenerate

    // Port A: Write logic
    always @(posedge clkA) begin
        if (enA & weA) begin
            RAM[addrA] <= diA;
        end
    end

    // Port B: Configurable Read Logic (Latency 1 or 2)
    generate
        //---------------------------------------------------------
        // LATENCY = 1
        //---------------------------------------------------------
        if (pLatency == 1) begin : gen_lat1
            reg [WIDTHA-1:0] mux;
            reg [$clog2(lp_ratio)-1:0] mux_idx;
            
            always @(posedge clkB) begin
                mux     = RAM[ addrB[$clog2(DEPTHB)-1 : $clog2(lp_ratio)] ];
                mux_idx = addrB[$clog2(lp_ratio)-1 : 0];
                
                if (enB & renB) begin
                    doB <= mux[mux_idx*WIDTHB +: WIDTHB];
                end
            end
        end
        
        //---------------------------------------------------------
        // LATENCY = 2
        //---------------------------------------------------------
        else if (pLatency == 2) begin : gen_lat2
            reg [WIDTHA-1:0] mux;
            reg [$clog2(lp_ratio)-1:0] mux_idx;
            reg [WIDTHB-1:0] doB_int;
            reg enB_reg, renB_reg;
            
            // Pipeline the enable signals
            always @(posedge clkB) begin
                enB_reg  <= enB;
                renB_reg <= renB;
            end
            
            // Stage 1: Read from RAM and perform multiplexing into internal register
            always @(posedge clkB) begin
                mux     = RAM[ addrB[$clog2(DEPTHB)-1 : $clog2(lp_ratio)] ];
                mux_idx = addrB[$clog2(lp_ratio)-1 : 0];
                
                if (enB & renB) begin
                    doB_int <= mux[mux_idx*WIDTHB +: WIDTHB];
                end
            end
            
            // Stage 2: Register the internal data out to the module port
            always @(posedge clkB) begin
                if (enB_reg & renB_reg) begin
                    doB <= doB_int;
                end
            end
        end
    endgenerate

endmodule