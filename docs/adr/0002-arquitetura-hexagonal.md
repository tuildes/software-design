# ADR-002 — Arquitetura Hexagonal (Ports & Adapters)

* **Status:** Aceito
* **Data:** 2026-11

## Contexto

O sistema notifica o usuário após reserva ou cancelamento (RF06). O canal inicial é e-mail (ou Fake no protótipo), com previsão de WhatsApp/SMS (**ASR2**). As regras de conflito, manutenção e restrição precisam de testes rápidos sem depender de SMTP ou banco reais (**ASR3** / R05).

A proposta também organiza o monólito em **camadas** (Apresentação → Aplicação/Domínio → Infraestrutura). A questão não é “ter ou não camadas”, e sim **como** o domínio se relaciona com a infraestrutura.

## Problema / forças

Proteger as regras de locação de mudanças em UI, provedor de notificação e mecanismo de persistência, sem complexidade desproporcional à equipe.

## Alternativas consideradas

1. **Acoplamento direto** — controllers/services instanciam classes concretas de SQL e e-mail.
2. **Camadas tradicionais acopladas** — Apresentação → Negócio → Persistência, porém o Negócio depende diretamente do ORM e de serviços externos (sem portas/DIP).
3. **Arquitetura Hexagonal + camadas com DIP *(escolhida)*** — núcleo isolado por portas primárias/secundárias; adaptadores nas bordas; camadas organizam o código com dependências para o centro.

## Decisão

Adotar a **Arquitetura Hexagonal (Ports & Adapters)** (opção 3), convivendo com a organização em camadas do monólito modular.

## Consequências positivas

* Domínio de reservas desacoplado de HTTP, SQL e SMTP.
* Novo canal de notificação = novo adaptador de `Notificador`, sem alterar entidades nem o fluxo de `realizarReserva`.
* Testes unitários com `InMemory*Repository` e `NotificadorFake`.

## Consequências negativas / riscos

* Mais interfaces, adaptadores e mapeamentos; risco de abstração excessiva fora dos pontos de variação reais (mitigado: portas só em `*Repository` e `Notificador`).
