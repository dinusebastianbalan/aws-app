
data "aws_eks_cluster" "default" {
  name = var.cluster_name
}

data "aws_secretsmanager_secret" "secrets" {
  arn = var.secret_arn
}

data "aws_secretsmanager_secret_version" "secret" {
  secret_id = data.aws_secretsmanager_secret.secrets.id
}

data "aws_eks_cluster_auth" "default" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.default.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}

resource "local_file" "kubeconfig" {
  sensitive_content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name = var.cluster_name,
    clusterca    = data.aws_eks_cluster.default.certificate_authority[0].data,
    endpoint     = data.aws_eks_cluster.default.endpoint,
  })
  filename = "./kubeconfig-${var.cluster_name}"
}

resource "kubernetes_namespace" "gateway" {
  metadata {
    name = "gateway"
  }
}

resource "helm_release" "nginx_ingress" {
  namespace = kubernetes_namespace.gateway.metadata.0.name
  wait      = true
  timeout   = 600

  name = "gateway"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "v4.3.0"
}

resource "helm_release" "csi-secrets-store" {
  name       = "csi-secrets-store"
  namespace = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver/secrets-store-csi-driver"

  set {
    name = "syncSecret.enabled"
    value = "true"
  }

  set {
    name = "enableSecretRotation"
    value = "true"
  }
}

resource "null_resource" "kubectl_aosc" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml"
    interpreter = ["/bin/bash", "-c"]
    }
}

resource "aws_iam_policy" "policy" {
  name        = "Secret_DB-policy"
  description = "SecretARN Policy"

  policy = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
        "Resource": ["${var.secret_arn}" ]
    } ]
}
EOT
}

data "tls_certificate" "example" {
  url = data.aws_eks_cluster.default.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "example" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.example.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.default.identity[0].oidc[0].issuer
}