module ascon_csr (
    input  logic        clk,          // Clock signal
    input  logic        rst_n,        // Active-low reset
    // Avalon-MM Slave Interface (32-bit)
    input  logic        chipselect,
    input  logic        write,
    input  logic        read,
    input  logic [4:0]  address,  // 4-bit address for 16 registers
    input  logic [31:0] writedata,
    output logic [31:0] readdata,
    // Interface to ascon_core
    output logic         start,
    output logic [1:0]   encrypt_decrypt,
    output logic [127:0] key,
    output logic [127:0] nonce,
    output  logic [63:0] associated_data[0:1],

    output logic [63:0]  plaintext_in [0:1],

    input  logic [63:0]  ciphertext_out [0:1],
    input  logic [63:0]  tag [0:1],

    input  logic [63:0]  plaintext_out [0:1],

    input  logic        done,
    input  logic        error
);

    // Control and Data Registers
    logic [31:0] control_reg;       // Control register: start, encrypt_decrypt
    logic [31:0] key_reg [0:3];     // 128-bit key split into 4x32-bit
    logic [31:0] nonce_reg [0:3];   // 128-bit nonce split into 4x32-bit
    logic [31:0] associated_data_reg [0:3]; // 128-bit associated data split into 4x32-bit
    logic [31:0] plaintext_reg [0:3]; // 128-bit plaintext split into 4x32-bit
    logic [31:0] ciphertext_reg [0:3]; // 128-bit ciphertext split into 4x32-bit
    logic [31:0] tag_reg [0:3];  // 128-bit tag input split into 4x32-bit
    logic [31:0] status_reg;        // Status register: done, error


    // Assign outputs to ascon_core
    assign start = control_reg[0];
    assign encrypt_decrypt = control_reg[2:1];
    assign key = {key_reg[0], key_reg[1], key_reg[2], key_reg[3]};
    assign nonce = {nonce_reg[0], nonce_reg[1], nonce_reg[2], nonce_reg[3]};
    assign associated_data[0] = {associated_data_reg[0], associated_data_reg[1]};
    assign associated_data[1] = {associated_data_reg[2], associated_data_reg[3]};
    assign plaintext_in[0] = {plaintext_reg[0], plaintext_reg[1]};
    assign plaintext_in[1] = {plaintext_reg[2], plaintext_reg[3]};
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_reg <= 32'd0;
            for (int i = 0; i < 4; i++) begin
                key_reg[i] <= 32'd0;
                nonce_reg[i] <= 32'd0;
                associated_data_reg[i] <= 32'd0;
                plaintext_reg[i] <= 32'd0;
                ciphertext_reg[i] <= 32'd0;
            end
        end else if (chipselect & write) begin
            case (address)
                5'h0: control_reg <= writedata;
                5'h1: key_reg[0] <= writedata;
                5'h2: key_reg[1] <= writedata;
                5'h3: key_reg[2] <= writedata;
                5'h4: key_reg[3] <= writedata;
                5'h5: nonce_reg[0] <= writedata;
                5'h6: nonce_reg[1] <= writedata;
                5'h7: nonce_reg[2] <= writedata;
                5'h8: nonce_reg[3] <= writedata;
                5'h9: associated_data_reg[0] <= writedata;
                5'hA: associated_data_reg[1] <= writedata;
                5'hB: associated_data_reg[2] <= writedata;
                5'hC: associated_data_reg[3] <= writedata;
                5'hD: plaintext_reg[0] <= writedata;
                5'hE: plaintext_reg[1] <= writedata;
                5'hF: plaintext_reg[2] <= writedata;
                5'h10: plaintext_reg[3] <= writedata;
            endcase
        end
    end

    // Read logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            readdata <= 32'd0;
            status_reg <= 32'd0;
        end else if (chipselect & read) begin
            status_reg <= {30'd0, error, done};
            case (address)
                5'h0: readdata <= control_reg;
                5'h1: readdata <= ciphertext_out[0][63:32];
                5'h2: readdata <= ciphertext_out[0][31:0];
                5'h3: readdata <= ciphertext_out[1][63:32];
                5'h4: readdata <= ciphertext_out[1][31:0];
                5'h5: readdata <= tag[0][63:32];
                5'h6: readdata <= tag[0][31:0];
                5'h7: readdata <= tag[1][63:32];
                5'h8: readdata <= tag[1][31:0];
                5'h9: readdata <= plaintext_out[0][63:32];
                5'hA: readdata <= plaintext_out[0][31:0];
                5'hB: readdata <= plaintext_out[1][63:32];
                5'hC: readdata <= plaintext_out[1][31:0];
                5'hD: readdata <= status_reg;
                default: readdata <= 32'd0;
            endcase
        end
    end


endmodule