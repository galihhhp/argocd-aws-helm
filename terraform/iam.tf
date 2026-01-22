data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each = toset(["arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
  "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"])

  policy_arn = each.value
  role       = aws_iam_role.eks_cluster.name
}

data "aws_iam_policy_document" "eks_node_group_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_group" {
  name               = "${var.name_prefix}-eks-node-group"
  assume_role_policy = data.aws_iam_policy_document.eks_node_group_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy" {
  for_each = toset(["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy", "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"])

  policy_arn = each.value
  role       = aws_iam_role.eks_node_group.name
}

