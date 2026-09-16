PAT_NUM = 10
from config import DEBUG

from algorithms import *

def write_matrix_pretty(matrix, filename='matrix_128x128_pretty.txt'):
    """Pretty write the 128x128 matrix to a file with x,y indexes"""
    with open(filename, 'a') as f:
        # Write column headers (x-axis)
        f.write("     ")  # Space for row index
        for x in range(128):
            f.write(f"{x:4d}")
        f.write("\n")
        
        # Write each row with row index (y-axis) and values
        for y in range(128):
            f.write(f"{y:3d}: ")  # Row index
            for x in range(128):
                f.write(f"{matrix[y, x]:4d}")
            f.write("\n")
    print(f"Pretty formatted matrix saved to '{filename}'")

if __name__ == "__main__":
    # Set random seed for reproducibility
    np.random.seed(40)
    with open("matrices.txt", "w") as f:
        f.write(f"{PAT_NUM}\n")
    with open("set_input.txt", "w") as f:
        pass
    with open("set_output.txt", "w") as f:
        pass
    if DEBUG:
        with open("debug_matrice.txt", "w") as f:
            pass
        with open("debug.txt", "w") as f:
            pass
    
    


    for pat_id in range(PAT_NUM):
        print(f"Pattern ID: {pat_id}")
        
         # Generate img data
        L0_mat = generate_matrix_128x128()
        L1_mat = generate_matrix_128x128()

        if DEBUG:
            with open("debug_matrice.txt", 'a') as f:
                f.write("======================== L0 matrice: =============================\n")
            write_matrix_pretty(L0_mat, f'debug_matrice.txt')
            with open("debug_matrice.txt", 'a') as f:
                f.write("======================== L1 matrice: =============================\n")
            write_matrix_pretty(L1_mat, f'debug_matrice.txt')

        # print(L0_mat)
        # print(L1_mat)
        # write to matrices.txt
        # print("Writing matrices to matrices.txt in raster scan order...")
        with open("matrices.txt", "a") as f:
            # Write each element in raster scan order (row by row)
            for row in range(128):
                for col in range(128):
                    f.write(f"{L0_mat[row, col]}\n")
            for row in range(128):
                for col in range(128):
                    f.write(f"{L1_mat[row, col]}\n")

        # Generate test coordinates
        for set_id in range(64):
            if DEBUG:
                with open("debug.txt", 'a') as f:
                    f.write(f"\n======================== Pattern ID: {pat_id}, Set ID: {set_id} ============================\n")

            pt1_L0_MVx = np.random.randint(0, 117)
            pt1_L0_frac_x = np.random.randint(0, 2)
            pt1_L0_MVy = np.random.randint(0, 117)
            pt1_L0_frac_y = np.random.randint(0, 2)
            pt1_L1_MVx = np.random.randint(0, 117)
            pt1_L1_frac_x = np.random.randint(0, 2)
            pt1_L1_MVy = np.random.randint(0, 117)
            pt1_L1_frac_y = np.random.randint(0, 2)
            #pt1_L0_frac_x = 1
            #pt1_L0_frac_y = 0
            #pt1_L1_frac_x = 1
            #pt1_L1_frac_y = 0

            pt1_L0_mode = 3 if pt1_L0_frac_y and pt1_L0_frac_x else 2 if pt1_L0_frac_y and not pt1_L0_frac_x else 1 if not pt1_L0_frac_y and pt1_L0_frac_x else 0
            pt1_L1_mode = 3 if pt1_L1_frac_y and pt1_L1_frac_x else 2 if pt1_L1_frac_y and not pt1_L1_frac_x else 1 if not pt1_L1_frac_y and pt1_L1_frac_x else 0

            if DEBUG:
                with open("debug.txt", 'a') as f:
                    f.write(f"  pt1: (L0_MVx, L0_MVy)=({pt1_L0_MVx},{pt1_L0_MVy}), (L0_frac_x, L0_frac_y)=({pt1_L0_frac_x},{pt1_L0_frac_y}), L0_mode={pt1_L0_mode}\n")
                    f.write(f"       (L1_MVx, L1_MVy)=({pt1_L1_MVx},{pt1_L1_MVy}), (L1_frac_x, L1_frac_y)=({pt1_L1_frac_x},{pt1_L1_frac_y}), L1_mode={pt1_L1_mode}\n")
                    f.write("\n")
            
            pt1_best_search_pt, pt1_min_satd = compute_mirror_MVD(L0_mat, L1_mat, pt1_L0_MVx, pt1_L0_MVy, pt1_L0_mode, pt1_L1_MVx, pt1_L1_MVy, pt1_L1_mode)

            if DEBUG:
                with open("debug.txt", 'a') as f:
                    f.write(f"  pt1:       Best search point={pt1_best_search_pt}, Min SATD={pt1_min_satd}\n")
                    f.write("\n")


            pt2_L0_MVx = np.clip(np.random.randint(pt1_L0_MVx - 5, pt1_L0_MVx + 6), 0, 116)
            pt2_L0_frac_x = np.random.randint(0, 2)
            pt2_L0_MVy = np.clip(np.random.randint(pt1_L0_MVy - 5, pt1_L0_MVy + 6), 0, 116)
            pt2_L0_frac_y = np.random.randint(0, 2)
            pt2_L1_MVx = np.clip(np.random.randint(pt1_L1_MVx - 5, pt1_L1_MVx + 6), 0, 116)
            pt2_L1_frac_x = np.random.randint(0, 2)
            pt2_L1_MVy = np.clip(np.random.randint(pt1_L1_MVy - 5, pt1_L1_MVy + 6), 0, 116)
            pt2_L1_frac_y = np.random.randint(0, 2)


            pt2_L0_mode = 3 if pt2_L0_frac_y and pt2_L0_frac_x else 2 if pt2_L0_frac_y and not pt2_L0_frac_x else 1 if not pt2_L0_frac_y and pt2_L0_frac_x else 0
            pt2_L1_mode = 3 if pt2_L1_frac_y and pt2_L1_frac_x else 2 if pt2_L1_frac_y and not pt2_L1_frac_x else 1 if not pt2_L1_frac_y and pt2_L1_frac_x else 0

            
            if DEBUG:
                with open("debug.txt", 'a') as f:
                    f.write(f"  pt2: (L0_MVx, L0_MVy)=({pt2_L0_MVx},{pt2_L0_MVy}), (L0_frac_x, L0_frac_y)=({pt2_L0_frac_x},{pt2_L0_frac_y}), L0_mode={pt2_L0_mode}\n")
                    f.write(f"       (L1_MVx, L1_MVy)=({pt2_L1_MVx},{pt2_L1_MVy}), (L1_frac_x, L1_frac_y)=({pt2_L1_frac_x},{pt2_L1_frac_y}), L1_mode={pt2_L1_mode}\n")
                    f.write("\n")
            
            pt2_best_search_pt, pt2_min_satd = compute_mirror_MVD(L0_mat, L1_mat, pt2_L0_MVx, pt2_L0_MVy, pt2_L0_mode, pt2_L1_MVx, pt2_L1_MVy, pt2_L1_mode)

            if DEBUG:
                with open("debug.txt", 'a') as f:
                    f.write(f"  pt2:       Best search point={pt2_best_search_pt}, Min SATD={pt2_min_satd}\n")
                    f.write("\n")

            
            with open("set_input.txt", "a") as f:
                f.write(f"{pt1_L0_MVx}\n")
                f.write(f"{pt1_L0_frac_x}\n")
                f.write(f"{pt1_L0_MVy}\n")
                f.write(f"{pt1_L0_frac_y}\n")
                f.write(f"{pt1_L1_MVx}\n")
                f.write(f"{pt1_L1_frac_x}\n")
                f.write(f"{pt1_L1_MVy}\n")
                f.write(f"{pt1_L1_frac_y}\n")
                f.write(f"{pt2_L0_MVx}\n")
                f.write(f"{pt2_L0_frac_x}\n")
                f.write(f"{pt2_L0_MVy}\n")
                f.write(f"{pt2_L0_frac_y}\n")
                f.write(f"{pt2_L1_MVx}\n")
                f.write(f"{pt2_L1_frac_x}\n")
                f.write(f"{pt2_L1_MVy}\n")
                f.write(f"{pt2_L1_frac_y}\n")

            with open("set_output.txt", "a") as f:
                f.write(f"{pt1_best_search_pt}\n")
                f.write(f"{pt1_min_satd}\n")
                f.write(f"{pt2_best_search_pt}\n")
                f.write(f"{pt2_min_satd}\n")


            # if set_id < 4:
            #     print(f"  Set {set_id}:")
            #     print(f"    pt1: L0_MV=({pt1_L0_MVx},{pt1_L0_MVy}), L0_frac=({pt1_L0_frac_x},{pt1_L0_frac_y}), L0_mode={pt1_L0_mode}")
            #     print(f"         L1_MV=({pt1_L1_MVx},{pt1_L1_MVy}), L1_frac=({pt1_L1_frac_x},{pt1_L1_frac_y}), L1_mode={pt1_L1_mode}")
            #     print(f"         Best search point={pt1_best_search_pt}, Min SATD={pt1_min_satd}")

            #     print(f"    pt2: L0_MV=({pt2_L0_MVx},{pt2_L0_MVy}), L0_frac=({pt2_L0_frac_x},{pt2_L0_frac_y}), L0_mode={pt2_L0_mode}")
            #     print(f"         L1_MV=({pt2_L1_MVx},{pt2_L1_MVy}), L1_frac=({pt2_L1_frac_x},{pt2_L1_frac_y}), L1_mode={pt2_L1_mode}")
            #     print(f"         Best search point={pt2_best_search_pt}, Min SATD={pt2_min_satd}")