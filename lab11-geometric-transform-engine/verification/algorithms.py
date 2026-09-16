import numpy as np
# from config import DEBUG

EN_MX=0
EN_MY=0
EN_TRP=0
EN_STRP=0
EN_R90=0
EN_R180=0
EN_R270=0
EN_RS=0
EN_LS=0
EN_US=0
EN_DS=0
EN_ZZ4=0
EN_ZZ8=0
EN_MO4=0
EN_MO8=1


def mirror_x_axis(matrix):
    """
    Performs MX operation: vertical flip along the X-axis.
    Mirrors the image top-to-bottom.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with rows reversed (first row becomes last row, etc.)
    """
    return np.flipud(matrix)


def mirror_y_axis(matrix):
    """
    Performs MY operation: horizontal flip along the Y-axis.
    Mirrors the image left-to-right.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with columns reversed (first column becomes last column, etc.)
    """
    return np.fliplr(matrix)


def transpose(matrix):
    """
    Performs TRP operation: transpose (reflect along main diagonal).
    Reflects the image along its main diagonal from top-left to bottom-right.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with rows and columns swapped (matrix[i][j] becomes matrix[j][i])
    """
    return np.transpose(matrix)


def secondary_transpose(matrix):
    """
    Performs STRP operation: secondary transpose (reflect along secondary diagonal).
    Reflects the image along its secondary diagonal from top-right to bottom-left.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array reflected along the secondary diagonal
    """
    # Secondary transpose can be achieved by flipping both horizontally and vertically, then transposing
    # Or equivalently: transpose, then flip both axes
    return np.transpose(np.flipud(np.fliplr(matrix)))


def rotate_90_clockwise(matrix):
    """
    Performs R90 operation: rotate 90 degrees clockwise.
    Rotates the image 90 degrees clockwise around its center.
    Top row becomes rightmost column, leftmost column becomes top row.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array rotated 90 degrees clockwise
    """
    # 90 degree clockwise rotation can be achieved by transpose then horizontal flip
    return np.fliplr(np.transpose(matrix))


def rotate_180(matrix):
    """
    Performs R180 operation: rotate 180 degrees.
    Rotates the image 180 degrees around its center.
    Pixels are inverted both horizontally and vertically, making the image appear upside down.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array rotated 180 degrees
    """
    # 180 degree rotation can be achieved by flipping both vertically and horizontally
    return np.flipud(np.fliplr(matrix))


def rotate_270_clockwise(matrix):
    """
    Performs R270 operation: rotate 270 degrees clockwise (90 degrees counterclockwise).
    Rotates the image 270 degrees clockwise around its center.
    Top row moves to leftmost column, rightmost column becomes top row.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array rotated 270 degrees clockwise
    """
    # 270 degree clockwise rotation can be achieved by transpose then vertical flip
    return np.flipud(np.transpose(matrix))


def right_shift(matrix, shift_amount=5):
    """
    Performs RS operation: right shift with mirror padding.
    Shifts the image to the right by the specified amount (default 5 pixels).
    Pixels on the right edge move outside the visible region.
    Empty spaces on the left are filled using mirrored reflection of the original leftmost columns.
    
    Args:
        matrix: 16x16 numpy array
        shift_amount: number of pixels to shift right (default 5)
        
    Returns:
        16x16 numpy array shifted right with mirror padding
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Fill the shifted original content
    if shift_amount < cols:
        result[:, shift_amount:] = matrix[:, :cols-shift_amount]
    
    # Fill the left padding with mirrored content
    for i in range(min(shift_amount, cols)):
        # Mirror the leftmost columns in reverse order
        source_col = min(shift_amount - 1 - i, cols - 1)
        result[:, i] = matrix[:, source_col]
    
    return result


def left_shift(matrix, shift_amount=5):
    """
    Performs LS operation: left shift with mirror padding.
    Shifts the image to the left by the specified amount (default 5 pixels).
    Pixels on the left edge move outside the visible region.
    Empty spaces on the right are filled using mirrored reflection of the original rightmost columns.
    
    Args:
        matrix: 16x16 numpy array
        shift_amount: number of pixels to shift left (default 5)
        
    Returns:
        16x16 numpy array shifted left with mirror padding
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Fill the shifted original content
    if shift_amount < cols:
        result[:, :cols-shift_amount] = matrix[:, shift_amount:]
    
    # Fill the right padding with mirrored content
    for i in range(min(shift_amount, cols)):
        # Mirror the rightmost columns in reverse order
        source_col = max(cols - 1 - (shift_amount - 1 - i), 0)
        result[:, cols - 1 - i] = matrix[:, source_col]
    
    return result


