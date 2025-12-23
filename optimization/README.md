# Trabalho de Dimensionamento de Sistemas - Relatório Final

**Data:** 23 de Dezembro de 2025

**Autores:**
- Luan Carvalho - 2526438
- José Freitas Alves Neto - 2519203
- Isaque Araujo Gadelha - 2519194

---

## 1. Introdução

Este trabalho teve como objetivo otimizar a performance de uma aplicação WordPress através de técnicas de cache em nível de servidor, visando maximizar o throughput e minimizar a latência sob diferentes cargas de usuários simultâneos.

---

## 2. Metodologia

### 2.1 Ambiente de Testes

A infraestrutura foi provisionada na AWS utilizando CloudFormation, com a seguinte configuração:

- **Load Balancer:** AWS Application Load Balancer (ALB)
- **Instâncias de Aplicação:** 3x EC2 t3.xlarge (4 vCPUs, 16GB RAM cada)
- **Servidor Web:** Apache 2.4.65
- **Aplicação:** WordPress com conteúdo pré-gerado
- **Banco de Dados:** MariaDB em instância separada
- **Gerador de Carga:** Locust executando em EC2 dedicado

### 2.2 Cenários de Teste

Foram realizados testes com 5 diferentes cargas de usuários simultâneos:
- 100 usuários
- 300 usuários
- 600 usuários
- 900 usuários
- 1100 usuários

Cada teste teve duração de 2 minutos, com tempo de estabilização de 30 segundos entre testes.

---

## 3. Resultados do Baseline (Sem Otimização)

Primeiro, executamos testes com a configuração padrão do WordPress e Apache, sem nenhuma otimização de cache.

### Resultados do Baseline

| Usuários | RPS | P50 (ms) | P95 (ms) | Taxa de Erro |
|:---:|---:|---:|---:|---:|
| 100 | 25.9 | 1.100 | 4.600 | 0% |
| 300 | 24.5 | 9.000 | 13.000 | 0.19% |
| 600 | 25.0 | 21.000 | 26.000 | 1.76% |
| 900 | 24.9 | 31.000 | 37.000 | 1.61% |
| 1100 | 25.0 | 39.000 | 44.000 | 1.57% |

### Análise do Baseline

O sistema sem otimização apresentou sérios problemas de escalabilidade:

1. **Throughput saturado:** O sistema manteve aproximadamente 25 RPS independente da carga, indicando saturação total dos recursos.

2. **Latência inaceitável:** Com 1100 usuários, o tempo de resposta mediano foi de 39 segundos, tornando a aplicação praticamente inutilizável.

3. **Degradação progressiva:** A latência cresceu linearmente com o aumento de usuários (1.1s -> 39s), demonstrando falta de escalabilidade.

4. **Aparecimento de erros:** A partir de 300 usuários simultâneos, começaram a aparecer erros (0.19% a 1.76%), indicando que o sistema estava operando além de sua capacidade.

---

## 4. Estratégia de Otimização Implementada

### 4.1 Por que Apache mod_cache?

A escolha da otimização via **Apache mod_cache** foi baseada em experiência prévia com caching em nível de servidor. Sabíamos que esta abordagem oferece vantagens significativas:

1. **Cache em nível de servidor:** O Apache serve páginas estáticas antes mesmo do PHP ser invocado
2. **Menor overhead:** Não depende da execução do WordPress/PHP para cada requisição
3. **Maior performance:** Cache é servido diretamente da memória/disco do Apache
4. **Transparente:** Não requer alterações no código da aplicação

### 4.2 Configuração Implementada

A otimização consistiu na instalação e configuração do `mod_cache_disk` do Apache com os seguintes parâmetros principais:

```apache
<IfModule mod_cache_disk.c>
    CacheEnable disk "/"
    CacheRoot "/var/cache/httpd/mod_cache_disk"
    CacheIgnoreHeaders Set-Cookie Cookie
    CacheIgnoreCacheControl On
    
    # CONFIGURAÇÃO CRÍTICA
    CacheQuickHandler off
    
    CacheLock on
    CacheMaxExpire 86400
</IfModule>
```

