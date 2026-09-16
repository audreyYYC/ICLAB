//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//    (C) Copyright System Integration and Silicon Implementation Laboratory
//    All Right Reserved
//		Date		: 2025/10
//		Version		: v1.0
//   	File Name   : Poker.v
//   	Module Name : Poker
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//############################################################################
module Poker #(parameter IP_WIDTH = 9) (
    // Input signals
    IN_HOLE_CARD_NUM, IN_HOLE_CARD_SUIT, IN_PUB_CARD_NUM, IN_PUB_CARD_SUIT,
    // Output signals
    OUT_WINNER
);

// ===============================================================
// Input & Output
// ===============================================================
input [IP_WIDTH*8-1:0]  IN_HOLE_CARD_NUM;
input [IP_WIDTH*4-1:0]  IN_HOLE_CARD_SUIT;
input [19:0]  IN_PUB_CARD_NUM;
input [9:0]  IN_PUB_CARD_SUIT;

output [IP_WIDTH-1:0]  OUT_WINNER;

// ===============================================================
// Reg & Wire
// ===============================================================
wire [27:0] player_cards [0:IP_WIDTH-1]; //{[3:0],[3:0],[3:0],[3:0],[3:0],[3:0],[3:0]} * N
wire [13:0] player_suits [0:IP_WIDTH-1]; //{[1:0],[1:0],[1:0],[1:0],[1:0],[1:0],[1:0]} * N

wire [27:0] sorted_cards [0:IP_WIDTH-1];
wire [13:0] same_cards [0:IP_WIDTH-1];

wire [27:0] suit_sorted [0:IP_WIDTH-1];

wire [23:0] hand [0:IP_WIDTH-1];

reg [23:0] winner_hand;
reg [IP_WIDTH-1:0] out_winner_reg;

// ===============================================================
// Design
// ===============================================================
genvar i;
generate
    for (i = 0 ; i < IP_WIDTH ; i = i + 1) begin
        assign player_cards[i] = {
            IN_HOLE_CARD_NUM[i * 8 + 7:i * 8 + 4], IN_HOLE_CARD_NUM[i * 8 + 3:i * 8], //player
            IN_PUB_CARD_NUM[19:16], //community
            IN_PUB_CARD_NUM[15:12],
            IN_PUB_CARD_NUM[11:8],
            IN_PUB_CARD_NUM[7:4],
            IN_PUB_CARD_NUM[3:0]
        };
        assign player_suits[i] = {
            IN_HOLE_CARD_SUIT[i * 4 + 3:i * 4 + 2], IN_HOLE_CARD_SUIT[i * 4 + 1:i * 4], //player
            IN_PUB_CARD_SUIT[9:8],
            IN_PUB_CARD_SUIT[7:6],
            IN_PUB_CARD_SUIT[5:4],
            IN_PUB_CARD_SUIT[3:2],
            IN_PUB_CARD_SUIT[1:0]
        };

        sort_number sort_num_inst (
            .unsorted_cards(player_cards[i]),
            .sorted_cards(sorted_cards[i])
        );

        sort_suit sort_suit_inst (
            .unsorted_cards(player_cards[i]),
            .unsorted_suits(player_suits[i]),
            .sorted_suit(suit_sorted[i])
        );

        count_same count_same_inst (
            .sorted_cards(sorted_cards[i]),
            .same_cards(same_cards[i])
        );

        gen_hand gen_hand_inst (
            .sorted_cards(sorted_cards[i]),
            .sorted_suit(suit_sorted[i]),
            .same_cards(same_cards[i]),

            .curr_hand(hand[i])
        );
    end
endgenerate

always @(*) begin
    winner_hand = 0;
    out_winner_reg = 0;
    for (integer i = 0 ; i < IP_WIDTH; i = i + 1) begin
        if(hand[i] > winner_hand) begin
            out_winner_reg = 0;
            out_winner_reg[i] = 1;
            winner_hand = hand[i];
        end
        else if (hand[i] == winner_hand) 
            out_winner_reg[i] = 1;
    end
end

assign OUT_WINNER = out_winner_reg;

endmodule

// ===============================================================
// SORT
// ===============================================================
module sort_number (
    input [27:0] unsorted_cards,  // 7 cards
    output [27:0] sorted_cards
);

