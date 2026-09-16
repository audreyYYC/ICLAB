import numpy as np
from config import DEBUG

def generate_matrix_128x128():
    """
    Generate a 128x128 numpy matrix with random integer values ranging from 0 to 255.
    
    Returns:
        numpy.ndarray: A 128x128 matrix with values in the range [0, 255]
    """
    return np.random.randint(0, 256, size=(128, 128), dtype=np.uint8)

def get_matrix_13x13(img_mat, x, y):
    """
    Extract a 13x13 matrix from a 128x128 image matrix with edge replication.
    
    Args:
        img_mat (numpy.ndarray): Input 128x128 image matrix
        x (int): X coordinate (reference point)
        y (int): Y coordinate (reference point)
    
    Returns:
        numpy.ndarray: A 13x13 matrix starting from (x-2, y-2) as top-left corner
                      with edge replication for out-of-bounds coordinates
    """
    # Initialize 13x13 output matrix
    result = np.zeros((13, 13), dtype=img_mat.dtype)
    
    # Calculate starting coordinates (x-2, y-2)
    start_x = x - 2
    start_y = y - 2
    
    # Fill the 13x13 matrix
    for i in range(13):
        for j in range(13):
            # Calculate current coordinates in the original image
            curr_y = start_y + i
            curr_x = start_x + j
            
            
            # Apply edge replication (clamp coordinates to [0, 127])
            clamped_x = max(0, min(127, curr_x))
            clamped_y = max(0, min(127, curr_y))
            
            # Copy the value from the original image
            # result[i, j] = img_mat[clamped_x, clamped_y]
            result[i, j] = img_mat[clamped_y, clamped_x]
    
    return result 


def compute_BI_8x8(mat_13x13, mode):
    """
    Computes the 8x8 BI output from a 13x13 input matrix using a 6-tap FIR filter.
    Modified to clip output between -255 and 255.
    
    Parameters:
    - mat_13x13: 13x13 numpy array
    - mode: int (0: No Interp, 1: Horizontal, 2: Vertical, 3: 2D Separable)
    
    Returns:
    - 8x8 numpy array (int16)
    """
    
    if mat_13x13.shape != (13, 13):
        raise ValueError("Input matrix must be 13x13.")
        
    src = mat_13x13.astype(np.int32)
    output = np.zeros((8, 8), dtype=np.int32)
    
    # Filter Formula: Val = (P_-2 - 5*P_-1 + 20*P_0 + 20*P_1 - 5*P_2 + P_3)
    def apply_6tap(p):
        return (1*p[0] - 5*p[1] + 20*p[2] + 20*p[3] - 5*p[4] + 1*p[5])

    # MODIFIED: Clip to range [-255, 255]
    def clip_val(val):
        # return np.clip(val, -256, 255)
        return np.clip(val, 0, 255)

    row_offset = 2
    col_offset = 2

    # --- Mode 0: No Interpolation ---
    if mode == 0:
        for r in range(8):
            for c in range(8):
                output[r, c] = src[row_offset + r, col_offset + c]
    
    # --- Mode 1: Horizontal Interpolation Only ---
    elif mode == 1:
        for r in range(8):
            for c in range(8):
                curr_r = row_offset + r
                curr_c = col_offset + c
                pixels = src[curr_r, curr_c-2 : curr_c+4]
                val = apply_6tap(pixels)
                output[r, c] = clip_val((val + 16) >> 5)

    # --- Mode 2: Vertical Interpolation Only ---
    elif mode == 2:
        for r in range(8):
            for c in range(8):
                curr_r = row_offset + r
                curr_c = col_offset + c
                pixels = src[curr_r-2 : curr_r+4, curr_c]
                val = apply_6tap(pixels)
                output[r, c] = clip_val((val + 16) >> 5)

    # --- Mode 3: 2D Separable Interpolation ---
    elif mode == 3:
        # Step 1: Horizontal Filter (Intermediate) - Do NOT clip here
        temp_h = np.zeros((13, 8), dtype=np.int32)
        for r in range(13):
            for c in range(8):
                curr_c = col_offset + c
                pixels = src[r, curr_c-2 : curr_c+4]
                temp_h[r, c] = apply_6tap(pixels)

        # Step 2: Vertical Filter on Intermediate Results
        for r in range(8):
            for c in range(8):
                curr_r = row_offset + r 
                pixels = temp_h[curr_r-2 : curr_r+4, c]
                val = apply_6tap(pixels)
                
                # Step 3: Normalize and Clip
                output[r, c] = clip_val((val + 512) >> 10)

    return output