**Nota importante:** A configuração `CacheQuickHandler off` foi crítica para evitar erros 403 Forbidden. Com esta diretiva desligada, o cache passa pela fase de autorização do Apache, resolvendo conflitos com o Load Balancer.

### 4.3 Implementação

O script de otimização (`apache_mod_cache_otimizado.sh`) foi aplicado em todas as três instâncias de aplicação através do script master `apply_optimization.sh`.

---

## 5. Resultados com Otimização (Apache mod_cache)

Após aplicar a otimização de cache, os testes foram repetidos com as mesmas cargas.

### Resultados Otimizados

| Usuários | RPS | P50 (ms) | P95 (ms) | Taxa de Erro |
|:---:|---:|---:|---:|---:|
| 100 | 48.4 | 4 | 5 | 0% |
| 300 | 145.1 | 4 | 6 | 0% |
| 600 | 289.3 | 5 | 10 | 0% |
| 900 | 429.8 | 7 | 24 | 0% |
| 1100 | 512.2 | 17 | 99 | 0% |

---

## 6. Comparativo: Baseline vs Otimizado

### 6.1 Throughput (Requests por Segundo)

| Usuários | Baseline (RPS) | Otimizado (RPS) | Ganho |
|:---:|---:|---:|---:|
| 100 | 25.9 | 48.4 | +87% |
| 300 | 24.5 | 145.1 | +492% |
| 600 | 25.0 | 289.3 | +1.057% |
| 900 | 24.9 | 429.8 | +1.626% |
| 1100 | 25.0 | 512.2 | **+1.949%** |

**Observação:** Quanto maior a carga, maior o ganho proporcionado pelo cache. Isso demonstra que a otimização é especialmente eficaz em cenários de alta demanda.

### 6.2 Latência P50 (Tempo de Resposta Mediano)

| Usuários | Baseline (ms) | Otimizado (ms) | Melhoria |
|:---:|---:|---:|---:|
| 100 | 1.100 | 4 | 99,6% |
| 300 | 9.000 | 4 | 99,96% |
| 600 | 21.000 | 5 | 99,98% |
| 900 | 31.000 | 7 | 99,98% |
| 1100 | 39.000 | 17 | **99,96%** |

### 6.3 Taxa de Erros

| Usuários | Baseline | Otimizado |
|:---:|---:|---:|
| 100 | 0% | 0% |
| 300 | 0,19% | 0% |
| 600 | 1,76% | 0% |
| 900 | 1,61% | 0% |
| 1100 | 1,57% | 0% |

**Resultado:** 0% de erros em todos os cenários otimizados, incluindo nas cargas onde o baseline apresentava falhas.

### 6.4 Escalabilidade

**Baseline:**
- Throughput estagnado em ~25 RPS (não escala)
- Latência cresce linearmente (1s -> 39s)
- Erros aparecem a partir de 300 usuários

**Otimizado:**
- Throughput escala quase linearmente (48 -> 512 RPS)
- Latência cresce lentamente (4ms -> 17ms)
- Zero erros em todas as cargas

---

## 7. Limite de 1100 Usuários

### 7.1 Por que parar em 1100 usuários?

Os testes foram limitados a 1100 usuários simultâneos devido a duas observações importantes:

1. **Início do aumento de latência:** Embora o sistema continuasse funcional e sem erros, a latência mediana começou a crescer mais significativamente:
   - 900 usuários: 7ms
   - 1100 usuários: 17ms (aumento de 143%)

2. **Limitação do gerador de carga:** O Locust (gerador de carga) começou a emitir avisos de CPU acima de 90%, indicando que as medições poderiam ficar imprecisas em cargas maiores.

### 7.2 Capacidade Real do Sistema

É importante notar que:
- O sistema **ainda estava operacional** com 1100 usuários
- A latência de 17ms ainda é **excelente** (comparado aos 39 segundos do baseline)
- A taxa de erro permaneceu em **0%**

Portanto, 1100 usuários não representa o limite absoluto do sistema, mas sim o ponto onde decidimos encerrar os testes para garantir medições confiáveis.

---

## 8. Análise de Desempenho

