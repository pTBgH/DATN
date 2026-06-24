import sys
import os

# Append scratch directory to path to import run_ssh_srv05
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from run_ssh_srv05 import run_ssh

cmd = "sudo journalctl -b -3"
print("Fetching logs from 7189srv05...")
output = run_ssh(cmd)
lines = output.splitlines()

target = "The system will power off now!"
idx = -1
for i, line in enumerate(lines):
    if target in line:
        idx = i
        break

if idx != -1:
    print(f"Found target line at index {idx}:")
    start = max(0, idx - 40)
    end = min(len(lines), idx + 10)
    for j in range(start, end):
        prefix = "-> " if j == idx else "   "
        print(f"{prefix}{lines[j]}")
else:
    print("Target line not found in log output.")
    print(f"Total lines fetched: {len(lines)}")
    # Print lines that mention systemd-logind or power/shutdown
    print("Filtering lines for logind/poweroff/shutdown:")
    count = 0
    for line in lines:
        if any(term in line.lower() for term in ["logind", "power", "shutdown", "halt"]):
            print(line)
            count += 1
            if count > 50:
                print("... truncated list ...")
                break
