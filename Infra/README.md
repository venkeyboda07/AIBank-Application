## Connect kubectl to your EKS cluster

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name venkat_aws-cluster

```

# AWS EKS Cluster using Terraform

This repository provisions an **Amazon EKS (Elastic Kubernetes Service)** cluster with a **managed node group** using **Terraform**.  
It also explains how to connect to the cluster using **kubectl**.

---

## Overview

The Terraform configuration creates the following AWS resources:

- VPC
- Public subnets across multiple Availability Zones
- Internet Gateway and route table
- Security groups for EKS cluster and worker nodes
- IAM roles and policies for EKS
- EKS cluster
- EKS managed node group

This setup is intended for **learning and practice purposes**.

---

## Prerequisites

Ensure the following tools are installed and configured:

- AWS CLI
- Terraform
- kubectl
- An existing EC2 Key Pair in the target AWS region

## SSH Key Pair Variable

The EKS node group allows SSH access to worker nodes using an EC2 key pair.

```bash
variable "ssh_key_name" {
  description = "The name of the SSH key pair to use for instances"
  type        = string
  default     = "id_rsa"
}

```

### Important:
The value of ssh_key_name (I am using default key name is "id_rsa" so instead of "id_rsa" you can use your exact key pair name) must exactly match the name of an existing EC2 key pair in the configured AWS region.
If the key pair does not exist, the EKS node group creation will fail.