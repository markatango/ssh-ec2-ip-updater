# ec2-session-persist

Maintain persistent SSH sessions to an AWS EC2 instance even when your local machine's external IP address changes. Runs on any linux terminal, even **Termux (Android)**.

When your ISP changes your external IP, your SSH connection drops. This tool:
1. Monitors your external IP address in the background
2. Detects when it changes
3. Updates the EC2 security group inbound rule automatically
4. Reconnects SSH and reattaches your tmux session — picking up exactly where you left off

---

## How It Works

```
Termux (Android)                        EC2 Instance
────────────────                        ─────────────
SSH connection ───────────────────────► tmux session
(drops on IP change)                    (keeps running)

ip_monitor.sh (background)
  └─► detects new IP
  └─► updates security group
  └─► reconnects SSH
  └─► tmux attach ──────────────────► resumes session
```

---

## Prerequisites

### On your Android device (Termux)
- [Termux](https://f-droid.org/packages/com.termux/) installed via F-Droid (recommended over Play Store)
- AWS CLI configured with credentials that have EC2 security group permissions
- SSH key for your EC2 instance accessible from Termux

### On your EC2 instance
- `tmux` installed
- SSH access configured

### AWS IAM permissions required
Your AWS CLI credentials need at minimum:
```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:AuthorizeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupIngress"
  ],
  "Resource": "arn:aws:ec2:REGION:ACCOUNT_ID:security-group/SECURITY_GROUP_ID"
}
```

---

## Installation

### 1. Install dependencies in Termux

```bash
pkg update && pkg upgrade
pkg install curl awscli openssh
```

### 2. Clone the repository

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/ec2-session-persist.git
cd ec2-session-persist
```

### 3. Configure AWS CLI

```bash
aws configure
```

Enter your AWS Access Key ID, Secret Access Key, default region, and output format (`json`).

### 4. Copy and edit the config file

```bash
cp config.env.example config.env
nano config.env
```

Fill in your values:

```bash
EC2_HOST="your-ec2-hostname-or-ip"
EC2_USER="ec2-user"
SSH_KEY="$HOME/.ssh/your-key.pem"
SECURITY_GROUP_ID="sg-xxxxxxxxxxxxxxxxx"
AWS_REGION="us-east-1"
POLL_INTERVAL=30          # seconds between IP checks
RECONNECT_DELAY=5         # seconds to wait after updating security group
```

### 5. Set permissions on your SSH key

```bash
chmod 600 ~/.ssh/your-key.pem
```

### 6. Make the script executable

```bash
chmod +x ip_monitor.sh
```

### 7. Install tmux on your EC2 instance

SSH in manually the first time and install tmux:

```bash
# Amazon Linux / RHEL
sudo yum install -y tmux

# Ubuntu / Debian
sudo apt-get install -y tmux
```

---

## Setup: SSH Config (local)

Add this to `~/.ssh/config` in Termux to slow disconnects during IP transitions:

```
Host your-ec2-host
    HostName your-ec2-hostname-or-ip
    User ec2-user
    IdentityFile ~/.ssh/your-key.pem
    ServerAliveInterval 15
    ServerAliveCountMax 4
    TCPKeepAlive yes
```

---

## Setup: `.bashrc` additions

Add the following to `~/.bashrc` in Termux so the monitor starts automatically with every new terminal session, but only runs one instance at a time:

```bash
# ── ec2-session-persist ──────────────────────────────────────────
# Start IP monitor in background if not already running
if ! pgrep -f "ip_monitor.sh" > /dev/null 2>&1; then
    termux-wake-lock
    nohup ~/ec2-session-persist/ip_monitor.sh \
        > ~/ec2-session-persist/ip_monitor.log 2>&1 &
fi

# Convenience aliases
alias ec2='ssh -i ~/.ssh/your-key.pem -t ec2-user@your-ec2-host "tmux new-session -A -s main"'
alias ec2log='tail -f ~/ec2-session-persist/ip_monitor.log'
alias ec2stop='pkill -f ip_monitor.sh && echo "Monitor stopped."'
# ─────────────────────────────────────────────────────────────────
```

After editing, reload:
```bash
source ~/.bashrc
```

---

## Usage

### Connect to EC2 (always via tmux)

```bash
ec2
```

This connects and attaches to (or creates) a persistent tmux session named `main`. If your IP changes while you're connected, the monitor will handle reconnection automatically.

### Check monitor status

```bash
ec2log
```

### Stop the monitor

```bash
ec2stop
```

### Restart the monitor manually

```bash
nohup ~/ec2-session-persist/ip_monitor.sh > ~/ec2-session-persist/ip_monitor.log 2>&1 &
```

---

## tmux Quick Reference

Once connected, these tmux basics are useful:

| Keys | Action |
|---|---|
| `Ctrl+b d` | Detach from session (session keeps running) |
| `Ctrl+b c` | New window |
| `Ctrl+b n` | Next window |
| `Ctrl+b [` | Scroll mode (use arrow keys, `q` to exit) |
| `tmux ls` | List sessions |

---

## Android Battery Optimization

Android may kill Termux background processes when the screen is off. To prevent this:

1. Go to **Settings → Apps → Termux → Battery**
2. Set to **Unrestricted** (or disable battery optimization)
3. The script also calls `termux-wake-lock` automatically on start

---

## Troubleshooting

**Monitor not starting on new terminal**
Run `source ~/.bashrc` or open a new Termux session. Check for syntax errors with `bash -n ~/.bashrc`.

**`wget` not found**
```bash
pkg install wget
```

**AWS CLI errors on security group update**
Verify your credentials with `aws sts get-caller-identity` and confirm the IAM permissions listed in Prerequisites.

**tmux session not found after reconnect**
The EC2 instance may have rebooted. SSH in manually and start a new session with `ec2`, then work inside tmux going forward.

**SSH key permission denied**
```bash
chmod 600 ~/.ssh/your-key.pem
```

---

## License

MIT
