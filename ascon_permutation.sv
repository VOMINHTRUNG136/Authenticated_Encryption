module ascon_permutation #(
    parameter ROUNDS = 12  // Default number of rounds
) (
    input  logic        clk,          // Clock signal
    input  logic        rst_n,        // Active-low reset
    input  logic        start,        // Start signal
    input  logic [63:0] state_in [0:4], // Input state (5 x 64-bit)
    output logic [63:0] state_out [0:4], // Output state (5 x 64-bit)
    output logic        done          // Done signal
);

    // Constants for 12 rounds
    logic [63:0] constants [0:11] = '{
        64'hf0, 64'he1, 64'hd2, 64'hc3,
        64'hb4, 64'ha5, 64'h96, 64'h87,
        64'h78, 64'h69, 64'h5a, 64'h4b
    };

    // Internal state registers
    logic [63:0] state [0:4];
    logic [3:0]  round;              // Round counter (0 to ROUNDS-1)
    logic        running;            // FSM running state
	logic [63:0] temp_state [0:4];
    // Rotate function as combinational logic
    function logic [63:0] rotate(input logic [63:0] x, input int l);
        return (x >> l) ^ (x << (64 - l));
    endfunction

    // S-box lookup table (5-bit input, 5-bit output)
    logic [4:0] sbox_table [0:31] = '{
        5'h04, 5'h0b, 5'h1f, 5'h14, 5'h1a, 5'h15, 5'h09, 5'h02,
        5'h1b, 5'h05, 5'h08, 5'h12, 5'h1d, 5'h03, 5'h06, 5'h1c,
        5'h1e, 5'h13, 5'h07, 5'h0e, 5'h00, 5'h0d, 5'h11, 5'h18,
        5'h10, 5'h0c, 5'h01, 5'h19, 5'h16, 5'h0a, 5'h0f, 5'h17
    };

    // FSM states
    enum logic [1:0] {
        IDLE  = 2'b00,
        RUN   = 2'b01,
        DONE  = 2'b10
    } state_reg, next_state;

    // Sequential logic for state, round counter, and permutation
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            round <= 4'd0;
            running <= 1'b0;
            for (int i = 0; i < 5; i++) state[i] <= 64'h0;
        end else begin
            state_reg <= next_state;

            // Start the permutation
            if (state_reg == IDLE && start) begin
                for (int i = 0; i < 5; i++) state[i] <= state_in[i];
                round <= 4'd0;
                running <= 1'b1;
            end

            // Update round counter and running flag
            if (state_reg == RUN) begin
                // Compute next state (from combinational logic below)
                for (int i = 0; i < 5; i++) state[i] <= temp_state[i];
                if (round < ROUNDS - 1) begin
                    round <= round + 1;
                end else begin
                    running <= 1'b0;
                end
            end

            // Reset running when entering IDLE
            if (state_reg == DONE) begin
                running <= 1'b0;
            end
        end
    end

    // Next state logic
    always_comb begin
        case (state_reg)
            IDLE: begin
                if (start) next_state = RUN;
                else next_state = IDLE;
            end
            RUN: begin
                if (round == ROUNDS - 1) next_state = DONE;
                else next_state = RUN;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Permutation logic (add_constant, sbox, linear)

    logic [63:0] sbox_temp [0:4]; // Intermediate state after S-box
    logic [4:0]  sbox_in, sbox_out;

    always_comb begin
        // Step 1: Add constant
        for (int i = 0; i < 5; i++) temp_state[i] = state[i];
        temp_state[2] = state[2] ^ constants[(12 - ROUNDS) + round];

        // Step 2: S-box layer
        for (int i = 0; i < 5; i++) sbox_temp[i] = 64'h0; // Reset sbox_temp
        for (int i = 0; i < 64; i++) begin
            sbox_in = {temp_state[4][i], temp_state[3][i], temp_state[2][i], temp_state[1][i], temp_state[0][i]};
            sbox_out = sbox_table[sbox_in];
            sbox_temp[0][i] = sbox_out[0];
            sbox_temp[1][i] = sbox_out[1];
            sbox_temp[2][i] = sbox_out[2];
            sbox_temp[3][i] = sbox_out[3];
            sbox_temp[4][i] = sbox_out[4];
        end

        // Step 3: Linear diffusion layer
        temp_state[0] = sbox_temp[0] ^ rotate(sbox_temp[0], 19) ^ rotate(sbox_temp[0], 28);
        temp_state[1] = sbox_temp[1] ^ rotate(sbox_temp[1], 61) ^ rotate(sbox_temp[1], 39);
        temp_state[2] = sbox_temp[2] ^ rotate(sbox_temp[2], 1)  ^ rotate(sbox_temp[2], 6);
        temp_state[3] = sbox_temp[3] ^ rotate(sbox_temp[3], 10) ^ rotate(sbox_temp[3], 17);
        temp_state[4] = sbox_temp[4] ^ rotate(sbox_temp[4], 7)  ^ rotate(sbox_temp[4], 41);
    end

    // Output logic
    assign state_out = state;
    assign done = (state_reg == DONE);

endmodule