def get_13x13_and_compute_BI_8x8(img_mat, x, y, mode):
    """
    Extract a 13x13 matrix from a 128x128 image matrix and compute the 8x8 BI output.
    
    Args:
        img_mat (numpy.ndarray): Input 128x128 image matrix
        x (int): X coordinate of the pixel
        y (int): Y coordinate of the pixel
        mode (int): Interpolation mode (0: No Interp, 1: Horizontal, 2: Vertical, 3: 2D Separable)
    
    Returns:
        numpy.ndarray: Computed 8x8 BI output
    """
    # Ensure input is a 128x128 matrix
    if img_mat.shape != (128, 128):
        raise ValueError("Input matrix must be 128x128.")
    
    # Extract the 13x13 matrix centered at (x, y)
    mat_13x13 = get_matrix_13x13(img_mat, x, y)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write(f"Extracted 13x13 matrix at ({y}, {x}):\n")
            f.write(f"{mat_13x13}\n")
            f.write("\n")
    
    # Compute the 8x8 BI output using the specified mode
    return compute_BI_8x8(mat_13x13, mode)

def calculate_satd_8x8(L0_8x8, L1_8x8):
    """
    Calculate Sum of Absolute Transformed Differences (SATD) between two 8x8 blocks.
    
    Steps:
    1. Calculate residual: D = L0 - L1
    2. Divide 8x8 difference block into four 4x4 sub-blocks
    3. Apply Hadamard transform to each 4x4 sub-block: Y = H × D4x4 × H^T
    4. Sum absolute values of all coefficients in each transformed block
    5. Return total cost (sum of all four 4x4 SATDs)
    
    Args:
        L0_8x8 (numpy.ndarray): First 8x8 block (int32)
        L1_8x8 (numpy.ndarray): Second 8x8 block (int32)
    
    Returns:
        int: Total SATD cost
    """
    # Ensure input matrices are the correct shape and type
    L0 = np.array(L0_8x8, dtype=np.int32)
    L1 = np.array(L1_8x8, dtype=np.int32)
    
    if L0.shape != (8, 8) or L1.shape != (8, 8):
        raise ValueError("Both input matrices must be 8x8")
    
    # Step 1: Calculate residual D = L0 - L1
    D = L0 - L1
    
    # 4x4 Hadamard matrix (consisting of 1 and -1)
    H = np.array([
        [ 1,  1,  1,  1],
        [ 1, -1,  1, -1],
        [ 1,  1, -1, -1],
        [ 1, -1, -1,  1]
    ], dtype=np.int32)
    
    total_satd = 0
    
    # Step 2: Divide 8x8 difference block into four 4x4 sub-blocks
    # Step 3: Apply Hadamard transform and Step 4: Sum absolute values
    for i in range(2):  # 2x2 grid of 4x4 blocks
        for j in range(2):
            # Extract 4x4 sub-block
            start_row = i * 4
            start_col = j * 4
            D_4x4 = D[start_row:start_row+4, start_col:start_col+4]
            
            # Apply Hadamard transform: Y = H × D4x4 × H^T
            Y = H @ D_4x4 @ H.T
            
            # Sum absolute values of all coefficients
            satd_4x4 = np.sum(np.abs(Y))
            total_satd += satd_4x4
    
    # Step 5: Return total cost
    return total_satd

def calculate_satd_8x8_v2(L0_8x8, L1_8x8):
    """
    Calculates the SATD (Sum of Absolute Transformed Differences) for 8x8 blocks
    based on the provided algorithm steps.
    """
    # Step 1: Residual
    # Calculate difference block D = L0 - L1
    # We cast to int32 to ensure negative differences are preserved correctly
    D = L0_8x8.astype(np.int32) - L1_8x8.astype(np.int32)

    # Define the 4x4 Hadamard matrix H (consisting of 1 and -1)
    # Standard construction
    H = np.array([
        [1,  1,  1,  1],
        [1, -1,  1, -1],
        [1,  1, -1, -1],
        [1, -1, -1,  1]
    ], dtype=np.int32)

    total_satd = 0

    # Step 2: 4x4 Partition
    # We iterate over the 8x8 block to extract four 4x4 sub-blocks.
    # The offsets for the top-left corners of the 4x4 blocks are (0,0), (0,4), (4,0), and (4,4).
    for row_offset in [0, 4]:
        for col_offset in [0, 4]:
            # Extract the 4x4 sub-block
            D_4x4 = D[row_offset : row_offset+4, col_offset : col_offset+4]

            # Step 3: Hadamard Transform
            # Formula: Y = H * D_4x4 * H^T
            # We use the @ operator for matrix multiplication
            Y = H @ D_4x4 @ H.T

            # Step 4: Summation
            # Sum the absolute values of all coefficients in Y
            satd_4x4 = np.sum(np.abs(Y))

            # Step 5: Total Cost
            # Accumulate the SATD of the current sub-block into the total
            total_satd += satd_4x4

    return total_satd


