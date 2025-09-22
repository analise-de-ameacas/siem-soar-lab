# Simula um brute-force gerando várias falhas de login no agente do Wazuh local
# Este script assume que o agente Wazuh está registrado e que existe um container agent disponível.

# Local do container do agente (ajuste conforme necessário)
$agentContainer = 'wazuh-agent'

if (-not (docker ps -a --format "{{.Names}}" | Select-String $agentContainer)) {
    Write-Host "Container do agente '$agentContainer' não encontrado. Crie um agente ou ajuste o nome do container."
    exit 1
}

# Executa múltiplas tentativas de SSH falhas no container para simular brute-force
for ($i=0; $i -lt 30; $i++) {
    docker exec $agentContainer bash -c "echo 'invalid' | sudo -S false >/dev/null 2>&1 || true"
}

Write-Host "Simulação concluída. Aguarde Wazuh processar os alertas."
