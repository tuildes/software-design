# 2. Modelo de Domínio e Responsabilidades

Este documento identifica os conceitos do domínio de locação de espaços esportivos, distribui responsabilidades entre classes e módulos e justifica as escolhas com GRASP e SOLID. A divisão reflete o que já aparece nos diagramas de classes, sequência e comunicação, com ajustes pontuais de fronteira e nomenclatura.

**Papéis de orquestração (regra geral):**

* **Controller** — recebe a entrada externa, valida formato superficial e **encaminha** o caso de uso ao Service. Não aplica regra de negócio.
* **Service** — orquestra entidades, repositórios e portas; **aplica e coordena** as regras do caso de uso.
* **Entidade / Value Object** — concentra a regra sobre o dado que possui (Information Expert).

---

## 1. Conceitos e Módulos do Domínio

Dentro do **Monólito Modular**, o sistema é organizado em quatro módulos coesos que se comunicam por chamadas locais e contratos claros:

1. **Módulo de Espaços Esportivos:** Gestão do cadastro de quadras/espaços, restrições de uso e períodos de manutenção (RF01, RF04, RF07, RF08, RF09).
2. **Módulo de Reservas (Core Principal):** Orquestração do agendamento, checagem de conflitos de horário, cancelamentos e consultas de disponibilidade (RF02, RF03, RF05).
3. **Módulo de Usuários:** Gestão de cadastro e validação de aptidão de clientes e administradores (RF10).
4. **Módulo de Notificação (Integração Externa):** Contrato (`Notificador`) e adaptadores responsáveis por enviar confirmações e avisos de cancelamento (RF06).

### Por que esses módulos (e não outros)?

* **Espaços**, **Reservas** e **Usuários** mudam por razões de negócio distintas (cadastro físico e regras do espaço; agenda e conflitos; identidade/aptidão do cliente). Separá-los aumenta coesão e reduz o risco de um único “módulo God”.
* **Notificação** não modela regra de locação: só entrega um efeito colateral (aviso). Por isso fica como **módulo de integração**, atrás de uma porta, e não como conceito do domínio.
* Comunicação entre módulos de domínio é **local (in-process)**. A saída para o mundo externo passa por **portas** (`*Repository`, `Notificador`).

---

## 2. Classes e Responsabilidades

### 2.1 Domínio — entidades e value objects

#### `EspacoEsportivo` (Entidade)

* **Dados:** `id`, `nome`, `tipo`, `capacidade`, `emManutencao`, `periodosManutencao`, referência às `RestricaoDeUso` associadas.
* **Responsabilidades:** decidir se o espaço pode ser reservado em um período (`estaDisponivelParaReserva`), verificar se atende às restrições (`atendeRestricoes`), iniciar/encerrar manutenção e associar restrições.
* **Por que classe separada:** representa o agregado físico/operacional do negócio (quadra/espaço). Manutenção e restrições pertencem ao ciclo de vida do espaço, não da reserva.

#### `RestricaoDeUso` (Entidade)

* **Dados:** `id`, `descricao`, `duracaoMaximaMinutos`, `antecedenciaMinimaHoras`, `apenasUsuariosAutorizados` (e demais parâmetros de política que o espaço possa exigir).
* **Responsabilidades:** `validar(usuario, periodo)` — avaliar se uma intenção de reserva respeita esta restrição.
* **Por que entidade (e não Value Object):** a restrição **pode ser alterada** ao longo do tempo (RF09) e possui **identidade independente** do restante do modelo (pode ser reutilizada, versionada ou reatribuída a espaços). Tratar como VO imutável “embutido” no espaço dificultaria mudanças independentes e rastreio.
* **Relação:** `EspacoEsportivo` conhece suas restrições e delega a validação detalhada a cada `RestricaoDeUso` (ainda Information Expert em dois níveis).

#### `Reserva` (Entidade)

* **Dados:** `id`, `espacoEsportivo`, `usuario`, `periodoHorario`, `status` (`CONFIRMADA` \| `CANCELADA`).
* **Responsabilidades:** `cancelar()`, `estaAtiva()`, `conflitaCom(periodo)`.
* **Por que classe separada:** é o registro de compromisso de agenda; o estado (`status`) e a noção de conflito ativo pertencem a ela, não ao controller nem ao repositório.
* **Nomenclatura:** usa-se `conflitaCom` (genérico). O critério interno pode evoluir (sobreposição simples, folga entre slots, etc.) sem forçar renomeação da API do domínio.

#### `PeriodoHorario` (Value Object)

