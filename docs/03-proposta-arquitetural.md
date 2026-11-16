# 3. Proposta Arquitetural

## 1. Organização Arquitetural Explícita

A arquitetura proposta é a combinação abaixo. Em seguida, cada elemento é mostrado **como aparece na solução** — não apenas pelo nome.

```text
Cliente–Servidor
  +
Monólito Modular
  +
Organização em Camadas
  +
MVC na Apresentação
```

### 1.1 Cliente–Servidor — como aparece

* Há um **cliente** (Web ou CLI) e um **servidor de aplicação** separados.
* O cliente **não** decide se o horário está livre, se há manutenção ou se a reserva pode ser criada. Ele apenas envia o pedido e recebe a resposta.
* O servidor concentra a lógica: valida aptidão, disponibilidade, restrições e conflitos; persiste; dispara notificação; devolve `201`, `403` ou `409`.
* **Evidência no fluxo principal:** `POST /api/v1/reservas` sai do cliente, chega ao `ReservaController` no servidor e só então o `ReservaService` executa as regras (diagrama de sequência / comunicação).

### 1.2 Monólito Modular — como aparece

* Tudo roda em **um único deploy / um processo** (não há um microsserviço por módulo).
* Por dentro, o servidor se divide em módulos com fronteira lógica:
  * **Reservas** — agenda, conflito, cancelamento, consultas de disponibilidade;
  * **Espaços Esportivos** — cadastro, manutenção, `RestricaoDeUso`;
  * **Usuários** — cadastro e aptidão;
  * **Notificação** — integração (fora do domínio de locação).
* A colaboração entre módulos é **chamada local (in-process)**. Ex.: ao reservar, o módulo Reservas consulta Espaços e Usuários sem atravessar a rede.
* **Evidência no diagrama de componentes:** um nó “Servidor de Aplicação (Monólito Modular — 1 Deploy)” contendo esses módulos.

### 1.3 Organização em Camadas — como aparece

Dentro do monólito, o código se organiza em camadas com dependência **de fora para dentro**:

| Camada | O que contém nesta solução | O que *não* faz |
| :--- | :--- | :--- |
| **Apresentação** | `ReservaController`, `EspacoEsportivoController` | Não calcula conflito nem manutenção |
| **Aplicação / Domínio** | `*Service` + entidades (`Reserva`, `EspacoEsportivo`, …) | Não fala HTTP, SQL ou SMTP diretamente |
| **Infraestrutura** | Implementações de `*Repository`, `EmailNotificador`, `NotificadorFake` | Não define regra de negócio |

* A camada de cima chama a do meio; a do meio usa **interfaces** (`ReservaRepository`, `Notificador`); a infraestrutura **implementa** essas interfaces.
* Assim, trocar Postgres por InMemory ou E-mail por Fake muda só a camada inferior.
* **Camada lógica ≠ tier físico:** as três camadas vivem no mesmo processo; o banco e o SMTP são recursos externos ligados pela infraestrutura.

### 1.4 MVC na Apresentação — como aparece

O MVC vale **na camada de apresentação** (não no domínio inteiro):

| Papel MVC | Na nossa solução |
| :--- | :--- |
| **Controller** | `ReservaController` / `EspacoEsportivoController` — recebem o HTTP, chamam o Service, devolvem o status |
| **Model** | Dados do request/response (ex.: `usuarioId`, `espacoId`, período) e o resultado do caso de uso trazido do Service |
| **View** | Representação devolvida ao cliente — aqui, o **JSON** da resposta REST (`201` com resumo da reserva, ou corpo de erro) |

* O Controller **orquestra e passa adiante**; quem aplica regra é o Service + entidades (camada de aplicação/domínio).
* **Evidência no diagrama de sequência:** `Cliente → ReservaController → ReservaService → …`; o Controller não chama `conflitaCom` nem `estaDisponivelParaReserva`.

### 1.5 Visão conjunta (diagrama de componentes)

