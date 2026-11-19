# 3. Proposta Arquitetural

## 1. Organização Arquitetural Explícita

```text
Estilo Cliente-Servidor (Acesso HTTP/REST ou CLI)
  +
Padrão Monólito Modular (Divisão lógica em 4 módulos em 1 único processo/deploy)
  +
Padrão Arquitetura Hexagonal / Ports & Adapters (Isolamento do núcleo e DIP)
  +
Estilo Repository Architecture (Banco relacional centralizado como fonte única da verdade)
```

> O servidor é implantado como **monólito modular** (1 processo/deploy, módulos Reservas / Espaços / Usuários + integração de Notificação). Isso é a forma de empacotamento; a organização arquitetural nomeada acima é o que estrutura acesso, isolamento do núcleo, camadas e persistência.

### 1.1 Cliente–Servidor — como aparece

* Há um **cliente** (Web ou CLI) e um **servidor de aplicação** separados.
* O cliente **não** decide disponibilidade, manutenção, restrição ou conflito: só envia o pedido e recebe a resposta.
* O servidor concentra a lógica, persiste, notifica e devolve `201`, `403` ou `409`.
* **Evidência:** `POST /api/v1/reservas` no fluxo principal (diagramas de sequência e comunicação).

### 1.2 Arquitetura Hexagonal — como aparece

* O **núcleo** (entidades + `*Service`) não depende de HTTP, SQL/ORM nem SMTP.
* **Adaptadores primários (driving):** `ReservaController`, `EspacoEsportivoController`, `UsuarioController` — conduzem o caso de uso a partir do cliente.
* **Portas secundárias:** `ReservaRepository`, `EspacoEsportivoRepository`, `UsuarioRepository`, `Notificador`.
* **Adaptadores secundários (driven):** Postgres/InMemory e `EmailNotificador` / `NotificadorFake`.
* Dependências apontam **de fora para o centro** (DIP): trocar e-mail por WhatsApp ou Fake não altera `Reserva` nem o fluxo de `realizarReserva`.
* **Evidência:** diagrama de componentes (núcleo + portas + adaptadores) e ASR2 (modificabilidade de notificação).

### 1.3 Organização em Camadas — como aparece

Dentro do hexágono, o código ainda se organiza em camadas lógicas:

| Camada | Conteúdo na solução | Papel |
| :--- | :--- | :--- |
| **Apresentação** | Controllers (adaptadores primários) | Entrada/saída HTTP; encaminha ao Service |
| **Aplicação / Domínio** | `*Service` + entidades / VO | Casos de uso e regras (`conflitaCom`, `estaDisponivelParaReserva`, …) |
| **Infraestrutura** | Adaptadores de persistência e notificação | Implementam as portas; falam com banco e SMTP |

* Camada de cima chama a do meio; o meio depende de **interfaces**, não de classes concretas da infraestrutura.
* **Camada ≠ tier:** as três camadas rodam no mesmo processo; banco e serviço de e-mail são recursos externos.

### 1.4 Repository Architecture — como aparece

* Os módulos operam sobre um **banco relacional único** como **fonte única da verdade** da agenda (espaços, restrições, manutenções, reservas).
* Consistência **ACID** na mesma transação local: checar conflito + gravar reserva (ASR1 / RF05).
* **Distinção:** *Repository Architecture* = estilo de dados centralizados; *Repository Pattern* = portas OO (`*Repository`) usadas no hexágono para acessar esse banco sem acoplar o domínio ao SQL.
* **Evidência:** diagrama de componentes (“Banco de Dados Relacional Único”) e fluxo de `salvar(novaReserva)` após `conflitaCom`.

### 1.5 Visão conjunta

