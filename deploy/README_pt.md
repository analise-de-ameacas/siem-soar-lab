# Deploy SIEM + SOAR (Wazuh + Shuffle) - Guia rápido (PT-BR)

Este diretório contém artefatos para subir uma stack de Wazuh (single-node) e integrar ao Shuffle (SOAR) usando Docker Compose.

Pré-requisitos
- Docker e Docker Compose instalados na máquina host.
- Powershell (Windows) ou shell equivalente.
- Ter acesso à internet para baixar imagens oficiais.

Passos resumidos
1. Criar a network Docker externa:
   - O script `start_all.ps1` já cria a network `siem-net` se não existir.
2. Subir o Wazuh:
   - `.
un\start_all.ps1` (ou execute os comandos listados abaixo)
3. Subir o Shuffle:
   - O Compose do Shuffle foi modificado para usar a network `siem-net`.

Como funciona a integração
- Um forwarder (pequeno container Python) irá consultar a API do Wazuh e encaminhar alertas para um webhook do Shuffle.
- No Shuffle você deve criar um trigger/Webhook que recebe o JSON de alerta e inicia um workflow.
- No workflow do Shuffle, adicione um step que chama a API do Wazuh para coletar o evento, e outro step que chama um modelo de IA (ex.: Gemini) para análise.

Configurações importantes
- Use sempre o IP da máquina host (ex.: 192.168.1.10) para acessar as interfaces do Wazuh e do Shuffle a partir de outros hosts.
- Não use `localhost` para links entre containers.
- Verifique se portas 5601, 9200, 5001, etc. não conflitam com serviços existentes; ajuste os mapeamentos caso necessário.

Como obter chave API Gemini (opcional)
- Siga o passo-a-passo em https://ai.google.dev/gemini-api/docs/api-key?hl=pt-br ou acesse o Google AI Studio: https://aistudio.google.com/app/apikey

Simulação de evento (Brute-force)
- Use `simulate_bruteforce.ps1` para gerar tentativas de login falhas no agente e provocar alertas de segurança no Wazuh.

Próximos passos recomendados
- Criar um workflow no Shuffle que receba o webhook e acione o modelo de IA para análise.
- Melhorar o forwarder: autenticação com API key, filtragem de alertas duplicados, retries.
- Criar pipeline que bloqueie IPs via firewall ou roteador (ex.: via iptables em hosts Linux ou chamada para API do roteador).

Exemplo rápido de configuração no Shuffle
- Crie um Webhook Trigger no Shuffle (crie um trigger do tipo "Webhook" e copie a URL).
- Preencha `SHUFFLE_WEBHOOK` no arquivo `.env` do `deploy/wazuh-forwarder` com essa URL.
- Importe (ou crie) um workflow simples no Shuffle com os passos:
   1) Trigger: recebe o payload do forwarder contendo o alerta do Wazuh.
   2) Action: chama a API do Wazuh para buscar detalhes do alerta (opcional).
   3) Action: chama um modelo de IA (ex.: Gemini) via API para analisar o evento e sugerir ação.
   4) Action: se IA recomendar bloqueio, execute um step que chama um endpoint que aplique um bloqueio (ex.: API do firewall, ou execução de comando em host gerenciado).

Importante: o forwarder atual é um exemplo mínimo. Para produção, implemente autenticação com a API do Wazuh, tracking de último alert id, e deduplicação.


