# ADR-001 — Monólito Modular como organização estrutural

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O sistema de locação de espaços esportivos será desenvolvido e mantido por uma equipe de 3 pessoas, com tempo e recursos limitados (**ASR3**). Também precisa impedir conflitos de reserva com consistência forte (**ASR1**) e permitir evolução dos domínios sem dependências desnecessárias.

## Problema / forças

Equilibrar simplicidade de implantação e transações locais com organização interna que evite código espaguete e permita a equipe trabalhar em partes distintas (Reservas, Espaços, Usuários, Notificação).

## Alternativas consideradas

1. **Monólito simples** — um deploy, sem separação modular rígida nem isolamento claro de fronteiras.
2. **Monólito modular *(escolhida)*** — um único processo/deploy, dividido em módulos coesos com contratos claros e chamadas locais.
3. **Microsserviços** — serviços e deploys separados, comunicação em rede e, em geral, dados distribuídos.

## Decisão

Adotar o **Monólito Modular** (opção 2).

## Consequências positivas

* Implantação e operação simples, compatíveis com equipe reduzida.
* Consistência forte das reservas via transações locais de banco (junto à Repository Architecture).
* Isolamento lógico entre Espaços, Reservas, Usuários e o módulo de integração de Notificação; facilita manutenção e eventual extração futura.

## Consequências negativas / riscos

* Exige disciplina em revisões para que módulos não acessem detalhes internos uns dos outros e o sistema não degenere em monólito acidental.