```text
[Cliente Web / CLI]
        │  HTTP/REST JSON (síncrono)          ← Cliente–Servidor
        ▼
┌────── Servidor (Monólito Modular, 1 deploy) ──────────────────────────────┐
│  Adaptadores primários (Apresentação)                                     │
│    ReservaController · EspacoEsportivoController · UsuarioController      │
│         │                                                                 │
│         ▼  Portas primárias / Services                                    │
│  ┌──── Núcleo Hexagonal (Camadas Aplicação/Domínio) ──────────────────┐ │
│  │  Reservas | Espaços | Usuários                                      │ │
│  │  Portas: *Repository, Notificador                                   │ │
│  └───────────┬──────────────────────────────┬──────────────────────────┘ │
│              ▼                              ▼                            │
│  Adaptadores secundários (Infraestrutura)                                │
│    Postgres / InMemory · EmailNotificador / NotificadorFake              │
└──────────────┬──────────────────────────────┬────────────────────────────┘
               │ SQL / ACID                   │ SMTP / API
               ▼                              ▼
  Banco relacional único              Sistema externo de notificação
  (Repository Architecture)
```

---

## 2. Principais Componentes e Responsabilidades

| Componente | Onde se encaixa | Responsabilidade |
| :--- | :--- | :--- |
| **Cliente (Web / CLI)** | Lado cliente | Inicia comandos/consultas; consome JSON. |
| **`ReservaController`** | Adaptador primário / apresentação | Criar/cancelar reserva e consultas de disponibilidade; só encaminha ao `ReservaService`. |
| **`EspacoEsportivoController`** | Adaptador primário / apresentação | Cadastro, manutenção e restrições; encaminha ao `EspacoEsportivoService`. |
| **`UsuarioController`** | Adaptador primário / apresentação | Cadastro de usuários (RF10); encaminha ao `UsuarioService`. |
| **`ReservaService`** | Núcleo · módulo Reservas | Orquestra o caso de uso principal (regras + portas + notificação). |
| **`EspacoEsportivoService`** | Núcleo · módulo Espaços | Cadastro, manutenção, `RestricaoDeUso`. |
| **`UsuarioService`** | Núcleo · módulo Usuários | Cadastro/busca de usuários (RF10). |
| **Entidades / VO** | Domínio | `Reserva`, `EspacoEsportivo`, `RestricaoDeUso`, `Usuario`, `PeriodoHorario`. |
| **Portas `*Repository` / `Notificador`** | Limite hexagonal | Contratos do núcleo; implementações na infraestrutura. |
| **Adaptadores Postgres / InMemory / Email / Fake** | Infraestrutura | Persistência e envio real/simulado. |
| **Banco relacional único** | Repository Architecture | Fonte única da verdade; transações ACID. |
| **Sistema externo de notificação** | Integração externa | Entrega do aviso (SMTP/API). |

---

## 3. Dependências entre Componentes

Direção: **bordas → núcleo** (hexágono) e **apresentação → domínio ← infraestrutura** (camadas).

```text
Cliente
  → Controllers (adaptadores primários)
      → *Service (núcleo)
          → Entidades
          → *Repository / Notificador (portas)
              ← Adaptadores Postgres / Email / Fake
```

* **Reservas → Espaços** e **Reservas → Usuários** por chamada **in-process** (mesmo monólito).
* Infraestrutura implementa portas; o núcleo **não** importa Postgres nem SMTP.

---

## 4. Interfaces Relevantes

### Portas primárias (entrada)

* `ReservaService.realizarReserva / cancelarReserva / consultarHorariosDisponiveis / consultarEspacosDisponiveis`
* `EspacoEsportivoService.cadastrarEspaco / agendarManutencao / liberarManutencao / definirRestricoes`
* `UsuarioService.cadastrarUsuario / buscarUsuario`

### Portas secundárias (saída)

| Interface | Operações | Adaptadores |
| :--- | :--- | :--- |
| `ReservaRepository` | `salvar`, `buscarPorId`, `listarPorEspacoEData`, `listarAtivasPorPeriodo` | PostgreSQL, InMemory |
| `EspacoEsportivoRepository` | `salvar`, `buscarPorId`, `listarTodos` | PostgreSQL, InMemory |
| `UsuarioRepository` | `salvar`, `buscarPorId` | PostgreSQL, InMemory |
| `Notificador` | `notificar(destinatario, assunto, mensagem)` | `EmailNotificador`, `NotificadorFake` |

---

## 5. Mecanismos e Decisões de Comunicação

