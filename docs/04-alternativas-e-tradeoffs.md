# 4. Alternativas Arquiteturais e Trade-offs

Foram comparadas duas alternativas além da solução adotada no documento de proposta: **Cliente–Servidor + Monólito Modular com Arquitetura Hexagonal, Organização em Camadas e Repository Architecture** (banco relacional único).

---

## 1. Alternativa 1 — Monólito Simples (sem portas / acoplado)

**O que seria:** um único deploy, porém sem fronteiras de módulo rígidas e sem isolamento do núcleo: regras de reserva, acesso SQL/ORM e envio de e-mail no mesmo caminho de código (controllers/services instanciando detalhes concretos).

### Benefícios

* Custo e complexidade iniciais baixos.
* Adequado na aparência a equipe pequena e prazo curto (poucas classes/interfaces).

### Custos e riscos

* **Modificabilidade (ASR2):** acoplar regra de negócio ao provedor de e-mail/SQL dificulta trocar ou adicionar canais de notificação (WhatsApp, Fake, etc.).
* **Testabilidade (ASR3 / R05):** testes das regras de conflito, manutenção e restrição tendem a depender de banco e SMTP reais.
* **Evolução:** risco de regressão e “monólito bola de lama” à medida que RF01–RF10 crescem.

---

## 2. Alternativa 2 — Microsserviços

**O que seria:** Reservas, Espaços, Usuários e Notificação como serviços e (tipicamente) bases separados, comunicando-se pela rede.

### Benefícios

* Escalabilidade e deploy independentes por capacidade (ex.: escalar só reservas).
* Isolamento de falhas entre serviços, se houver tolerância adequada.

### Custos e riscos

* **Consistência (ASR1):** impedir *double booking* e reserva sob manutenção entre serviços/bancos exigiria transações distribuídas ou Sagas com consistência eventual — o oposto da fonte única da verdade com ACID local.
* **Fluxo principal:** `realizarReserva` precisaria coordenar Reservas + Espaços (+ Usuários) via rede, com maior latência e falhas parciais.
* **Complexidade e custo (ASR3, R02, R03):** múltiplos deploys, observabilidade, contratos e pipelines incompatíveis com equipe de 3 pessoas e recursos limitados.

---

## 3. Trade-off da solução escolhida

A solução **Monólito Modular + Hexagonal + Camadas + Repository Architecture** (acesso **Cliente–Servidor**) prioriza:

* **ASR1** — consistência forte na agenda (transações locais no banco único);
* **ASR2** — troca/adição de notificação só com novo adaptador da porta `Notificador`;
* **ASR3** — um deploy, módulos lógicos claros, núcleo testável com InMemory/Fake.

Em troca, abre mão da escalabilidade granular e do isolamento físico dos microsserviços, e aceita um pouco mais de estrutura (portas, adaptadores, camadas) do que um monólito simples.

| Critério | Monólito Simples | Solução escolhida | Microsserviços |
| :--- | :--- | :--- | :--- |
| **Modificabilidade** | Baixa (acoplamento tende a crescer) | **Alta** (módulos + portas/adaptadores) | Alta entre serviços, cara em contratos |
| **Desempenho** | Alto (memória) | **Alto** (in-process) | Menor (rede/serialização) |
| **Disponibilidade** | Média (deploy único) | **Média** (deploy único; notificação isolável por adaptador) | Alta por serviço (com tolerância) |
| **Testabilidade** | Baixa (regras presas a banco/e-mail) | **Muito alta** (núcleo + Fake/InMemory) | Complexa (contrato + integração) |
| **Complexidade** | Muito baixa | **Moderada** | Muito alta |
| **Deploy** | Simples (1 artefato) | **Simples** (1 artefato) | Complexo (vários) |
| **Escalabilidade** | Vertical / réplica do todo | Vertical / réplica do todo | Granular por serviço |
| **Custo (dev + operação)** | Baixo no início, alto na manutenção | **Equilibrado** (3 pessoas) | Muito alto (inviável no prazo) |

**Camadas vs Hexagonal:** na solução, as duas coexistem. As camadas (Apresentação → Aplicação/Domínio → Infraestrutura) organizam o monólito; o hexágono garante que o domínio dependa de **portas**, não da infraestrutura concreta. O que se rejeita na Alternativa 1 / no contraste do ADR-002 é a camada de negócio **acoplada** ao ORM/e-mail — não a ideia de camadas em si.