def up_shift(matrix, shift_amount=5):
    """
    Performs US operation: up shift with mirror padding.
    Shifts the image upward by the specified amount (default 5 pixels).
    Pixels on the top edge move outside the visible region.
    Empty spaces at the bottom are filled using mirrored reflection of the original top rows.
    
    Args:
        matrix: 16x16 numpy array
        shift_amount: number of pixels to shift up (default 5)
        
    Returns:
        16x16 numpy array shifted up with mirror padding
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Fill the shifted original content
    if shift_amount < rows:
        result[:rows-shift_amount, :] = matrix[shift_amount:, :]
    
    # Fill the bottom padding with mirrored content
    for i in range(min(shift_amount, rows)):
        # Mirror the top rows in reverse order
        source_row = max(rows - 1 - (shift_amount - 1 - i), 0)
        result[rows - 1 - i, :] = matrix[source_row, :]
    
    return result


def down_shift(matrix, shift_amount=5):
    """
    Performs DS operation: down shift with mirror padding.
    Shifts the image downward by the specified amount (default 5 pixels).
    Pixels on the bottom edge move outside the visible region.
    Empty spaces at the top are filled using mirrored reflection of the original bottom rows.
    
    Args:
        matrix: 16x16 numpy array
        shift_amount: number of pixels to shift down (default 5)
        
    Returns:
        16x16 numpy array shifted down with mirror padding
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Fill the shifted original content
    if shift_amount < rows:
        result[shift_amount:, :] = matrix[:rows-shift_amount, :]
    
    # Fill the top padding with mirrored content
    for i in range(min(shift_amount, rows)):
        # Mirror the bottom rows in reverse order
        source_row = min(shift_amount - 1 - i, rows - 1)
        result[i, :] = matrix[source_row, :]
    
    return result


