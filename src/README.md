# Código-fonte — Locação de Espaços Esportivos

Protótipo em Swift (SPM) organizado como **Cliente–Servidor + Arquitetura Hexagonal + Camadas + Repository Architecture**.

```text
src/
├── App/                         # Executável (CLI + arranque do servidor)
│   └── main.swift
└── LocacaoEspacos/              # Biblioteca (núcleo testável)
    ├── Dominio/                 # Entidades e value objects
    ├── Aplicacao/               # Casos de uso + portas
    │   ├── Reservas/
    │   ├── Espacos/
    │   ├── Usuarios/
    │   └── Portas/              # Contratos (Repository, Notificador)
    ├── Adaptadores/
    │   ├── Primarios/           # HTTP / controllers (driving)
    │   └── Secundarios/         # Persistência e notificação (driven)
    │       ├── Persistencia/    # SQLite + InMemory
    │       └── Notificacao/     # Email + Fake
    └── Composicao/              # Wiring (injeção das implementações)
```

Documentação de requisitos, arquitetura e API: pasta [`docs/`](../docs/) na raiz do repositório.

---

## O que cada pasta faz

| Pasta | Papel |
| :--- | :--- |
| **`App/`** | Entrada do processo: sobe o servidor HTTP ou age como cliente CLI contra a API. |
| **`Dominio/`** | Regras puras (`Reserva`, `EspacoEsportivo`, `PeriodoHorario`, …). Sem HTTP/SQL. |
| **`Aplicacao/`** | Services que orquestram casos de uso; dependem só de **portas**. |
| **`Aplicacao/Portas/`** | Interfaces do hexágono (`*Repository`, `Notificador`). |
| **`Adaptadores/Primarios/`** | REST JSON (`ServidorHttp`, controllers). |
| **`Adaptadores/Secundarios/`** | SQLite / memória e e-mail / fake. |
| **`Composicao/`** | Monta o grafo de dependências conforme flags da CLI. |

Dependências apontam **para o centro**: adaptadores → aplicação/domínio; o domínio não conhece SQLite nem HTTP.

---

## Como rodar

Requisitos: Swift 5.9+, macOS 13+, biblioteca `sqlite3` do sistema.

Na raiz do repositório:

```bash
# Compilar
swift build

# Testes
swift test

# Servidor (SQLite + notificador fake — bom para demo)
swift run locacao-espacos servidor \
  --porta 8080 \
  --notificador fake \
  --persistencia sqlite \
  --banco locacao.sqlite
```

Em outro terminal, cliente interativo:

```bash
swift run locacao-espacos cli --servidor http://127.0.0.1:8080
```

Ou comandos pontuais (com o servidor já no ar):

```bash
swift run locacao-espacos usuario cadastrar \
  --nome "Ana" --email ana@ex.com --telefone 11999999999 \
  --perfil CLIENTE --servidor http://127.0.0.1:8080

swift run locacao-espacos espaco cadastrar \
  --nome "Quadra 1" --tipo Quadra --capacidade 10 \
  --servidor http://127.0.0.1:8080

swift run locacao-espacos reserva criar \
  --usuario <UUID> --espaco <UUID> \
  --data 2026-11-20 --inicio 10:00 --fim 11:00 \
  --servidor http://127.0.0.1:8080

swift run locacao-espacos reserva listar --servidor http://127.0.0.1:8080
```

Ajuda da CLI:

```bash
swift run locacao-espacos --ajuda
```

### Opções do servidor

| Flag | Valores | Efeito |
| :--- | :--- | :--- |
| `--porta` | ex.: `8080` | Porta HTTP |
| `--notificador` | `email` \| `fake` | Adaptador de notificação |
| `--persistencia` | `sqlite` \| `memoria` | Adaptador de repositório |
| `--banco` | caminho | Arquivo SQLite (só com `sqlite`) |

Trocar notificador ou persistência **não** altera domínio nem services — só o wiring em `Composicao/`.

---

## API (resumo)

Base: `http://127.0.0.1:8080/api/v1`

| Método | Caminho | Uso |
| :--- | :--- | :--- |
| `POST` | `/usuarios` | Cadastrar usuário |
| `POST` | `/espacos` | Cadastrar espaço |
| `POST` | `/reservas` | Criar reserva (caso de uso principal) |
| `GET` | `/reservas` | Listar reservas |
| `GET` | `/espacos/{id}/horarios-disponiveis?...` | Consulta de disponibilidade |

Detalhes de corpos e códigos de erro: [`docs/api.md`](../docs/api.md) (quando preenchido) e os controllers em `Adaptadores/Primarios/`.

---

## Targets SPM

Definidos em [`Package.swift`](../Package.swift):

| Target | Path | Produto |
| :--- | :--- | :--- |
| `LocacaoEspacos` | `src/LocacaoEspacos` | biblioteca |
| `App` | `src/App` | executável `locacao-espacos` |
| `LocacaoEspacosTests` | `Tests/LocacaoEspacosTests` | testes |
