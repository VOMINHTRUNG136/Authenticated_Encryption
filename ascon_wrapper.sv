module ascon_wrapper (
    input  logic        clk,
    input  logic        rst_n,
    // Avalon-MM Slave Interface (32-bit)
    input  logic        chipselect,
    input  logic        write,
    input  logic        read,
    input  logic [4:0]  address,
    input  logic [31:0] writedata,
    output logic [31:0] readdata
);

    // Internal signals
    logic        start;
    logic [1:0]  encrypt_decrypt;
    logic [127:0] key;
    logic [127:0] nonce;
    logic [63:0] associated_data[0:1];

    logic [63:0]  plaintext_in [0:1];

    logic [63:0]  ciphertext_out [0:1];
    logic [63:0]  tag [0:1];

    logic [63:0]  plaintext_out [0:1];

    logic        done;
    logic        error;

    // Instantiate ascon_csr
    ascon_csr csr (
        .clk(clk),
        .rst_n(rst_n),
        .chipselect(chipselect),
        .write(write),
        .read(read),
        .address(address),
        .writedata(writedata),
        .readdata(readdata),
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

    ascon_core core (
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

endmodule