# Relatório de Testes - Apache mod_cache Otimizado

**Data:** 23/12/2025  
**Estratégia:** Apache mod_cache com `CacheQuickHandler off`

---

## 🎯 Estratégia de Otimização

### Solução Implementada
**Apache mod_cache em nível de servidor** com correção do erro 403 Forbidden

**Configuração-chave:**
```apache
CacheEnable disk "/"
CacheRoot "/var/cache/httpd/mod_cache_disk"
CacheIgnoreHeaders Set-Cookie Cookie
CacheQuickHandler off  # ← CRÍTICO: resolve o erro 403
```

### Por que funciona?
- **Cache em nível de servidor:** Apache serve páginas antes do PHP processar
- **CacheQuickHandler off:** Cache passa pela fase de autorização do Apache
- **CacheIgnoreHeaders Cookie:** Permite cache funcionar com Load Balancer

---

## 📊 Resultados Comparativos

### Baseline (SEM otimização) vs Otimizado

| Usuários | RPS Baseline | RPS Otimizado | Ganho | P50 Baseline | P50 Otimizado | Redução |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **100** | 25.9 | **48.4** | **+87%** | 1100ms | **4ms** | **99.6%** |
| **300** | 24.5 | **145.1** | **+492%** | 9000ms | **4ms** | **99.96%** |
| **600** | 25.0 | **289.3** | **+1057%** | 21000ms | **5ms** | **99.98%** |
| **900** | 24.9 | **429.8** | **+1626%** | 31000ms | **7ms** | **99.98%** |
| **1100** | 25.0 | **512.2** | **+1949%** | 39000ms | **17ms** | **99.96%** |

---

## 🚨 Limite dos Testes: 1100 Usuários

**Motivo da parada:** Os testes foram limitados a **1100 usuários simultâneos** porque:

1. **Baseline (sem otimização):**
   - A partir de 300 usuários já apresentava **erros (0.19% a 1.76%)**
   - Sistema praticamente inoperável com 39 segundos de latência

2. **Com otimização:**
   - **0% erros até 1100 usuários** ✅
   - Sistema ainda funcional com 17ms de latência
   - Gerador de carga (Locust) começou a apresentar avisos de CPU > 90%
   - Próximo teste poderia apresentar inconsistências nas medições

**Conclusão:** Limite de 1100 usuários foi estabelecido como ponto seguro para comparação justa entre baseline e otimizado, garantindo medições precisas.

---

## 📈 Análise Detalhada

### Throughput (Requests/s)

```
Baseline:        ████ ~25 RPS (saturado)
Com otimização:  ████████████████████████████████ 512 RPS
```

**Ganho máximo:** +1949% (20x mais throughput)

### Latência Mediana (P50)

```
Baseline (1100):   ████████████████████████████████████ 39000ms
Com otimização:    █ 17ms
```

**Redução:** 99.96% (2294x mais rápido)

### Escalabilidade

#### Baseline
- **Não escala:** Mantém ~25 RPS independente da carga
- **Latência cresce linearmente:** 1.1s → 39s
- **Erros aparecem:** 0.19% a 1.76% com carga

#### Com Otimização
- **Escala linearmente:** 48 → 512 RPS
- **Latência cresce lentamente:** 4ms → 17ms
- **Zero erros:** 0% em todos os cenários

---

## 📁 Estrutura dos Resultados

Cada teste contém:
- `dados_stats.csv` - Métricas agregadas
- `dados_stats_history.csv` - Histórico temporal
- `dados_failures.csv` - Erros (se houver)
- `dados_exceptions.csv` - Exceções (se houver)
- `index.html` - Relatório visual
- `teste_completo.log` - Log completo

---

## ✅ Conclusões

### Performance
- ✅ **+1949% throughput** sob carga máxima
- ✅ **99.96% redução de latência**
- ✅ **0% erros** em todos os cenários
- ✅ Sistema **20x mais eficiente**

### Escalabilidade
- ✅ Escala **linearmente** com a carga
- ✅ Mantém latências **sub-100ms** até 1100 usuários
- ✅ Baseline colapsa aos 300 usuários

### Confiabilidade
- ✅ **Zero erros** vs 1-2% no baseline
- ✅ Solução **estável** e **reproduzível**
- ✅ **Pronto para produção**

---

## 🔧 Configuração do Ambiente

- **Load Balancer:** AWS ALB (Application Load Balancer)
- **Instâncias:** 3x EC2 t3.xlarge (4 vCPU, 16GB RAM)
- **Servidor Web:** Apache 2.4.65 com mod_cache_disk
- **Aplicação:** WordPress
- **Banco de Dados:** MariaDB (instância separada)
- **Gerador de Carga:** Locust em EC2 dedicado

---

## 📝 Script de Otimização

**Arquivo:** `../optimization/apache_mod_cache_otimizado.sh`

**Como aplicar:**
```bash
bash ../apply_optimization.sh
```

---

**Testado e aprovado:** 23/12/2025  
**Status:** ✅ PRONTO PARA PRODUÇÃO

