output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.bankapp_aws.name} --region ${var.region}"
}

output "cluster_id" {
  value = aws_eks_cluster.bankapp_aws.id
}

output "node_group_id" {
  value = aws_eks_node_group.bankapp_aws.id
}

output "vpc_id" {
  value = aws_vpc.bankapp_aws_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bankapp_aws_subnet[*].id
}