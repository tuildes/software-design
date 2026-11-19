# ADR-001 — Organização estrutural base do projeto

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O sistema de locação de espaços esportivos possui tempo e recursos limitados e será desenvolvido e mantido por uma equipe reduzida de 3 pessoas (**ASR3**). Além disso, precisa garantir que não haja conflito de reservas simultâneas (**ASR1**) e que os domínios possam evoluir sem gerar dependências desnecessárias.

## Problema / Forças Envolvidas

Equilibrar simplicidade de implantação e transações locais com organização interna que evite código espaguete e permita a equipe trabalhar em partes distintas (Reservas, Espaços, Usuários, Notificação).

## Alternativas consideradas

1. **Monólito simples** — Estrutura única sem separação modular rígida nem isolamento de fronteiras internas.
2. **Monólito modular** — Estrutura única, porém dividida internamente em módulos coesos com contratos claros e chamadas locais.
3. **Microsserviços** — serviços e deploys separados, comunicação em rede e, em geral, dados distribuídos.

## Decisão

Adotar o **Monólito Modular** (opção 2).

## Consequências positivas

* Implantação e operação simples, compatíveis com equipe reduzida.
* Facilita a consistência forte das reservas usando transações locais de banco de dados.
* Garante isolamento lógico entre Espaços, Reservas, Usuários e Notificações, facilitando manutenção e futura extração de módulos caso o sistema cresça.

## Consequências negativas / riscos

* Exige disciplina rigorosa da equipe em revisões de código para impedir que módulos acessem diretamente detalhes internos uns dos outros e degenerem em um monólito simples acidental.