# API HTTP e execução do protótipo

Este documento explica **por que** o protótipo fala por API, **como** a API funciona e **como rodar** o projeto.

Base URL (padrão): `http://127.0.0.1:8080`  
Prefixo: `/api/v1`  
Formato: JSON (`Content-Type: application/json`)

---

## 1. Por que implementação por API?

A organização arquitetural escolhida começa por **Cliente–Servidor**. A API HTTP/REST é a fronteira concreta entre os dois lados:

| Motivo | O que isso garante |
| :--- | :--- |
| **Separação cliente × servidor** | O cliente (CLI hoje; Web/mobile depois) **não** decide conflito, restrição ou manutenção. Só envia o pedido e interpreta a resposta. |
| **Um contrato estável** | O núcleo (`*Service` + domínio) permanece igual; muda só quem consome a API. |
| **Encaixa no hexágono** | Controllers são **adaptadores primários**: traduzem HTTP → caso de uso. Trocar CLI por Web não mexe em `ReservaService`. |
| **Feedback imediato** | Resposta síncrona com códigos claros (`201`, `403`, `409`) — adequado a RF05 (conflito de horário). |
| **Demonstração** | Dá para mostrar o servidor num terminal e o cliente noutro, evidenciando a arquitetura na prática. |

A CLI **não** é a regra de negócio: ela é só um cliente HTTP. Subir o servidor e chamar `POST /api/v1/reservas` é o mesmo caminho usado pela CLI.

```text
[CLI / curl / futuro Web]
        │  HTTP + JSON
        ▼
  Adaptadores primários (controllers)
        │
        ▼
  Aplicação + Domínio (regras)
        │
        ▼
  Adaptadores secundários (SQLite / Fake e-mail)
```

---

## 2. Como a API funciona

### 2.1 Fluxo geral

1. O cliente envia método + caminho + corpo JSON (quando houver).
2. `ServidorHttp` roteia para o controller adequado.
3. O controller valida o payload e chama o `*Service`.
4. O service aplica regras e usa portas (`*Repository`, `Notificador`).
5. A resposta volta como JSON + status HTTP.

Erros de negócio vêm no corpo:

```json
{ "mensagem": "Reserva invalida: horario ja reservado" }
```

### 2.2 Endpoints do protótipo

Só o que está implementado hoje:

| Método | Endpoint | Função | Sucesso |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/v1/usuarios` | Cadastrar usuário | `201` |
| `POST` | `/api/v1/espacos` | Cadastrar espaço | `201` |
| `POST` | `/api/v1/reservas` | Criar reserva (caso principal) | `201` |
| `GET` | `/api/v1/reservas` | Listar reservas | `200` |

> Outros endpoints da proposta completa (cancelamento, disponibilidade, manutenção…) estão no desenho arquitetural; o protótipo cobre a **fatia vertical**: cadastro + criar reserva + listar + erros de conflito/autorização.

### 2.3 `POST /api/v1/usuarios`

**Pedido**

```http
POST /api/v1/usuarios
Content-Type: application/json

{
  "nome": "Ana Silva",
  "email": "ana@exemplo.com",
  "telefone": "11999999999",
  "perfil": "CLIENTE"
}
```

| Campo | Obrigatório | Notas |
| :--- | :--- | :--- |
| `nome` | sim | texto não vazio |
| `email` | sim | texto não vazio |
| `telefone` | sim | texto não vazio |
| `perfil` | não | `CLIENTE` (padrão) ou `ADMIN` |

**Resposta `201`**

```json
{
  "id": "…-uuid-…",
  "nome": "Ana Silva",
  "email": "ana@exemplo.com",
  "telefone": "11999999999",
  "perfil": "CLIENTE",
  "ativo": true
}
```

Guarde o `id` — a reserva usa `usuarioId`.

### 2.4 `POST /api/v1/espacos`

**Pedido**

```http
POST /api/v1/espacos
Content-Type: application/json

{
  "nome": "Quadra 1",
  "tipo": "Quadra",
  "capacidade": 10
}
```

| Campo | Obrigatório | Notas |
| :--- | :--- | :--- |
| `nome` | sim | |
| `tipo` | sim | |
| `capacidade` | sim | inteiro &gt; 0 |

**Resposta `201`**

```json
{
  "id": "…-uuid-…",
  "nome": "Quadra 1",
  "tipo": "Quadra",
  "capacidade": 10
}
```

### 2.5 `POST /api/v1/reservas` (caso de uso principal)

Cria a reserva, valida usuário/espaço/período, detecta conflito, persiste e dispara o notificador.

**Pedido**

```http
POST /api/v1/reservas
Content-Type: application/json

