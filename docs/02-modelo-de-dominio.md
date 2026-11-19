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

## 2. Classes, Interfaces e Responsabilidades

### 2.1 Domínio — Entidades, Objetos de Valor e Enums

#### `EspacoEsportivo` (Entidade)

* **Atributos:** `id: UUID`, `nome: String`, `tipo: String`, `capacidade: int`, `emManutencao: boolean`, `periodosManutencao: List<PeriodoHorario>`, `restricoesDeUso: List<RestricaoDeUso>`.
* **Métodos:** `estaDisponivelParaReserva(periodo: PeriodoHorario): boolean`, `atendeRestricoes(usuario: Usuario, periodo: PeriodoHorario): boolean`, `iniciarManutencao(periodo: PeriodoHorario): void`, `encerrarManutencao(): void`, `adicionarRestricao(restricao: RestricaoDeUso): void`.
* **Por que a classe existe:** Representa o agregado físico e operacional do negócio (quadra/espaço); manutenção e restrições pertencem ao ciclo de vida do espaço, não da reserva.

#### `RestricaoDeUso` (Entidade)

* **Atributos:** `id: UUID`, `descricao: String`, `duracaoMaximaMinutos: int`, `antecedenciaMinimaHoras: int`, `apenasUsuariosAutorizados: boolean`.
* **Métodos:** `validar(usuario: Usuario, periodo: PeriodoHorario): boolean`.
* **Por que a classe existe (e por que é Entidade, não Value Object):** Avalia se uma intenção de reserva respeita uma política de uso do espaço. É Entidade porque **pode ser alterada** ao longo do tempo (RF09) e possui **identidade independente** (podendo ser reutilizada, versionada ou reatribuída a espaços). `EspacoEsportivo` conhece suas restrições e delega a validação detalhada a cada `RestricaoDeUso` (Information Expert em dois níveis).

#### `Reserva` (Entidade)

* **Atributos:** `id: UUID`, `espacoEsportivo: EspacoEsportivo`, `usuario: Usuario`, `periodoHorario: PeriodoHorario`, `status: StatusReserva`.
* **Métodos:** `cancelar(): void`, `estaAtiva(): boolean`, `conflitaCom(outroPeriodo: PeriodoHorario): boolean`.
* **Por que a classe existe:** É o registro de compromisso de agenda; o ciclo de vida do estado (`status`) e a regra de conflito ativo (`conflitaCom`, nomenclatura genérica cujo critério interno pode evoluir sem renomear a API do domínio) pertencem a ela, não ao controller nem ao repositório.

#### `PeriodoHorario` (Value Object)

* **Atributos:** `data: LocalDate`, `horaInicio: LocalTime`, `horaFim: LocalTime`.
* **Métodos:** `sobrepoe(outroPeriodo: PeriodoHorario): boolean`, `ehValido(): boolean`.
* **Por que a classe existe:** Intervalo temporal é um conceito imutável (igualdade por valor) reutilizado por reservas, manutenções e consultas; encapsulá-lo evita espalhar comparações de horário pelos services.

#### `Usuario` (Entidade)

* **Atributos:** `id: UUID`, `nome: String`, `email: String`, `telefone: String`, `perfil: TipoPerfil`, `ativo: boolean`.
* **Métodos:** `podeRealizarReserva(): boolean`.
* **Por que a classe existe:** Concentra a identidade e a regra de aptidão para reservar (`ativo` e `perfil`), que é regra do usuário, não do espaço nem do controller.

#### `StatusReserva` e `TipoPerfil` (Enums)

* **Valores:** `StatusReserva` (`CONFIRMADA`, `CANCELADA`) e `TipoPerfil` (`CLIENTE`, `ADMIN`).
* **Por que existem:** Tipificam de forma explícita e segura os estados válidos de uma reserva e os perfis de permissão do usuário no domínio.

---

### 2.2 Aplicação — Serviços de Casos de Uso (Coordenação / Portas Primárias)

#### `ReservaService`

* **Métodos:** `realizarReserva(usuarioId: UUID, espacoId: UUID, periodo: PeriodoHorario): Reserva`, `cancelarReserva(reservaId: UUID, usuarioId: UUID): void`, `consultarHorariosDisponiveis(espacoId: UUID, data: LocalDate): List<PeriodoHorario>`, `consultarEspacosDisponiveis(periodo: PeriodoHorario): List<EspacoEsportivo>`.
* **Responsabilidade:** Orquestrar repositórios, entidades do domínio e a porta `Notificador` (buscar entidades, delegar validações às entidades, detectar conflito percorrendo reservas e chamando `conflitaCom`, persistir `Reserva` e acionar `Notificador`) sem absorver regras que pertencem às entidades e sem conhecer HTTP, SQL ou SMTP.
* **Por que a classe existe:** Atua como coordenador dedicado do caso de uso (*Pure Fabrication*), mantendo o domínio livre de dependências de banco de dados e de provedores de notificação.

#### `EspacoEsportivoService`

