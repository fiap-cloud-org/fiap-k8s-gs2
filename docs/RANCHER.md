# Rancher: painel para o namespace unifiapay

A Global Solution pede o Rancher para acompanhar de forma visual os Pods, Jobs e CronJobs do namespace `unifiapay`. O Rancher roda em um container Docker ao lado do cluster kind e o cluster é importado no painel.

> Este guia foi usado na entrega de novembro de 2025. Na revisão do repositório, o fluxo da aplicação foi testado de novo no Docker Compose e no kind, mas o Rancher não foi reinstalado.

## 1. Subir o Rancher

```bash
export RANCHER_BOOTSTRAP_PASSWORD='<escolha-uma-senha-forte>'
./scripts/setup-rancher.sh
```

O script cria o container `rancher` com a senha do primeiro login vinda de `RANCHER_BOOTSTRAP_PASSWORD` (variável `CATTLE_BOOTSTRAP_PASSWORD` da imagem), expõe `https://localhost:8443` e usa a porta HTTP `8081`, porque a `8080` é da `api-pagamentos`. A senha não é impressa nem gravada em arquivo.

Equivalente manual:

```bash
docker run -d --name rancher --restart=unless-stopped \
  -p 8081:80 -p 8443:443 \
  -e CATTLE_BOOTSTRAP_PASSWORD="$RANCHER_BOOTSTRAP_PASSWORD" \
  --privileged rancher/rancher:latest
```

Se o container já existia sem a variável, a senha gerada pelo Rancher aparece nos logs (`docker logs rancher 2>&1 | grep "Bootstrap Password:"`). Não salve essa saída no repositório.

## 2. Primeiro acesso

1. Abra `https://localhost:8443` e aceite o certificado autoassinado.
2. Entre com a senha de bootstrap e defina a senha definitiva.
3. Em **Server URL**, use o IP do host na rede local (ex.: `https://192.168.0.10:8443`). Com `localhost`, o agente que roda dentro do kind não alcança o Rancher.

## 3. Importar o cluster kind

1. **Cluster Management > Import Existing > Generic**, nome `unifiapay-kind`.
2. Com o `kubectl` no contexto do kind, rode o comando gerado pelo painel:

   ```bash
   kubectl config use-context kind-unifiapay
   curl --insecure -sfL https://<ip-do-host>:8443/v3/import/<token-gerado>.yaml | kubectl apply -f -
   ```

   O token da URL é gerado pelo Rancher para cada importação: não versione esse comando.
3. Espere o cluster ficar **Active** (`kubectl -n cattle-system get pods` mostra o `cattle-cluster-agent`).

## 4. O que acompanhar no painel

| Tela | O que mostra |
|---|---|
| Workloads > Pods (namespace `unifiapay`) | 2 réplicas da `api-pagamentos` e 1 da `auditoria-service` |
| Workloads > CronJobs | `cronjob-fechamento-reserva`, agenda `0 */6 * * *`, e os Jobs criados |
| Pod > View Logs | Logs em tempo real dos PIX registrados e das liquidações |
| Storage > PersistentVolumeClaims | `unifiapay-logs-pvc` (livro-razão) em `Bound` |

## 5. Remover

```bash
docker rm -f rancher
```

No cluster, apague o namespace `cattle-system` e os recursos `cattle-*` criados pela importação, ou apague o cluster kind inteiro.
