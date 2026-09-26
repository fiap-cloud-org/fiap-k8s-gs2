#!/bin/bash

###############################################################################
# Script de Teste de Comunicação entre Containers
# Gera evidências para Etapa 2 do desafio
###############################################################################

set -e

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Teste de Comunicação - Containers${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Voltar para raiz do projeto
cd "$(dirname "$0")/.."
BASE_DIR=$(pwd)
EVIDENCIAS_DIR="$BASE_DIR/evidencias/etapa2-rede"

echo -e "${BLUE}[1/8] Criando pasta de evidências...${NC}"
mkdir -p "$EVIDENCIAS_DIR"
echo -e "${GREEN}✓ Pasta criada: $EVIDENCIAS_DIR${NC}"
echo ""

echo -e "${BLUE}[2/8] Verificando containers...${NC}"
cd docker
docker compose ps
echo ""

echo -e "${BLUE}[3/8] Subindo containers (se necessário)...${NC}"
docker compose up -d
sleep 3
echo -e "${GREEN}✓ Containers iniciados${NC}"
echo ""

echo -e "${BLUE}[4/8] Verificando IPs dos containers...${NC}"
API_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' api-pagamentos)
AUD_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' auditoria-service)
echo "  API Pagamentos: $API_IP (esperado: 172.25.0.10)"
echo "  Auditoria:      $AUD_IP (esperado: 172.25.0.20)"
echo ""

echo -e "${BLUE}[5/8] Salvando evidência 1 - Inspeção da rede...${NC}"
docker network inspect unifiap_net > "$EVIDENCIAS_DIR/01-docker-network-inspect.txt"
echo -e "${GREEN}✓ Salvo: 01-docker-network-inspect.txt${NC}"
echo ""

# As imagens python:slim não têm ping nem curl: os testes usam o próprio Python
echo -e "${BLUE}[6/8] Testando HTTP: auditoria-service → api-pagamentos ($API_IP:8080)...${NC}"
docker exec auditoria-service python -c "import urllib.request; print(urllib.request.urlopen('http://$API_IP:8080/health', timeout=5).read().decode())" \
  | tee "$EVIDENCIAS_DIR/02-http-auditoria-to-api.txt"
echo -e "${GREEN}✓ Salvo: 02-http-auditoria-to-api.txt${NC}"
echo ""

echo -e "${BLUE}[7/8] Testando conexão TCP: api-pagamentos → auditoria-service ($AUD_IP)...${NC}"
docker exec api-pagamentos python -c "
import socket
s = socket.socket(); s.settimeout(3)
r = s.connect_ex(('$AUD_IP', 9))
print('host $AUD_IP alcançável na rede unifiap_net' if r in (0, 111) else f'sem rota até $AUD_IP (erro {r})')
" | tee "$EVIDENCIAS_DIR/02-tcp-api-to-auditoria.txt"
echo -e "${GREEN}✓ Salvo: 02-tcp-api-to-auditoria.txt${NC}"
echo ""

echo -e "${BLUE}[8/8] Salvando logs da API (variáveis de ambiente)...${NC}"
docker compose logs api-pagamentos | head -n 50 > "$EVIDENCIAS_DIR/03-logs-env-vars.txt"
echo -e "${GREEN}✓ Salvo: 03-logs-env-vars.txt${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Testes concluídos!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Evidências salvas em:${NC}"
ls -lh "$EVIDENCIAS_DIR"
echo ""

echo -e "${YELLOW}Testando API externamente:${NC}"
echo -e "${BLUE}Health Check:${NC}"
curl -s "${API_URL:-http://localhost:8080}/health" | jq . || echo "API não respondeu ou jq não instalado"
echo ""

echo -e "${BLUE}Reserva Bancária:${NC}"
curl -s "${API_URL:-http://localhost:8080}/api/v1/reserva" | jq . || echo "API não respondeu ou jq não instalado"
echo ""

echo -e "${GREEN}✓ Etapa 2 - Rede, Comunicação e Segmentação completa!${NC}"
