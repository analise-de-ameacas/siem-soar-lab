# Deploy em WSL / Ubuntu

Passos rápidos para rodar o lab (Wazuh single-node + Shuffle) usando WSL/Ubuntu.

Pré-requisitos
- Docker Desktop instalado e com WSL2 integrado
- WSL2 distro (Ubuntu) com Docker CLI funcionando
- Pelo menos 4GB de memória alocada ao Docker Desktop (recomendado 6GB)

1) Ajustes no Docker Desktop
- Abra Docker Desktop → Settings → Resources → Advanced → Memory: 6GB (ou >=4GB)
- Apply & Restart

2) Preparar os volumes e permissões (no WSL/Ubuntu)
```bash
cd ~/path/to/siem-soar-lab/deploy/linux
./ensure_volumes.sh
```

3) Iniciar todos os serviços
```bash
./start_all.sh
```

4) Verificar logs e status
```bash
cd ../shuffle/Shuffle
docker compose ps
docker compose logs --tail 200 opensearch
```

5) Simular brute-force (após registrar o agente)
```bash
./simulate_bruteforce.sh
```

Observações
- Se preferir que o Shuffle use um volume docker gerenciado (padrão do repo), não use o `docker-compose.override.yml`.
- Se o OpenSearch não subir por falta de memória, reduza temporariamente o heap em `shuffle/Shuffle/docker-compose.yml` alterando `OPENSEARCH_JAVA_OPTS` para 1024m (apenas para testes).
