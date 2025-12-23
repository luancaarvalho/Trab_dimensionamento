#!/bin/bash
# Script para rodar bateria completa de testes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Obter DNS do Load Balancer
LB_DNS=$(cat .lb_dns 2>/dev/null || aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" --output text 2>/dev/null)

if [ -z "$LB_DNS" ]; then
    echo "ERRO: Nao foi possivel obter o DNS do Load Balancer"
    exit 1
fi

# Obter IP do gerador
GENERATOR_IP=$(cat .generator_ip 2>/dev/null || aws ec2 describe-instances --filters "Name=tag:Name,Values=${OWNER_TAG}-Generator" "Name=instance-state-name,Values=running" --query "Reservations[].Instances[].PublicIpAddress" --output text)

if [ -z "$GENERATOR_IP" ]; then
    echo "ERRO: Nao foi possivel obter o IP do gerador"
    exit 1
fi

# Criar pasta de resultados com timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="bateria_apache_cache_$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "==========================================="
echo " BATERIA DE TESTES"
echo "==========================================="
echo "Load Balancer: $LB_DNS"
echo "Gerador: $GENERATOR_IP"
echo "Pasta de resultados: $RESULTS_DIR"
echo ""

# Array de configuracoes de teste
USERS=(100 300 600 900 1100)
DURATION="2m"

for USERS_COUNT in "${USERS[@]}"; do
    echo "==========================================="
    echo " TESTE: $USERS_COUNT usuarios por $DURATION"
    echo "==========================================="
    
    TEST_DIR="resultados_${USERS_COUNT}users_${DURATION}_$(date +%Y%m%d_%H%M%S)"
    
    # Executar teste remoto
    echo "Iniciando teste no gerador..."
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$GENERATOR_IP << EOSSH
cd /home/ec2-user
locust -f locustfile.py \
    --headless \
    --users $USERS_COUNT \
    --spawn-rate 10 \
    --run-time $DURATION \
    --host http://$LB_DNS \
    --html index.html \
    --csv dados 2>&1 | tee teste_completo.log
EOSSH
    
    if [ $? -ne 0 ]; then
        echo "ERRO: Falha ao executar teste"
        continue
    fi
    
    echo "Baixando resultados..."
    mkdir -p "$RESULTS_DIR/$TEST_DIR"
    
    # Baixar HTML do Locust
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/index.html \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    # Baixar todos os CSVs do Locust
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/dados_stats.csv \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/dados_stats_history.csv \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/dados_failures.csv \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/dados_exceptions.csv \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    # Baixar log de execucao
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        ec2-user@$GENERATOR_IP:/home/ec2-user/teste_completo.log \
        "$RESULTS_DIR/$TEST_DIR/" 2>/dev/null
    
    echo "OK Resultados salvos em: $RESULTS_DIR/$TEST_DIR"
    echo ""
    
    # Aguardar 10 segundos entre testes
    if [ "$USERS_COUNT" != "${USERS[-1]}" ]; then
        echo "Aguardando 10 segundos antes do proximo teste..."
        sleep 10
    fi
done

echo "==========================================="
echo " BATERIA COMPLETA!"
echo "==========================================="
echo "Todos os resultados em: $RESULTS_DIR"
echo ""

# Criar log de execucao
cat > "$RESULTS_DIR/execucao.log" << EOF
Bateria de Testes - Apache mod_cache Otimizado
Data: $(date)
Load Balancer: $LB_DNS
Gerador: $GENERATOR_IP

Testes executados:
$(for u in "${USERS[@]}"; do echo "- $u usuarios por $DURATION"; done)

Status: Completa
EOF

echo "Log de execucao salvo em: $RESULTS_DIR/execucao.log"

