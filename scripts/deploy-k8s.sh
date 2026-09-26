#!/bin/bash

###############################################################################
# Script de Deploy no Kubernetes
# Uso: ./deploy-k8s.sh
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deploy Kubernetes - UniFIAP Pay SPB${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se kubectl está instalado
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Erro: kubectl não encontrado${NC}"
    echo "Instale o kubectl primeiro: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Verificar conexão com cluster
echo -e "${BLUE}Verificando conexão com cluster Kubernetes...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Erro: Não foi possível conectar ao cluster${NC}"
    echo "Certifique-se de que o Kind (kind) ou outro cluster Kubernetes está rodando e que seu KUBECONFIG está apontando para ele"
    exit 1
fi
echo -e "${GREEN}✓ Conectado ao cluster${NC}"
echo ""

# Aplicar manifests
echo -e "${BLUE}Aplicando manifests Kubernetes...${NC}"
echo ""

kubectl apply -f k8s/01-namespace.yaml
echo -e "${GREEN}✓ Namespace criado${NC}"

kubectl apply -f k8s/02-configmap.yaml
echo -e "${GREEN}✓ ConfigMap criado${NC}"

kubectl apply -f k8s/03-secret.yaml
echo -e "${GREEN}✓ Secret criado${NC}"

kubectl apply -f k8s/09-rbac-serviceaccount.yaml
echo -e "${GREEN}✓ ServiceAccount criado${NC}"

kubectl apply -f k8s/10-rbac-role.yaml
echo -e "${GREEN}✓ Role criado${NC}"

kubectl apply -f k8s/11-rbac-rolebinding.yaml
echo -e "${GREEN}✓ RoleBinding criado${NC}"

kubectl apply -f k8s/04-pvc.yaml
echo -e "${GREEN}✓ PVC criado${NC}"

# Aguardar PVC estar bound
echo -e "${YELLOW}Aguardando PVC ficar bound...${NC}"
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/unifiapay-logs-pvc -n unifiapay --timeout=60s
echo -e "${GREEN}✓ PVC está bound${NC}"

kubectl apply -f k8s/05-deployment-api.yaml
echo -e "${GREEN}✓ Deployment API criado${NC}"

kubectl apply -f k8s/06-deployment-auditoria.yaml
echo -e "${GREEN}✓ Deployment Auditoria criado${NC}"

kubectl apply -f k8s/07-service-api.yaml
echo -e "${GREEN}✓ Services criados${NC}"

kubectl apply -f k8s/08-cronjob-fechamento.yaml
echo -e "${GREEN}✓ CronJob criado${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Deploy concluído!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Aguardar pods estarem prontos
echo -e "${BLUE}Aguardando pods ficarem prontos...${NC}"
kubectl wait --for=condition=ready pod -l app=api-pagamentos -n unifiapay --timeout=120s
echo -e "${GREEN}✓ Pods da API prontos${NC}"

echo ""
echo -e "${YELLOW}Status dos recursos:${NC}"
echo ""
kubectl get all -n unifiapay

echo ""
echo -e "${YELLOW}Comandos úteis:${NC}"
echo "  Ver pods:        kubectl get pods -n unifiapay"
echo "  Ver logs API:    kubectl logs -l app=api-pagamentos -n unifiapay --tail=50"
echo "  Ver logs Audit:  kubectl logs -l app=auditoria-service -n unifiapay --tail=50"
echo "  Escalar API:     kubectl scale deployment api-pagamentos --replicas=3 -n unifiapay"
echo "  Ver CronJobs:    kubectl get cronjob -n unifiapay"
echo "  Testar API (via port-forward): kubectl -n unifiapay port-forward svc/api-pagamentos-service 30080:8080 & then curl http://localhost:30080/health"
echo ""
echo -e "${GREEN}Para acessar a API externamente:${NC}"
if command -v kind &> /dev/null; then
    echo "  Para acesso rápido com kind: kubectl -n unifiapay port-forward svc/api-pagamentos-service 30080:8080 &"
else
    echo "  Para expor localmente: kubectl -n unifiapay port-forward svc/api-pagamentos-service 30080:8080 &"
fi
