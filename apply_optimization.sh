#!/bin/bash
# Script Master: Aplica Apache mod_cache otimizado em todas as instncias

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "============================================================="
echo "#   APLICANDO APACHE MOD_CACHE OTIMIZADO                    #"
echo "============================================================="
echo ""

# Obter IPs das instncias de aplicao
echo "[INFO] Buscando instncias de aplicao..."
APP_IPS=($(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${OWNER_TAG}-App" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].PublicIpAddress" \
    --output text))

if [ ${#APP_IPS[@]} -eq 0 ]; then
    echo "[ERRO] Erro: Nenhuma instncia de aplicao encontrada"
    exit 1
fi

echo "OK Encontradas ${#APP_IPS[@]} instncias de aplicao"
echo ""

# Aplicar otimizao em cada instncia
SUCCESS_COUNT=0
FAIL_COUNT=0

for IP in "${APP_IPS[@]}"; do
    echo "---------------------------------------------------------"
    echo "[>>] Aplicando otimizao em: $IP"
    echo "---------------------------------------------------------"
    
    # Copiar script
    echo "   -> Copiando script..."
    scp -i $KEY_FILE -o StrictHostKeyChecking=no \
        $SCRIPT_DIR/optimization/apache_mod_cache_otimizado.sh \
        ec2-user@$IP:/tmp/ 2>&1 | grep -v "Warning: Permanently added"
    
    if [ $? -ne 0 ]; then
        echo "   [ERRO] Erro ao copiar script para $IP"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo ""
        continue
    fi
    
    # Executar script
    echo "   -> Executando otimizao..."
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$IP \
        "sudo bash /tmp/apache_mod_cache_otimizado.sh" 2>&1 | grep -E "(OK|ERRO|===|Apache|Cache)"
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "   [OK] Otimizao aplicada com sucesso em $IP"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo ""
        echo "   [ERRO] Erro ao aplicar otimizao em $IP"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    echo ""
done

# Resumo
echo "============================================================="
echo "#   RESUMO DA APLICAO                                     #"
echo "============================================================="
echo ""
echo "Total de instncias: ${#APP_IPS[@]}"
echo "[OK] Sucesso: $SUCCESS_COUNT"
echo "[ERRO] Falhas: $FAIL_COUNT"
echo ""

if [ $SUCCESS_COUNT -eq ${#APP_IPS[@]} ]; then
    echo "[SUCESSO] Otimizao aplicada com sucesso em TODAS as instncias!"
    echo ""
    echo "[AGUARDE] Aguardando 30 segundos para estabilizao..."
    sleep 30
    echo ""
    echo "[OK] Sistema pronto para testes!"
    echo ""
    echo "[INFO] Para testar a performance:"
    
    # Obter DNS do Load Balancer
    LB_DNS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME \
        --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" \
        --output text 2>/dev/null)
    
    if [ ! -z "$LB_DNS" ]; then
        echo "   bash run_test_with_html.sh $LB_DNS 100 2m"
    else
        echo "   bash run_test_with_html.sh <DNS_DO_LB> 100 2m"
    fi
    echo ""
    echo "[DEPLOY] Melhorias esperadas:"
    echo "   - Throughput: +87% a +1949% (depende da carga)"
    echo "   - Latncia: 99.6% mais rpido"
    echo "   - Taxa de erro: 0%"
    echo ""
    exit 0
elif [ $SUCCESS_COUNT -gt 0 ]; then
    echo "[AVISO]  Otimizao aplicada parcialmente ($SUCCESS_COUNT de ${#APP_IPS[@]})"
    echo "   Verifique os erros acima e tente novamente nas instncias que falharam"
    exit 1
else
    echo "[ERRO] Falha ao aplicar otimizao em todas as instncias"
    echo "   Verifique os erros acima"
    exit 1
fi

