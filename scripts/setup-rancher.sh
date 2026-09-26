#!/bin/bash

###############################################################################
# Script de Setup do Rancher
# Uso: ./setup-rancher.sh
###############################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Rancher - UniFIAP Pay SPB${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar se Docker está rodando
if ! docker info &> /dev/null; then
    echo -e "${RED}Erro: Docker não está rodando${NC}"
    echo "Inicie o Docker primeiro"
    exit 1
fi
echo -e "${GREEN}✓ Docker está rodando${NC}"

# Verificar se já existe container Rancher
if docker ps -a --format '{{.Names}}' | grep -q '^rancher$'; then
    echo -e "${YELLOW}Container Rancher já existe${NC}"
    
    # Verificar se está rodando
    if docker ps --format '{{.Names}}' | grep -q '^rancher$'; then
        echo -e "${GREEN}✓ Rancher já está rodando${NC}"
        echo ""
        echo -e "${BLUE}Para obter a senha de bootstrap:${NC}"
        echo "  docker logs rancher 2>&1 | grep 'Bootstrap Password:'"
        echo ""
        echo -e "${BLUE}Acesse o Rancher em:${NC}"
        echo -e "  ${YELLOW}https://localhost:8443${NC}"
        echo ""
        exit 0
    else
        echo -e "${YELLOW}Iniciando container Rancher existente...${NC}"
        docker start rancher
        echo -e "${GREEN}✓ Rancher iniciado${NC}"
        sleep 5
    fi
else
    echo -e "${BLUE}Criando novo container Rancher...${NC}"
    
    # Subir Rancher
    docker run -d \
      --name rancher \
      --restart=unless-stopped \
      -p 8080:80 -p 8443:443 \
      --privileged \
      rancher/rancher:latest
    
    echo -e "${GREEN}✓ Container Rancher criado${NC}"
    echo ""
    echo -e "${YELLOW}Aguardando Rancher inicializar (isso pode levar 1-2 minutos)...${NC}"
    sleep 30
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Rancher está pronto!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Obter senha de bootstrap
echo -e "${BLUE}Obtendo senha de bootstrap...${NC}"
sleep 2

BOOTSTRAP_PASSWORD=$(docker logs rancher 2>&1 | grep "Bootstrap Password:" | head -1 | awk '{print $NF}')

if [ -z "$BOOTSTRAP_PASSWORD" ]; then
    echo -e "${YELLOW}Senha de bootstrap ainda não disponível.${NC}"
    echo -e "${YELLOW}Execute o comando abaixo em alguns segundos:${NC}"
    echo ""
    echo -e "${BLUE}docker logs rancher 2>&1 | grep 'Bootstrap Password:'${NC}"
else
    echo -e "${GREEN}✓ Senha de Bootstrap obtida:${NC}"
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "  ${BOOTSTRAP_PASSWORD}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    echo -e "${YELLOW}A senha não é gravada em arquivo: troque-a no primeiro login.${NC}"
fi

echo ""
echo -e "${BLUE}Próximos passos:${NC}"
echo ""
echo "1. Acesse o Rancher:"
echo -e "   ${YELLOW}https://localhost:8443${NC}"
echo ""
echo "2. Aceite o certificado auto-assinado no navegador"
echo ""
echo "3. Faça login com a senha de bootstrap mostrada acima"
echo ""
echo "4. Defina uma nova senha administrativa"
echo ""
echo "5. Importar cluster Kind:"
echo "   - Cluster Management → Import Existing → Generic"
echo "   - Nome: unifiapay-kind"
echo "   - Copiar comando kubectl apply e executar"
echo ""
echo -e "${BLUE}Comandos úteis:${NC}"
echo "  Ver logs:        docker logs -f rancher"
echo "  Parar Rancher:   docker stop rancher"
echo "  Reiniciar:       docker restart rancher"
echo "  Remover:         docker stop rancher && docker rm rancher"
echo ""

# Verificar se Kind está rodando
if kind get clusters 2>/dev/null | grep -q 'unifiapay'; then
    echo -e "${GREEN}✓ Cluster Kind 'unifiapay' detectado${NC}"
    echo ""
    echo -e "${YELLOW}Para conectar o Kind ao Rancher:${NC}"
    echo "1. No Rancher: Cluster Management → Import Existing"
    echo "2. Copiar comando kubectl apply gerado"
    echo "3. Executar no terminal (contexto: kind-unifiapay)"
else
    echo -e "${YELLOW}⚠️  Cluster Kind 'unifiapay' não encontrado${NC}"
    echo "   Crie o cluster primeiro com: kind create cluster --name unifiapay"
fi

echo ""
echo -e "${GREEN}Setup concluído!${NC}"
