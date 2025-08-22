# Wave 0 Deployment
ak@Alexanders-MBP base-app-layer % ./deploy-wave0-complete.sh
[2025-08-22 02:44:03] Starting Wave 0 Deployment - Platform Foundation
[2025-08-22 02:44:03] Environment: dev | Region: us-east-1 | Cluster: base-app-layer-dev-platform
[STEP] Validating Prerequisites
[INFO] Connected to cluster: arn:aws:eks:us-east-1:084129280818:cluster/platform-app-layer-dev
[INFO] Prerequisites validated successfully
[STEP] Deploying ArgoCD
[2025-08-22 02:44:04] Cleaning up existing ArgoCD resources...
namespace/argocd created
[2025-08-22 02:44:06] Deploying ArgoCD from upstream...
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-applicationset-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-notifications-controller created
serviceaccount/argocd-redis created
serviceaccount/argocd-repo-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-applicationset-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-notifications-controller created
role.rbac.authorization.k8s.io/argocd-redis created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-notifications-controller created
rolebinding.rbac.authorization.k8s.io/argocd-redis created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-cmd-params-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-notifications-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-notifications-secret created
secret/argocd-secret created
service/argocd-applicationset-controller created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-notifications-controller-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server created
service/argocd-server-metrics created
deployment.apps/argocd-applicationset-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-notifications-controller created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
statefulset.apps/argocd-application-controller created
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy created
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-redis-network-policy created
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy created
networkpolicy.networking.k8s.io/argocd-server-network-policy created
[INFO] Waiting for pods in namespace argocd (timeout: 300s)
pod/argocd-application-controller-0 condition met
pod/argocd-applicationset-controller-6ff6f74bc9-9mbs7 condition met
pod/argocd-dex-server-558dc4bd7b-5xtq7 condition met
pod/argocd-notifications-controller-9977b5bd6-v22tg condition met
pod/argocd-redis-6594484976-8q9wp condition met
pod/argocd-repo-server-845d4f5c49-x5s9x condition met
pod/argocd-server-59d75f4c95-kjvh7 condition met
[INFO] All pods in argocd are ready
configmap/argocd-cmd-params-cm patched
[INFO] Checking health for argocd in namespace argocd
[INFO] ✅ ArgoCD: Running
[INFO] ArgoCD admin password: Ps73R4D3n8j1np3I
[2025-08-22 02:44:48] ArgoCD deployed successfully
[STEP] Deploying cert-manager
namespace/cert-manager created
Warning: resource namespaces/cert-manager is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
namespace/cert-manager configured
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
serviceaccount/cert-manager-cainjector created
serviceaccount/cert-manager created
serviceaccount/cert-manager-webhook created
configmap/cert-manager created
configmap/cert-manager-webhook created
clusterrole.rbac.authorization.k8s.io/cert-manager-cainjector unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-issuers unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-certificates unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-orders unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-challenges unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-cluster-view unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-view unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-edit unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-approve:cert-manager-io unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-certificatesigningrequests unchanged
clusterrole.rbac.authorization.k8s.io/cert-manager-webhook:subjectaccessreviews unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-cainjector unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-issuers unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-certificates unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-orders unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-challenges unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-approve:cert-manager-io unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-certificatesigningrequests unchanged
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-webhook:subjectaccessreviews configured
role.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection unchanged
role.rbac.authorization.k8s.io/cert-manager:leaderelection unchanged
role.rbac.authorization.k8s.io/cert-manager-webhook:dynamic-serving created
rolebinding.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection unchanged
rolebinding.rbac.authorization.k8s.io/cert-manager:leaderelection configured
rolebinding.rbac.authorization.k8s.io/cert-manager-webhook:dynamic-serving created
service/cert-manager created
service/cert-manager-webhook created
deployment.apps/cert-manager-cainjector created
deployment.apps/cert-manager created
deployment.apps/cert-manager-webhook created
mutatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook configured
validatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook configured
[INFO] Waiting for pods in namespace cert-manager (timeout: 180s)
pod/cert-manager-cainjector-5469cf6649-w2bds condition met
pod/cert-manager-dc97f5746-rnckb condition met
pod/cert-manager-webhook-54d9668fdc-wtt4t condition met
[INFO] All pods in cert-manager are ready
[INFO] Checking health for cert-manager in namespace cert-manager
[INFO] ✅ cert-manager: Running
[2025-08-22 02:44:59] cert-manager deployed successfully
[STEP] Deploying AWS Load Balancer Controller
[2025-08-22 02:44:59] Using local AWS LB Controller manifests...
serviceaccount/aws-load-balancer-controller created
clusterrole.rbac.authorization.k8s.io/aws-load-balancer-controller created
clusterrolebinding.rbac.authorization.k8s.io/aws-load-balancer-controller created
service/aws-load-balancer-webhook-service created
deployment.apps/aws-load-balancer-controller created
ingressclassparams.elbv2.k8s.aws/alb created
ingressclass.networking.k8s.io/alb created
pod/aws-load-balancer-controller-556bb6b786-qct26 condition met
pod/aws-load-balancer-controller-556bb6b786-rv6mg condition met
[INFO] Checking health for aws-load-balancer-controller in namespace kube-system
[INFO] ✅ AWS LB Controller: Running
[2025-08-22 02:45:14] AWS Load Balancer Controller deployed
[STEP] Deploying Vault
namespace/vault created
[2025-08-22 02:45:15] Using local Vault manifests...
serviceaccount/vault created
serviceaccount/vault-bootstrap created
role.rbac.authorization.k8s.io/vault-bootstrap created
rolebinding.rbac.authorization.k8s.io/vault-bootstrap created
configmap/vault-config created
service/vault created
service/vault-ui created
statefulset.apps/vault created
job.batch/vault-bootstrap created
[INFO] Waiting for pods in namespace vault (timeout: 120s)
pod/vault-0 condition met
pod/vault-bootstrap-89r8k condition met
[INFO] All pods in vault are ready
[INFO] Checking health for vault in namespace vault
[INFO] ✅ Vault: Running
[2025-08-22 02:45:36] Vault deployed successfully
[STEP] Deploying Platform UI
[2025-08-22 02:45:36] Using local Platform UI manifests...
Error from server (NotFound): error when creating "platform-services-v2/application-services/platform-ui": namespaces "platform-ui" not found
Error from server (NotFound): error when creating "platform-services-v2/application-services/platform-ui": namespaces "platform-ui" not found
Error from server (NotFound): error when creating "platform-services-v2/application-services/platform-ui": namespaces "platform-ui" not found
Error from server (NotFound): error when creating "platform-services-v2/application-services/platform-ui": namespaces "platform-ui" not found
ak@Alexanders-MBP base-app-layer % ./deploy-wave0-complete.sh
[2025-08-22 02:50:26] Starting Wave 0 Deployment - Platform Foundation
[2025-08-22 02:50:26] Environment: dev | Region: us-east-1 | Cluster: base-app-layer-dev-platform
[STEP] Validating Prerequisites
[INFO] Connected to cluster: arn:aws:eks:us-east-1:084129280818:cluster/platform-app-layer-dev
[INFO] Prerequisites validated successfully
[STEP] Deploying ArgoCD
[2025-08-22 02:50:28] Cleaning up existing ArgoCD resources...
namespace/argocd created
[2025-08-22 02:50:29] Deploying ArgoCD from upstream...
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-applicationset-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-notifications-controller created
serviceaccount/argocd-redis created
serviceaccount/argocd-repo-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-applicationset-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-notifications-controller created
role.rbac.authorization.k8s.io/argocd-redis created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-notifications-controller created
rolebinding.rbac.authorization.k8s.io/argocd-redis created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-cmd-params-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-notifications-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-notifications-secret created
secret/argocd-secret created
service/argocd-applicationset-controller created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-notifications-controller-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server created
service/argocd-server-metrics created
deployment.apps/argocd-applicationset-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-notifications-controller created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
statefulset.apps/argocd-application-controller created
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy created
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-redis-network-policy created
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy created
networkpolicy.networking.k8s.io/argocd-server-network-policy created
[INFO] Waiting for pods in namespace argocd (timeout: 300s)
pod/argocd-application-controller-0 condition met
pod/argocd-applicationset-controller-6ff6f74bc9-5kw2s condition met
pod/argocd-dex-server-558dc4bd7b-2c47c condition met
pod/argocd-notifications-controller-9977b5bd6-xm458 condition met
pod/argocd-redis-6594484976-ztf7r condition met
pod/argocd-repo-server-845d4f5c49-d6n6j condition met
pod/argocd-server-59d75f4c95-kfjkd condition met
[INFO] All pods in argocd are ready
configmap/argocd-cmd-params-cm patched
[INFO] Checking health for argocd in namespace argocd
[ERROR] ❌ ArgoCD: Failed
ak@Alexanders-MBP base-app-layer % ./deploy-wave0-complete.sh
[2025-08-22 02:53:03] Starting Wave 0 Deployment - Platform Foundation
[2025-08-22 02:53:03] Environment: dev | Region: us-east-1 | Cluster: base-app-layer-dev-platform
[STEP] Validating Prerequisites
[INFO] Connected to cluster: arn:aws:eks:us-east-1:084129280818:cluster/platform-app-layer-dev
[INFO] Prerequisites validated successfully
[STEP] Deploying ArgoCD
[2025-08-22 02:53:04] Cleaning up existing ArgoCD resources...
namespace/argocd created
[2025-08-22 02:53:06] Deploying ArgoCD from upstream...
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-applicationset-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-notifications-controller created
serviceaccount/argocd-redis created
serviceaccount/argocd-repo-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-applicationset-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-notifications-controller created
role.rbac.authorization.k8s.io/argocd-redis created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-notifications-controller created
rolebinding.rbac.authorization.k8s.io/argocd-redis created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-applicationset-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-cmd-params-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-notifications-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-notifications-secret created
secret/argocd-secret created
service/argocd-applicationset-controller created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-notifications-controller-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server created
service/argocd-server-metrics created
deployment.apps/argocd-applicationset-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-notifications-controller created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
statefulset.apps/argocd-application-controller created
networkpolicy.networking.k8s.io/argocd-application-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-applicationset-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-dex-server-network-policy created
networkpolicy.networking.k8s.io/argocd-notifications-controller-network-policy created
networkpolicy.networking.k8s.io/argocd-redis-network-policy created
networkpolicy.networking.k8s.io/argocd-repo-server-network-policy created
networkpolicy.networking.k8s.io/argocd-server-network-policy created
[INFO] Waiting for pods in namespace argocd (timeout: 300s)
pod/argocd-application-controller-0 condition met
pod/argocd-applicationset-controller-6ff6f74bc9-smp77 condition met
pod/argocd-dex-server-558dc4bd7b-fnm5z condition met
pod/argocd-notifications-controller-9977b5bd6-xqdr8 condition met
pod/argocd-redis-6594484976-r7grp condition met
pod/argocd-repo-server-845d4f5c49-d7jbj condition met
pod/argocd-server-59d75f4c95-jzt96 condition met
[INFO] All pods in argocd are ready
configmap/argocd-cmd-params-cm patched
[INFO] Checking health for argocd in namespace argocd
[INFO] ✅ ArgoCD: Running (7/       7 pods ready)
[INFO] ArgoCD admin password: SwTaL93m7BS-21H8
[2025-08-22 02:53:48] ArgoCD deployed successfully
[STEP] Deploying cert-manager
namespace/cert-manager created
Warning: resource namespaces/cert-manager is missing the kubectl.kubernetes.io/last-applied-configuration annotation which is required by kubectl apply. kubectl apply should only be used on resources created declaratively by either kubectl create --save-config or kubectl apply. The missing annotation will be patched automatically.
namespace/cert-manager configured
customresourcedefinition.apiextensions.k8s.io/certificaterequests.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/certificates.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/challenges.acme.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/clusterissuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/issuers.cert-manager.io created
customresourcedefinition.apiextensions.k8s.io/orders.acme.cert-manager.io created
serviceaccount/cert-manager-cainjector created
serviceaccount/cert-manager created
serviceaccount/cert-manager-webhook created
configmap/cert-manager created
configmap/cert-manager-webhook created
clusterrole.rbac.authorization.k8s.io/cert-manager-cainjector created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-issuers created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-certificates created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-orders created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-challenges created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim created
clusterrole.rbac.authorization.k8s.io/cert-manager-cluster-view created
clusterrole.rbac.authorization.k8s.io/cert-manager-view created
clusterrole.rbac.authorization.k8s.io/cert-manager-edit created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-approve:cert-manager-io created
clusterrole.rbac.authorization.k8s.io/cert-manager-controller-certificatesigningrequests created
clusterrole.rbac.authorization.k8s.io/cert-manager-webhook:subjectaccessreviews created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-cainjector created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-issuers created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-clusterissuers created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-certificates created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-orders created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-challenges created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-ingress-shim created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-approve:cert-manager-io created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-controller-certificatesigningrequests created
clusterrolebinding.rbac.authorization.k8s.io/cert-manager-webhook:subjectaccessreviews created
role.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection unchanged
role.rbac.authorization.k8s.io/cert-manager:leaderelection unchanged
role.rbac.authorization.k8s.io/cert-manager-webhook:dynamic-serving created
rolebinding.rbac.authorization.k8s.io/cert-manager-cainjector:leaderelection unchanged
rolebinding.rbac.authorization.k8s.io/cert-manager:leaderelection configured
rolebinding.rbac.authorization.k8s.io/cert-manager-webhook:dynamic-serving created
service/cert-manager created
service/cert-manager-webhook created
deployment.apps/cert-manager-cainjector created
deployment.apps/cert-manager created
deployment.apps/cert-manager-webhook created
mutatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook created
validatingwebhookconfiguration.admissionregistration.k8s.io/cert-manager-webhook created
[INFO] Waiting for pods in namespace cert-manager (timeout: 180s)
pod/cert-manager-cainjector-5469cf6649-zd6sb condition met
pod/cert-manager-dc97f5746-pbx9l condition met
pod/cert-manager-webhook-54d9668fdc-pjv76 condition met
[INFO] All pods in cert-manager are ready
[INFO] Checking health for cert-manager in namespace cert-manager
[INFO] ✅ cert-manager: Running (       3 pods ready)
[2025-08-22 02:54:01] cert-manager deployed successfully
[STEP] Deploying AWS Load Balancer Controller
[2025-08-22 02:54:01] Using local AWS LB Controller manifests...
serviceaccount/aws-load-balancer-controller created
clusterrole.rbac.authorization.k8s.io/aws-load-balancer-controller created
clusterrolebinding.rbac.authorization.k8s.io/aws-load-balancer-controller created
service/aws-load-balancer-webhook-service created
deployment.apps/aws-load-balancer-controller created
ingressclassparams.elbv2.k8s.aws/alb created
ingressclass.networking.k8s.io/alb created
pod/aws-load-balancer-controller-556bb6b786-jc9bf condition met
pod/aws-load-balancer-controller-556bb6b786-w549t condition met
[INFO] Checking health for aws-load-balancer-controller in namespace kube-system
[INFO] ✅ AWS LB Controller: Running (       2 pods ready)
[2025-08-22 02:54:14] AWS Load Balancer Controller deployed
[STEP] Deploying Vault
namespace/vault created
[2025-08-22 02:54:15] Using local Vault manifests...
serviceaccount/vault created
serviceaccount/vault-bootstrap created
role.rbac.authorization.k8s.io/vault-bootstrap created
rolebinding.rbac.authorization.k8s.io/vault-bootstrap created
configmap/vault-config created
service/vault created
service/vault-ui created
statefulset.apps/vault created
job.batch/vault-bootstrap created
[INFO] Waiting for pods in namespace vault (timeout: 120s)
pod/vault-0 condition met
pod/vault-bootstrap-94pwl condition met
[INFO] All pods in vault are ready
[INFO] Checking health for vault in namespace vault
[INFO] ✅ Vault: Running
[2025-08-22 02:54:39] Vault deployed successfully
[STEP] Deploying Platform UI
namespace/platform-ui created
[2025-08-22 02:54:40] Using local Platform UI manifests...
configmap/nginx-proxy-config created
service/platform-ui-proxy created
deployment.apps/platform-ui-proxy created
Warning: annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
ingress.networking.k8s.io/platform-ui-proxy-ingress created
[INFO] Waiting for pods in namespace platform-ui (timeout: 120s)
pod/platform-ui-proxy-6486b96564-hvhfg condition met
pod/platform-ui-proxy-6486b96564-kcqd5 condition met
[INFO] All pods in platform-ui are ready
[INFO] Checking health for platform-ui in namespace platform-ui
[INFO] ✅ Platform UI: Running
[2025-08-22 02:54:54] Platform UI deployed successfully
[STEP] Setting up GitOps Configuration
[2025-08-22 02:54:54] Configuring ArgoCD repositories...
secret/base-app-layer-repo created
secret/airflow-helm-repo created
secret/aws-eks-charts-repo created
secret/grafana-helm-repo created
secret/istio-helm-repo created
secret/kubeflow-helm-repo created
secret/bitnami-helm-repo created
secret/prometheus-helm-repo created
secret/hashicorp-helm-repo created
[2025-08-22 02:54:55] Configuring ArgoCD projects...
appproject.argoproj.io/aws-infrastructure created
appproject.argoproj.io/base-layer created
appproject.argoproj.io/ml-apps created
appproject.argoproj.io/monitoring-apps created
appproject.argoproj.io/orchestration-apps created
appproject.argoproj.io/platform-applications created
appproject.argoproj.io/platform-core created
appproject.argoproj.io/platform-orchestration created
appproject.argoproj.io/platform-shared created
appproject.argoproj.io/workflow-apps created
[2025-08-22 02:54:56] Applying Wave 0 ApplicationSet for future GitOps management...
applicationset.argoproj.io/wave0-core-services created
[2025-08-22 02:54:57] GitOps configuration completed
[STEP] Validating Wave 0 Deployment
[2025-08-22 02:54:57] === WAVE 0 COMPONENT STATUS ===
  ✅ argocd: Deployed & Healthy
  ✅ cert-manager: Deployed & Healthy
  ✅ aws-load-balancer-controller: Deployed & Healthy
  ✅ vault: Deployed & Healthy
  ✅ platform-ui: Deployed & Healthy
