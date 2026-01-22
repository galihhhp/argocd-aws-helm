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

# EKS Access Entry untuk IAM user yang akan diakses EKS cluster
data "aws_caller_identity" "current" {} # output: arn:aws:iam::859842719537:user/inituser

locals {
  eks_access_principals = length(var.eks_access_entries) > 0 ? var.eks_access_entries : [data.aws_caller_identity.current.arn]
}

resource "aws_eks_access_entry" "main" {
  for_each = toset(local.eks_access_principals)

  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = each.value
  kubernetes_groups = []
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = toset(local.eks_access_principals)

  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.main]
}