* **Métodos:** `cadastrarEspaco(nome: String, tipo: String, capacidade: int): EspacoEsportivo`, `agendarManutencao(espacoId: UUID, periodo: PeriodoHorario): void`, `liberarManutencao(espacoId: UUID): void`, `definirRestricoes(espacoId: UUID, restricoes: List<RestricaoDeUso>): void`.
* **Responsabilidade:** Coordenar casos de uso administrativos do espaço, delegando invariantes a `EspacoEsportivo` e `RestricaoDeUso`.
* **Por que a classe existe:** Isola a orquestração das operações administrativas de quadras/espaços em relação à camada de entrada e à persistência.

#### `UsuarioService`

* **Métodos:** `cadastrarUsuario(nome: String, email: String, telefone: String, perfil: TipoPerfil): Usuario`, `buscarUsuario(usuarioId: UUID): Usuario`.
* **Responsabilidade:** Coordenar o ciclo de vida e a busca de usuários no domínio.
* **Por que a classe existe:** Encapsula a orquestração de criação e consulta de usuários (RF10), servindo de porta primária para o `UsuarioController`.

---

### 2.3 Adaptadores Primários — Controllers (Camada de Entrada)

#### `ReservaController`

* **Métodos:** `criarReserva(request)`, `cancelarReserva(reservaId: UUID, usuarioId: UUID)`, `consultarDisponibilidadeEspaco(espacoId: UUID, data: LocalDate)`, `consultarEspacosDisponiveis(data: LocalDate, horaInicio: LocalTime, horaFim: LocalTime)`.
* **Por que a classe existe:** Recebe requisições externas (HTTP/CLI) dos fluxos de reserva, cancelamento e consulta e apenas encaminha ao `ReservaService`.

#### `EspacoEsportivoController`

* **Métodos:** `cadastrarEspaco(request)`, `agendarManutencao(espacoId: UUID, request)`, `definirRestricoes(espacoId: UUID, request)`.
* **Por que a classe existe:** Adapta a entrada administrativa de espaços, manutenção e restrições de uso, delegando ao `EspacoEsportivoService`.

#### `UsuarioController`

* **Métodos:** `cadastrarUsuario(request)`.
* **Por que a classe existe:** Recebe a requisição externa de criação de usuário (RF10), valida o formato da entrada e delega ao `UsuarioService`.

---

### 2.4 Portas Secundárias — Interfaces de Saída no Núcleo

#### `Notificador`

* **Métodos:** `notificar(destinatario: String, assunto: String, mensagem: String): void`.
* **Por que a interface existe:** Define o contrato de saída para envio de notificações (RF06), permitindo trocar o provedor de comunicação sem alterar o `ReservaService`.

#### `ReservaRepository`

* **Métodos:** `salvar(reserva: Reserva): void`, `buscarPorId(id: UUID): Reserva`, `listarPorEspacoEData(espacoId: UUID, data: LocalDate): List<Reserva>`, `listarAtivasPorPeriodo(periodo: PeriodoHorario): List<Reserva>`.
* **Por que a interface existe:** Define o contrato de persistência e consulta de reservas, isolando o núcleo de detalhes de SQL/banco de dados.

#### `EspacoEsportivoRepository`

* **Métodos:** `salvar(espaco: EspacoEsportivo): void`, `buscarPorId(id: UUID): EspacoEsportivo`, `listarTodos(): List<EspacoEsportivo>`.
* **Por que a interface existe:** Abstrai o acesso a dados de espaços esportivos, manutenções e restrições associadas.

#### `UsuarioRepository`

* **Métodos:** `salvar(usuario: Usuario): void`, `buscarPorId(id: UUID): Usuario`.
* **Por que a interface existe:** Abstrai a persistência e recuperação de entidades `Usuario` para os serviços de aplicação.

---

### 2.5 Adaptadores Secundários — Implementações Concretas na Infraestrutura

#### `EmailNotificador` e `NotificadorFake` (Notificação)

* **Implementam:** `Notificador`.
* **Por que as classes existem:** `EmailNotificador` concretiza o envio de e-mail via SMTP, enquanto `NotificadorFake` simula o envio em memória para testes automatizados e execução local do protótipo.

#### `PostgreSQLReservaRepository`, `PostgreSQLEspacoEsportivoRepository`, `PostgreSQLUsuarioRepository` (e `Sqlite*Repository` / `InMemory*Repository`) (Persistência)

* **Implementam:** `ReservaRepository`, `EspacoEsportivoRepository` e `UsuarioRepository`.
* **Por que as classes existem:** Os adaptadores relacionais (`PostgreSQL*` na especificação alvo e `Sqlite*` no protótipo local) concretizam a persistência transacional ACID no banco único, enquanto os adaptadores `InMemory` (`InMemoryReservaRepository`, `InMemoryEspacoEsportivoRepository`, `InMemoryUsuarioRepository`) permitem testar as regras de negócio em memória em milissegundos.

Fluxo canônico (alinhado aos diagramas de sequência e comunicação):

