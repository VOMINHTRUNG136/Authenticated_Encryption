`timescale 1ns / 1ps
module ascon_wrapper_tb;

    // Signals
    logic        clk;
    logic        rst_n;
    logic        chipselect;
    logic        write;
    logic        read;
    logic [4:0]  address;
    logic [31:0] writedata;
    logic [31:0] readdata;
    logic [31:0] writeDataArray [0:16];
    integer i;
    logic        start;
    logic [1:0]  encrypt_decrypt;
    logic [127:0] key;
    logic [127:0] nonce;
    logic [63:0]  associated_data[0:1];
    logic [63:0]  plaintext_in [0:1];


    // Instantiate DUT
    ascon_wrapper uut (
        .clk(clk),
        .rst_n(rst_n),
        .chipselect(chipselect),
        .write(write),
        .read(read),
        .address(address),
        .writedata(writedata),
        .readdata(readdata)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
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
    end
    initial begin
        #5
        writeDataArray[0] = {29'h0, encrypt_decrypt, start};

        writeDataArray[1] = key[127:96];
        writeDataArray[2] = key[95:64];
        writeDataArray[3] = key[63:32];
        writeDataArray[4] = key[31:0];
        
        writeDataArray[5] = nonce[127:96];
        writeDataArray[6] = nonce[95:64];
        writeDataArray[7] = nonce[63:32];
        writeDataArray[8] = nonce[31:0];

        writeDataArray[9]  = associated_data[0][63:32];
        writeDataArray[10]  = associated_data[0][31:0];
        writeDataArray[11] = associated_data[1][63:32];
        writeDataArray[12] = associated_data[1][31:0];

        writeDataArray[13] = plaintext_in[0][63:32];
        writeDataArray[14] = plaintext_in[0][31:0];
        writeDataArray[15] = plaintext_in[1][63:32];
        writeDataArray[16] = plaintext_in[1][31:0];


    end


    // Test sequence
    initial begin
        i = 0;
        rst_n = 0;
        chipselect = 0;
        write = 0;
        read = 0;
        address = 5'h0;
        write = 32'd0;
        writedata = 32'd0;
        #10
        rst_n = 1;
        #20;
        chipselect = 1;
        write = 1;
    end
    initial begin
    #30
    for (i = 1; i <= 17; i = i + 1)
    begin
        #10
        address = i%17;
        writedata = writeDataArray[i%17];
    end
    #5
    start = 0;
    #5
    writeDataArray[0] = {29'h0, encrypt_decrypt, start};
    writedata = writeDataArray[0];
    end
    initial begin
    #850
    start = 1;
    encrypt_decrypt = 2'd1;
    #5
    writeDataArray[0] = {29'h0, encrypt_decrypt, start};
    writedata = writeDataArray[0];
    start = 0;
    #5
    writeDataArray[0] = {29'h0, encrypt_decrypt, start};
    writedata = writeDataArray[0];
    end
endmodule