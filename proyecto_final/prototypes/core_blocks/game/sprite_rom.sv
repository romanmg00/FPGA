// sprite_rom: one RGB444 sprite memory, initialised from the .mem twin of a
// .coe made by tools/png2coe.py (row by row, top-left first). Owner: Roman
// (sprite_rom, contract section 4). Domain: clk = clk_pix. No crossing.
//
// Read latency is 2 clk_pix cycles (address register, then output register),
// the value in the sprite tips' Block Memory Generator example; callers
// issue the address 2 cycles before the pixel is shown. PROVISIONAL: the
// tips build this with Block Memory Generator from the .coe; here Vivado
// infers the same block ROM from the same words. Swapping in the IP needs
// its generated latency to stay 2.
module sprite_rom #(
    parameter integer AW = 10,                 // 1024 words for 32 x 32, 256 for 16 x 16
    parameter string INIT_FILE = "bike-synth-32.mem"
) (
    input  logic          clk,
    input  logic [AW-1:0] addr,
    output logic [11:0]   data = '0
);
    (* rom_style = "block" *) logic [11:0] mem [0:(1 << AW) - 1];
    initial $readmemh(INIT_FILE, mem);
    logic [11:0] word = '0;
    always_ff @(posedge clk) begin
        word <= mem[addr];
        data <= word;
    end
endmodule
