`timescale 1ns / 1ps
module tb_ascon_core;
    // Signals
    logic        clk;
    logic        rst_n;
    logic        start;
    logic [1:0]  encrypt_decrypt;
    logic [127:0] key;
    logic [127:0] nonce;
    logic [63:0]  associated_data [0:1];

    logic [63:0]  plaintext_in [0:1];

    logic [63:0]  ciphertext_out [0:1];
    logic [63:0]  tag[0:1];

    logic [63:0]  plaintext_out [0:1];

    logic        done;
    logic        error;

    // Instantiate DUT
    ascon_core dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .encrypt_decrypt(encrypt_decrypt),
        .key(key),
        .nonce(nonce),
        .associated_data(associated_data),
        .plaintext_in(plaintext_in),
        .ciphertext_out(ciphertext_out),
        .tag(tag),
        .plaintext_out(plaintext_out),
        .done(done),
        .error(error)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Test
    initial begin

        // Initialize signals
        rst_n = 0;
        start = 0;
        encrypt_decrypt = 2'd2;
        key = 128'h0;
        nonce = 128'h0;

        associated_data[0] = 64'h0;
        associated_data[0] = 64'h0;

        plaintext_in[0] = 64'h0;
        plaintext_in[1] = 64'h0;

        // Reset
        #30;
        rst_n = 1;
        start = 1;
        encrypt_decrypt = 2'd0;
        key = 128'h1234567890ABCDEF1234567890ABCDEF;
        nonce = 128'hFEDCBA9876543210FEDCBA9876543210;

        // "Authenticated!"
        associated_data[0] = 64'h41757468656E74;
        associated_data[1] = 64'h6963617465642121;

        // "ConfidentialData"
        plaintext_in[0] = 64'h436F6E666964656E;
        plaintext_in[1] = 64'h7469616C44617461;
        #10;
        start = 0;
        #800
        start = 1;
        #10;
        start = 0;
        encrypt_decrypt = 1;
    end
endmodule