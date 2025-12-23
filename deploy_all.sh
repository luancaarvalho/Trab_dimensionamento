#!/bin/bash
# deploy_all.sh - Script Master de Orquestrao
# Executa todo o processo de deploy na sequncia correta

set -e  # Para na primeira falha

# --- Carrega configuraes ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# --- Validaes de Pr-requisitos ---
echo "========================================="
echo " VALIDANDO PR-REQUISITOS"
echo "========================================="

# Verifica se a chave PEM existe
if [ ! -f "$SCRIPT_DIR/$KEY_FILE" ]; then
    echo "ERRO: Arquivo $KEY_FILE no encontrado em $SCRIPT_DIR"
    exit 1
fi

# Verifica permisses da chave
chmod 400 "$SCRIPT_DIR/$KEY_FILE" 2>/dev/null || true

# Verifica se AWS CLI est instalado
if ! command -v aws &> /dev/null; then
    echo "ERRO: AWS CLI no est instalado"
    exit 1
fi

# Verifica credenciais AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERRO: Credenciais AWS invlidas ou no configuradas"
    exit 1
fi

echo "OK Pr-requisitos validados"
echo ""

# --- 1. Criar Stack CloudFormation ---
echo "========================================="
echo " PASSO 1: CRIANDO STACK CLOUDFORMATION"
echo "========================================="

# Verifica se a stack j existe
STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "NONE")

if [ "$STACK_EXISTS" != "NONE" ] && [ "$STACK_EXISTS" != "DELETE_COMPLETE" ]; then
    echo "AVISO: Stack $STACK_NAME j existe (Status: $STACK_EXISTS)"
    echo "       Pulando criao da stack..."
else
    echo "Criando stack CloudFormation..."
    aws cloudformation create-stack \
        --stack-name $STACK_NAME \
        --template-body file://$SCRIPT_DIR/lab-arena.yaml \
        --parameters ParameterKey=KeyName,ParameterValue=$KEY_NAME \
        --capabilities CAPABILITY_IAM
    
    echo "Aguardando stack ficar pronta (isso pode levar 3-5 minutos)..."
    aws cloudformation wait stack-create-complete --stack-name $STACK_NAME
    
    echo "OK Stack criada com sucesso"
fi

# Obtm o DNS do Load Balancer
LB_DNS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerDNS'].OutputValue" --output text)
echo "Load Balancer DNS: $LB_DNS"
echo ""

# --- 2. Deploy da Aplicao ---
echo "========================================="
echo " PASSO 2: DEPLOY DA APLICAO"
echo "========================================="
bash "$SCRIPT_DIR/deploy_app.sh"
echo ""

# --- 3. Deploy do Gerador de Carga ---
echo "========================================="
echo " PASSO 3: DEPLOY DO GERADOR DE CARGA"
echo "========================================="
bash "$SCRIPT_DIR/deploy_generator.sh"
echo ""

# --- 4. Aguardar Instncias Ficarem Saudveis ---
echo "========================================="
echo " PASSO 4: AGUARDANDO INSTNCIAS FICAREM SAUDVEIS"
echo "========================================="

echo "Aguardando 60 segundos para instncias inicializarem..."
sleep 60

# Verifica health check do Load Balancer
echo "Verificando health check do Load Balancer..."
TG_ARN=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='TargetGroupARN'].OutputValue" --output text)

MAX_RETRIES=30
RETRY_COUNT=0
HEALTHY=false

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HEALTHY_COUNT=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --query "TargetHealthDescriptions[?TargetHealth.State=='healthy'].TargetHealth.State" --output text | wc -w)
    
    if [ "$HEALTHY_COUNT" -gt 0 ]; then
        HEALTHY=true
        echo "OK $HEALTHY_COUNT instncia(s) saudvel(is) no Load Balancer"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Aguardando instncias ficarem saudveis... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

if [ "$HEALTHY" = false ]; then
    echo "AVISO: Instncias ainda no esto saudveis aps $MAX_RETRIES tentativas"
    echo "       Verifique manualmente o status do Load Balancer"
fi

echo ""

# --- 5. Resumo Final ---
echo "========================================="
echo " DEPLOY CONCLUDO!"
echo "========================================="
echo ""
echo "URL da Aplicao: http://$LB_DNS"
echo ""
echo "Para testar a aplicao:"
echo "  ./run_remote_test.sh $LB_DNS 10 1m"
echo ""
echo "Para monitorar:"
echo "  ./monitor.sh"
echo ""
echo "Para destruir tudo:"
echo "  ./teardown.sh all"
echo ""


