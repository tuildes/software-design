# 1. Descrição do Problema e Requisitos

**Tema 14 — Locação de espaços esportivos:** sistema para organizar reservas de quadras e outros espaços esportivos, controlando horários, restrições de uso, cancelamentos e períodos de manutenção.

---

## 1. Contexto do Sistema

Em ambientes universitários, clubes ou complexos esportivos, a locação de quadras e espaços físicos costuma enfrentar problemas recorrentes como conflitos de agendamento no mesmo horário (*double booking*), dificuldade em visualizar horários ou espaços livres, reservas feitas em períodos de manutenção e aplicação inconsistente de regras de uso específicas de cada espaço.

O sistema proposto centraliza o controle de espaços esportivos, regras de utilização, agendas de reserva, bloqueios de manutenção e notificações aos usuários, oferecendo uma base coesa e preparada para evoluir sem acoplamento rígido a tecnologias de interface, banco de dados ou provedores de envio de mensagens.

---

## 2. Principais Atores

### Atores primários (iniciam casos de uso)

* **Usuário (Cliente):** consulta disponibilidade de horários e espaços, efetua reservas e cancela suas próprias reservas.
* **Administrador (`Admin`):** cadastra novos espaços esportivos, registra ou encerra períodos de manutenção, define/altera restrições de uso dos espaços e cadastra novos usuários (clientes).

### Ator secundário / sistema externo (acionado pelo sistema)

* **Sistema Externo de Notificação:** serviço externo responsável por entregar avisos de confirmação ou cancelamento de reserva ao usuário (inicialmente via e-mail, extensível para WhatsApp/SMS).

> **Nota:** o Banco de Dados não é ator de negócio. Ele é componente de infraestrutura/persistência (fonte única da verdade) e será representado nos diagramas de componentes/arquitetura, não na lista de atores.

---

## 3. Requisitos Funcionais

| ID | Requisito Funcional | Ator Principal |
| :--- | :--- | :--- |
| **RF01** | Cadastrar novo espaço esportivo | Administrador |
| **RF02** | Reservar espaços esportivos | Usuário (Cliente) |
| **RF03** | Cancelar reserva | Usuário (Cliente) |
| **RF04** | Alterar disponibilidade para período de manutenção (impedindo reserva pelo cliente) | Administrador |
| **RF05** | Impedir duas reservas no mesmo horário no mesmo espaço | Sistema |
| **RF06** | Notificar usuário após reserva ser efetuada ou cancelada | Sistema Externo de Notificação |
| **RF07** | Consultar disponibilidade de horário em um espaço | Usuário (Cliente) |
| **RF08** | Consultar disponibilidade de espaços em um horário | Usuário (Cliente) |
| **RF09** | Definir/alterar restrições de uso para cada espaço | Administrador |
| **RF10** | Criar novos usuários (clientes) | Administrador |

---

## 4. Restrições Relevantes

1. **R01 — Evolução desacoplada:** permitir evolução do projeto sem gerar dependências desnecessárias entre regras de negócio e infraestrutura.
2. **R02 — Equipe reduzida:** projeto desenvolvido e mantido por apenas 3 integrantes.
3. **R03 — Tempo e recursos limitados:** necessidade de manter implantação simples e baixo custo operacional.
4. **R04 — Consistência dos dados:** o sistema deve garantir consistência satisfatória dos dados de agenda e disponibilidade (sem conflitos de reserva).
5. **R05 — Testabilidade:** as regras críticas de negócio devem ser facilmente testáveis de forma automatizada.

---

## 5. Requisitos Arquiteturalmente Significativos (ASRs)

Os ASRs abaixo são formulados com estímulo, cenário e efeito verificável, de modo a orientar decisões concretas de arquitetura.

### ASR1 — Dados centralizados e consistência forte nas reservas

Quando dois ou mais clientes solicitam reserva para o mesmo espaço esportivo em períodos sobrepostos simultaneamente, ou quando um administrador coloca o espaço em manutenção no mesmo instante, o sistema deve garantir consistência transacional estrita (ACID) para que **zero reservas duplicadas ou inválidas** sejam persistidas.

### ASR2 — Modificabilidade para novos canais de notificação

Quando for necessário substituir o canal de notificação atual (ex.: e-mail) ou adicionar novos provedores (ex.: WhatsApp, SMS ou *Fake* para testes), a troca deve ocorrer implementando apenas um novo adaptador, sem alterar nenhuma classe de domínio ou caso de uso de reserva.

### ASR3 — Manutenibilidade e testabilidade em equipe reduzida

Uma equipe de 3 pessoas deve conseguir manter módulos de negócio independentes em nível lógico e executar a suíte de testes unitários das regras de reserva, manutenção e restrições em milissegundos, sem depender de banco de dados ou servidor SMTP em execução.

---

## 6. Influência dos ASRs nas Decisões Arquiteturais

| ASR | Influência nas decisões |
| :--- | :--- |
| **ASR1** | Impede a adoção de múltiplos bancos isolados com consistência eventual (como em microsserviços) e direciona para o estilo **Repository Architecture** (fonte única da verdade em banco relacional centralizado) dentro de um **Monólito Modular**, onde conflitos de agenda são resolvidos com transações locais. |
| **ASR2** | Motiva a adoção da **Arquitetura Hexagonal (Ports & Adapters)** com o princípio **DIP**, definindo uma porta de saída explícita (`Notificador`) que desacopla o núcleo do provedor concreto de notificação. |
| **ASR3** | Descarta microsserviços devido à sobrecarga operacional incompatível com equipe e prazo reduzidos, e direciona para um **Monólito Modular** (fronteiras lógicas claras, um único deploy) aliado ao núcleo puro da **Arquitetura Hexagonal**, viabilizando testes em memória via *mocks/fakes*. |
