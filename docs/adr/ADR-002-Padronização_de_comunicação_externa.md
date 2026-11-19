# ADR-002 — Padronização de comunicação externa

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O sistema precisa notificar usuários quando reservas são efetuadas ou canceladas (RF06). Inicialmente será utilizado e-mail (ou notificador simulado), mas há previsão de evolução para WhatsApp/SMS (**ASR2**). Além disso, as regras de conflito de horários, manutenção e restrições exigem testes rápidos e confiáveis (**ASR3** / R05).

## Problema / Forças Envolvidas

Como proteger as regras de negócio de mudanças em canais de notificação, frameworks web e mecanismos de persistência sem introduzir complexidade desproporcional.

## Alternativas consideradas

1. **Acoplamento direto** — Controllers e serviços instanciando diretamente classes concretas de banco de dados e e-mail.
2. **Camadas tradicionais acopladas** — Separação horizontal (Apresentação → Negócio → Persistência) onde o Negócio depende diretamente da camada de Persistência/ORM e de serviços externos. (sem portas/DIP).
3. **Arquitetura Hexagonal — Ports & Adapters** — núcleo isolado por portas primárias/secundárias; adaptadores nas bordas; camadas organizam o código com dependências para o centro (DIP)

## Decisão

Adotar a **Arquitetura Hexagonal (Ports & Adapters)** (opção 3)
## Consequências positivas

* Desacoplamento total entre o domínio de reservas e detalhes externos (UI, banco, provedor de notificação).
* Adição ou substituição de canais de notificação exige apenas criar um novo adaptador implementando `Notificador`, sem alterar entidades nem o fluxo de `realizarReserva`.
* Viabiliza testes unitários instantâneos utilizando`InMemory*Repository` e `NotificadorFake`.

## Consequências negativas / riscos

* Mais interfaces, adaptadores e mapeamentos; risco de abstração excessiva fora dos pontos de variação reais (mitigado: portas só em `*Repository` e `Notificador`).