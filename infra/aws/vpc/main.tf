# modules/foundation/vpc/main.tf
# VPC module - inherits versions/providers from version

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with project-specific name
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# 5 Subnets as specified
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-jumphost"
    Type = "Public"
  })
}

resource "aws_subnet" "private_external_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_external_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-external-a"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_external_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_external_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-external-b"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "private_internal_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_internal_subnet_a_cidr
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-internal-a"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  })
}

resource "aws_subnet" "private_internal_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_internal_subnet_b_cidr
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-internal-b"
    Type = "Private"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  })
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat-eip"
  })
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-private-rt"
  })
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_external_a" {
  subnet_id      = aws_subnet.private_external_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_external_b" {
  subnet_id      = aws_subnet.private_external_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_internal_a" {
  subnet_id      = aws_subnet.private_internal_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_internal_b" {
  subnet_id      = aws_subnet.private_internal_b.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# ENHANCED CLEANUP RESOURCES FOR RELIABLE DESTRUCTION
# =============================================================================

# Time delay to allow dependent resources to clean up
resource "time_sleep" "wait_for_dependencies" {
  depends_on = [
    aws_vpc.main,
    aws_subnet.public,
    aws_subnet.private_external_a,
    aws_subnet.private_external_b,
    aws_subnet.private_internal_a,
    aws_subnet.private_internal_b
  ]

  destroy_duration = "90s"
}

# Cleanup orphaned ENIs before VPC deletion
resource "null_resource" "cleanup_enis" {
  triggers = {
    vpc_id  = aws_vpc.main.id
    region  = var.aws_region
    profile = var.aws_profile
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== VPC ENI Cleanup ==="
      echo "VPC ID: ${self.triggers.vpc_id}"

      # Wait for EKS/other services to release ENIs
      echo "Waiting for dependent services to release ENIs..."
      sleep 60

      # Find all ENIs in the VPC
      echo "Finding ENIs in VPC..."
      ENI_IDS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "")

      if [ ! -z "$ENI_IDS" ]; then
        echo "Found ENIs to clean up: $ENI_IDS"

        for eni in $ENI_IDS; do
          if [ ! -z "$eni" ] && [ "$eni" != "None" ]; then
            echo "Processing ENI: $eni"

            # Get ENI status
            STATUS=$(aws ec2 describe-network-interfaces \
              --network-interface-ids $eni \
              --query 'NetworkInterfaces[0].Status' \
              --output text \
              --region ${self.triggers.region} \
              --profile ${self.triggers.profile} 2>/dev/null || echo "not-found")

            echo "ENI $eni status: $STATUS"

            # If attached, try to detach it
            if [ "$STATUS" = "in-use" ]; then
              ATTACHMENT_ID=$(aws ec2 describe-network-interfaces \
                --network-interface-ids $eni \
                --query 'NetworkInterfaces[0].Attachment.AttachmentId' \
                --output text \
                --region ${self.triggers.region} \
                --profile ${self.triggers.profile} 2>/dev/null || echo "")

              if [ ! -z "$ATTACHMENT_ID" ] && [ "$ATTACHMENT_ID" != "None" ]; then
                echo "Detaching ENI $eni (attachment: $ATTACHMENT_ID)..."
                aws ec2 detach-network-interface \
                  --attachment-id $ATTACHMENT_ID \
                  --force \
                  --region ${self.triggers.region} \
                  --profile ${self.triggers.profile} 2>/dev/null || echo "Failed to detach or already detached"

                # Wait for detachment
                sleep 15
              fi
            fi

            # Try to delete the ENI
            echo "Deleting ENI: $eni"
            aws ec2 delete-network-interface \
              --network-interface-id $eni \
              --region ${self.triggers.region} \
              --profile ${self.triggers.profile} 2>/dev/null || echo "ENI $eni already deleted or protected"
          fi
        done

        # Final wait for AWS to process deletions
        echo "Waiting for ENI deletions to complete..."
        sleep 20
      else
        echo "No ENIs found for cleanup"
      fi

      echo "VPC ENI cleanup completed"
    EOT
  }

  depends_on = [time_sleep.wait_for_dependencies]
}

# Cleanup NAT Gateway EIP allocations
resource "null_resource" "cleanup_eips" {
  triggers = {
    vpc_id  = aws_vpc.main.id
    eip_id  = aws_eip.nat.id
    region  = var.aws_region
    profile = var.aws_profile
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== VPC EIP Cleanup ==="

      # Check for any remaining EIPs associated with the VPC
      EIP_ALLOCS=$(aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[?AssociationId!=`null`].AllocationId' \
        --output text \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "")

      if [ ! -z "$EIP_ALLOCS" ]; then
        echo "Found associated EIPs: $EIP_ALLOCS"
        for eip in $EIP_ALLOCS; do
          if [ ! -z "$eip" ] && [ "$eip" != "None" ]; then
            echo "Disassociating EIP: $eip"
            ASSOC_ID=$(aws ec2 describe-addresses \
              --allocation-ids $eip \
              --query 'Addresses[0].AssociationId' \
              --output text \
              --region ${self.triggers.region} \
              --profile ${self.triggers.profile} 2>/dev/null || echo "")

            if [ ! -z "$ASSOC_ID" ] && [ "$ASSOC_ID" != "None" ]; then
              aws ec2 disassociate-address \
                --association-id $ASSOC_ID \
                --region ${self.triggers.region} \
                --profile ${self.triggers.profile} 2>/dev/null || echo "Already disassociated"
            fi
          fi
        done
      else
        echo "No associated EIPs found"
      fi

      echo "VPC EIP cleanup completed"
    EOT
  }

  depends_on = [null_resource.cleanup_enis]
}

# Detach and cleanup Internet Gateway
resource "null_resource" "cleanup_igw" {
  triggers = {
    vpc_id  = aws_vpc.main.id
    igw_id  = aws_internet_gateway.main.id
    region  = var.aws_region
    profile = var.aws_profile
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Internet Gateway Cleanup ==="
      echo "IGW ID: ${self.triggers.igw_id}"
      echo "VPC ID: ${self.triggers.vpc_id}"

      # Try to detach the IGW
      echo "Detaching Internet Gateway from VPC..."
      aws ec2 detach-internet-gateway \
        --internet-gateway-id ${self.triggers.igw_id} \
        --vpc-id ${self.triggers.vpc_id} \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "IGW already detached or being deleted"

      # Wait for detachment
      sleep 10

      # Try to delete the IGW
      echo "Deleting Internet Gateway..."
      aws ec2 delete-internet-gateway \
        --internet-gateway-id ${self.triggers.igw_id} \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "IGW already deleted"

      echo "Internet Gateway cleanup completed"
    EOT
  }

  depends_on = [null_resource.cleanup_eips]
}

# Final VPC cleanup verification
resource "null_resource" "final_vpc_cleanup" {
  triggers = {
    vpc_id  = aws_vpc.main.id
    region  = var.aws_region
    profile = var.aws_profile
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Final VPC Cleanup Verification ==="

      # Check for any remaining dependencies
      echo "Checking for remaining VPC dependencies..."

      # Check for security groups (other than default)
      SG_COUNT=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" \
        --query 'length(SecurityGroups[?GroupName!=`default`])' \
        --output text \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "0")

      if [ "$SG_COUNT" != "0" ]; then
        echo "Warning: $SG_COUNT non-default security groups still exist"
        echo "These will need manual cleanup or will be handled by Terraform"
      fi

      # Check for remaining ENIs
      ENI_COUNT=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=${self.triggers.vpc_id}" \
        --query 'length(NetworkInterfaces)' \
        --output text \
        --region ${self.triggers.region} \
        --profile ${self.triggers.profile} 2>/dev/null || echo "0")

      if [ "$ENI_COUNT" != "0" ]; then
        echo "Warning: $ENI_COUNT network interfaces still exist"
        echo "VPC deletion may fail - manual cleanup may be required"
      else
        echo "All ENIs cleaned up successfully"
      fi

      echo "VPC is ready for deletion"
      echo "=== Cleanup verification completed ==="
    EOT
  }

  depends_on = [
    null_resource.cleanup_enis,
    null_resource.cleanup_eips,
    null_resource.cleanup_igw
  ]
}
