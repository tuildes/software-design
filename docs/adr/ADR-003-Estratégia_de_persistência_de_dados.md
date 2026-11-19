# ADR-003 — Estratégia de persistência de dados

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O sistema precisa de fonte única e confiável da verdade, pois o principal risco de negócio do sistema é a inconsistência de agenda. O sistema não deverá permitir duas reservas sobrepostas no mesmo espaço e horário (RF05) nem deverá permitir a reserva enquanto o espaço estiver em manutenção (RF04). 

## Problema / Forças Envolvidas

Garantir consistência imediata entre espaços, restrições, manutenções e reservas com baixo custo de infraestrutura e desenvolvimento.

## Alternativas consideradas

1. **Banco relacional único centralizado** — Base relacional compartilhada pelo monólito modular com transações ACID e integridade referencial (*Repository Architecture*).
2. **Bancos separados por módulo** — Cada módulo mantendo seu próprio banco isolado e sincronizando estado por eventos/consistência eventual. (*Database-per-module*)
3. **Banco não relacional distribuído (NoSQL)** — Armazenamento distribuído, privilegiando particionamento/disponibilidade em detrimento de transações relacionais ACID entre entidades.

## Decisão

Utilizar um **banco relacional único centralizado** (opção 1).

## Consequências positivas

* Garante fonte única da verdade para disponibilidade e reservas.
* Permite usar transações ACID e travas/restrições no banco para impedir *double booking* com simplicidade.
* Simplifica configuração, backup e manutenção por uma equipe reduzida.

## Consequências negativas / riscos

* Ponto único de falha e possível gargalo sob carga muito alta.
* Adaptadores de persistência acoplados ao esquema relacional compartilhado (migrações exigem cuidado).
