#!/usr/bin/expect -f

set timeout 20
set ip "13.251.248.85"
set user "ubuntu"
set password "o7%(z3fOa^mvA@OotXal="

spawn ssh -o StrictHostKeyChecking=no $user@$ip "kubectl get pods -A; kubectl get svc -A; kubectl get ingress -A"

expect {
    "*assword:*" {
        send "$password\r"
        exp_continue
    }
    "*yes/no*" {
        send "yes\r"
        exp_continue
    }
    eof
}