{
  "usuarioId": "…-uuid-do-usuario-…",
  "espacoId": "…-uuid-do-espaco-…",
  "data": "2026-11-20",
  "horaInicio": "10:00",
  "horaFim": "11:00"
}
```

| Campo | Formato |
| :--- | :--- |
| `usuarioId` / `espacoId` | UUID |
| `data` | `AAAA-MM-DD` |
| `horaInicio` / `horaFim` | `HH:MM` |

**Resposta `201`**

```json
{
  "id": "…",
  "usuarioId": "…",
  "usuarioNome": "Ana Silva",
  "espacoId": "…",
  "espacoNome": "Quadra 1",
  "data": "2026-11-20",
  "horaInicio": "10:00",
  "horaFim": "11:00",
  "status": "CONFIRMADA"
}
```

**Erros frequentes**

| Status | Situação |
| :--- | :--- |
| `400` | JSON inválido, período inválido, campos malformados |
| `403` | Usuário não autorizado a reservar (ex.: inativo) |
| `404` | Usuário ou espaço não encontrado |
| `409` | Horário já reservado, espaço indisponível ou restrição |

### 2.6 `GET /api/v1/reservas`

Sem corpo. Resposta `200` com array de objetos no mesmo formato do item criado.

### 2.7 Exemplo com `curl`

Com o servidor no ar:

```bash
# 1) Usuário
curl -s -X POST http://127.0.0.1:8080/api/v1/usuarios \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Ana","email":"ana@ex.com","telefone":"11999999999","perfil":"CLIENTE"}'

# 2) Espaço
curl -s -X POST http://127.0.0.1:8080/api/v1/espacos \
  -H 'Content-Type: application/json' \
  -d '{"nome":"Quadra 1","tipo":"Quadra","capacidade":10}'

# 3) Reserva (troque os UUIDs)
curl -s -X POST http://127.0.0.1:8080/api/v1/reservas \
  -H 'Content-Type: application/json' \
  -d '{"usuarioId":"UUID","espacoId":"UUID","data":"2026-11-20","horaInicio":"10:00","horaFim":"11:00"}'

# 4) Listar
curl -s http://127.0.0.1:8080/api/v1/reservas
```

---

## 3. Como rodar o projeto

### Requisitos

- macOS 13+
- Swift 5.9+ (Xcode / Swift toolchain)
- `sqlite3` do sistema

### Compilar e testar

Na raiz do repositório:

```bash
swift build
swift test
```

### Subir o servidor

```bash
swift run locacao-espacos servidor \
  --porta 8080 \
  --notificador fake \
  --persistencia sqlite \
  --banco locacao.sqlite
```

| Flag | Valores | Papel |
| :--- | :--- | :--- |
| `--porta` | ex. `8080` | Porta HTTP |
| `--notificador` | `fake` \| `email` | Adaptador de notificação |
| `--persistencia` | `sqlite` \| `memoria` | Adaptador de repositório |
| `--banco` | caminho | Arquivo SQLite (só com `sqlite`) |

Para demo em sala, prefira `--notificador fake`: o terminal do servidor mostra o bloco de notificação a cada reserva.

### Usar a CLI (cliente)

Em **outro** terminal:

```bash
swift run locacao-espacos cli --servidor http://127.0.0.1:8080
```

Menu: cadastrar usuário → cadastrar espaço → criar reserva → ver reservas.

Comandos pontuais (também contra a API):

```bash
swift run locacao-espacos usuario cadastrar \
  --nome Ana --email ana@ex.com --telefone 11999999999 \
  --perfil CLIENTE --servidor http://127.0.0.1:8080

swift run locacao-espacos espaco cadastrar \
  --nome "Quadra 1" --tipo Quadra --capacidade 10 \
  --servidor http://127.0.0.1:8080

swift run locacao-espacos reserva criar \
  --usuario UUID --espaco UUID \
  --data 2026-11-20 --inicio 10:00 --fim 11:00 \
  --servidor http://127.0.0.1:8080

swift run locacao-espacos reserva listar --servidor http://127.0.0.1:8080
```

Ajuda:

```bash
swift run locacao-espacos --ajuda
```

### Roteiro rápido para apresentar

1. Terminal A: subir o servidor (`fake` + `sqlite`).
2. Terminal B: `cli` → cadastrar usuário e espaço → criar reserva.
3. No terminal A: apontar o log HTTP `POST /api/v1/reservas → 201` e o bloco do `NotificadorFake`.
4. No terminal B: criar outra reserva no mesmo horário → mostrar `409`.
5. Opcional: `curl` no mesmo endpoint para reforçar que a CLI é só um cliente da API.

---

## Referências

- Estrutura do código e papéis das pastas: [`src/README.md`](../src/README.md)
- Proposta arquitetural (Cliente–Servidor + Hexagonal): [`03-proposta-arquitetural.md`](03-proposta-arquitetural.md)
- Fatia do protótipo e evolução: [`05-prototipo-e-testes.md`](05-prototipo-e-testes.md)