* **Dados:** `data`, `horaInicio`, `horaFim`.
* **Responsabilidades:** `sobrepoe(outro)`, `ehValido()`.
* **Por que classe separada:** intervalo temporal é conceito reutilizado por reserva, manutenção e consultas; encapsular evita espalhar comparações de horário em services. Como value object, a igualdade é por valor e o objeto é imutável.

#### `Usuario` (Entidade)

* **Dados:** `id`, `nome`, `email`, `telefone`, `perfil` (`CLIENTE` \| `ADMIN`), `ativo`.
* **Responsabilidades:** `podeRealizarReserva()`.
* **Por que classe separada:** aptidão para reservar é regra do usuário (ativo/perfil), não do espaço nem do controller.

### 2.2 Aplicação — services (coordenação do caso de uso)

#### `ReservaService`

* **Métodos:** `realizarReserva`, `cancelarReserva`, `consultarHorariosDisponiveis`, `consultarEspacosDisponiveis`.
* **Responsabilidade:** buscar entidades via repositórios; perguntar às entidades as regras que elas possuem; detectar conflito percorrendo reservas ativas e chamando `conflitaCom`; criar/persistir `Reserva`; acionar o módulo de notificação.
* **O que não faz:** não interpreta HTTP; não contém SQL; não calcula sobreposição “na mão” se isso já está em `PeriodoHorario`/`Reserva`.

#### `EspacoEsportivoService`

* **Métodos:** `cadastrarEspaco`, `agendarManutencao`, `liberarManutencao`, `definirRestricoes`.
* **Responsabilidade:** casos de uso administrativos do espaço; delega invariantes a `EspacoEsportivo` / `RestricaoDeUso`.

#### `UsuarioService`

* **Métodos:** `cadastrarUsuario`, `buscarUsuario`.
* **Responsabilidade:** ciclo de vida de usuário no domínio; sem controller dedicado no protótipo.

#### `NotificacaoService` (módulo de integração)

* **Responsabilidade:** montar/disparar a comunicação de confirmação ou cancelamento via porta `Notificador`.
* **Por que existe (e não é domínio):** isola o “como avisar” do “como reservar”. `ReservaService` chama `NotificacaoService` (ou a porta, via esse service), em vez de conhecer SMTP, templates ou provedores.
* **Porta:** `Notificador.notificar(destinatario, assunto, mensagem)`.
* **Adaptadores:** `EmailNotificador`, `NotificadorFake` (testes/protótipo).

### 2.3 Entrada e persistência (fora do domínio, mas relevantes à distribuição)

| Classe | Papel |
| :--- | :--- |
| `ReservaController` | Entrada dos fluxos de reserva, cancelamento e consulta; só encaminha ao `ReservaService`. |
| `EspacoEsportivoController` | Entrada administrativa de espaços, manutenção e restrições; encaminha ao `EspacoEsportivoService`. |
| `ReservaRepository`, `EspacoEsportivoRepository`, `UsuarioRepository` | Portas de persistência (contratos no núcleo; implementações Postgres / InMemory na infraestrutura). |

Fluxo canônico (já nos diagramas de sequência/comunicação):

```text
Cliente → ReservaController → ReservaService
         → repositórios (busca)
         → Usuario / EspacoEsportivo / Reserva (regras)
         → ReservaRepository.salvar
         → NotificacaoService → Notificador
```

---

## 3. Justificativas GRASP

| Responsabilidade | Quem assume | GRASP | Justificativa |
| :--- | :--- | :--- | :--- |
| Receber pedido externo e devolver resposta | `ReservaController` / `EspacoEsportivoController` | **Controller** | Capturam o evento na borda e delegam; sem regra de agenda ou manutenção. |
| Disponibilidade / manutenção do espaço | `EspacoEsportivo` | **Information Expert** | Detém `emManutencao` e `periodosManutencao`. |
| Validar política de uso | `RestricaoDeUso` (+ coordenação em `EspacoEsportivo`) | **Information Expert** | A restrição conhece seus próprios parâmetros; o espaço conhece *quais* restrições valem. |
| Sobreposição de intervalos | `PeriodoHorario` | **Information Expert** | Possui `data`, `horaInicio`, `horaFim`. |
| Conflito de reserva ativa | `Reserva` | **Information Expert** | Combina `estaAtiva()` com o período; critério pode evoluir internamente. |
| Aptidão do cliente | `Usuario` | **Information Expert** | Conhece `ativo` / `perfil`. |
| Orquestrar busca, validações cruzadas, persistência e aviso | `ReservaService` | **Pure Fabrication** | Nenhuma entidade deve conhecer repositório ou notificador. |
| Criar nova `Reserva` após validações | `ReservaService` | **Creator** | Já reúne `Usuario`, `EspacoEsportivo` e `PeriodoHorario` válidos. |
| Troca de canal de notificação / de banco | `Notificador`, `*Repository` | **Protected Variations**, **Indirection**, **Polymorphism** | Variações tecnológicas ficam atrás de contratos. |
| Baixo acoplamento entre módulos | Fronteiras de módulo + portas | **Low Coupling** / **High Cohesion** | Cada módulo muda por um motivo principal de negócio. |

