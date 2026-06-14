# GatewayClass CR — Gateway API entry point for the BNK CNE controller.
#
# Operator-facing Gateway CRs reference this class via .spec.gatewayClassName.
# The cne-controller watches Gateways pointing at this controllerName and
# programs TMM listeners / pools accordingly.
#
# controllerName is namespace-scoped: f5.com/<instance_namespace>-f5-cne-controller.
# Default install uses instance_namespace=f5-cne-system → controller name is
# f5.com/f5-cne-system-f5-cne-controller.
#
# Source: awsbnkctl:internal/k8s/manifests/host-device/gatewayclass.yaml.tmpl
#         awsbnkctl:internal/k8s/render/render.go GatewayClassVars / RenderGatewayClass
#
# This file uses Terraform templatefile() syntax (${var}).
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: ${gatewayclass_name}
  labels:
    app.kubernetes.io/managed-by: bnk-forge
    app.kubernetes.io/instance: ${cluster_name}
spec:
  controllerName: f5.com/${instance_namespace}-f5-cne-controller
  description: F5 BIG-IP Kubernetes Gateway