```text
Cliente → ReservaController → ReservaService
         → repositórios (busca)
         → Usuario / EspacoEsportivo / RestricaoDeUso / Reserva / PeriodoHorario (regras)
         → ReservaRepository.salvar
         → Notificador
```

---

## 3. Distribuição de Responsabilidades e Justificativas GRASP

| Responsabilidade / Operação | Classe Responsável | Padrão GRASP | Justificativa |
| :--- | :--- | :--- | :--- |
| Receber requisições externas de reserva, cancelamento, consulta e cadastro e retornar resposta | `ReservaController` / `EspacoEsportivoController` / `UsuarioController` | **Controller** | Capturam o evento do caso de uso na borda HTTP/CLI e delegam ao Service correspondente, sem conter regras de negócio. |
| Verificar se o espaço está disponível (não está em manutenção no período) | `EspacoEsportivo` | **Information Expert** | Detém `emManutencao` e `periodosManutencao`, respondendo `estaDisponivelParaReserva(periodo)`. |
| Validar política de uso (se usuário e período atendem às restrições do espaço) | `RestricaoDeUso` (+ coordenação em `EspacoEsportivo`) | **Information Expert** | A restrição conhece seus próprios parâmetros (`validar(usuario, periodo)`); o espaço conhece *quais* restrições valem em `restricoesDeUso`. |
| Calcular se dois intervalos de horário se sobrepõem | `PeriodoHorario` | **Information Expert** | Possui `data`, `horaInicio` e `horaFim` e encapsula o cálculo em `sobrepoe(outroPeriodo)`. |
| Verificar conflito de horário com reserva ativa | `Reserva` | **Information Expert** | Combina seu estado ativo (`estaAtiva()`) com a sobreposição de `PeriodoHorario` em `conflitaCom(outroPeriodo)`, permitindo evoluir o critério internamente. |
| Cancelar uma reserva alterando seu status | `Reserva` | **Information Expert** | `Reserva` conhece seu próprio `status` e impede transições inválidas, alterando o estado para `CANCELADA`. |
| Verificar se o usuário pode fazer uma reserva | `Usuario` | **Information Expert** | Conhece `ativo` e `perfil` e encapsula a regra de aptidão em `podeRealizarReserva()`. |
| Orquestrar busca em repositórios, validações cruzadas, persistência e disparo de notificação | `ReservaService` | **Pure Fabrication** | Nenhuma entidade do domínio deve conhecer banco de dados ou provedor de notificação. |
| Instanciar nova `Reserva` após validações | `ReservaService` | **Creator** | Já reúne `Usuario`, `EspacoEsportivo` e `PeriodoHorario` válidos no fluxo do caso de uso. |
| Desacoplar canal de notificação e mecanismo de persistência do núcleo | `Notificador` e `*Repository` | **Protected Variations**, **Indirection**, **Polymorphism** | Variações tecnológicas (troca de E-mail para WhatsApp ou troca de banco) ficam isoladas atrás de contratos polimórficos. |
| Manter interações enxutas entre camadas e classes focadas | Fronteiras de módulo + portas | **Low Coupling** e **High Cohesion** | Cada módulo e classe muda por um único motivo principal de negócio e depende apenas das abstrações necessárias. |

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
| Notificação como módulo de integração atrás da porta `Notificador` e adaptadores (`EmailNotificador`, `NotificadorFake`) | Domínio de reserva não conhece e-mail/WhatsApp; atende ASR2 e testabilidade com Fake sem camada intermediária desnecessária. | Mais um contrato/adaptadores para manter; mitigado mantendo a porta `Notificador` enxuta e acionada diretamente pelo `ReservaService`. |
| `RestricaoDeUso` como entidade independente | RF09 fica natural (alterar/reassociar restrições); identidade e ciclo de vida próprios. | Mais persistência e consistência de associação espaço↔restrição do que um VO embutido. |
| `PeriodoHorario` como VO separado | Reuso e encapsulamento de sobreposição; services ficam legíveis. | Classe a mais para um conceito simples — custo baixo frente ao ganho de clareza. |
| Regras em entidades + orquestração no `ReservaService` | Information Expert real; evita “service anêmico” e “controller gordo”. | Service concentra o fluxo; precisa permanecer só coordenador (não reimplementar regras das entidades). |
| Controllers dedicados por módulo (`ReservaController`, `EspacoEsportivoController`, `UsuarioController`) | Cada módulo expõe sua própria borda de entrada de forma uniforme e coesa (inclusive RF10). | Um adaptador primário adicional para manter no roteamento HTTP/CLI. |
| Nomes genéricos (`conflitaCom`, `sobrepoe`, `validar`) | API estável se a regra interna mudar. | Exige documentação/testes claros do comportamento atual, já que o nome não detalha o critério. |

Em resumo: separa-se **o que muda por motivo de negócio diferente** (espaço, reserva, usuário, canal de aviso) e mantém-se **junto** o que precisa de consistência forte na mesma transação de reserva — alinhado aos ASRs de consistência, modificabilidade de notificação e testabilidade em equipe reduzida.
