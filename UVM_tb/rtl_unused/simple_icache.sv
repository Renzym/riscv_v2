`ifndef SIMPLE_ICACHE_SV
`define SIMPLE_ICACHE_SV

`timescale 1ns/1ps

module simple_icache #(
    parameter int ADDR_WIDTH   = 10,
    parameter int CACHE_LINES  = 16,
    parameter int MISS_LATENCY = 3
) (
    input  logic                  clk,
    input  logic                  reset,
    input  logic                  cpu_req,
    input  logic [31:0]           cpu_addr,
    output logic                  cpu_ready,
    output logic [31:0]           cpu_rdata,
    input  logic                  invalidate,

    output logic [ADDR_WIDTH-1:0] mem_addr,
    input  logic [31:0]           mem_rdata
);

    localparam int NUM_WAYS = 2;
    localparam int SET_COUNT = CACHE_LINES / NUM_WAYS;
    localparam int SET_BITS = $clog2(SET_COUNT);
    localparam int TAG_WIDTH = ADDR_WIDTH - SET_BITS;
    localparam int COUNT_WIDTH = (MISS_LATENCY <= 1) ? 1 : $clog2(MISS_LATENCY);
    localparam logic [COUNT_WIDTH-1:0] MISS_COUNT_RELOAD = COUNT_WIDTH'(MISS_LATENCY - 1);

    logic [31:0] data_array [0:NUM_WAYS-1][0:SET_COUNT-1];
    logic [TAG_WIDTH-1:0] tag_array [0:NUM_WAYS-1][0:SET_COUNT-1];
    logic                 valid_array [0:NUM_WAYS-1][0:SET_COUNT-1];
    logic                 lru_way [0:SET_COUNT-1];

    logic                   miss_active;
    logic [COUNT_WIDTH-1:0] miss_count;
    logic [ADDR_WIDTH-1:0] miss_word_addr;
    logic [SET_BITS-1:0]   miss_set;
    logic [TAG_WIDTH-1:0]  miss_tag;
    logic                  miss_fill_way;

    logic [ADDR_WIDTH-1:0] cpu_word_addr;
    logic [SET_BITS-1:0]   cpu_set;
    logic [TAG_WIDTH-1:0]  cpu_tag;
    logic                  hit;
    logic                  hit_way;
    logic                  replace_way;
    logic                  found_invalid_way;

    initial begin
        if ((CACHE_LINES < 4) || ((CACHE_LINES % NUM_WAYS) != 0))
            $fatal(1, "simple_icache requires an even CACHE_LINES value of at least 4.");
    end

    assign cpu_word_addr = cpu_addr[ADDR_WIDTH+1:2];
    assign cpu_set = cpu_word_addr[SET_BITS-1:0];
    assign cpu_tag = cpu_word_addr[ADDR_WIDTH-1:SET_BITS];

    assign mem_addr = miss_active ? miss_word_addr : cpu_word_addr;

    always_comb begin
        hit = 1'b0;
        hit_way = 1'b0;
        replace_way = lru_way[cpu_set];
        found_invalid_way = 1'b0;

        for (int way = 0; way < NUM_WAYS; way = way + 1) begin
            if (cpu_req && valid_array[way][cpu_set] && (tag_array[way][cpu_set] == cpu_tag)) begin
                hit = 1'b1;
                hit_way = logic'(way);
            end

            if (!valid_array[way][cpu_set] && !found_invalid_way) begin
                replace_way = logic'(way);
                found_invalid_way = 1'b1;
            end
        end
    end

    always_comb begin
        cpu_ready = 1'b0;
        cpu_rdata = 32'd0;

        if (hit) begin
            cpu_ready = 1'b1;
            cpu_rdata = data_array[hit_way][cpu_set];
        end else if (miss_active && cpu_req && (cpu_word_addr == miss_word_addr) && (miss_count == '0)) begin
            cpu_ready = 1'b1;
            cpu_rdata = mem_rdata;
        end
    end

    always_ff @(posedge clk or posedge reset) begin
        integer set_idx;
        integer way_idx;
        if (reset) begin
            miss_active <= 1'b0;
            miss_count <= '0;
            miss_word_addr <= '0;
            miss_set <= '0;
            miss_tag <= '0;
            miss_fill_way <= 1'b0;
            for (set_idx = 0; set_idx < SET_COUNT; set_idx = set_idx + 1) begin
                lru_way[set_idx] <= 1'b0;
                for (way_idx = 0; way_idx < NUM_WAYS; way_idx = way_idx + 1) begin
                    data_array[way_idx][set_idx] <= 32'd0;
                    tag_array[way_idx][set_idx] <= '0;
                    valid_array[way_idx][set_idx] <= 1'b0;
                end
            end
        end else begin
            if (invalidate) begin
                for (set_idx = 0; set_idx < SET_COUNT; set_idx = set_idx + 1) begin
                    lru_way[set_idx] <= 1'b0;
                    for (way_idx = 0; way_idx < NUM_WAYS; way_idx = way_idx + 1)
                        valid_array[way_idx][set_idx] <= 1'b0;
                end
            end

            if (!cpu_req) begin
                miss_active <= 1'b0;
                miss_count <= '0;
            end else if (hit) begin
                miss_active <= 1'b0;
                miss_count <= '0;
                lru_way[cpu_set] <= ~hit_way;
            end else if (!miss_active || (cpu_word_addr != miss_word_addr)) begin
                miss_active <= 1'b1;
                miss_word_addr <= cpu_word_addr;
                miss_set <= cpu_set;
                miss_tag <= cpu_tag;
                miss_fill_way <= replace_way;
                if (MISS_LATENCY <= 1)
                    miss_count <= '0;
                else
                    miss_count <= MISS_COUNT_RELOAD;
            end else if (miss_count != '0) begin
                miss_count <= miss_count - 1'b1;
            end else begin
                data_array[miss_fill_way][miss_set] <= mem_rdata;
                tag_array[miss_fill_way][miss_set] <= miss_tag;
                valid_array[miss_fill_way][miss_set] <= 1'b1;
                lru_way[miss_set] <= ~miss_fill_way;
                miss_active <= 1'b0;
            end
        end
    end

endmodule

`endif