def zigzag_4x4(matrix):
    """
    Performs ZZ4 operation: 4x4 zig-zag reordering.
    Divides the image into multiple 4x4 sub-blocks and reorders each sub-block
    following a zig-zag scanning pattern that traverses diagonally from top-left to bottom-right.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with 4x4 sub-blocks reordered in zig-zag pattern
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Define the 4x4 zig-zag pattern (diagonal traversal)
    # Zig-zag pattern for 4x4 block: traverse diagonally from top-left to bottom-right
    zigzag_order = [
        (0, 0),  # 0
        (0, 1), (1, 0),  # 1, 2
        (2, 0), (1, 1), (0, 2),  # 3, 4, 5
        (0, 3), (1, 2), (2, 1), (3, 0),  # 6, 7, 8, 9
        (3, 1), (2, 2), (1, 3),  # 10, 11, 12
        (2, 3), (3, 2),  # 13, 14
        (3, 3)  # 15
    ]
    
    # Process each 4x4 sub-block
    for block_row in range(0, rows, 4):
        for block_col in range(0, cols, 4):
            # Extract the 4x4 sub-block
            sub_block = matrix[block_row:block_row+4, block_col:block_col+4]
            
            # Reorder according to zig-zag pattern
            for idx, (r, c) in enumerate(zigzag_order):
                result[block_row + idx // 4, block_col + idx % 4] = sub_block[r][c]
    
    return result


def zigzag_8x8(matrix):
    """
    Performs ZZ8 operation: 8x8 zig-zag reordering.
    Divides the image into multiple 8x8 sub-blocks and reorders each sub-block
    following a zig-zag scanning pattern that traverses diagonally from top-left to bottom-right.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with 8x8 sub-blocks reordered in zig-zag pattern
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Define the 8x8 zig-zag pattern (diagonal traversal)
    # Zig-zag pattern for 8x8 block: traverse diagonally from top-left to bottom-right
    zigzag_order = [
        (0, 0),  # 0
        (0, 1), (1, 0),  # 1, 2
        (2, 0), (1, 1), (0, 2),  # 3, 4, 5
        (0, 3), (1, 2), (2, 1), (3, 0),  # 6, 7, 8, 9
        (4, 0), (3, 1), (2, 2), (1, 3), (0, 4),  # 10, 11, 12, 13, 14
        (0, 5), (1, 4), (2, 3), (3, 2), (4, 1), (5, 0),  # 15, 16, 17, 18, 19, 20
        (6, 0), (5, 1), (4, 2), (3, 3), (2, 4), (1, 5), (0, 6),  # 21, 22, 23, 24, 25, 26, 27
        (0, 7), (1, 6), (2, 5), (3, 4), (4, 3), (5, 2), (6, 1), (7, 0),  # 28, 29, 30, 31, 32, 33, 34, 35
        (7, 1), (6, 2), (5, 3), (4, 4), (3, 5), (2, 6), (1, 7),  # 36, 37, 38, 39, 40, 41, 42
        (2, 7), (3, 6), (4, 5), (5, 4), (6, 3), (7, 2),  # 43, 44, 45, 46, 47, 48
        (7, 3), (6, 4), (5, 5), (4, 6), (3, 7),  # 49, 50, 51, 52, 53
        (4, 7), (5, 6), (6, 5), (7, 4),  # 54, 55, 56, 57
        (7, 5), (6, 6), (5, 7),  # 58, 59, 60
        (6, 7), (7, 6),  # 61, 62
        (7, 7)  # 63
    ]
    
    # Process each 8x8 sub-block
    for block_row in range(0, rows, 8):
        for block_col in range(0, cols, 8):
            # Extract the 8x8 sub-block
            sub_block = matrix[block_row:block_row+8, block_col:block_col+8]
            
            # Reorder according to zig-zag pattern
            for idx, (r, c) in enumerate(zigzag_order):
                result[block_row + idx // 8, block_col + idx % 8] = sub_block[r, c]
    
    return result


def morton_4x4(matrix):
    """
    Performs MO4 operation: 4x4 Morton order reordering.
    Divides the image into multiple 4x4 sub-blocks and reorders each sub-block
    following a Morton order pattern, which interleaves row and column indices
    to produce a recursive "Z"-shaped traversal.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with 4x4 sub-blocks reordered in Morton order pattern
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Define the 4x4 Morton order pattern (Z-shaped recursive traversal)
    # Morton order for 4x4 block: interleaves row and column indices
    morton_order = [
        (0, 0), (0, 1), (1, 0), (1, 1),  # top-left 2x2 quadrant
        (0, 2), (0, 3), (1, 2), (1, 3),  # top-right 2x2 quadrant  
        (2, 0), (2, 1), (3, 0), (3, 1),  # bottom-left 2x2 quadrant
        (2, 2), (2, 3), (3, 2), (3, 3)   # bottom-right 2x2 quadrant
    ]
    
    # Process each 4x4 sub-block
    for block_row in range(0, rows, 4):
        for block_col in range(0, cols, 4):
            # Extract the 4x4 sub-block
            sub_block = matrix[block_row:block_row+4, block_col:block_col+4]
            
            # Reorder according to Morton order pattern
            for idx, (r, c) in enumerate(morton_order):
                result[block_row + idx // 4, block_col + idx % 4] = sub_block[r, c]
    
    return result


def morton_8x8(matrix):
    """
    Performs MO8 operation: 8x8 Morton order reordering.
    Divides the image into multiple 8x8 sub-blocks and reorders each sub-block
    following a Morton order pattern (Z-order traversal), visiting pixels in a pattern
    that alternates between horizontal and vertical directions to form a fractal-like "Z" path.
    
    Args:
        matrix: 16x16 numpy array
        
    Returns:
        16x16 numpy array with 8x8 sub-blocks reordered in Morton order pattern
    """
    rows, cols = matrix.shape
    result = np.zeros_like(matrix)
    
    # Define the 8x8 Morton order pattern (Z-shaped recursive traversal)
    # Morton order for 8x8 block: recursive quadrant-based ordering
    morton_order = [
        # Top-left 4x4 quadrant (0-15)
        (0, 0), (0, 1), (1, 0), (1, 1),  # TL of TL
        (0, 2), (0, 3), (1, 2), (1, 3),  # TR of TL
        (2, 0), (2, 1), (3, 0), (3, 1),  # BL of TL
        (2, 2), (2, 3), (3, 2), (3, 3),  # BR of TL
        
        # Top-right 4x4 quadrant (16-31)
        (0, 4), (0, 5), (1, 4), (1, 5),  # TL of TR
        (0, 6), (0, 7), (1, 6), (1, 7),  # TR of TR
        (2, 4), (2, 5), (3, 4), (3, 5),  # BL of TR
        (2, 6), (2, 7), (3, 6), (3, 7),  # BR of TR
        
        # Bottom-left 4x4 quadrant (32-47)
        (4, 0), (4, 1), (5, 0), (5, 1),  # TL of BL
        (4, 2), (4, 3), (5, 2), (5, 3),  # TR of BL
        (6, 0), (6, 1), (7, 0), (7, 1),  # BL of BL
        (6, 2), (6, 3), (7, 2), (7, 3),  # BR of BL
        
        # Bottom-right 4x4 quadrant (48-63)
        (4, 4), (4, 5), (5, 4), (5, 5),  # TL of BR
        (4, 6), (4, 7), (5, 6), (5, 7),  # TR of BR
        (6, 4), (6, 5), (7, 4), (7, 5),  # BL of BR
        (6, 6), (6, 7), (7, 6), (7, 7)   # BR of BR
    ]
    
    # Process each 8x8 sub-block
    for block_row in range(0, rows, 8):
        for block_col in range(0, cols, 8):
            # Extract the 8x8 sub-block
            sub_block = matrix[block_row:block_row+8, block_col:block_col+8]
            
            # Reorder according to Morton order pattern
            for idx, (r, c) in enumerate(morton_order):
                result[block_row + idx // 8, block_col + idx % 8] = sub_block[r, c]
    
    return result


if __name__ == "__main__":
    # Test example with a simple 4x4 matrix to demonstrate the concept
    print("Testing MX, MY, TRP, STRP, R90, R180, R270, RS, LS, US, DS, ZZ4, ZZ8, MO4, and MO8 operations with a 4x4 example:")
    test_matrix = np.array([
        [0, 1, 2, 3],
        [4, 5, 6, 7],
        [8, 9, 10, 11],
        [12, 13, 14, 15]
    ])
    
    print("Original matrix:")
    print(test_matrix)
    
    if EN_MX:
        mx_result = mirror_x_axis(test_matrix)
        print("\nAfter MX operation (vertical flip):")
        print(mx_result)
    
    if EN_MY:
        my_result = mirror_y_axis(test_matrix)
        print("\nAfter MY operation (horizontal flip):")
        print(my_result)
    
    if EN_TRP:
        trp_result = transpose(test_matrix)
        print("\nAfter TRP operation (transpose):")
        print(trp_result)
    
    if EN_STRP:
        strp_result = secondary_transpose(test_matrix)
        print("\nAfter STRP operation (secondary transpose):")
        print(strp_result)
    
    if EN_R90:
        r90_result = rotate_90_clockwise(test_matrix)
        print("\nAfter R90 operation (90° clockwise rotation):")
        print(r90_result)
    
    if EN_R180:
        r180_result = rotate_180(test_matrix)
        print("\nAfter R180 operation (180° rotation):")
        print(r180_result)
    
    if EN_R270:
        r270_result = rotate_270_clockwise(test_matrix)
        print("\nAfter R270 operation (270° clockwise rotation):")
        print(r270_result)
    
    if EN_RS:
        rs_result = right_shift(test_matrix, 2)  # Use 2 pixels shift for 4x4 example
        print("\nAfter RS operation (right shift with mirror padding):")
        print(rs_result)
    
    if EN_LS:
        ls_result = left_shift(test_matrix, 2)  # Use 2 pixels shift for 4x4 example
        print("\nAfter LS operation (left shift with mirror padding):")
        print(ls_result)
    
    if EN_US:
        us_result = up_shift(test_matrix, 2)  # Use 2 pixels shift for 4x4 example
        print("\nAfter US operation (up shift with mirror padding):")
        print(us_result)
    
    if EN_DS:
        ds_result = down_shift(test_matrix, 2)  # Use 2 pixels shift for 4x4 example
        print("\nAfter DS operation (down shift with mirror padding):")
        print(ds_result)
    
    if EN_ZZ4:
        zz4_result = zigzag_4x4(test_matrix)
        print("\nAfter ZZ4 operation (4x4 zig-zag reordering):")
        print(zz4_result)
    
    if EN_ZZ8:
        # For 4x4 test matrix, ZZ8 won't apply (need 8x8), so create 8x8 test
        test_8x8 = np.arange(64).reshape(8, 8)
        print("\n8x8 test matrix for ZZ8:")
        print(test_8x8)
        zz8_result = zigzag_8x8(test_8x8)
        print("\nAfter ZZ8 operation (8x8 zig-zag reordering):")
        print(zz8_result)
    
    if EN_MO4:
        mo4_result = morton_4x4(test_matrix)
        print("\nAfter MO4 operation (4x4 Morton order reordering):")
        print(mo4_result)
    
    if EN_MO8:
        # For 4x4 test matrix, MO8 won't apply (need 8x8), so create 8x8 test
        test_8x8 = np.arange(64).reshape(8, 8)
        print("\n8x8 test matrix for MO8:")
        print(test_8x8)
        mo8_result = morton_8x8(test_8x8)
        print("\nAfter MO8 operation (8x8 Morton order reordering):")
        print(mo8_result)
    
    # Test with a 16x16 matrix
    print("\n" + "="*50)
    print("Testing with 16x16 matrix:")
    matrix_16x16 = np.arange(256).reshape(16, 16)
    
    print("Original 16x16 matrix:")
    print(matrix_16x16)


    # op1: MX
    if EN_MX:
        mx_result_16x16 = mirror_x_axis(matrix_16x16)
        print("\nAfter MX operation")
        print(mx_result_16x16)
        
    
    # op2: MY
    if EN_MY:
        my_result_16x16 = mirror_y_axis(matrix_16x16)
        print("\nAfter MY operation")
        print(my_result_16x16)
    
    # op3: TRP
    if EN_TRP:
        trp_result_16x16 = transpose(matrix_16x16)
        print("\nAfter TRP operation")
        print(trp_result_16x16)
    
    # op4: STRP
    if EN_STRP:
        strp_result_16x16 = secondary_transpose(matrix_16x16)
        print("\nAfter STRP operation")
        print(strp_result_16x16)
    
    # op5: R90
    if EN_R90:
        r90_result_16x16 = rotate_90_clockwise(matrix_16x16)
        print("\nAfter R90 operation")
        print(r90_result_16x16)
    
    # op6: R180
    if EN_R180:
        r180_result_16x16 = rotate_180(matrix_16x16)
        print("\nAfter R180 operation")
        print(r180_result_16x16)
    
    # op7: R270
    if EN_R270:
        r270_result_16x16 = rotate_270_clockwise(matrix_16x16)
        print("\nAfter R270 operation")
        print(r270_result_16x16)
    
    # op8: RS
    if EN_RS:
        rs_result_16x16 = right_shift(matrix_16x16, 5)  # Default 5 pixels shift
        print("\nAfter RS operation (right shift 5 pixels with mirror padding)")
        print(rs_result_16x16)
    
    # op9: LS
    if EN_LS:
        ls_result_16x16 = left_shift(matrix_16x16, 5)  # Default 5 pixels shift
        print("\nAfter LS operation (left shift 5 pixels with mirror padding)")
        print(ls_result_16x16)
    
    # op10: US
    if EN_US:
        us_result_16x16 = up_shift(matrix_16x16, 5)  # Default 5 pixels shift
        print("\nAfter US operation (up shift 5 pixels with mirror padding)")
        print(us_result_16x16)
    
    # op11: DS
    if EN_DS:
        ds_result_16x16 = down_shift(matrix_16x16, 5)  # Default 5 pixels shift
        print("\nAfter DS operation (down shift 5 pixels with mirror padding)")
        print(ds_result_16x16)
    
    # op12: ZZ4
    if EN_ZZ4:
        zz4_result_16x16 = zigzag_4x4(matrix_16x16)
        print("\nAfter ZZ4 operation (4x4 zig-zag reordering)")
        print(zz4_result_16x16)
    
    # op13: ZZ8
    if EN_ZZ8:
        zz8_result_16x16 = zigzag_8x8(matrix_16x16)
        print("\nAfter ZZ8 operation (8x8 zig-zag reordering)")
        print(zz8_result_16x16)
    
    # op14: MO4
    if EN_MO4:
        mo4_result_16x16 = morton_4x4(matrix_16x16)
        print("\nAfter MO4 operation (4x4 Morton order reordering)")
        print(mo4_result_16x16)
    
    # op15: MO8
    if EN_MO8:
        mo8_result_16x16 = morton_8x8(matrix_16x16)
        print("\nAfter MO8 operation (8x8 Morton order reordering)")
        print(mo8_result_16x16)