wire [3:0] s0 [0:6];
wire [3:0] s1 [0:6];
wire [3:0] s2 [0:6];
wire [3:0] s3 [0:6];
wire [3:0] s4 [0:6];
wire [3:0] s5 [0:6];
wire [3:0] s6 [0:6];
assign s0[0] = unsorted_cards[27:24];
assign s0[1] = unsorted_cards[23:20];
assign s0[2] = unsorted_cards[19:16];
assign s0[3] = unsorted_cards[15:12];
assign s0[4] = unsorted_cards[11:8];
assign s0[5] = unsorted_cards[7:4];
assign s0[6] = unsorted_cards[3:0];


// Compare pairs (0,1), (2,3), (4,5)
compare_swap cs1_0 (.a(s0[0]), .b(s0[1]), .max(s1[0]), .min(s1[1]));
compare_swap cs1_1 (.a(s0[2]), .b(s0[3]), .max(s1[2]), .min(s1[3]));
compare_swap cs1_2 (.a(s0[4]), .b(s0[5]), .max(s1[4]), .min(s1[5]));
assign s1[6] = s0[6];

// Compare (0,2), (1,3), (4,6)
compare_swap cs2_0 (.a(s1[0]), .b(s1[2]), .max(s2[0]), .min(s2[2]));
compare_swap cs2_1 (.a(s1[1]), .b(s1[3]), .max(s2[1]), .min(s2[3]));
compare_swap cs2_2 (.a(s1[4]), .b(s1[6]), .max(s2[4]), .min(s2[6]));
assign s2[5] = s1[5];

// Compare (0,4), (1,5), (2,6) 
compare_swap cs3_0 (.a(s2[0]), .b(s2[4]), .max(s3[0]), .min(s3[4]));
compare_swap cs3_1 (.a(s2[1]), .b(s2[5]), .max(s3[1]), .min(s3[5]));
compare_swap cs3_2 (.a(s2[2]), .b(s2[6]), .max(s3[2]), .min(s3[6]));
assign s3[3] = s2[3];

// Compare (1,2), (3,4), (5,6)
assign s4[0] = s3[0];
compare_swap cs4_0 (.a(s3[1]), .b(s3[2]), .max(s4[1]), .min(s4[2]));
compare_swap cs4_1 (.a(s3[3]), .b(s3[4]), .max(s4[3]), .min(s4[4]));
compare_swap cs4_2 (.a(s3[5]), .b(s3[6]), .max(s4[5]), .min(s4[6]));

// Compare (0,1), (2,3), (4,5)
compare_swap cs5_0 (.a(s4[0]), .b(s4[1]), .max(s5[0]), .min(s5[1]));
compare_swap cs5_1 (.a(s4[2]), .b(s4[3]), .max(s5[2]), .min(s5[3]));
compare_swap cs5_2 (.a(s4[4]), .b(s4[5]), .max(s5[4]), .min(s5[5]));
assign s5[6] = s4[6];

// Compare (1,2), (3,4), (5, 6)
assign s6[0] = s5[0];
compare_swap cs6_0 (.a(s5[1]), .b(s5[2]), .max(s6[1]), .min(s6[2]));
compare_swap cs6_1 (.a(s5[3]), .b(s5[4]), .max(s6[3]), .min(s6[4]));
compare_swap cs6_2 (.a(s5[5]), .b(s5[6]), .max(s6[5]), .min(s6[6]));


assign sorted_cards = {s6[0], s6[1], s6[2], s6[3], s6[4], s6[5], s6[6]};

endmodule

// ===============================================================
// Sort - Grouped by Suits
// ===============================================================
module sort_suit (
    input [27:0] unsorted_cards,
    input [13:0] unsorted_suits,
    output [27:0] sorted_suit
);

wire [3:0] card [0:6];
wire [1:0] suit [0:6];

assign card[0] = unsorted_cards[27:24];
assign card[1] = unsorted_cards[23:20];
assign card[2] = unsorted_cards[19:16];
assign card[3] = unsorted_cards[15:12];
assign card[4] = unsorted_cards[11:8];
assign card[5] = unsorted_cards[7:4];
assign card[6] = unsorted_cards[3:0];

assign suit[0] = unsorted_suits[13:12];
assign suit[1] = unsorted_suits[11:10];
assign suit[2] = unsorted_suits[9:8];
assign suit[3] = unsorted_suits[7:6];
assign suit[4] = unsorted_suits[5:4];
assign suit[5] = unsorted_suits[3:2];
assign suit[6] = unsorted_suits[1:0];

