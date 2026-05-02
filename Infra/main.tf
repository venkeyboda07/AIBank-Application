provider "aws" {
  region = var.region
}

# -------------------------------------------------
# VPC
# -------------------------------------------------
resource "aws_vpc" "bankapp_aws_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "bankapp-aws-vpc"
  }
}

# -------------------------------------------------
# Public Subnets
# -------------------------------------------------
resource "aws_subnet" "bankapp_aws_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.bankapp_aws_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bankapp_aws_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bankapp-aws-subnet-${count.index}"

    "kubernetes.io/cluster/bankapp_aws-cluster" = "shared"
    "kubernetes.io/role/elb"                   = "1"
  }
}

# -------------------------------------------------
# Internet Gateway
# -------------------------------------------------
resource "aws_internet_gateway" "bankapp_aws_igw" {
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  tags = {
    Name = "bankapp-aws-igw"
  }
}

# -------------------------------------------------
# Route Table
# -------------------------------------------------
resource "aws_route_table" "bankapp_aws_route_table" {
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bankapp_aws_igw.id
  }

  tags = {
    Name = "bankapp-aws-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.bankapp_aws_subnet[count.index].id
  route_table_id = aws_route_table.bankapp_aws_route_table.id
}

# -------------------------------------------------
# Security Groups
# -------------------------------------------------
resource "aws_security_group" "bankapp_aws_cluster_sg" {
  name   = "bankapp-cluster-sg"
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankapp-cluster-sg"
  }
}

resource "aws_security_group" "bankapp_aws_node_sg" {
  name   = "bankapp-node-sg"
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bankapp-node-sg"
  }
}

# -------------------------------------------------
# IAM ROLE FOR EKS CLUSTER
# -------------------------------------------------
resource "aws_iam_role" "bankapp_aws_cluster_role" {
  name = "bankapp-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bankapp_aws_cluster_role_policy" {
  role       = aws_iam_role.bankapp_aws_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -------------------------------------------------
# IAM ROLE FOR NODE GROUP
# -------------------------------------------------
resource "aws_iam_role" "bankapp_aws_node_group_role" {
  name = "bankapp-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "bankapp_aws_node_group_role_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "bankapp_aws_node_group_cni_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "bankapp_aws_node_group_registry_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -------------------------------------------------
# IAM ROLE FOR EBS CSI DRIVER
# -------------------------------------------------
resource "aws_iam_role" "ebs_csi_role" {
  name = "bankapp-ebs-csi-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "pods.eks.amazonaws.com"
      }
      Action = [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# -------------------------------------------------
# EKS CLUSTER
# -------------------------------------------------
resource "aws_eks_cluster" "bankapp_aws" {
  name     = "bankapp_aws-cluster"
  role_arn = aws_iam_role.bankapp_aws_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bankapp_aws_subnet[*].id
    security_group_ids = [aws_security_group.bankapp_aws_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.bankapp_aws_cluster_role_policy
  ]
}

# -------------------------------------------------
# NODE GROUP
# -------------------------------------------------
resource "aws_eks_node_group" "bankapp_aws" {
  cluster_name    = aws_eks_cluster.bankapp_aws.name
  node_group_name = "bankapp-node-group"
  node_role_arn   = aws_iam_role.bankapp_aws_node_group_role.arn
  subnet_ids      = aws_subnet.bankapp_aws_subnet[*].id

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bankapp_aws_node_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.bankapp_aws_node_group_role_policy,
    aws_iam_role_policy_attachment.bankapp_aws_node_group_cni_policy,
    aws_iam_role_policy_attachment.bankapp_aws_node_group_registry_policy
  ]
}

# -------------------------------------------------
# EKS ADDON - EBS CSI DRIVER
# -------------------------------------------------
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.bankapp_aws.name
  addon_name                  = "aws-ebs-csi-driver"
  service_account_role_arn    = aws_iam_role.ebs_csi_role.arn
  resolve_conflicts_on_create = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.bankapp_aws
  ]
}