def compute_mirror_MVD(img_mat_L0, img_mat_L1, L0_x, L0_y, L0_mode, L1_x, L1_y, L1_mode):
    """
    Computes the mirrored motion vector difference (MVD) for a given pixel in a 128x128 image matrix.
    
    Args:
        img_mat_L0 (numpy.ndarray): Input 128x128 image matrix for L0 reference
        img_mat_L1 (numpy.ndarray): Input 128x128 image matrix for L1 reference
        L0_x (int): X coordinate of the pixel (L0 reference)
        L0_y (int): Y coordinate of the pixel (L0 reference)
        L0_mode (int): Interpolation mode for L0 (0: No Interp, 1: Horizontal, 2: Vertical, 3: 2D Separable)
        L1_x (int): X coordinate of the pixel (L1 reference)
        L1_y (int): Y coordinate of the pixel (L1 reference)
        L1_mode (int): Interpolation mode for L1 (0: No Interp, 1: Horizontal, 2: Vertical, 3: 2D Separable)
    
    Returns:
        tuple: (best_search_point, min_satd) - search point index with the smallest SATD value and its SATD
    """
    # Ensure input is a 128x128 matrix
    if img_mat_L0.shape != (128, 128):
        raise ValueError("Input matrix must be 128x128.")
    
    if img_mat_L1.shape != (128, 128):
        raise ValueError("Input matrix must be 128x128.")
    
    # search pt 0: L0(0,0) -> L1(2,2)
    L0_BI_8x8_pt0 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x, L0_y, L0_mode)
    L1_BI_8x8_pt0 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 2, L1_y + 2, L1_mode)
    satd_pt0 = calculate_satd_8x8(L0_BI_8x8_pt0, L1_BI_8x8_pt0)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write("search point0 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt0}\n")
            f.write("\n")
            f.write("search point0 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt0}\n")
            f.write("\n")
            f.write(f"    Search Point 0: SATD={satd_pt0}\n")

    # search pt 1: L0(0,1) -> L1(2,1)
    L0_BI_8x8_pt1 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x, L0_y + 1, L0_mode)
    L1_BI_8x8_pt1 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 2, L1_y + 1, L1_mode)
    satd_pt1 = calculate_satd_8x8(L0_BI_8x8_pt1, L1_BI_8x8_pt1)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write("search point1 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt1}\n")
            f.write("\n")
            f.write("search point1 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt1}\n")
            f.write("\n")
            f.write(f"    Search Point 1: SATD={satd_pt1}\n")

    # search pt 2: L0(0,2) -> L1(2,0)
    L0_BI_8x8_pt2 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x, L0_y + 2, L0_mode)
    L1_BI_8x8_pt2 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 2, L1_y, L1_mode)
    satd_pt2 = calculate_satd_8x8(L0_BI_8x8_pt2, L1_BI_8x8_pt2)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write("search point2 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt2}\n")
            f.write("\n")
            f.write("search point2 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt2}\n")
            f.write("\n")
            f.write(f"    Search Point 2: SATD={satd_pt2}\n")

    # search pt 3: L0(1,0) -> L1(1,2)
    L0_BI_8x8_pt3 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 1, L0_y, L0_mode)
    L1_BI_8x8_pt3 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 1, L1_y + 2, L1_mode)
    satd_pt3 = calculate_satd_8x8(L0_BI_8x8_pt3, L1_BI_8x8_pt3)

    if DEBUG:
        with open("debug.txt", 'a') as f:        
            f.write("search point3 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt3}\n")
            f.write("\n")
            f.write("search point3 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt3}\n")
            f.write("\n")
            f.write(f"    Search Point 3: SATD={satd_pt3}\n")

    # search pt 4: L0(1,1) -> L1(1,1) (Center)
    L0_BI_8x8_pt4 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 1, L0_y + 1, L0_mode)
    L1_BI_8x8_pt4 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 1, L1_y + 1, L1_mode)
    satd_pt4 = calculate_satd_8x8(L0_BI_8x8_pt4, L1_BI_8x8_pt4)

    if DEBUG:
        with open("debug.txt", 'a') as f:        
            f.write("search point4 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt4}\n")
            f.write("\n")
            f.write("search point4 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt4}\n")
            f.write("\n")
            f.write(f"    Search Point 4: SATD={satd_pt4}\n")

    # search pt 5: L0(1,2) -> L1(1,0)
    L0_BI_8x8_pt5 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 1, L0_y + 2, L0_mode)
    L1_BI_8x8_pt5 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x + 1, L1_y, L1_mode)
    satd_pt5 = calculate_satd_8x8(L0_BI_8x8_pt5, L1_BI_8x8_pt5)

    if DEBUG:
        with open("debug.txt", 'a') as f:        
            f.write("search point5 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt5}\n")
            f.write("\n")
            f.write("search point5 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt5}\n")
            f.write("\n")
            f.write(f"    Search Point 5: SATD={satd_pt5}\n")

    # search pt 6: L0(2,0) -> L1(0,2)
    L0_BI_8x8_pt6 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 2, L0_y, L0_mode)
    L1_BI_8x8_pt6 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x, L1_y + 2, L1_mode)
    satd_pt6 = calculate_satd_8x8(L0_BI_8x8_pt6, L1_BI_8x8_pt6)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write("search point6 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt6}\n")
            f.write("\n")
            f.write("search point6 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt6}\n")
            f.write("\n")
            f.write(f"    Search Point 6: SATD={satd_pt6}\n")

    # search pt 7: L0(2,1) -> L1(0,1)
    L0_BI_8x8_pt7 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 2, L0_y + 1, L0_mode)
    L1_BI_8x8_pt7 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x, L1_y + 1, L1_mode)
    satd_pt7 = calculate_satd_8x8(L0_BI_8x8_pt7, L1_BI_8x8_pt7)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            f.write("search point7 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt7}\n")
            f.write("\n")
            f.write("search point7 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt7}\n")
            f.write("\n")
            f.write(f"    Search Point 7: SATD={satd_pt7}\n")

    # search pt 8: L0(2,2) -> L1(0,0)
    L0_BI_8x8_pt8 = get_13x13_and_compute_BI_8x8(img_mat_L0, L0_x + 2, L0_y + 2, L0_mode)
    L1_BI_8x8_pt8 = get_13x13_and_compute_BI_8x8(img_mat_L1, L1_x, L1_y, L1_mode)
    satd_pt8 = calculate_satd_8x8(L0_BI_8x8_pt8, L1_BI_8x8_pt8)

    if DEBUG:         
        with open("debug.txt", 'a') as f:
            f.write("search point8 L0_BI_8x8:\n")
            f.write(f"{L0_BI_8x8_pt8}\n")
            f.write("\n")
            f.write("search point8 L1_BI_8x8:\n")
            f.write(f"{L1_BI_8x8_pt8}\n")
            f.write("\n")
            f.write(f"    Search Point 8: SATD={satd_pt8}\n")
            f.write("\n")

    # Collect all SATD values
    satd_list = [
        satd_pt0, satd_pt1, satd_pt2, 
        satd_pt3, satd_pt4, satd_pt5, 
        satd_pt6, satd_pt7, satd_pt8
    ]

    # Find the minimum SATD and its index
    min_satd = min(satd_list)
    best_search_point = satd_list.index(min_satd)

    if DEBUG:
        with open("debug.txt", 'a') as f:
            satd_list_str = [int(x) for x in satd_list]
            f.write(f"\nSearch Point SATD List: {satd_list_str}\n")
            f.write(f"\nBest Search Point: {best_search_point} with SATD={int(min_satd)}\n")
            f.write("\n--------------------------------------------------\n")

    return (best_search_point, min_satd)

