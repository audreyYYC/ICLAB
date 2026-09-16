import numpy as np
from algorithms import *
from config import DEBUG
PAT_NUM = 1000
SEED = 42

def generate_images():
    """
    Generate 128 random 16x16 matrices with values in range [0,255].
    
    Returns:
    - matrice_set: numpy array of shape (128, 16, 16) with dtype np.uint8
    """
    
    # Set random seed for reproducible results
    if SEED is not None:
        np.random.seed(SEED)
    
    # Generate 128 16x16 matrices with values in range [0,255]
    matrice_images = np.random.randint(0, 256, size=(128, 16, 16), dtype=np.uint8)
    # matrice_images[0] = np.arange(256).reshape(16, 16)
    
    return matrice_images

def generate_cmd(pat_idx):
    # Set seed for deterministic command generation with different seed per pattern
    if SEED is not None:
        np.random.seed(SEED + pat_idx)
    # Generate random source and destination indices from 0-127
    ms_idx = np.random.randint(0, 128)
    # ms_idx = 0
    md_idx = np.random.randint(0, 128)
    
    # Generate random code from [0,6] or [8,15]
    # Randomly choose between the two ranges
    if np.random.choice([True, False]):
        code = np.random.randint(0, 7)  # [0,6]
    else:
        code = np.random.randint(8, 16)  # [8,15]
    # code = 15
    
    return code, ms_idx, md_idx

def process_cmd(pat_idx, code, ms_idx, md_idx, matrice_images):
    if DEBUG:
        with open("debug.txt", "a") as f:
            f.write(f"Processing command: pat_idx={pat_idx}, code={code}, ms_idx={ms_idx}, md_idx={md_idx}\n")
            f.write("\n")
    
    # Get source and destination images
    img_ms = matrice_images[ms_idx]

    if DEBUG:
        with open("debug.txt", "a") as f:
            f.write(f"Source image (img_ms):\n{matrice_images[ms_idx]}\n")
            f.write("\n")

    # Process based on code
    if code == 0:
        img_processed = mirror_x_axis(img_ms)
    elif code == 1:
        img_processed = mirror_y_axis(img_ms)
    elif code == 2:
        img_processed = transpose(img_ms)
    elif code == 3:
        img_processed = secondary_transpose(img_ms)
    elif code == 4:
        img_processed = rotate_90_clockwise(img_ms)
    elif code == 5:
        img_processed = rotate_180(img_ms)
    elif code == 6:
        img_processed = rotate_270_clockwise(img_ms)
    elif code == 8:
        img_processed = right_shift(img_ms)
    elif code == 9:
        img_processed = left_shift(img_ms)
    elif code == 10:
        img_processed = up_shift(img_ms)
    elif code == 11:
        img_processed = down_shift(img_ms)
    elif code == 12:
        img_processed = zigzag_4x4(img_ms)
    elif code == 13:
        img_processed = zigzag_8x8(img_ms)
    elif code == 14:
        img_processed = morton_4x4(img_ms)
    elif code == 15:
        img_processed = morton_8x8(img_ms)
    else:
        # Handle unexpected code values
        raise ValueError(f"Invalid code: {code}")

    matrice_images[md_idx] = img_processed

    if DEBUG:
        with open("debug.txt", "a") as f:
            f.write(f"Processed image (img_md):\n{matrice_images[md_idx]}\n")
            # f.write("Processed image (img_md) in hex:\n")
            # processed_matrix = matrice_images[md_idx]
            # for row in range(16):
            #     hex_row = ' '.join([f'{processed_matrix[row, col]:02x}' for col in range(16)])
            #     f.write(f"{hex_row}\n")
            # f.write("\n")
            
            f.write("-" * 70 + "\n")

def generate_pattern():
    # Generate the matrice_images
    matrice_images = generate_images()

    # Print the 16x16 index 79 matrix
    print("16x16 matrix at index 79:")
    idx = 102
    matrix_79 = matrice_images[idx]
    for row in range(16):
        hex_row = ' '.join([f'{matrix_79[row, col]:02x}' for col in range(16)])
        print(hex_row)
    print(matrice_images[idx])

    # write to images.txt
    with open("images.txt", "a") as f:
        for matrix_idx in range(128):
            matrix = matrice_images[matrix_idx]
            # Write each element in raster scan order (row by row)
            for row in range(16):
                for col in range(16):
                    f.write(f"{matrix[row, col]}\n")

    for pat_idx in range(PAT_NUM):
        code, ms_idx, md_idx = generate_cmd(pat_idx)
        with open("cmds.txt", "a") as f:
            f.write(f"{code}\n")
            f.write(f"{ms_idx}\n")
            f.write(f"{md_idx}\n")
        
        process_cmd(pat_idx, code, ms_idx, md_idx, matrice_images)
        
        with open("image_output.txt", "a") as f:
            for row in range(16):
                for col in range(16):
                    f.write(f"{matrice_images[md_idx][row, col]}\n")

    


if __name__ == "__main__":
    with open("images.txt", "w") as f:
        pass

    with open("cmds.txt", "w") as f:
        f.write(f"{PAT_NUM}\n")

    with open("image_output.txt", "w") as f:
        pass

    if DEBUG:
        with open("debug.txt", "w") as f:
            pass

    generate_pattern()