### 8.1 Eficiência da Solução

A otimização via Apache mod_cache provou ser extremamente eficiente:

1. **Configuração mínima:** Apenas um script de configuração aplicado em todas as instâncias
2. **Sem alteração de código:** Não foi necessário modificar a aplicação WordPress
3. **Sem recursos adicionais:** Mesma infraestrutura (3 instâncias t3.xlarge)
4. **Ganho massivo:** Aumento de até 1.949% no throughput

### 8.2 Custo-Benefício

Com a mesma configuração de hardware:

**Baseline:**
- Capacidade: ~25 RPS
- Custo por requisição: Alto (3 instâncias t3.xlarge para 25 RPS)

**Otimizado:**
- Capacidade: 512 RPS (20x mais)
- Custo por requisição: 20x menor

Isso significa que conseguimos atender **20 vezes mais usuários** com a **mesma infraestrutura**, apenas com uma configuração de cache adequada.

---

## 9. Conclusão

### 9.1 Objetivos Alcançados

Este trabalho demonstrou com sucesso que:

1. **Otimização de cache em nível de servidor é altamente eficaz:** Conseguimos aumentar o throughput em até 1.949% (quase 20x) com configuração mínima.

2. **Escalabilidade melhorada drasticamente:** O sistema passou de não-escalável (25 RPS fixo) para escalabilidade quase linear (48 -> 512 RPS).

3. **Latência reduzida em 99,96%:** Tempo de resposta foi de 39 segundos para 17 milissegundos sob carga máxima testada.

4. **Confiabilidade total:** 0% de erros em todos os cenários, comparado a 1-2% de erros no baseline sob carga.

### 9.2 Aprendizados Principais

1. **Cache é fundamental:** Em aplicações com conteúdo predominantemente estático (como WordPress), cache é a otimização mais impactante.

2. **Nível de cache importa:** Cache em nível de servidor (Apache) é mais eficiente que cache em nível de aplicação (plugins WordPress).

3. **Configuração correta é crítica:** `CacheQuickHandler off` foi essencial para evitar erros 403 com Load Balancer.

4. **Escalabilidade requer otimização:** Hardware adicional não resolve problemas de arquitetura; otimização adequada é mais eficaz.

### 9.3 Trabalho Concluído

Com a configuração mínima implementada (Apache mod_cache), conseguimos:

- **Alto throughput:** 512 RPS com apenas 3 instâncias t3.xlarge
- **Baixa latência:** Tempo de resposta consistentemente abaixo de 20ms até 1100 usuários
- **Alta confiabilidade:** Zero erros em todos os cenários
- **Ótimo custo-benefício:** 20x mais capacidade com a mesma infraestrutura

Isso conclui o trabalho de dimensionamento, demonstrando que uma **estratégia de cache bem implementada** é capaz de transformar um sistema saturado e lento em um sistema altamente escalável e performático, **sem necessidade de recursos adicionais**.

---

## 10. Arquivos e Documentação

### 10.1 Estrutura do Projeto

```
trab_dimensionamento/
├── README.md                         # Guia rápido
├── apply_optimization.sh             # Script para aplicar otimização
├── optimization/
│   ├── apache_mod_cache_otimizado.sh # Script de otimização
│   └── README.md                     # Este relatório
├── bateria_baseline_antes_otimizacoes/
│   └── resultados_*/                 # Dados do baseline
└── bateria_apache_cache_*/
    └── resultados_*/                 # Dados otimizados
```

### 10.2 Como Reproduzir

1. Configurar credenciais AWS em `config.sh`
2. Executar `bash deploy_all.sh` para subir infraestrutura
3. Executar `bash apply_optimization.sh` para aplicar cache
4. Executar testes com diferentes cargas
5. Executar `bash teardown.sh all` para destruir infraestrutura

### 10.3 Referências

- **Apache mod_cache:** https://httpd.apache.org/docs/2.4/mod/mod_cache.html
- **CacheQuickHandler:** https://httpd.apache.org/docs/2.4/mod/mod_cache.html#cachequickhandler

---

**Data de Conclusão:** 23/12/2025  
**Versão:** 1.0 (Final)
