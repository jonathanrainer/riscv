module data_memory
  #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_WORDS  = 256
  )(
    // Clock and Reset
    input  logic                    clk,
    
    input  logic                    req_i,
    input  logic [ADDR_WIDTH-1:0]   addr_i,
    input  logic                    we_i,
    input  logic [DATA_WIDTH/8-1:0] be_i,
    input  logic [DATA_WIDTH-1:0]   wdata_i,
    
    output logic                    gnt_o,
    output logic                    rvalid_o,
    output logic [DATA_WIDTH-1:0]   rdata_o,
    output logic                    err_o
  );

  localparam words = NUM_WORDS/(DATA_WIDTH/8);

  logic [DATA_WIDTH/8-1:0][7:0] mem[words];
  logic [DATA_WIDTH/8-1:0][7:0] wdata;
  logic [ADDR_WIDTH-1-$clog2(DATA_WIDTH/8):0] addr;
  
  logic we;
  logic [3:0] be;

  
    enum logic [2:0] {
    SLEEP = 3'b000,
    WAITG = 3'b001,
    GRANT = 3'b010,
    WRITE = 3'b011,
    READ = 3'b100
    } State, Next;
    
    int delay_counter = 0;
    int grant_limit = 1;
    int read_limit = 5;
    int write_limit = 1;

  initial
    begin
        mem = '{default:32'h0};
        mem[0] = 32'hB000B1E5;
        mem[1] = 32'hB001B1E5;
        mem[32] = 32'h33333333;
        gnt_o = 1'b0;
        rvalid_o = 1'b0;
        rdata_o = 32'bx;
        err_o = 1'b0;
        State = SLEEP;
        Next = SLEEP;
    end


  always @(posedge clk)
  begin
    State = Next;
    unique case(State)
        SLEEP: 
        begin
            rvalid_o = 0;
            if (req_i) Next = WAITG;
        end      
        WAITG:
        begin
            if (delay_counter < grant_limit) delay_counter++;
            else 
            begin
                addr = addr_i[ADDR_WIDTH-1:$clog2(DATA_WIDTH/8)];
                we = we_i;
                be = be_i;
                for(integer w = 0; w < DATA_WIDTH/8; w++)
                begin
                    wdata[w] = wdata_i[w*8 +: 8];
                end
                delay_counter = 0;
                gnt_o = 1;
                Next = GRANT;
            end
         end
         GRANT: 
         begin
            gnt_o = 0;
            if (we) Next = WRITE;
            else Next = READ;
         end
         READ:
         begin
            rdata_o = mem[addr];
            if (delay_counter < read_limit) delay_counter++;
            else 
            begin
                delay_counter = 0;    
                rvalid_o = 1;
                Next = SLEEP;
            end
         end
         WRITE:
         begin
            if (delay_counter < write_limit) delay_counter++;
            else
            begin
                for (integer i = 0; i < DATA_WIDTH/8; i++)
                begin
                    if (be[i]) mem[addr][i] = wdata[i];
                end
                delay_counter = 0;
                rvalid_o = 1;
                rdata_o = 32'h11111111;
                Next = SLEEP;
            end
         end   
      endcase 
  end
  
endmodule