| Fronteira | Mecanismo | Decisão e motivo |
| :--- | :--- | :--- |
| Cliente ↔ Servidor | **HTTP/REST síncrono + JSON** | Feedback imediato de confirmação/conflito (RF05). |
| Adaptador primário ↔ Service | **Chamada local** | Controller só conduz o caso de uso ao núcleo. |
| Entre módulos de domínio | **In-process** | Mesma transação local; sem rede interna. |
| Núcleo ↔ Persistência | **Porta `*Repository` + SQL ACID** | Repository Architecture + Repository Pattern; ASR1. |
| Núcleo ↔ Notificação | **Porta `Notificador`** | Hexágono: canal substituível (ASR2). |

### Fluxo principal — Realizar Reserva (como a arquitetura aparece)

1. **Cliente → `ReservaController`** — Cliente–Servidor; adaptador primário recebe o HTTP.
2. **Controller → `ReservaService.realizarReserva`** — atravessa apresentação → núcleo (camadas + hexágono).
3. **Service → `UsuarioRepository` / `podeRealizarReserva()`** — porta + regra de domínio.
4. **Service → `EspacoEsportivoRepository` / `estaDisponivelParaReserva` / `atendeRestricoes`** — módulo Espaços, in-process.
5. **Service → `listarPorEspacoEData` + `conflitaCom`** — RF05 no núcleo.
6. **Service → `salvar(novaReserva)`** — Repository Architecture (transação no banco único).
7. **Service → `Notificador`** — adaptador secundário (RF06).
8. **Controller → Cliente** — `201` / `403` / `409` em JSON.

---

## 6. Persistência

* **Repository Architecture:** um banco relacional compartilhado como fonte única da verdade.
* **Acesso:** só via adaptadores das portas `*Repository` (Repository Pattern no hexágono).
* **Transações locais:** validar conflito/manutenção e persistir a reserva atomicamente.
* **Testes/protótipo:** `InMemory*Repository` nas mesmas portas, sem alterar o núcleo.

O banco não é ator: é recurso da infraestrutura.

---

## 7. Integrações Externas

| Integração | Papel | Acoplamento |
| :--- | :--- | :--- |
| **Sistema externo de notificação** | Confirmação/cancelamento (RF06) | Porta `Notificador` → `EmailNotificador` / `NotificadorFake` |
| **Cliente Web/CLI** | Lado cliente do C–S | HTTP/REST; novos clientes reutilizam a API sem mudar o núcleo |

---

## 8. Documentação de API

Detalhamento operacional (corpos, curl, como rodar): [`api.md`](api.md).

### 8.1 Implementado no protótipo (fatia vertical)

| Método | Endpoint | Descrição | RF |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/usuarios` | Cadastrar usuário | RF10 |
| `POST` | `/api/v1/espacos` | Cadastrar espaço | RF01 |
| `POST` | `/api/v1/reservas` | Criar reserva; notifica se confirmada | RF02, RF05, RF06 |
| `GET` | `/api/v1/reservas` | Listar reservas | — |

Persistência do protótipo: **SQLite** (banco relacional único) ou InMemory; notificação `Email` / `Fake`.

**Exemplo — criar reserva:**

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

* `201` — reserva criada · `409` — conflito / indisponível / restrição · `403` — usuário inapto.

### 8.2 Desenho alvo (ainda não exposto no HTTP do protótipo)

| Método | Endpoint | Descrição | RF |
| :--- | :--- | :--- | :--- |
| `DELETE` | `/api/v1/reservas/{id}` | Cancelar reserva ativa; notifica | RF03, RF06 |
| `GET` | `/api/v1/espacos/{id}/disponibilidade?data=YYYY-MM-DD` | Horários disponíveis | RF07 |
| `GET` | `/api/v1/espacos/disponiveis?data=&inicio=&fim=` | Espaços livres no intervalo | RF08 |
| `PATCH` | `/api/v1/espacos/{id}/manutencao` | Manutenção (Admin) | RF04 |
| `PUT` | `/api/v1/espacos/{id}/restricoes` | Restrições de uso (Admin) | RF09 |

Parte da orquestração já existe nos `*Service` / domínio (ex.: manutenção e restrições em `EspacoEsportivoService`); faltam sobretudo rotas nos adaptadores primários.