// 0=clubs, 1=diamonds, 2=hearts, 3=spades
reg [3:0] clubs_cards [0:6];
reg [3:0] diamonds_cards [0:6];
reg [3:0] hearts_cards [0:6];
reg [3:0] spades_cards [0:6];

reg [27:0] suit_packed;
reg [2:0] club_num, diamond_num, hearts_num, spades_num;

always @(*) begin
    /*club_num = 0;
    diamond_num = 0;
    hearts_num = 0;
    spades_num = 0;
    for (integer j = 0; j < 7; j = j + 1) begin
        case (suit[j])
            2'd0: club_num = club_num + 1;
            2'd1: diamond_num = diamond_num + 1;
            2'd2: hearts_num = hearts_num + 1;
            2'd3: spades_num = spades_num + 1;
        endcase
    end*/
    club_num = (suit[0] == 0) + (suit[1] == 0) + (suit[2] == 0) + (suit[3] == 0) + (suit[4] == 0) + (suit[5] == 0) + (suit[6] == 0);
    diamond_num = (suit[0]== 1) + (suit[1]== 1) + (suit[2]== 1) + (suit[3]== 1) + (suit[4]== 1) + (suit[5]== 1) + (suit[6]== 1);
    hearts_num = (suit[0] == 2) + (suit[1] == 2) + (suit[2] == 2) + (suit[3] == 2) + (suit[4] == 2) + (suit[5] == 2) + (suit[6] == 2);

    for (integer j = 0; j < 7; j = j + 1) begin
        case (suit[j])
            2'd0: begin
                clubs_cards[j] = card[j];
                diamonds_cards[j] = 0;
                hearts_cards[j] = 0;
                spades_cards[j] = 0;
                //club_num = club_num + 1;
            end
            2'd1: begin
                clubs_cards[j] = 0;
                diamonds_cards[j] = card[j];
                hearts_cards[j] = 0;
                spades_cards[j] = 0;
                //diamond_num = diamond_num + 1;
            end
            2'd2: begin
                clubs_cards[j] = 0;
                diamonds_cards[j] = 0;
                hearts_cards[j] = card[j];
                spades_cards[j] = 0;
                //hearts_num = hearts_num + 1;
            end
            2'd3: begin
                clubs_cards[j] = 0;
                diamonds_cards[j] = 0;
                hearts_cards[j] = 0;
                spades_cards[j] = card[j];
                //spades_num = spades_num + 1;
            end
        endcase
    end
    if (club_num > 4)
        suit_packed = {clubs_cards[0], clubs_cards[1], clubs_cards[2], clubs_cards[3], clubs_cards[4], clubs_cards[5], clubs_cards[6]};
    else if (diamond_num > 4)
        suit_packed = {diamonds_cards[0], diamonds_cards[1], diamonds_cards[2], diamonds_cards[3], diamonds_cards[4], diamonds_cards[5], diamonds_cards[6]};
    else if (hearts_num > 4)
        suit_packed = {hearts_cards[0], hearts_cards[1], hearts_cards[2], hearts_cards[3], hearts_cards[4], hearts_cards[5], hearts_cards[6]};
    //if (spades_num > 4)
    else
        suit_packed = {spades_cards[0], spades_cards[1], spades_cards[2], spades_cards[3], spades_cards[4], spades_cards[5], spades_cards[6]};

end

sort_number sort_same_suit (.unsorted_cards(suit_packed), .sorted_cards(sorted_suit));

endmodule

// ===============================================================
// Count Same Numbers
// ===============================================================
module count_same (
    input [27:0] sorted_cards,
    output [13:0] same_cards
);

reg [1:0] count [0:6];

wire eq_01 = (sorted_cards[27:24] == sorted_cards[23:20]);
wire eq_12 = (sorted_cards[23:20] == sorted_cards[19:16]);
wire eq_23 = (sorted_cards[19:16] == sorted_cards[15:12]);
wire eq_34 = (sorted_cards[15:12] == sorted_cards[11:8]);
wire eq_45 = (sorted_cards[11:8] == sorted_cards[7:4]);
wire eq_56 = (sorted_cards[7:4] == sorted_cards[3:0]);

wire four_0123 = eq_01 & eq_12 & eq_23;
wire four_1234 = eq_12 & eq_23 & eq_34;
wire four_2345 = eq_23 & eq_34 & eq_45;
wire four_3456 = eq_34 & eq_45 & eq_56;