# --- Example Usage ---
if __name__ == "__main__":
    # Create a dummy 13x13 matrix with random values [0, 255]
    input_data = np.random.randint(0, 256, (13, 13), dtype=np.uint8)

    print("Input 13x13 Matrix:")
    print(input_data)   
    
    # Compute for Mode 3 (2D Separable)
    result = compute_BI_8x8(input_data, mode=3)
    print("\nComputed 8x8 BI Output (Mode 3 - 2D Separable):")
    print(result)
    
    print("Input Shape:", input_data.shape)
    print("Output Shape:", result.shape)
    print("Top-left output pixel:", result[0,0])
    
    # Test SATD function
    print("\n--- Testing SATD Function ---")
    
    # Create two sample 8x8 matrices
    L0 = np.random.randint(0, 256, (8, 8), dtype=np.int32)
    L1 = np.random.randint(0, 256, (8, 8), dtype=np.int32)
    
    print("L0 (8x8 matrix):")
    print(L0)
    print("\nL1 (8x8 matrix):")
    print(L1)
    
    # Calculate SATD
    satd_cost = calculate_satd_8x8_v2(L0, L1)
    print(f"\nSATD Cost: {satd_cost}")

    satd_cost = calculate_satd_8x8(L0, L1)
    print(f"SATD Cost: {satd_cost}")
    
    # Test with identical matrices (should give SATD = 0)
    satd_identical = calculate_satd_8x8_v2(L0, L0)
    print(f"SATD for identical matrices: {satd_identical}")

    satd_identical = calculate_satd_8x8(L0, L0)
    print(f"SATD for identical matrices: {satd_identical}")

    # Test get_13x13_and_compute_BI_8x8 function
    print("\n--- Testing get_13x13_and_compute_BI_8x8 Function ---")
    
    # Create a 128x128 test image
    test_img_128x128 = generate_matrix_128x128()
    print(f"Generated 128x128 test image with shape: {test_img_128x128.shape}")
    
    # Test coordinates
    test_x, test_y = 64, 64
    print(f"Testing at coordinates: ({test_x}, {test_y})")
    
    # Test all interpolation modes
    modes = [0, 1, 2, 3]
    mode_names = ["No Interpolation", "Horizontal", "Vertical", "2D Separable"]
    
    for mode, mode_name in zip(modes, mode_names):
        result_8x8 = get_13x13_and_compute_BI_8x8(test_img_128x128, test_x, test_y, mode)
        print(f"\nMode {mode} ({mode_name}):")
        print(f"  Output shape: {result_8x8.shape}")
        print(f"  Output dtype: {result_8x8.dtype}")
        print(f"  Output range: [{result_8x8.min()}, {result_8x8.max()}]")
        print(f"  Top-left 3x3 region:")
        print(result_8x8[:3, :3])
    
    # Test edge cases
    print("\n--- Edge Case Tests ---")
    
    # Test near boundary coordinates
    edge_coords = [(2, 2), (125, 125), (0, 0), (127, 127)]
    
    for x_coord, y_coord in edge_coords:
        try:
            result_edge = get_13x13_and_compute_BI_8x8(test_img_128x128, x_coord, y_coord, 3)
            print(f"  Coordinates ({x_coord}, {y_coord}): Success - Shape {result_edge.shape}")
        except Exception as e:
            print(f"  Coordinates ({x_coord}, {y_coord}): Error - {e}")

    # Test compute_mirror_MVD function
    print("\n--- Testing compute_mirror_MVD Function ---")
    
    # Create two different 128x128 test images for L0 and L1
    test_img_L0 = generate_matrix_128x128()
    test_img_L1 = generate_matrix_128x128()
    print(f"Generated L0 image with shape: {test_img_L0.shape}")
    print(f"Generated L1 image with shape: {test_img_L1.shape}")
    
    # Test with coordinates that allow for full 3x3 search (away from edges)
    test_coords = [(10, 10), (64, 64), (100, 100)]
    
    for test_x, test_y in test_coords:
        try:
            # Test with same coordinates for both L0 and L1, same modes
            best_search_point, min_satd = compute_mirror_MVD(test_img_L0, test_img_L1, test_x, test_y, 3, test_x, test_y, 3)
            print(f"  Coordinates L0=L1=({test_x}, {test_y}), modes L0=L1=3:")
            print(f"    Minimum SATD: {min_satd}")
            print(f"    Best search point: {best_search_point}")
            
        except Exception as e:
            print(f"  Coordinates ({test_x}, {test_y}): Error - {e}")

    # Test with different modes for L0 and L1
    print("\n  Testing with different interpolation modes:")
    try:
        best_search_point, min_satd = compute_mirror_MVD(test_img_L0, test_img_L1, 50, 50, 0, 50, 50, 3)
        print(f"    L0 mode=0, L1 mode=3 at (50,50): SATD: {min_satd}, Best point: {best_search_point}")
    except Exception as e:
        print(f"    Different modes test: Error - {e}")

    # Test edge cases for compute_mirror_MVD
    print("\n  Edge Case Tests for compute_mirror_MVD:")
    edge_coords_mvd = [(2, 2), (124, 124)]  # Coordinates that might be near boundaries
    
    for test_x, test_y in edge_coords_mvd:
        try:
            best_search_point, min_satd = compute_mirror_MVD(test_img_L0, test_img_L1, test_x, test_y, 3, test_x, test_y, 3)
            print(f"    Coordinates ({test_x}, {test_y}): Success - SATD: {min_satd}, Best point: {best_search_point}")
        except Exception as e:
            print(f"    Coordinates ({test_x}, {test_y}): Error - {e}")
    
    # Test with identical images (should give minimum SATD at center point)
    print("\n  Testing with identical L0 and L1 images:")
    test_coords_identical = [(50, 50), (80, 80)]
    
    for test_x, test_y in test_coords_identical:
        try:
            best_search_point, min_satd = compute_mirror_MVD(test_img_L0, test_img_L0, test_x, test_y, 3, test_x, test_y, 3)
            print(f"    Identical images at ({test_x}, {test_y}): SATD: {min_satd}, Best point: {best_search_point}")
            # Should be point 4 (center) with SATD = 0
        except Exception as e:
            print(f"    Identical images at ({test_x}, {test_y}): Error - {e}")
    
    # Test with offset L1 coordinates
    print("\n  Testing with offset L1 coordinates:")
    try:
        best_search_point, min_satd = compute_mirror_MVD(test_img_L0, test_img_L1, 60, 60, 3, 65, 65, 3)
        print(f"    L0 at (60,60), L1 at (65,65): SATD: {min_satd}, Best point: {best_search_point}")
    except Exception as e:
        print(f"    Offset coordinates test: Error - {e}")


