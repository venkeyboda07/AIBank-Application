output "cluster_id" {
  value = aws_eks_cluster.venkat_aws.id
}

output "node_group_id" {
  value = aws_eks_node_group.venkat_aws.id
}

output "vpc_id" {
  value = aws_vpc.venkat_aws_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.venkat_aws_subnet[*].id
}