wire three_012 = eq_01 & eq_12 & ~four_0123 & ~four_1234;
wire three_123 = eq_12 & eq_23 & ~four_0123 & ~four_1234 & ~four_2345;
wire three_234 = eq_23 & eq_34 & ~four_1234 & ~four_2345 & ~four_3456;
wire three_345 = eq_34 & eq_45 & ~four_2345 & ~four_3456;
wire three_456 = eq_45 & eq_56 & ~four_3456;

wire pair_01 = eq_01 & ~three_012 & ~three_123;
wire pair_12 = eq_12 & ~three_012 & ~three_123 & ~three_234;
wire pair_23 = eq_23 & ~three_123 & ~three_234 & ~three_345;
wire pair_34 = eq_34 & ~three_234 & ~three_345 & ~three_456;
wire pair_45 = eq_45 & ~three_345 & ~three_456;
wire pair_56 = eq_56 & ~three_456;

assign count[0] = four_0123 ? 2'd0 : 
                  three_012 ? 2'd3 :
                  pair_01 ? 2'd2 : 2'd1;

assign count[1] = (four_0123 || four_1234) ? 2'd0 :
                  (three_012 || three_123) ? 2'd3 :
                  (pair_01 || pair_12) ? 2'd2 : 2'd1;

assign count[2] = (four_0123 || four_1234 || four_2345) ? 2'd0 :
                  (three_012 || three_123 || three_234) ? 2'd3 :
                  (pair_12 || pair_23) ? 2'd2 : 2'd1;

assign count[3] = (four_0123 || four_1234 || four_2345 || four_3456) ? 2'd0 :
                  (three_123 || three_234 || three_345) ? 2'd3 :
                  (pair_23|| pair_34) ? 2'd2 : 2'd1;

assign count[4] = (four_1234 || four_2345 || four_3456) ? 2'd0 :
                  (three_234 || three_345 || three_456) ? 2'd3 :
                  (pair_34 || pair_45) ? 2'd2 : 2'd1;

assign count[5] = (four_2345 || four_3456) ? 2'd0 :
                  (three_345 || three_456) ? 2'd3 :
                  (pair_45 || pair_56) ? 2'd2 : 2'd1;


assign count[6] = four_3456 ? 2'd0 :
                  three_456 ? 2'd3 :
                  pair_56 ? 2'd2 : 2'd1;

assign same_cards = {count[0], count[1], count[2], count[3], count[4], count[5], count[6]};

endmodule


// ===============================================================
// Compare and Swap
// ===============================================================
module compare_swap (
    input [3:0] a,
    input [3:0] b,
    output [3:0] max,
    output [3:0] min
);

assign max = (a > b) ? a : b;
assign min = (a > b) ? b : a;

endmodule

// ===============================================================
// 5 BEST HAND
// ===============================================================
module gen_hand (
    input [27:0] sorted_cards,
    input [27:0] sorted_suit,
    input [13:0] same_cards,
    output [23:0] curr_hand
);
reg has_1, has_2, has_3, has_4, has_5, has_6, has_7;
reg [23:0] hand;

reg has_straight_flush, has_straight, has_flush, has_four_kind, has_full_house, has_three_kind, has_two_pair, has_pair;
reg [3:0] straight_flush_low, straight_low, four_kind_value, four_kind_kicker;
reg [3:0] full_house_trips, full_house_pair, pair_2, pair_2_kicker, three_kind_kicker_1, three_kind_kicker_2;
reg [3:0] pair_kicker_1, pair_kicker_2, pair_kicker_3;


wire [3:0] curr_card [0:6];
wire [1:0] curr_count [0:6];
wire [3:0] curr_suit [0:6];

assign curr_card[0] = sorted_cards[27:24];
assign curr_card[1] = sorted_cards[23:20];
assign curr_card[2] = sorted_cards[19:16];
assign curr_card[3] = sorted_cards[15:12];
assign curr_card[4] = sorted_cards[11:8];
assign curr_card[5] = sorted_cards[7:4];
assign curr_card[6] = sorted_cards[3:0];

assign curr_count[0] = same_cards[13:12];
assign curr_count[1] = same_cards[11:10];
assign curr_count[2] = same_cards[9:8];
assign curr_count[3] = same_cards[7:6];
assign curr_count[4] = same_cards[5:4];
assign curr_count[5] = same_cards[3:2];
assign curr_count[6] = same_cards[1:0];

assign curr_suit[0] = sorted_suit[27:24];
assign curr_suit[1] = sorted_suit[23:20];
assign curr_suit[2] = sorted_suit[19:16];
assign curr_suit[3] = sorted_suit[15:12];
assign curr_suit[4] = sorted_suit[11:8];
assign curr_suit[5] = sorted_suit[7:4];
assign curr_suit[6] = sorted_suit[3:0];

