
module "vector_service_account_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "3.6.0"

  create_role                   = true
  role_name                     = "${var.eks_cluster_name}-sa-vector"
  provider_url                  = replace(data.aws_eks_cluster.primary.identity.0.oidc.0.issuer, "https://", "")
  role_policy_arns              = []
  oidc_fully_qualified_subjects = ["system:serviceaccount:vector:*"]

  providers = {
    aws = aws
  }
}

# Inject this `ConfigMap` into the cluster - the flux-managed config expect
# it to be present and will consume the data we provide here.
resource "kubectl_manifest" "vector_injected_configmap" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: ConfigMap
    metadata:
      namespace: vector
      name: terraform-injected-values
    data:
      helm-chart-values.yaml: |
        vector-aggregator:
          serviceAccount:
            annotations:
              eks.amazonaws.com/role-arn: arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.vector_service_account_role.this_iam_role_name}
  YAML

  depends_on = [
    module.flux
  ]
}