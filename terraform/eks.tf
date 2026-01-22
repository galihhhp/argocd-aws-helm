resource "aws_eks_cluster" "main" {
  name = "${var.name_prefix}-eks-cluster"

  access_config {
    authentication_mode = "API"
  }

  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [
      aws_subnet.public_subnet.id,
      aws_subnet.private_subnet.id,
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [aws_subnet.private_subnet.id]
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_group_policy
  ]
}