integer n;

always @(*) begin
    has_straight_flush = 0;
    straight_flush_low = 0;

    has_four_kind = 0;
    four_kind_value = 0;
    four_kind_kicker = 0;

    has_full_house = 0;
    has_three_kind = 0;
    has_two_pair = 0;
    has_pair = 0;
    full_house_pair = 0;
    full_house_trips = 0;
    pair_2 = 0;
    three_kind_kicker_1 = 0;
    three_kind_kicker_2 = 0;
    pair_2_kicker = 0;
    pair_kicker_1 = 0;
    pair_kicker_2 = 0;
    pair_kicker_3 = 0;

    has_flush = 0;

    has_straight = 0;
    straight_low = 0;

    hand = 0;

    has_1 = 0;
    has_2 = 0;
    has_3 = 0;
    has_4 = 0;
    has_5 = 0;
    has_6 = 0;
    has_7 = 0;

    // ========== STRAIGHT FLUSH ==========
    if ((curr_suit[4] !== 0) && (curr_suit[0] == curr_suit[4] + 4)) begin
        has_straight_flush = 1;
        straight_flush_low = curr_suit[4];
    end
    else if (curr_suit[5] !== 0 && (curr_suit[1] == curr_suit[5] + 4)) begin
        has_straight_flush = 1;
        straight_flush_low = curr_suit[5];
    end
    else if (curr_suit[6] !== 0 && (curr_suit[2] == curr_suit[6] + 4)) begin
        has_straight_flush = 1;
        straight_flush_low = curr_suit[6];
    end
    if (curr_suit[0] == 14 && ((curr_suit[1] == 5 && curr_suit[4] == 2) || 
            (curr_suit[2] == 5 && curr_suit[5] == 2) || (curr_suit[3] == 5 && curr_suit[6] == 2))) begin // A 5 4 3 2
        has_straight_flush = 1;
        straight_flush_low = 1;
    end

    // ========== 4 OF A kIND ==========
    if (curr_count[3] == 0) begin
        has_four_kind = 1;
        four_kind_value = curr_card[3];
        if (curr_count[4] !== 0)
            four_kind_kicker = curr_card[4];
        else
            four_kind_kicker = curr_card[0];
    end

    // ========== FULL HOUSE, 3 OF A KIND, 2 PAIR ==========

    if(curr_count[1] == 2) begin
        full_house_pair = curr_card[1]; 
        has_pair = 1;
    end
    else if (curr_count[3] == 2) begin
        full_house_pair = curr_card[3];
        has_pair = 1;
    end
    else if (curr_count[5] == 2) begin
        full_house_pair = curr_card[5];
        has_pair = 1;
    end

    if(curr_count[0] == 1) 
        pair_kicker_1 = curr_card[0];
    else
        pair_kicker_1 = curr_card[2];

    if(curr_count[1] == 2) 
        pair_kicker_2 = curr_card[3];
    else
        pair_kicker_2 = curr_card[1];

    if(curr_count[2] == 2 || curr_count[1] == 2) 
        pair_kicker_3 = curr_card[4];
    else
        pair_kicker_3 = curr_card[2];


                
    if (curr_count[1] == 3 && curr_count[5] == 3) begin // 3 3
        full_house_trips = curr_card[1];
        full_house_pair = curr_card[5];
        has_full_house = 1;
    end
    else if (curr_count[2] == 3 || curr_count[4] == 3) begin // 3 2, 3
        has_three_kind = 1;
        if (curr_count[2] == 3) 
            full_house_trips = curr_card[2];
        else
            full_house_trips = curr_card[4];

        if (curr_count[1] == 2 || curr_count[3] == 2 || curr_count[5] == 2) 
            has_full_house = 1;


        if (curr_count[0] == 1) 
            three_kind_kicker_1 = curr_card[0];
        else
            three_kind_kicker_1 = curr_card[3];

        if (curr_count[1] == 1) 
            three_kind_kicker_2 = curr_card[1];
        else
            three_kind_kicker_2 = curr_card[4];
    end


    if (curr_count[1] == 2) begin
        if (curr_count[3] == 2) begin
            pair_2 = curr_card[3];
            has_two_pair = 1;
        end
        else if (curr_count[5] == 2) begin
            pair_2 = curr_card[5];
            has_two_pair = 1;
        end
    end
    else if (curr_count[3] == 2) begin
        if (curr_count[5] == 2) begin
            pair_2 = curr_card[5];
            has_two_pair = 1;
        end
    end

    if (curr_count[0] == 1) 
        pair_2_kicker = curr_card[0];
    else if(curr_count[2] == 1) 
        pair_2_kicker = curr_card[2];
    else
        pair_2_kicker = curr_card[4];


    // ========== FLUSH ==========
    if (curr_suit[4] !== 0) begin
        has_flush = 1;
    end

    // ========== STRAIGHT ==========
    if((curr_card[0] == curr_card[4] + 4) && curr_count[1] == 1 && curr_count[2] == 1 && curr_count[3] == 1) begin
        has_1 = 1;
    end
    if((curr_card[1] == curr_card[5] + 4) && curr_count[2] == 1 && curr_count[3] == 1 && curr_count[4] == 1) begin
        has_2 = 1;
    end
    if ((curr_card[0] == curr_card[5] + 4) && 
             (curr_count[1] + curr_count[2] + curr_count[3] + curr_count[4] == 6 && curr_count[0] == 1)) begin
        has_3 = 1;
    end
    if((curr_card[2] == curr_card[6] + 4) && curr_count[3] == 1 && curr_count[4] == 1 && curr_count[5] == 1) begin
        has_4 = 1;
    end
    if ((curr_card[1] == curr_card[6] + 4) &&
            (curr_count[2] + curr_count[3] + curr_count[4] + curr_count[5] == 6 && curr_count[6] == 1))begin 
        has_5 = 1;
    end

    if ((curr_card[0] == curr_card[6] + 4) && 
            ((curr_count[3] == 3 && ((curr_count[1] == 1 && curr_count[2] == 1) || (curr_count[1] == 1 && curr_count[5] == 1) || (curr_count[4] == 1 && curr_count[5] == 1))) ||
            (curr_count[2] == 2 && curr_count[4] == 2 && (curr_count[1] == 1 || curr_count[3] == 1 || curr_count[5] == 1)))) begin
        has_6 = 1;
    end
    if (curr_card[0] == 14) begin
        if (((curr_card[1] == 5 && curr_card[2] == 4) || (curr_card[2] == 5 && curr_card[3] == 4) || (curr_card[3] == 5 && curr_card[4] == 4)) &&
            ((curr_card[6] == 2 && curr_card[5] == 3) || (curr_card[5] == 2 && curr_card[4] == 3) || (curr_card[4] == 2 && curr_card[3] == 3))) begin
            has_7 = 1;
        end
    end

    if(has_1 || has_2 ||has_3 || has_4 || has_5 || has_6 || has_7)
        has_straight = 1;

    if(has_1)
        straight_low = curr_card[4];
    else if (has_2 || has_3)
        straight_low = curr_card[5];
    else if (has_4 || has_5 || has_6)
        straight_low = curr_card[6];
    else if(has_7)
        straight_low = 1;

    // ========== UPDATE WINNER ==========
    if (has_straight_flush) begin
        hand[23:20] = 8;
        hand[19:16] = straight_flush_low;
    end
    else if (has_four_kind) begin
        hand[23:20] = 7;
        hand[19:12] = {four_kind_value, four_kind_kicker};
    end
    else if (has_full_house) begin
        hand[23:20] = 6;
        hand[19:12] = {full_house_trips, full_house_pair};
    end
    else if (has_flush) begin
        hand[23:20] = 5;
        hand[19:0] = {curr_suit[0], curr_suit[1], curr_suit[2], curr_suit[3], curr_suit[4]};
    end
    else if (has_straight) begin
        hand[23:20] = 4;
        hand[19:16] = straight_low;
    end
    else if (has_three_kind) begin
        hand[23:20] = 3;
        hand[19:8] = {full_house_trips, three_kind_kicker_1, three_kind_kicker_2};
    end
    else if (has_two_pair) begin
        hand[23:20] = 2;
        hand[19:8] = {full_house_pair, pair_2, pair_2_kicker};
    end
    else if (has_pair) begin
        hand[23:20] = 1;
        hand[19:4] = {full_house_pair, pair_kicker_1, pair_kicker_2, pair_kicker_3};
    end
    else begin
        //hand[23:20] = 0;
        hand[19:0] = {curr_card[0], curr_card[1], curr_card[2], curr_card[3], curr_card[4]};
    end
end

assign curr_hand = hand;

endmodule