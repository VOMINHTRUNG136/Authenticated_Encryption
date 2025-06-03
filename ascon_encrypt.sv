// `include "ascon_permutation.sv"
module ascon_encrypt (
    input  logic        clk,          // Clock signal
    input  logic        rst_n,        // Active-low reset
    input  logic        start,        // Start signal
    input  logic [63:0] state_in [0:4], // Input state (5 x 64-bit) sau Initialization
    input  logic [63:0] associated_data[0:1],// Associated data input (2 x 64 bits)
    input  logic [63:0] plaintext [0:1], // Plaintext (2 blocks x 64-bit)
    output logic [63:0] ciphertext [0:1], // Ciphertext (2 blocks x 64-bit)
    output logic [63:0] state_out [0:4], // State after encrypt
    output logic        done          // Done signal
);

    // Internal signals
    logic [63:0] state [0:4];         // State in of permutation
    logic [63:0] perm_state [0:4];    // State out after permutation
    logic        perm_start;          // Start signal of permutation
    logic        perm_done;           // Done signal of permutation
    logic        running;             // FSM state

    // FSM states
    enum logic [3:0] {
        IDLE   = 4'b0000,
        BLOCK0_ASSOCIATED_DATA = 4'b0001,
        BLOCK1_ASSOCIATED_DATA = 4'b0010,
        BLOCK1_ASSOCIATED_DATA_PERM = 4'b0011,
        BLOCK0_PLAINTEXT = 4'b0100,
        BLOCK1_PLAINTEXT = 4'b0101,
        BLOCK1_PLAINTEXT_PERM = 4'b0110,
        DONE   = 4'b01111
    } state_reg, next_state;

    // Processing permutation (rounds = 6)
    ascon_permutation #(.ROUNDS(6)) perm (
        .clk(clk),
        .rst_n(rst_n),
        .start(perm_start),
        .state_in(state),
        .state_out(perm_state),
        .done(perm_done)
    );

    // Sequential logic for FSM and state
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            running <= 1'b0;
            done <= 1'b0;
            for (int i = 0; i < 5; i++) state[i] <= 64'h0;
            for (int i = 0; i < 5; i++) state_out[i] <= 64'h0;
            ciphertext[0] <= 64'h0;
            ciphertext[1] <= 64'h0;
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
                // Start processing associated data
                BLOCK0_ASSOCIATED_DATA: begin
                    // Process block 0
                    state[0] <= associated_data[0] ^ state[0]; // state[0] = state[0] ^ associated_data[0]
                end

                BLOCK1_ASSOCIATED_DATA: begin
                    // Block 1
                    perm_start <= 1'b1;
                end

                BLOCK1_ASSOCIATED_DATA_PERM: begin
                    perm_start <= 1'b0;
                    if (perm_done) begin
                        for (int i = 0; i < 5; i++) state[i] <= perm_state[i];
                        // Process block 1
                        state[0] <= state[0] ^ 64'h00000000;
                        state[1] <= state[1] ^ 64'h00000000;
                        state[2] <= state[2] ^ 64'h00000000;
                        state[3] <= state[3] ^ 64'h00000000;
                        state[4] <= state[4] ^ 64'h00000001;
                    end
                end
                // Finish processing associated data


                // Start processing plaintext
                BLOCK0_PLAINTEXT: begin
                    // Process block 0
                    ciphertext[0] <= plaintext[0] ^ state[0];// Output ciphertext[0]
                    state[0] <= plaintext[0] ^ state[0]; // state[0] = ciphertext[0]
                end

                BLOCK1_PLAINTEXT: begin
                    // Block 1
                    perm_start <= 1'b1;
                end

                BLOCK1_PLAINTEXT_PERM: begin
                    perm_start <= 1'b0;
                    if (perm_done) begin
                        for (int i = 0; i < 5; i++) state[i] <= perm_state[i];
                        // Process block 1
                        ciphertext[1] <= plaintext[1] ^ perm_state[0]; // Output ciphertext[1]
                        state[0] <= plaintext[1] ^ perm_state[0];     // state[0] = ciphertext[1]
                    end
                end
                // Finish processing phaintext

                DONE: begin
                    for (int i = 0; i < 5; i++) state_out[i] <= state[i]; // // state_out
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
                if (start) next_state = BLOCK0_ASSOCIATED_DATA;
                else next_state = IDLE;
            end
            BLOCK0_ASSOCIATED_DATA: begin
                next_state = BLOCK1_ASSOCIATED_DATA;
            end
            BLOCK1_ASSOCIATED_DATA: begin
                next_state = BLOCK1_ASSOCIATED_DATA_PERM;
            end
            BLOCK1_ASSOCIATED_DATA_PERM: begin
                if (perm_done) next_state = BLOCK0_PLAINTEXT;
                else next_state = BLOCK1_ASSOCIATED_DATA_PERM;
            end
            BLOCK0_PLAINTEXT: begin
                next_state = BLOCK1_PLAINTEXT;
            end
            BLOCK1_PLAINTEXT: begin
                next_state = BLOCK1_PLAINTEXT_PERM;
            end
            BLOCK1_PLAINTEXT_PERM: begin
                if (perm_done) next_state = DONE;
                else next_state = BLOCK1_PLAINTEXT_PERM;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule