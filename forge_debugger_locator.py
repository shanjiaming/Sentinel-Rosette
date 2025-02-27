import sys
import time
import pyautogui

def main():
    # Check if there are enough command line arguments
    if len(sys.argv) != 4:
        print("Usage: python script.py <num1> <num2> <num3>")
        sys.exit(1)
    
    try:
        count_C = int(sys.argv[1])
        count_s = int(sys.argv[2])
        count_j = int(sys.argv[3])
    except ValueError:
        print("Please enter three integers.")
        sys.exit(1)
    
    # # Wait for the user to input 'p'
    # while True:
    #     key = input("Press 'p' to start simulating typing:")
    #     if key.lower() == 'p':
    #         break

    print("The simulated typing will start in 3 seconds. Please switch your cursor to the target window...")
    time.sleep(3)

    pyautogui.write('g', interval=0.01)

    # Simulate keyboard typing: output uppercase 'C' count_C times
    for _ in range(count_C):
        pyautogui.write('C', interval=0.01)
    # Output lowercase 's' count_s times
    for _ in range(count_s):
        pyautogui.write('s', interval=0.01)
    # Output lowercase 'j' count_j times
    for _ in range(count_j):
        pyautogui.write('j', interval=0.01)

if __name__ == '__main__':
    main()
