# ---------------- region ----------------

provider "aws" {
  region = var.region
}

# ---------------- VPC ----------------

resource "aws_vpc" "bankapp_aws_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bankapp-aws-vpc"
  }
}

resource "aws_subnet" "bankapp_aws_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.bankapp_aws_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bankapp_aws_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["ap-south-1a", "ap-south-1b"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bankapp_aws-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "bankapp_aws_igw" {
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  tags = {
    Name = "bankapp_aws-igw"
  }
}

resource "aws_route_table" "bankapp_aws_route_table" {
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bankapp_aws_igw.id
  }

  tags = {
    Name = "bankapp_aws-route-table"
  }
}

resource "aws_route_table_association" "a" {
  count          = 2
  subnet_id      = aws_subnet.bankapp_aws_subnet[count.index].id
  route_table_id = aws_route_table.bankapp_aws_route_table.id
}

# ---------------- Security Groups ----------------

resource "aws_security_group" "bankapp_aws_cluster_sg" {
  vpc_id = aws_vpc.bankapp_aws_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bankapp_aws_node_sg" {
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
}

# ---------------- IAM ----------------

resource "aws_iam_role" "bankapp_aws_cluster_role" {
  name = "bankapp_aws-cluster-role"

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

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.bankapp_aws_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "bankapp_aws_node_group_role" {
  name = "bankapp_aws-node-group-role"

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

# ---------- Node policies ---------
resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------EBS CSI permission ---------
resource "aws_iam_role_policy_attachment" "ebs_policy" {
  role       = aws_iam_role.bankapp_aws_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# ---------------- EKS Cluster ----------------

resource "aws_eks_cluster" "bankapp_aws" {
  name     = "bankapp_aws-cluster"
  role_arn = aws_iam_role.bankapp_aws_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bankapp_aws_subnet[*].id
    security_group_ids = [aws_security_group.bankapp_aws_cluster_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy
  ]
}

# ---------------- Launch Template (IMDS) ----------------

resource "aws_launch_template" "bankapp_lt" {
  name_prefix = "bankapp-lt"

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional" 
  }
}

# ---------------- Node Group ----------------

resource "aws_eks_node_group" "bankapp_aws" {
  cluster_name    = aws_eks_cluster.bankapp_aws.name
  node_group_name = "bankapp_aws-node-group"
  node_role_arn   = aws_iam_role.bankapp_aws_node_group_role.arn
  subnet_ids      = aws_subnet.bankapp_aws_subnet[*].id

  launch_template {
    id      = aws_launch_template.bankapp_lt.id
    version = "$Latest"
  }

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.bankapp_aws
  ]
}

# ---------------- EBS CSI DRIVER (AUTO INSTALL) ----------------

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = aws_eks_cluster.bankapp_aws.name
  addon_name   = "aws-ebs-csi-driver"

  depends_on = [
    aws_eks_node_group.bankapp_aws
  ]
}
