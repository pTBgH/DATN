import subprocess
import sys

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.stdout, res.stderr
    except Exception as e:
        return "", str(e)

# Query host boot -1 logs for vmnet, vmware, oom
print("Running journalctl on host (boot -1)...")
cmd = 'journalctl -b -1 --since "2026-06-23 16:00:00"'
stdout, stderr = run_cmd(cmd)

if stderr:
    print(f"Error querying journal: {stderr}")

lines = stdout.splitlines()
print(f"Total log lines fetched from host boot -1: {len(lines)}")

# Search for OOM, kill, vmnet, vmware, dhcp
terms = ["oom-killer", "out of memory", "killed process", "vmnet", "vmware", "dhcp", "dhcpd"]
matched = []
for line in lines:
    if any(term in line.lower() for term in terms):
        matched.append(line)

print(f"Found {len(matched)} matching lines. Showing last 100 lines:")
for line in matched[-100:]:
    print(line)
