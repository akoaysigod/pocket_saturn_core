// Pocket CD disc source (glue/cd): the sector ring. SLOTS raw sectors (2352 bytes each, slot s at bridge byte
// offset s * 2352) that APF's "data slot read" target commands write through the bridge (clk_74a), read back on
// clk_sys as the 16-bit words of CDB_HLE's SEC_DATA format (word k of a sector = {byte 2k + 1, byte 2k}).
//
// Write side: a bridge write to BASE << 28 + byte offset (offset < 32 KB) stores the 32-bit word as it comes: the
// bridge's address / data / write registers (io_bridge_peripheral) feed the block RAM's input registers, no logic but
// the window decode. BRIDGE_LE: core_top's bridge_endian_little (1 as in the sotn PSX core: file byte 4k in
// bridge_wr_data[7:0]).
// Read side: 16-bit word raddr (raddr[0] picks the half of the 32-bit RAM word), one clock after the address.
//
// Block RAM: SLOTS * 588 32-bit words. Six slots use explicit 2048-word and 1480-word banks,
// each capped at depth 2048 (or a stricter MAXD). Other slot counts retain the original array.
// The six-slot mapping is a resource hypothesis; target synthesis/fit must establish actual RAM use and timing.
module cd_ring #(
	parameter       SLOTS     = 6,
	parameter       BRIDGE_LE = 1,
	parameter [3:0] BASE      = 4'h4,
	parameter       MAXD      = SLOTS <= 3 ? 2048 : 4096
) (
	input              clk_74a,
	input      [31: 0] bridge_addr,
	input              bridge_wr,
	input      [31: 0] bridge_wr_data,

	input              clk,
	input      [13: 0] raddr,
	output     [15: 0] q
);
	localparam WORDS = SLOTS * 588;
	localparam AW    = $clog2(WORDS);


	wire        we = bridge_wr && bridge_addr[31:28] == BASE && bridge_addr[27:15] == 13'd0;
	wire [31:0] wd = BRIDGE_LE ? bridge_wr_data
	                           : {bridge_wr_data[7:0], bridge_wr_data[15:8], bridge_wr_data[23:16], bridge_wr_data[31:24]};
	generate if (SLOTS == 6) begin : banked_six
		localparam BANK_MAXD = MAXD < 2048 ? MAXD : 2048;
		// Preserve the original truncated indices, including upper-window aliases.
		// Two independent registered RAM reads; select is registered alongside data.
		// Resource savings and mux timing require a target-device fit.
		(* ramstyle = "M10K, no_rw_check", max_depth = BANK_MAXD *) reg [31:0] lo[0:2047];
		(* ramstyle = "M10K, no_rw_check", max_depth = BANK_MAXD *) reg [31:0] hi[0:1479];
		wire [11:0] wa = bridge_addr[13:2];
		wire [11:0] ra = raddr[12:1];
		// Independent enables also preserve no-write behavior for an unknown bank.
		always @(posedge clk_74a) begin
			if (we && wa[11]) hi[wa[10:0]] <= wd;
			if (we && !wa[11]) lo[wa[10:0]] <= wd;
		end
		reg [31:0] qlo, qhi;
		reg bank, half;
		always @(posedge clk) begin
			qlo <= lo[ra[10:0]];
			qhi <= hi[ra[10:0]];
			bank <= ra[11];
			half <= raddr[0];
		end
		reg [31:0] q32;
		always @* begin
			case (bank)
				1'b0: q32 = qlo;
				1'b1: q32 = qhi;
				default: q32 = 32'bx;
			endcase
		end
		assign q = half ? q32[31:16] : q32[15:0];
	end else begin : original_other_sizes
		(* ramstyle = "M10K, no_rw_check", max_depth = MAXD *) reg [31:0] ram[0:WORDS-1];
		always @(posedge clk_74a) if (we) ram[bridge_addr[AW+1:2]] <= wd;
		reg [31:0] q32;
		reg half;
		always @(posedge clk) begin
			q32 <= ram[raddr[AW:1]];
			half <= raddr[0];
		end
		assign q = half ? q32[31:16] : q32[15:0];
	end endgenerate
endmodule