```text
[Cliente Web / CLI]                    ← lado Cliente
        │  HTTP/REST JSON (síncrono)   ← Cliente–Servidor
        ▼
┌──────────── Servidor (Monólito Modular, 1 deploy) ────────────┐
│  APRESENTAÇÃO (MVC)                                           │
│    Controller → (Model request/response) → View JSON          │
│    ReservaController · EspacoEsportivoController              │
│         │                                                     │
│         ▼                                                     │
│  APLICAÇÃO / DOMÍNIO          ← camadas + módulos             │
│    Reservas | Espaços | Usuários | Notificação (integração) │
│         │                                                     │
│         ▼  interfaces (*Repository, Notificador)              │
│  INFRAESTRUTURA                                               │
│    Postgres/InMemory · EmailNotificador / NotificadorFake     │
└───────────┬──────────────────────────┬────────────────────────┘
            │ SQL / ACID               │ SMTP / API
            ▼                          ▼
   Banco relacional único     Sistema externo de notificação
```

---

## 2. Principais Componentes e Responsabilidades

| Componente | Camada / módulo | Responsabilidade |
| :--- | :--- | :--- |
| **Cliente (Web / CLI)** | Fora do servidor | Inicia consultas e comandos; renderiza ou exibe o JSON de resposta. |
| **`ReservaController`** | Apresentação (MVC — C) | Entrada dos fluxos de criar/cancelar reserva e consultar disponibilidade; valida formato superficial; chama `ReservaService`; devolve status HTTP + corpo. |
| **`EspacoEsportivoController`** | Apresentação (MVC — C) | Entrada administrativa: cadastro de espaço, manutenção, restrições; encaminha ao `EspacoEsportivoService`. |
| **`ReservaService`** | Aplicação · Módulo Reservas | Orquestra o caso de uso principal: busca entidades, aplica/coordena regras, persiste, dispara notificação. |
| **`EspacoEsportivoService`** | Aplicação · Módulo Espaços | Casos de uso de cadastro, manutenção e definição de `RestricaoDeUso`. |
| **`UsuarioService`** | Aplicação · Módulo Usuários | Cadastro/busca de usuário (RF10), sem `UsuarioController` dedicado. |
| **`NotificacaoService`** | Integração | Encapsula o disparo de confirmação/cancelamento via porta `Notificador`. |
| **Entidades / VO** | Domínio | `Reserva`, `EspacoEsportivo`, `RestricaoDeUso`, `Usuario`, `PeriodoHorario` — regras locais (disponibilidade, conflito, aptidão, etc.). |
| **Portas `*Repository` / `Notificador`** | Limite domínio ↔ infra | Contratos usados pelos services; implementações ficam na infraestrutura. |
| **Adaptadores Postgres / InMemory / Email / Fake** | Infraestrutura | Acesso ao banco e envio real ou simulado de mensagens. |
| **Banco relacional único** | Persistência | Fonte única da verdade da agenda (consistência ACID nas reservas). |
| **Sistema externo de notificação** | Integração externa | SMTP/API que entrega o aviso ao usuário. |

Não há `UsuarioController`: o cliente interage pelo `ReservaController`; o admin de espaços pelo `EspacoEsportivoController`; RF10 permanece no `UsuarioService` (adaptador primário mínimo: CLI/seed/endpoint admin pontual).

---

## 3. Dependências entre Componentes

Direção geral: **de fora para dentro** (apresentação → aplicação/domínio ← infraestrutura via interfaces).

```text
Cliente
  → ReservaController / EspacoEsportivoController
      → ReservaService / EspacoEsportivoService / UsuarioService
          → Entidades do domínio
          → ReservaRepository, EspacoEsportivoRepository, UsuarioRepository
          → NotificacaoService → Notificador
```

Dependências entre módulos de domínio (sempre **locais / in-process**):

* **Reservas → Espaços** e **Reservas → Usuários**, no fluxo de realizar reserva (precisa do espaço, das restrições e da aptidão do usuário).
* Espaços e Usuários **não** dependem de Reservas para seus casos de uso próprios.