---

## 4. Análise de Coesão e Acoplamento

### Coesão (alta, por desenho)

* **`PeriodoHorario` / `Reserva`:** só regras de tempo, estado da reserva e conflito.
* **`EspacoEsportivo` / `RestricaoDeUso`:** só ciclo de vida do espaço e políticas de uso.
* **`Usuario`:** só identidade e aptidão.
* **`ReservaService`:** só coordenação do caso de uso de agenda (não mistura SMTP nem SQL).
* **Controllers:** só adaptação de entrada/saída.

### Acoplamento (baixo nas bordas; concentrado no service)

* O **domínio não depende** de HTTP, JDBC/ORM nem SMTP.
* Dependências apontam das **bordas para o centro** (adaptadores → portas → domínio).
* `ReservaService` é o **ponto de maior acoplamento estrutural** (vários repositórios + notificação + entidades). Isso é aceitável e intencional para um Pure Fabrication de caso de uso; o trade-off é isolá-lo bem e não deixar essa orquestração vazar para controllers ou entidades.

---

## 5. Aplicação de SOLID

* **SRP:** controller ≠ service ≠ entidade ≠ adaptador de e-mail. Cada um muda por motivo diferente.
* **OCP:** novo canal de notificação = novo adaptador de `Notificador`, sem alterar `Reserva` nem o fluxo principal de `realizarReserva`.
* **LSP:** `EmailNotificador` e `NotificadorFake` (idem repositórios Postgres/InMemory) substituem-se onde a porta é esperada.
* **ISP:** portas pequenas e por contexto (`Notificador`, `ReservaRepository`, etc.), sem “IRepository” genérico inchado.
* **DIP:** services de alto nível dependem de abstrações (`*Repository`, `Notificador`), não de Postgres ou SMTP.

A escolha de **`RestricaoDeUso` como entidade** também dialoga com SRP/OCP: a política de uso evolui (RF09) sem forçar reescrita de `Reserva` ou do controller; alterações ficam na classe que é dona da regra.

---

## 6. Trade-offs das Separações

| Separação | Benefício | Custo / risco |
| :--- | :--- | :--- |
| Três módulos de domínio (Espaços / Reservas / Usuários) | Coesão por motivo de mudança; facilita equipe pequena evoluir partes sem “tudo em um arquivo”. | Exige disciplina de fronteira (chamadas locais claras; evitar acesso direto ao banco de outro módulo). |
| Notificação como módulo de integração + `NotificacaoService` / porta | Domínio de reserva não conhece e-mail/WhatsApp; atende ASR2 e testabilidade com Fake. | Mais um tipo/contrato no caminho do caso de uso; risco de over-engineering se o aviso for trivial demais — mitigado mantendo o service fino. |
| `RestricaoDeUso` como entidade independente | RF09 fica natural (alterar/reassociar restrições); identidade e ciclo de vida próprios. | Mais persistência e consistência de associação espaço↔restrição do que um VO embutido. |
| `PeriodoHorario` como VO separado | Reuso e encapsulamento de sobreposição; services ficam legíveis. | Classe a mais para um conceito simples — custo baixo frente ao ganho de clareza. |
| Regras em entidades + orquestração no `ReservaService` | Information Expert real; evita “service anêmico” e “controller gordo”. | Service concentra o fluxo; precisa permanecer só coordenador (não reimplementar regras das entidades). |
| Sem `UsuarioController` | Menos superfície de API; o cliente não “é controlado”, só usa o sistema. | RF10 precisa de outro adaptador primário mínimo para acionar `UsuarioService`. |
| Nomes genéricos (`conflitaCom`, `sobrepoe`, `validar`) | API estável se a regra interna mudar. | Exige documentação/testes claros do comportamento atual, já que o nome não detalha o critério. |

Em resumo: separa-se **o que muda por motivo de negócio diferente** (espaço, reserva, usuário, canal de aviso) e mantém-se **junto** o que precisa de consistência forte na mesma transação de reserva — alinhado aos ASRs de consistência, modificabilidade de notificação e testabilidade em equipe reduzida.
