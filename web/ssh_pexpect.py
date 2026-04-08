import pexpect
import sys

ip = "13.251.248.85"
user = "ubuntu"
password = "o7%(z3fOa^mvA@OotXal="

print(f"Connecting to {user}@{ip}...")
child = pexpect.spawn(f"ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no {user}@{ip}", encoding='utf-8')
child.logfile = sys.stdout

try:
    i = child.expect(["assword:", "yes/no"], timeout=10)
    if i == 1:
        child.sendline("yes")
        child.expect("assword:")
        
    child.sendline(password)
    child.expect(["\$", "\#", ">", "ubuntu@ip-"], timeout=15)
    print("\nConnected! Running commands...")
    child.sendline("kubectl get pods -A")
    child.expect(["\$", "\#", ">", "ubuntu@ip-"], timeout=5)
    print("Done")
except Exception as e:
    print(f"\nError: {e}")