A infraestrutura **implementa** as portas; o núcleo **não** depende das classes Postgres/Email.

---

## 4. Interfaces Relevantes

### Portas de aplicação (entrada da camada de domínio)

Na prática, os `*Service` são o contrato usado pelos controllers (porta primária implícita do caso de uso):

* `ReservaService.realizarReserva / cancelarReserva / consultarHorariosDisponiveis / consultarEspacosDisponiveis`
* `EspacoEsportivoService.cadastrarEspaco / agendarManutencao / liberarManutencao / definirRestricoes`
* `UsuarioService.cadastrarUsuario / buscarUsuario`

### Portas de saída (domínio → infraestrutura)

| Interface | Operações relevantes | Implementações |
| :--- | :--- | :--- |
| `ReservaRepository` | `salvar`, `buscarPorId`, `listarPorEspacoEData`, `listarAtivasPorPeriodo` | PostgreSQL, InMemory |
| `EspacoEsportivoRepository` | `salvar`, `buscarPorId`, `listarTodos` | PostgreSQL, InMemory |
| `UsuarioRepository` | `salvar`, `buscarPorId` | PostgreSQL, InMemory |
| `Notificador` | `notificar(destinatario, assunto, mensagem)` | `EmailNotificador`, `NotificadorFake` |

Essas interfaces são o mecanismo que permite trocar persistência ou canal de aviso **sem alterar** controllers nem entidades — coerente com a organização em camadas e com o ASR de modificabilidade de notificação.

---

## 5. Mecanismos e Decisões de Comunicação

| Fronteira | Mecanismo | Decisão e motivo |
| :--- | :--- | :--- |
| Cliente ↔ Servidor | **HTTP/REST síncrono + JSON** | A reserva precisa de resposta imediata (confirmada, horário ocupado, espaço em manutenção). Assíncrono na borda atrasaria o feedback do RF05. |
| Controller ↔ Service | **Chamada local** | MVC na apresentação: o Controller só encaminha; não há fila nem RPC interno. |
| Entre módulos (Reservas / Espaços / Usuários) | **In-process** | Monólito modular: latência mínima e participação na **mesma transação** local ao persistir a reserva. |
| Service ↔ Persistência | **Porta Repository + SQL transacional** | Checagem de conflito + `salvar` na mesma unidade de trabalho (ASR1). |
| Service ↔ Notificação | **Porta `Notificador` via `NotificacaoService`** | Integração desacoplada; hoje síncrona e simples; o adaptador pode evoluir (fila, WhatsApp) sem mudar o domínio. |

### Fluxo principal — Realizar Reserva (como a arquitetura aparece)

Alinhado aos diagramas de sequência e comunicação:

1. **Cliente → `ReservaController`** — `POST` criar reserva (**Cliente–Servidor** + **MVC**: Controller recebe o Model de request).
2. **Controller → `ReservaService.realizarReserva`** — atravessa a **camada de apresentação → aplicação** (chamada local).
3. **Service → `UsuarioRepository` / `Usuario.podeRealizarReserva()`** — aptidão no domínio.
4. **Service → `EspacoEsportivoRepository` / `estaDisponivelParaReserva` / `atendeRestricoes`** — regras do módulo Espaços, via dependência modular local.
5. **Service → `ReservaRepository.listarPorEspacoEData` + `Reserva.conflitaCom`** — RF05 no módulo Reservas.
6. **Service → `new Reserva` + `ReservaRepository.salvar`** — persistência ACID no banco único.
7. **Service → `NotificacaoService` → `Notificador`** — integração externa (RF06).
8. **Controller → Cliente** — `201` + JSON (**View** na apresentação) ou `403`/`409` com mensagem de erro.

O mesmo padrão vale para consulta de disponibilidade e cancelamento: Controller orquestra HTTP; Service coordena domínio e portas; entidades guardam as regras.

---

## 6. Persistência

