/**************************************************************************/
// Copyright (c) 2025, SI2 Lab
// MODULE: PATTERN_IP
// FILE NAME: PATTERN_IP.v
// DESCRIPTION: Testbench pattern for Poker IP - reads from input.txt/output.txt
/**************************************************************************/

`ifdef RTL
    `define CYCLE_TIME 20.0
`endif
`ifdef GATE
    `define CYCLE_TIME 20.0
`endif

module PATTERN #(parameter IP_WIDTH = 9)(
    // Output to DUT
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT,
    // Input from DUT
    OUT_WINNER
);

// ========================================
// Input & Output
// ========================================
output reg [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
output reg [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
output reg [19:0]  IN_PUB_CARD_NUM;
output reg [9:0]  IN_PUB_CARD_SUIT;

input [IP_WIDTH-1:0]  OUT_WINNER;

// ========================================
// Parameter & Integer
// ========================================
integer i, pat;
integer error_count;
integer pass_count;
integer total_tests;
integer input_file, output_file;
integer scan_result;

// Card values
parameter CLUB = 2'd0;
parameter DIAMOND = 2'd1;
parameter HEART = 2'd2;
parameter SPADE = 2'd3;

// ========================================
// Wire & Reg
// ========================================
reg [3:0] pub_card_num [0:4];
reg [1:0] pub_card_suit [0:4];
reg [3:0] hole_card_num [0:IP_WIDTH-1][0:1];
reg [1:0] hole_card_suit [0:IP_WIDTH-1][0:1];
reg [IP_WIDTH-1:0] golden_winner;

//================================================================
// Initial
//================================================================
initial begin
    error_count = 0;
    pass_count = 0;
    total_tests = 0;
    
    IN_HOLE_CARD_NUM = 0;
    IN_HOLE_CARD_SUIT = 0;
    IN_PUB_CARD_NUM = 0;
    IN_PUB_CARD_SUIT = 0;
    
    $display("========================================");
    $display("   Poker IP Testbench");
    $display("   Reading from input.txt/output.txt");
    $display("   IP_WIDTH = %0d", IP_WIDTH);
    $display("========================================\n");
    
    // Open files
    input_file = $fopen("../00_TESTBED/input.txt", "r");
    output_file = $fopen("../00_TESTBED/output.txt", "r");
    
    if (input_file == 0) begin
        $display("[ERROR] Cannot open input.txt");
        $finish;
    end
    
    if (output_file == 0) begin
        $display("[ERROR] Cannot open output.txt");
        $finish;
    end
    
    // Read number of test cases
    scan_result = $fscanf(input_file, "%d\n", total_tests);
    if (scan_result != 1) begin
        $display("[ERROR] Failed to read number of test cases");
        $finish;
    end
    
    $display("Total test cases to run: %0d\n", total_tests);
    
    #(`CYCLE_TIME);
    
    // Run all test cases
    for (pat = 0; pat < total_tests; pat = pat + 1) begin
        run_test_case(pat);
    end
    
    // Close files
    $fclose(input_file);
    $fclose(output_file);
    
    // Display results
    $display("\n========================================");
    $display("   Test Results");
    $display("========================================");
    $display("Total Tests: %0d", total_tests);
    $display("PASS: %0d", pass_count);
    $display("FAIL: %0d", error_count);
    $display("========================================\n");
    
    if (error_count == 0) begin
        $display("★★★ All tests passed! ★★★\n");
    end else begin
        $display("✗✗✗ %0d test(s) failed ✗✗✗\n", error_count);
    end
    
    #(`CYCLE_TIME * 2);
    $finish;
end

//================================================================
// Task: Run one test case
//================================================================
task run_test_case;
    input integer test_num;
    integer j, k;
    begin
        // Read public cards (5 cards)
        for (j = 0; j < 5; j = j + 1) begin
            scan_result = $fscanf(input_file, "%h %h\n", pub_card_num[j], pub_card_suit[j]);
            if (scan_result != 2) begin
                $display("[ERROR] Failed to read public card %0d in test %0d", j, test_num);
                $finish;
            end
        end
        
        // Read players' hole cards (9 players × 2 cards)
        for (j = 0; j < IP_WIDTH; j = j + 1) begin
            for (k = 0; k < 2; k = k + 1) begin
                scan_result = $fscanf(input_file, "%h %h\n", 
                                     hole_card_num[j][k], hole_card_suit[j][k]);
                if (scan_result != 2) begin
                    $display("[ERROR] Failed to read hole card for player %0d in test %0d", j, test_num);
                    $finish;
                end
            end
        end
        
        // Read expected output
        scan_result = $fscanf(output_file, "%h\n", golden_winner);
        if (scan_result != 1) begin
            $display("[ERROR] Failed to read expected output for test %0d", test_num);
            $finish;
        end
        
        // Pack data to send to DUT
        pack_and_send();
        
        // Wait and check output
        #(`CYCLE_TIME);
        check_output(test_num);
    end
endtask

//================================================================
// Task: Pack and send data to DUT
//================================================================
task pack_and_send;
    integer j, k;
    begin
        // Pack public cards
        IN_PUB_CARD_NUM = {pub_card_num[0], pub_card_num[1], pub_card_num[2], 
                          pub_card_num[3], pub_card_num[4]};
        IN_PUB_CARD_SUIT = {pub_card_suit[0], pub_card_suit[1], pub_card_suit[2], 
                           pub_card_suit[3], pub_card_suit[4]};
        
        // Pack hole cards (Player i goes to bits [i*8+7:i*8])
        for (j = 0; j < IP_WIDTH; j = j + 1) begin
            IN_HOLE_CARD_NUM[j*8 +: 8] = {hole_card_num[j][1], hole_card_num[j][0]};
            IN_HOLE_CARD_SUIT[j*4 +: 4] = {hole_card_suit[j][1], hole_card_suit[j][0]};
        end
    end
endtask

//================================================================
// Task: Check output
//================================================================
task check_output;
    input integer test_num;
    begin
        if (OUT_WINNER === golden_winner) begin
            $display("[PASS] Test %0d", test_num + 1);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %0d", test_num + 1);
            $display("       Expected: %b (0x%03h)", golden_winner, golden_winner);
            $display("       Got:      %b (0x%03h)", OUT_WINNER, OUT_WINNER);
            display_cards();
            error_count = error_count + 1;
        end
    end
endtask

//================================================================
// Task: Display cards (for debugging failed tests)
//================================================================
task display_cards;
    integer j;
    begin
        $display("\n       === Card Details ===");
        $display("       Public: %s %s %s %s %s",
                 card_str(pub_card_num[0], pub_card_suit[0]),
                 card_str(pub_card_num[1], pub_card_suit[1]),
                 card_str(pub_card_num[2], pub_card_suit[2]),
                 card_str(pub_card_num[3], pub_card_suit[3]),
                 card_str(pub_card_num[4], pub_card_suit[4]));
        
        for (j = 0; j < IP_WIDTH; j = j + 1) begin
            $display("       Player[%0d]: %s %s", j,
                     card_str(hole_card_num[j][0], hole_card_suit[j][0]),
                     card_str(hole_card_num[j][1], hole_card_suit[j][1]));
        end
        $display("");
    end
endtask

//================================================================
// Function: Card to string
//================================================================
function [15:0] card_str;
    input [3:0] num;
    input [1:0] suit;
    reg [7:0] n;
    reg [7:0] s;
    begin
        case(num)
            4'd2:  n = "2";
            4'd3:  n = "3";
            4'd4:  n = "4";
            4'd5:  n = "5";
            4'd6:  n = "6";
            4'd7:  n = "7";
            4'd8:  n = "8";
            4'd9:  n = "9";
            4'd10: n = "T";
            4'd11: n = "J";
            4'd12: n = "Q";
            4'd13: n = "K";
            4'd14: n = "A";
            default: n = "?";
        endcase
        
        case(suit)
            2'd0: s = "C";
            2'd1: s = "D";
            2'd2: s = "H";
            2'd3: s = "S";
            default: s = "?";
        endcase
        
        card_str = {n, s};
    end
endfunction

endmodule