# Trabalho de Dimensionamento - Apache mod_cache

**Resultado:** +1949% throughput | 99.9% redução latência | 0% erros

---

## Autores

- **Luan Carvalho** - 2526438
- **José Freitas Alves Neto** - 2519203
- **Isaque Araujo Gadelha** - 2519194

---

## Estrutura

```
trab_dimensionamento/
├── deploy_all.sh                    # Subir infraestrutura
├── teardown.sh                      # Descer infraestrutura
├── apply_optimization.sh            # Aplicar otimização
│
├── optimization/                    # Solução de otimização
│   ├── apache_mod_cache_otimizado.sh
│   └── README.md                    # Documentação técnica
│
├── bateria_baseline_antes_otimizacoes/  # Testes SEM otimização
│   └── resultados_*/
│
└── bateria_apache_cache_*/          # Testes COM otimização
    ├── RELATORIO.md                 # Relatório principal
    └── resultados_*/
```

---

## Como Usar

### 0. Configurar credenciais (primeiro uso)
```bash
# Editar config.sh e adicionar suas credenciais AWS
nano config.sh
```

### 1. Subir infraestrutura
```bash
bash deploy_all.sh
```

### 2. Aplicar otimização
```bash
bash apply_optimization.sh
```

### 3. Testar (opcional)
```bash
bash run_test_with_html.sh <LB_DNS> 100 2m
```

### 4. Descer infraestrutura
```bash
bash teardown.sh all
```

---

## Relatório Final do Trabalho

**Localização:** `optimization/README.md`

Este é o relatório final completo com análise, metodologia, resultados e conclusões do trabalho.

**Resumo dos Resultados:**
- Throughput: 25 -> 512 RPS (+1949%)
- Latência: 39s -> 17ms (99.96%)
- Erros: 1-2% -> 0%

---

## Configuração-Chave

```apache
CacheQuickHandler off  # Resolve erro 403
```

---

**Status:** Testado e aprovado para produção