* **Estilo:** banco de dados **relacional único** (fonte única da verdade da agenda).
* **Acesso:** apenas pelos adaptadores que implementam `*Repository` (camada de infraestrutura).
* **Transações:** locais ao monólito — validar disponibilidade/conflito e gravar a reserva na mesma transação, evitando *double booking*.
* **Protótipo/testes:** implementação **InMemory** das mesmas portas, sem mudar services nem controllers.

O banco **não** é ator nem módulo de domínio; é recurso de infraestrutura conectado pela camada inferior.

---

## 7. Integrações Externas

| Integração | Papel | Como se acopla |
| :--- | :--- | :--- |
| **Sistema externo de notificação** (SMTP / API de mensageria) | Entregar confirmação ou cancelamento ao usuário (RF06) | `NotificacaoService` → porta `Notificador` → `EmailNotificador` (produção) ou `NotificadorFake` (teste/protótipo) |
| **Cliente Web/CLI** | Único “cliente” do estilo Cliente–Servidor neste desenho | HTTP/REST; novos clientes (ex.: mobile) reutilizam a mesma API sem alterar o núcleo |

Não há integração síncrona obrigatória além de persistência e notificação no escopo atual.

---

## 8. Documentação de API

API REST exposta pelos controllers da camada de apresentação. Corpos em JSON; erros de negócio relevantes ao fluxo de reserva usam status como `403` (usuário inapto) e `409` (conflito / espaço indisponível / restrição).

| Método | Endpoint | Descrição | RF |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/reservas` | Criar reserva; dispara notificação se confirmada | RF02, RF05, RF06 |
| `DELETE` | `/api/v1/reservas/{id}` | Cancelar reserva ativa; dispara notificação | RF03, RF06 |
| `GET` | `/api/v1/espacos/{id}/disponibilidade?data=YYYY-MM-DD` | Horários disponíveis do espaço na data | RF07 |
| `GET` | `/api/v1/espacos/disponiveis?data=&inicio=&fim=` | Espaços livres no intervalo | RF08 |
| `POST` | `/api/v1/espacos` | Cadastrar espaço (Admin) | RF01 |
| `PATCH` | `/api/v1/espacos/{id}/manutencao` | Registrar/encerrar manutenção (Admin) | RF04 |
| `PUT` | `/api/v1/espacos/{id}/restricoes` | Definir/alterar restrições de uso (Admin) | RF09 |
| `POST` | `/api/v1/usuarios` | Cadastrar usuário (Admin; aciona `UsuarioService`, sem controller dedicado no modelo de domínio) | RF10 |

**Exemplo — criar reserva (fluxo principal):**

```http
POST /api/v1/reservas
Content-Type: application/json

{
  "usuarioId": "...",
  "espacoId": "...",
  "data": "2026-11-20",
  "horaInicio": "19:00",
  "horaFim": "20:00"
}
```

* Sucesso: `201` com resumo da reserva.
* Horário já reservado / espaço em manutenção / restrição: `409`.
* Usuário não autorizado a reservar: `403`.

---

## 9. Síntese — a combinação na solução (não só nos nomes)

No **realizar reserva**, as quatro decisões aparecem juntas, nesta ordem:

1. **Cliente–Servidor:** o cliente envia `POST /api/v1/reservas`; o servidor processa e responde `201`/`403`/`409`.
2. **MVC (apresentação):** `ReservaController` recebe o Model (JSON), chama o Service e devolve a View (JSON).
3. **Camadas:** a chamada desce Apresentação → Aplicação/Domínio → Infraestrutura (repositórios / notificador); o domínio não conhece HTTP nem SQL.
4. **Monólito Modular:** no mesmo processo, Reservas colabora com Espaços e Usuários por chamada local; a notificação fica no módulo de integração; um único deploy cobre o fluxo inteiro.

Essa combinação sustenta consistência de agenda (transação local + banco único), evolução do canal de aviso (interface `Notificador` na infraestrutura) e operação com equipe reduzida (um deploy, fronteiras lógicas claras).
