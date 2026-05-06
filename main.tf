provider "aws" {
  region = "ap-south-1"
}

data "aws_vpc" "existing" {
  id = "vpc-0aeb9af7097d60b8b"
}

data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
}

resource "aws_security_group" "krishna01_cluster_sg" {
  vpc_id = data.aws_vpc.existing.id
}

resource "aws_security_group" "krishna01_node_sg" {
  vpc_id = data.aws_vpc.existing.id
}

resource "aws_eks_cluster" "krishna01" {
  name     = "krishna01-cluster"
  role_arn = aws_iam_role.krishna01_cluster_role.arn

  vpc_config {
    subnet_ids         = data.aws_subnets.existing.ids
    security_group_ids = [aws_security_group.krishna01_cluster_sg.id]
  }
}

resource "aws_security_group" "krishna01_cluster_sg" {
  vpc_id = aws_vpc.krishna01_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "krishna01-cluster-sg"
  }
}

resource "aws_security_group" "krishna01_node_sg" {
  vpc_id = aws_vpc.krishna01_vpc.id

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
    Name = "krishna01-node-sg"
  }
}

resource "aws_eks_cluster" "krishna01" {
  name     = "krishna01-cluster"
  role_arn = aws_iam_role.krishna01_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.krishna01_subnet[*].id
    security_group_ids = [aws_security_group.krishna01_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.krishna01.name
  addon_name      = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "krishna01" {
  cluster_name    = aws_eks_cluster.krishna01.name
  node_group_name = "krishna01-node-group"
  node_role_arn   = aws_iam_role.krishna01_node_group_role.arn
  subnet_ids      = aws_subnet.krishna01_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["c7i-flex.large"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.krishna01_node_sg.id]
  }
}

resource "aws_iam_role" "krishna01_cluster_role" {
  name = "krishna01-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "krishna01_cluster_role_policy" {
  role       = aws_iam_role.krishna01_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "krishna01_node_group_role" {
  name = "krishna01-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "krishna01_node_group_role_policy" {
  role       = aws_iam_role.krishna01_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "krishna01_node_group_cni_policy" {
  role       = aws_iam_role.krishna01_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "krishna01_node_group_registry_policy" {
  role       = aws_iam_role.krishna01_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "krishna01_node_group_ebs_policy" {
  role       = aws_iam_role.krishna01_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