[2025-08-22 02:54:57] === CLUSTER STATUS ===
NAME                         STATUS   ROLES    AGE     VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                KERNEL-VERSION   CONTAINER-RUNTIME
ip-10-0-1-166.ec2.internal   Ready    <none>   13h     v1.33.1-eks-b9364f6   10.0.1.166    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-2-193.ec2.internal   Ready    <none>   23h     v1.33.1-eks-b9364f6   10.0.2.193    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-3-157.ec2.internal   Ready    <none>   13h     v1.33.1-eks-b9364f6   10.0.3.157    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-3-192.ec2.internal   Ready    <none>   7h48m   v1.33.1-eks-b9364f6   10.0.3.192    <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
ip-10-0-3-36.ec2.internal    Ready    <none>   11h     v1.33.1-eks-b9364f6   10.0.3.36     <none>        Bottlerocket OS 1.44.0 (aws-k8s-1.33)   6.12.37          containerd://2.0.5+bottlerocket
[2025-08-22 02:54:58] === NAMESPACES ===
argocd            Active   112s
cert-manager      Active   70s
platform-ui       Active   18s
vault             Active   43s
[2025-08-22 02:54:58] === SERVICE ENDPOINTS ===
NAMESPACE     NAME                        CLASS    HOSTS   ADDRESS                                                      PORTS   AGE
platform-ui   platform-ui-proxy-ingress   <none>   *       base-platform-ui-v2-1528159834.us-east-1.elb.amazonaws.com   80      18s
argocd         argocd-applicationset-controller          ClusterIP   172.20.206.230   <none>        7000/TCP,8080/TCP            108s
argocd         argocd-dex-server                         ClusterIP   172.20.42.151    <none>        5556/TCP,5557/TCP,5558/TCP   108s
argocd         argocd-metrics                            ClusterIP   172.20.64.114    <none>        8082/TCP                     108s
argocd         argocd-notifications-controller-metrics   ClusterIP   172.20.24.83     <none>        9001/TCP                     108s
argocd         argocd-redis                              ClusterIP   172.20.216.212   <none>        6379/TCP                     108s
argocd         argocd-repo-server                        ClusterIP   172.20.9.37      <none>        8081/TCP,8084/TCP            108s
argocd         argocd-server                             ClusterIP   172.20.221.132   <none>        80/TCP,443/TCP               107s
argocd         argocd-server-metrics                     ClusterIP   172.20.84.155    <none>        8083/TCP                     107s
cert-manager   cert-manager                              ClusterIP   172.20.53.29     <none>        9402/TCP                     68s
cert-manager   cert-manager-webhook                      ClusterIP   172.20.172.187   <none>        443/TCP                      68s
kube-system    aws-load-balancer-webhook-service         ClusterIP   172.20.134.136   <none>        443/TCP                      58s
platform-ui    platform-ui-proxy                         ClusterIP   172.20.190.101   <none>        80/TCP                       18s
vault          vault                                     ClusterIP   172.20.53.80     <none>        8200/TCP,8201/TCP            43s
vault          vault-ui                                  NodePort    172.20.116.102   <none>        8200:30200/TCP               42s
[STEP] Access Information

