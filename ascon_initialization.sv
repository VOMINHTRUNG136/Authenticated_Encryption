// `include "ascon_permutation.sv"

module ascon_initialization (
    input  logic        clk,          // Clock signal
    input  logic        rst_n,        // Active-low reset
    input  logic        start,        // Start signal
    input  logic [127:0] key,         // 128-bit key
    input  logic [127:0] nonce,       // 128-bit nonce
    output logic [63:0]  state_out [0:4], // Output state (5 x 64-bit)
    output logic        done          // Done signal
);

    // Initialization Vector (IV) cho Ascon-128
    localparam logic [63:0] IV = 64'h80400c0600000000; // k=128, r=64, a=12, b=6

    // Internal signals
    logic [63:0] state [0:4];         // Internal state (5 x 64-bit)
    logic [63:0] perm_state [0:4];    // State after permutation
    logic        perm_start;          // Starting permutation
    logic        perm_done;           // Done permutation
    logic        running;             // FSM state

    // FSM states
    enum logic [1:0] {
        IDLE  = 2'b00,
        INIT  = 2'b01,
        PERM  = 2'b10,
        DONE  = 2'b11
    } state_reg, next_state;

    // Connect module ascon_permutation to get state in, state out
    ascon_permutation perm (
        .clk(clk),
        .rst_n(rst_n),
        .start(perm_start),
        .state_in(state),
        .state_out(perm_state),
        .done(perm_done)
    );

    // Sequential logic for FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            running <= 1'b0;
            for (int i = 0; i < 5; i++) state[i] <= 64'h0;
            done <= 1'b0;
        end else begin
            state_reg <= next_state;
            case (state_reg)
                IDLE: begin
                    if (start) begin
                        // Initial state: S = IV || K || N
                        state[0] <= IV;
                        state[1] <= key[127:64];
                        state[2] <= key[63:0];
                        state[3] <= nonce[127:64];
                        state[4] <= nonce[63:0];
                        running <= 1'b1;
                        done <= 1'b0;
                    end
                end
                INIT: begin
                    // Start permutation
                    perm_start <= 1'b1;
                end
                PERM: begin
                    perm_start <= 1'b0;
                    if (perm_done) begin
                        // Update values after permutation
                        for (int i = 0; i < 5; i++) begin
                            state[i] <= perm_state[i];
                        end
                    end
                end

                DONE: begin
                    // XOR with key (only XOR with state[3] and state[4] because key 128-bit)
                    state[3] <= state[3] ^ key[127:64];
                    state[4] <= state[4] ^ key[63:0];
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
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
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

    // Assign output
    assign state_out = state;

endmodule