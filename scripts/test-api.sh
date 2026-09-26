#!/bin/bash

###############################################################################
# Script de Teste da API - Simula transações PIX
# Uso: ./test-api.sh
###############################################################################

set -e

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Obter URL da API
API_URL="http://localhost:30080"

# Verificar se kubectl está disponível e iniciar port-forward
if command -v kubectl &> /dev/null; then
  echo "Iniciando port-forward para o service api-pagamentos (localhost:30080 -> svc/api-pagamentos-service:8080)..."
  kubectl -n unifiapay port-forward svc/api-pagamentos-service 30080:8080 >/dev/null 2>&1 &
  PF_PID=$!
  # Garantir que o port-forward seja finalizado ao sair
  trap 'echo "Parando port-forward (pid $PF_PID)"; kill $PF_PID >/dev/null 2>&1 || true' EXIT
  sleep 2  # Aguarda o port-forward estar pronto
else
  echo "⚠️  kubectl não encontrado - assumindo que a API está disponível em http://localhost:30080"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Teste da API - UniFIAP Pay${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "API URL: ${YELLOW}${API_URL}${NC}"
echo ""

# Teste 1: Health Check
echo -e "${BLUE}[1/4] Health Check...${NC}"
curl -s ${API_URL}/health | jq .
echo ""

# Teste 2: Consultar Reserva
echo -e "${BLUE}[2/4] Consultar Reserva Bancária...${NC}"
curl -s ${API_URL}/api/v1/reserva | jq .
echo ""

# Teste 3: PIX Válido
echo -e "${BLUE}[3/4] Enviar PIX válido (R\$ 100,00)...${NC}"
curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{
    "valor": 100.00,
    "chave_destino": "teste@email.com",
    "descricao": "Teste PIX válido"
  }' | jq .
echo ""

# Teste 4: PIX Inválido (valor maior que reserva)
echo -e "${BLUE}[4/4] Enviar PIX inválido (valor > reserva)...${NC}"
curl -s -X POST ${API_URL}/api/v1/pix \
  -H "Content-Type: application/json" \
  -d '{
    "valor": 99999999.00,
    "chave_destino": "teste@email.com",
    "descricao": "Teste PIX inválido"
  }' | jq .
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Testes concluídos!${NC}"
echo -e "${GREEN}========================================${NC}"
