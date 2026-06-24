import pexpect
import sys
import os

def run_ssh(cmd):
    password = "baobao"
    ip = "172.16.82.128"
    user = "ptb"
    
    # Run ssh command
    ssh_cmd = f"ssh -o StrictHostKeyChecking=no {user}@{ip} '{cmd}'"
    child = pexpect.spawn(ssh_cmd)
    
    try:
        # Expect password prompt or host key verification prompt
        index = child.expect(["[Pp]assword:", pexpect.EOF, pexpect.TIMEOUT], timeout=10)
        if index == 0:
            child.sendline(password)
            child.expect(pexpect.EOF)
            output = child.before.decode('utf-8')
            return output
        else:
            return f"Error: SSH failed with index {index}. Output:\n" + child.before.decode('utf-8')
    except Exception as e:
        return f"Exception occurred: {str(e)}\nOutput:\n" + child.before.decode('utf-8')

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 run_ssh_srv05.py <command>")
        sys.exit(1)
    
    command = sys.argv[1]
    print(f"Running command on 7189srv05: {command}")
    print("---------------------------------------------")
    res = run_ssh(command)
    print(res)