# # Example usage:
# if __name__ == "__main__":
#     # Generate matrix with random integers 0-255
#     matrix_int = generate_matrix_128x128()
#     print(f"Integer matrix shape: {matrix_int.shape}")
#     print(f"Integer matrix dtype: {matrix_int.dtype}")
#     print(f"Integer matrix min/max: {matrix_int.min()}/{matrix_int.max()}")

#     # Pretty write the 128x128 matrix to a file with x,y indexes
#     with open('matrix_128x128_pretty.txt', 'w') as f:
#         # Write column headers (x-axis)
#         f.write("     ")  # Space for row index
#         for x in range(128):
#             f.write(f"{x:4d}")
#         f.write("\n")
        
#         # Write each row with row index (y-axis) and values
#         for y in range(128):
#             f.write(f"{y:3d}: ")  # Row index
#             for x in range(128):
#                 f.write(f"{matrix_int[y, x]:4d}")
#             f.write("\n")
#     print("Pretty formatted matrix saved to 'matrix_128x128_pretty.txt'")
    
#     # Test get_matrix_13x13 function
#     print("\n--- Testing get_matrix_13x13 ---")
    
#     # Test case 1: Normal case (center of image)
#     sub_matrix = get_matrix_13x13(matrix_int, 64, 64)
#     print(f"13x13 matrix at (64, 64) shape: {sub_matrix.shape}")
#     print(sub_matrix)
    
#     # Test case 2: Edge case (near boundary)
#     sub_matrix_edge = get_matrix_13x13(matrix_int, 1, 1)
#     print(f"13x13 matrix at (1, 1) shape: {sub_matrix_edge.shape}")
#     print(sub_matrix_edge)
    
#     # Test case 3: Corner case (at corner)
#     sub_matrix_corner = get_matrix_13x13(matrix_int, 0, 0)
#     print(f"13x13 matrix at (0, 0) shape: {sub_matrix_corner.shape}")
#     print(sub_matrix_corner)
    
#     # Test case 4: Near opposite corner
#     sub_matrix_far = get_matrix_13x13(matrix_int, 126, 126)
#     print(f"13x13 matrix at (126, 126) shape: {sub_matrix_far.shape}")
#     print(sub_matrix_far)
