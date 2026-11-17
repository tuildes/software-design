# ADR-003 — Persistência em banco relacional único (Repository Architecture)

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O principal risco de negócio é inconsistência de agenda: duas reservas sobrepostas no mesmo espaço (RF05) ou reserva enquanto o espaço entra em manutenção (RF04). O sistema precisa de uma fonte única e confiável da verdade (**ASR1**).

## Problema / forças

Garantir consistência imediata entre espaços, restrições, manutenções e reservas, com baixo custo de infraestrutura para equipe pequena.

## Alternativas consideradas

1. **Banco relacional único centralizado *(escolhida)*** — base compartilhada pelo monólito modular, transações ACID e integridade referencial (*Repository Architecture*).
2. **Bancos separados por módulo (*database-per-module*)** — cada módulo com seu banco e sincronização por eventos / consistência eventual.
3. **Banco não relacional distribuído (NoSQL)** — prioriza particionamento/disponibilidade em detrimento de transações ACID entre entidades relacionadas da agenda.

## Decisão

Utilizar um **banco de dados relacional único centralizado** (opção 1).

**Nota de vocabulário:** *Repository Architecture* aqui é o estilo de dados centralizados (fonte única da verdade). O *Repository Pattern* (`ReservaRepository`, etc.) é a porta hexagonal usada para acessar esse banco sem acoplar o domínio ao SQL.

## Consequências positivas

* Fonte única da verdade para disponibilidade e reservas.
* Transações ACID e restrições no banco para impedir *double booking* com simplicidade.
* Configuração, backup e operação simples para equipe reduzida.

## Consequências negativas / riscos

* Ponto único de falha e possível gargalo sob carga muito alta.
* Adaptadores de persistência acoplados ao esquema relacional compartilhado (migrações exigem cuidado).
