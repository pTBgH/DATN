import subprocess

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return res.stdout, res.stderr
    except Exception as e:
        return "", str(e)

print("Filtering host boot -1 logs for 'dhcpd'...")
cmd = 'journalctl -b -1 --since "2026-06-23 00:00:00" | grep -i "dhcpd"'
stdout, stderr = run_cmd(cmd)

lines = stdout.splitlines()
print(f"Total matched lines: {len(lines)}")
for line in lines[-100:]:
    print(line)
