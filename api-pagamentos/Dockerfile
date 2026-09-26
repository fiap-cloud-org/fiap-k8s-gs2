# Stage 1: Build
FROM python:3.11-slim AS builder

WORKDIR /build

# Copiar apenas requirements primeiro (cache layer)
COPY requirements.txt .

# Instalar dependências
RUN pip install --no-cache-dir --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.11-slim

# Criar usuário não-root para segurança
RUN useradd -m -u 1000 appuser && \
    mkdir -p /var/logs/api && \
    chown -R appuser:appuser /var/logs/api

WORKDIR /app

# Copiar dependências do stage de build
COPY --from=builder /root/.local /home/appuser/.local

# Copiar código da aplicação
COPY --chown=appuser:appuser . .

# Configurar PATH para incluir binários do pip
ENV PATH=/home/appuser/.local/bin:$PATH

# Trocar para usuário não-root
USER appuser

# Expor porta
EXPOSE 8080

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8080/health')" || exit 1

# Comando de inicialização
CMD ["python", "app.py"]
