# bnk-forge-modules/app/demo-ec2-traffic/main.tf
# EC2 Traffic Generator — External instance on 10.0.10.0/24 hitting BNK VIP
#
# This is the REAL demo traffic path:
#   EC2 (10.0.10.x) → VIP (10.0.10.100:80/:8080) → TMM → backend pods
#
# The EC2 sits on the same subnet as the TMM external interface (10.0.10.240)
# and the BNK Gateway VIP (10.0.10.100), simulating an external client.

# =============================================================================
# DATA SOURCES
# =============================================================================

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# =============================================================================
# USER DATA — Install tools + traffic scripts
# =============================================================================

locals {
  user_data = <<-USERDATA
    #!/bin/bash
    set -e

    # Install tools
    yum update -y
    yum install -y curl jq

    # Install hey (HTTP load generator)
    curl -sL https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64 -o /usr/local/bin/hey
    chmod +x /usr/local/bin/hey

    # Create traffic scripts directory
    mkdir -p /opt/bnk-demo/scripts

    # ==========================================================================
    # Script: Standard HTTP traffic (port 80)
    # ==========================================================================
    cat > /opt/bnk-demo/scripts/standard-traffic.sh << 'SCRIPT'
    #!/bin/bash
    VIP="${var.vip_address}"
    PORT="80"
    echo "=== BNK Demo: Standard HTTP Traffic ==="
    echo "Target: $VIP:$PORT"
    echo ""

    # Simple GET requests
    echo "--- GET / ---"
    for i in $(seq 1 10); do
      STATUS=$(curl -s -o /dev/null -w "%%{http_code}" --connect-timeout 5 http://$VIP:$PORT/)
      echo "  Request $i: HTTP $STATUS"
      sleep 1
    done

    # GET with different paths
    echo ""
    echo "--- GET /api/echo ---"
    for i in $(seq 1 5); do
      curl -s --connect-timeout 5 http://$VIP:$PORT/api/echo?req=$i | head -c 200
      echo ""
      sleep 1
    done

    echo ""
    echo "Standard traffic complete."
    SCRIPT

    # ==========================================================================
    # Script: Smart HTTP traffic (port 8080) — LLM chat requests
    # ==========================================================================
    cat > /opt/bnk-demo/scripts/smart-traffic.sh << 'SCRIPT'
    #!/bin/bash
    VIP="${var.vip_address}"
    PORT="8080"
    echo "=== BNK Demo: Smart LLM Traffic ==="
    echo "Target: $VIP:$PORT (Smart listener with iRule routing)"
    echo ""

    # OpenAI-compatible chat completions
    PROMPTS=(
      "Hello, how are you?"
      "Explain quantum computing in simple terms"
      "Write a Python function to sort a list"
      "What is the capital of Australia?"
      "Summarize the theory of relativity"
    )

    for i in $(seq 0 4); do
      PROMPT=$${PROMPTS[$i]}
      echo "--- Request $((i+1)): $PROMPT ---"
      curl -s --connect-timeout 10 -X POST http://$VIP:$PORT/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer demo-key" \
        -d "{
          \"model\": \"default\",
          \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT\"}],
          \"max_tokens\": 100
        }" | jq -r '.choices[0].message.content // .error // "no response"' 2>/dev/null || echo "  (no response or timeout)"
      echo ""
      sleep 2
    done

    echo "Smart traffic complete."
    SCRIPT

    # ==========================================================================
    # Script: Load test with hey
    # ==========================================================================
    cat > /opt/bnk-demo/scripts/load-test.sh << 'SCRIPT'
    #!/bin/bash
    VIP="${var.vip_address}"
    DURATION=$${1:-10}
    CONCURRENCY=$${2:-5}

    echo "=== BNK Demo: Load Test ==="
    echo "Target: $VIP:80"
    echo "Duration: $${DURATION}s, Concurrency: $CONCURRENCY"
    echo ""

    hey -z $${DURATION}s -c $CONCURRENCY http://$VIP:80/

    echo ""
    echo "Load test complete."
    SCRIPT

    # ==========================================================================
    # Script: Connectivity check
    # ==========================================================================
    cat > /opt/bnk-demo/scripts/check-connectivity.sh << 'SCRIPT'
    #!/bin/bash
    VIP="${var.vip_address}"
    echo "=== BNK Demo: Connectivity Check ==="
    echo ""

    echo "1. Ping VIP ($VIP):"
    ping -c 3 -W 2 $VIP 2>/dev/null && echo "   PASS" || echo "   FAIL (ICMP may be blocked, trying HTTP...)"

    echo ""
    echo "2. HTTP GET $VIP:80:"
    STATUS=$(curl -s -o /dev/null -w "%%{http_code}" --connect-timeout 5 http://$VIP:80/ 2>/dev/null)
    echo "   HTTP $STATUS"
    [ "$STATUS" = "000" ] && echo "   FAIL: No response (check TMM, Gateway, Routes)" || echo "   PASS"

    echo ""
    echo "3. HTTP GET $VIP:8080:"
    STATUS=$(curl -s -o /dev/null -w "%%{http_code}" --connect-timeout 5 http://$VIP:8080/ 2>/dev/null)
    echo "   HTTP $STATUS"
    [ "$STATUS" = "000" ] && echo "   FAIL: No response" || echo "   PASS"

    echo ""
    echo "4. TMM external self-IP (${var.tmm_external_ip}):"
    ping -c 2 -W 2 ${var.tmm_external_ip} 2>/dev/null && echo "   PASS" || echo "   FAIL (expected if ICMP blocked)"

    echo ""
    echo "Connectivity check complete."
    SCRIPT

    # Make all scripts executable
    chmod +x /opt/bnk-demo/scripts/*.sh

    # Create convenience aliases
    cat >> /etc/profile.d/bnk-demo.sh << 'PROFILE'
    alias standard='/opt/bnk-demo/scripts/standard-traffic.sh'
    alias smart='/opt/bnk-demo/scripts/smart-traffic.sh'
    alias loadtest='/opt/bnk-demo/scripts/load-test.sh'
    alias check='/opt/bnk-demo/scripts/check-connectivity.sh'
    echo ""
    echo "========================================="
    echo "  BNK Demo Traffic Generator"
    echo "========================================="
    echo "  VIP: ${var.vip_address}"
    echo "  Commands: standard, smart, loadtest, check"
    echo "  Scripts:  /opt/bnk-demo/scripts/"
    echo "========================================="
    echo ""
    PROFILE

    echo "BNK Demo Traffic Generator setup complete" > /opt/bnk-demo/setup-complete
  USERDATA
}

# =============================================================================
# EC2 INSTANCE
# =============================================================================

resource "aws_instance" "traffic_generator" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.external_subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_pair_name

  user_data = local.user_data

  tags = {
    Name                          = "${var.project_name}-traffic-generator"
    "app.kubernetes.io/part-of"   = "bnk-demo"
    "app.kubernetes.io/component" = "traffic-generator"
    Purpose                       = "External traffic source for BNK Gateway demo"
  }

  # Don't replace on user_data changes — just update
  lifecycle {
    ignore_changes = [ami]
  }
}

# =============================================================================
# OUTPUTS
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID of the traffic generator"
  value       = aws_instance.traffic_generator.id
}

output "private_ip" {
  description = "Private IP of the traffic generator (on 10.0.10.0/24 external subnet)"
  value       = aws_instance.traffic_generator.private_ip
}

output "traffic_generator_ready" {
  description = "Flag indicating the traffic generator EC2 is deployed"
  value       = true
}

output "ssh_command" {
  description = "SSH command to connect to the traffic generator (via jumphost)"
  value       = "ssh -J ec2-user@<jumphost-ip> ec2-user@${aws_instance.traffic_generator.private_ip}"
}

output "demo_commands" {
  description = "Available demo commands on the traffic generator"
  value = {
    connectivity_check = "ssh ec2-user@${aws_instance.traffic_generator.private_ip} /opt/bnk-demo/scripts/check-connectivity.sh"
    standard_traffic   = "ssh ec2-user@${aws_instance.traffic_generator.private_ip} /opt/bnk-demo/scripts/standard-traffic.sh"
    smart_traffic      = "ssh ec2-user@${aws_instance.traffic_generator.private_ip} /opt/bnk-demo/scripts/smart-traffic.sh"
    load_test          = "ssh ec2-user@${aws_instance.traffic_generator.private_ip} /opt/bnk-demo/scripts/load-test.sh 30 10"
  }
}
