// `include "ascon_permutation.sv"
module ascon_finalization (
    input  logic        clk,          // Clock signal
    input  logic        rst_n,        // Active-low reset
    input  logic        start,        // Start signal
    input  logic [63:0] state_in [0:4], // Input state (5 x 64-bit)
    input  logic [127:0] key,         // 128-bit key
    output logic [63:0] tag [0:1],    // Tag (2 x 64-bit)
    output logic        done          // Done signal
);

    // Internal signals
    logic [63:0] state [0:4];         // State in of permutation
    logic [63:0] perm_state [0:4];    // State out after permutation
    logic        perm_start;          // Start signal of permutation
    logic        perm_done;           // Done signal of permutation
    logic        running;             // FSM state

    // FSM states
    enum logic [1:0] {
        IDLE  = 2'b00,
        XOR_KEY = 2'b01,
        PERM  = 2'b10,
        DONE  = 2'b11
    } state_reg, next_state;

    // Connect module ascon_permutation (rounds = 12)
    ascon_permutation perm (
        .clk(clk),
        .rst_n(rst_n),
        .start(perm_start),
        .state_in(state),
        .state_out(perm_state),
        .done(perm_done)
    );

    // Sequential logic cho FSM và trạng thái
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            running <= 1'b0;
            done <= 1'b0;
            for (int i = 0; i < 5; i++) state[i] <= 64'h0;
            tag[0] <= 64'h0;
            tag[1] <= 64'h0;
        end else begin
            state_reg <= next_state;

            case (state_reg)
                IDLE: begin
                    if (start) begin
                        for (int i = 0; i < 5; i++) state[i] <= state_in[i];
                        running <= 1'b1;
                        done <= 1'b0;
                    end
                end
                
                // TRUE
                XOR_KEY: begin
                    // XOR key with state[1] and state[2]
                    state[1] <= state[1] ^ key[127:64]; // key[0]
                    state[2] <= state[2] ^ key[63:0];   // key[1]
                end
                PERM: begin
                    perm_start <= 1'b1; // Start permutation
                    if (perm_done) begin
                        for (int i = 0; i < 5; i++) state[i] <= perm_state[i];
                        perm_start <= 1'b0;
                    end
                end
                DONE: begin
                    // Assign Tag[127:0] = state[3] || state[4]
                    tag[0] <= state[3]; // state[3]
                    tag[1] <= state[4]; // state[4]
                    running <= 1'b0;
                    done <= 1'b1;
                end

            endcase
        end
    end

    // Next state logic
    always_comb begin
        case (state_reg)
            IDLE: begin
                if (start) next_state = XOR_KEY;
                else next_state = IDLE;
            end
            XOR_KEY: begin
                next_state = PERM;
            end
            PERM: begin
                if (perm_done) next_state = DONE;
                else next_state = PERM;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule