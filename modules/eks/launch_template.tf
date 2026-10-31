resource "aws_launch_template" "nodes" {
  name_prefix = "${var.name}-${var.environment}-eks-nodes-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    var.application_security_group_id
  ]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name        = "${var.name}-${var.environment}-eks-node"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.name
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name        = "${var.name}-${var.environment}-eks-node-volume"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = var.name
    })
  }

  update_default_version = true

  tags = merge(var.tags, {
    Name        = "${var.name}-${var.environment}-eks-node-launch-template"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.name
  })
}
