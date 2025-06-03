/****************************************************
- Input of Encryption: K, N, A, P
- Output of Encrytion: C, T(Authentication tag)

- Input of Decryption: K, N, A, C, T
- Output of Decrytion: P, E(Error Tag)

=> Output of ascon128: C, T(For encryption) and P, E(For decryption)
******************************************************/
`include "ascon_permutation.sv"
`include "ascon_initialization.sv"
`include "ascon_encrypt.sv"
`include "ascon_decrypt.sv"
`include "ascon_finalization.sv"
module ascon_core (
    // Input for encryption and decryption
    input  logic        clk,                        // Clock signal
    input  logic        rst_n,                      // Active-low reset
    input  logic        start,                      // Start signal
    input  logic [1:0]  encrypt_decrypt,            // 0: Encrypt, 1: Decrypt
    input  logic [127:0] key,                       // 128-bit key
    input  logic [127:0] nonce,                     // 128-bit nonce
    input  logic [63:0]  associated_data[0:1],      // Associated data input (2 x 64 bits)

    // Input for encryption
    input  logic [63:0]  plaintext_in [0:1],        // Plaintext input (2 x 64 bits)

    // Output of encryption
    output logic [63:0]  ciphertext_out [0:1],      // Ciphertext output (2 x 64 bits) for encryption
    output logic [63:0]  tag [0:1],             // Tag output (2 x 64 bits)

    /* Input for decryption is output of encryption */
    // Output of decryption
    output logic [63:0]  plaintext_out [0:1],       // Plaintext output (2 x 64 bits) for decryption

    // Controlled signals
    output logic        done,                       // Done signal
    output logic        error                       // Error signal = 1 when plaintext_out != plaintext_in
);

    // Internal signals
    logic [63:0] init_state [0:4];    // State after initialization
    logic [63:0] enc_state [0:4];     // State after encryption
    logic [63:0] dec_state [0:4];     // State after decryption

    logic        init_done;           // Done signal from initialization
    logic        enc_done;            // Done signal from encryption
    logic        dec_done;            // Done signal from decryption
    logic        fin_done;            // Done signal from finalization

    logic        init_start;          // Start signal for initialization
    logic        enc_start;           // Start signal for encryption
    logic        dec_start;           // Start signal for decryption
    logic        fin_start;           // Start signal for finalization

    logic [63:0] fin_tag [0:1];       // Tag from finalization
    logic [63:0] fin_ciphertext [0:1]; // Input of decryption
    logic [63:0] fin_plaintext [0:1]; // Output of decryption


    // FSM states
    enum logic [2:0] {
        IDLE       = 3'b000,
        INIT       = 3'b001,
        ENCRYPT    = 3'b010,
        DECRYPT    = 3'b011,
        FINALIZE   = 3'b100,
        DONE_STATE = 3'b101
    } state_reg, next_state;

    // Module instantiations
    ascon_initialization init (
        .clk(clk),
        .rst_n(rst_n),
        .start(init_start),
        .key(key),
        .nonce(nonce),
        .state_out(init_state),
        .done(init_done)
    );

    ascon_encrypt enc (
        .clk(clk),
        .rst_n(rst_n),
        .start(enc_start),
        .state_in(init_state),
        .associated_data(associated_data),
        .plaintext(plaintext_in),
        .ciphertext(fin_ciphertext),
        .state_out(enc_state),
        .done(enc_done)
    );

    ascon_decrypt dec (
        .clk(clk),
        .rst_n(rst_n),
        .start(dec_start),
        .state_in(init_state),
        .associated_data(associated_data),
        .ciphertext(fin_ciphertext),
        .plaintext(fin_plaintext),
        .state_out(dec_state),
        .done(dec_done)
    );

    ascon_finalization fin (
        .clk(clk),
        .rst_n(rst_n),
        .start(fin_start),
        .state_in(encrypt_decrypt ? dec_state : enc_state),
        .key(key),
        .tag(fin_tag),
        .done(fin_done)
    );

    // Sequential logic for FSM
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            ciphertext_out[0] <= 64'h0;
            ciphertext_out[1] <= 64'h0;

            tag[0] <= 64'h0;
            tag[1] <= 64'h0;

            plaintext_out[0] <= 64'h0;
            plaintext_out[1] <= 64'h0;
            
            done <= 0;
            error <= 0;
            state_reg <= IDLE;
            init_start <= 0;
            enc_start <= 0;
            dec_start <= 0;
            fin_start <= 0;
            done <= 0;
            error <= 0;
        end else begin
            state_reg <= next_state;
            case (state_reg)
                IDLE: begin
                    if (start) begin
                        init_start <= 1;
                        done <= 0;
                        error <= 0;
                    end
                end
                INIT: begin
                    init_start <= 0;
                    // init_done <= 0;
                    if (init_done) begin
                        if (encrypt_decrypt == 1) dec_start <= 1;
                        if(encrypt_decrypt == 0) enc_start <= 1;
                    end
                end
                ENCRYPT: begin
                    enc_start <= 0;
                    if (enc_done) fin_start <= 1;
                end
                DECRYPT: begin
                    dec_start <= 0;
                    if (dec_done) fin_start <= 1;
                end
                FINALIZE: begin
                    fin_start <= 0;
                    if (fin_done) begin
                        done <= 1;
                        if (encrypt_decrypt == 1) begin
                            plaintext_out <= fin_plaintext;
                            error <= (fin_tag[0] != tag[0]) || (fin_tag[1] != tag[1]);
                        end else begin
                            tag <= fin_tag;
                            ciphertext_out <= fin_ciphertext;
                            error <= 0;
                        end
                    end
                end
                DONE_STATE: begin
                    done <= 0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        case (state_reg)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = init_done ? ((encrypt_decrypt == 1) ? DECRYPT : (encrypt_decrypt == 0) ? ENCRYPT : IDLE) : INIT;
            ENCRYPT: next_state = enc_done ? FINALIZE : ENCRYPT;
            DECRYPT: next_state = dec_done ? FINALIZE : DECRYPT;
            FINALIZE: next_state = fin_done ? DONE_STATE : FINALIZE;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule