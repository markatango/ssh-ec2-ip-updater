#!/bin/bash

EC2_HOST="YOUR EC2 HOST.compute-1.amazonaws.com"
EC2_USER="USER_NAME"
SSH_KEY="SECRET_KEY"
SECURITY_GROUP_ID="sg-nnnnnnn"
AWS_REGION="YOUR AWS REGION"

get_external_ip() {
    curl -s https://checkip.amazonaws.com
}

update_security_group() {
    local new_ip="$1"
    local old_ip="$2"

    echo "Updating security group: $old_ip → $new_ip"

    # Remove old rule
    aws ec2 revoke-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp --port 22 \
        --cidr "${old_ip}/32"

    # Add new rule
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp --port 22 \
        --cidr "${new_ip}/32"
}

reconnect() {
    echo "Reconnecting and attaching tmux session..."
    ssh -i "$SSH_KEY" -t "${EC2_USER}@${EC2_HOST}" "tmux new-session -A -s main"
}

CURRENT_IP=$(get_external_ip)
echo "Starting monitor. Current IP: $CURRENT_IP"

while true; do
    sleep 30
    NEW_IP=$(get_external_ip)

    if [ "$NEW_IP" != "$CURRENT_IP" ]; then
        echo "IP changed: $CURRENT_IP → $NEW_IP"
        update_security_group "$NEW_IP" "$CURRENT_IP"
        CURRENT_IP="$NEW_IP"

        # Wait for security group to propagate
        sleep 5
        reconnect
    fi
done