🔐 ArgoCD Access:
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  URL: https://localhost:8080
  Username: admin
  Password: SwTaL93m7BS-21H8

🔑 Vault Access:
  kubectl port-forward svc/vault -n vault 8200:8200
  URL: http://localhost:8200
  Token: root (dev mode)

🖥️  Platform UI Access:
  kubectl port-forward svc/platform-ui-proxy -n platform-ui 8081:80
  URL: http://localhost:8081

🌐 Load Balancer Access:
  URL: http://base-platform-ui-v2-1528159834.us-east-1.elb.amazonaws.com

📋 Next Steps:
  1. Access ArgoCD and verify GitOps setup
  2. Deploy Wave 1 ApplicationSet:
     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml
  3. Deploy Wave 2 ApplicationSet:
     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave2-monitoring-logging.yaml
  4. Deploy Wave 3 ApplicationSet:
     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave3-application-services.yaml
[2025-08-22 02:55:02] 🎉 Wave 0 deployment completed successfully!
[2025-08-22 02:55:02] Platform foundation is ready for Wave 1+ deployments
ak@Alexanders-MBP base-app-layer % 

## Prerequisites
- EKS cluster running
- kubectl configured
- AWS credentials configured

## Manual Deployment Commands

### 1. ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 2. Cert-Manager
```bash
kubectl create namespace cert-manager
kubectl apply -f platform-services-v2/core-services/cert-manager/cert-manager-installation.yaml
```

### 3. AWS Load Balancer Controller
```bash
kubectl apply -k platform-services-v2/core-services/aws-load-balancer-controller
```

### 4. Vault
```bash
kubectl create namespace vault
kubectl apply -f platform-services-v2/core-services/vault/vault.yaml
```

## Verification

### Check ArgoCD
```bash
kubectl get pods -n argocd
kubectl get svc argocd-server -n argocd
```

### Check Cert-Manager
```bash
kubectl get pods -n cert-manager
```

### Check AWS LB Controller
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Check Vault
```bash
kubectl get pods -n vault
```

## Access ArgoCD
```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Wave 0 Status
- ✅ ArgoCD: Deployed
- ✅ Cert-Manager: Deployed  
- ✅ AWS LB Controller: Deployed
- ⏳ Vault: Namespace cleanup in progress