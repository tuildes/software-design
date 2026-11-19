# Código-fonte — Locação de Espaços Esportivos

Protótipo em Swift (SPM). A pasta `src/` **é a raiz da biblioteca** e espelha a arquitetura:

**Cliente–Servidor + Monólito Modular + Hexagonal (Ports & Adapters) + Repository Architecture (SQLite).**

```text
src/
├── App/                         # Cliente CLI + bootstrap do processo
├── Reservas/                    # Módulo (core)
│   ├── Dominio/
│   ├── Aplicacao/               # ReservaService + ReservaPort
│   └── Portas/                  # ReservaRepository, UnidadeDeTrabalho
├── Espacos/
│   ├── Dominio/
│   ├── Aplicacao/               # EspacoEsportivoService + EspacoPort
│   └── Portas/
├── Usuarios/
│   ├── Dominio/
│   ├── Aplicacao/               # UsuarioService + UsuarioPort
│   └── Portas/
├── Notificacao/                 # Módulo de integração (só contrato)
│   └── Portas/                  # Notificador
├── Adaptadores/
│   ├── Primarios/               # HTTP / controllers (driving)
│   └── Secundarios/             # SQLite, InMemory, Email, Fake (driven)
└── Composicao/                  # Wiring das implementações
```

Documentação: [`docs/`](../docs/) · API e como rodar: [`docs/api.md`](../docs/api.md).

---

## Como narrar a arquitetura (30s)

1. **`App/`** — cliente HTTP (não contém regra de negócio).
2. **Módulos** no topo — `Reservas`, `Espacos`, `Usuarios`, `Notificacao`.
3. Dentro de cada módulo — **Domínio → Aplicação → Portas** (camadas).
4. **`Adaptadores/`** — bordas do hexágono (HTTP entra; SQLite/e-mail saem).
5. **`Composicao/`** — escolhe adaptadores concretos (`--persistencia`, `--notificador`).

```text
[CLI / curl]
    │  HTTP + JSON
    ▼
Adaptadores/Primarios  →  *Port  →  *Service  →  Domínio
                              │
                              ▼
                         *Repository / Notificador
                              ▲
Adaptadores/Secundarios ──────┘
```

---

## Como rodar

```bash
swift build
swift test

swift run locacao-espacos servidor \
  --porta 8080 --notificador fake \
  --persistencia sqlite --banco locacao.sqlite

# outro terminal
swift run locacao-espacos cli --servidor http://127.0.0.1:8080
```

Ajuda: `swift run locacao-espacos --ajuda`

| Flag | Valores | Efeito |
| :--- | :--- | :--- |
| `--notificador` | `email` \| `fake` | Adaptador de notificação |
| `--persistencia` | `sqlite` \| `memoria` | Adaptador de repositório |
| `--banco` | caminho | Arquivo SQLite |

Trocar flags **não** altera `Reservas/Aplicacao` — só o wiring em `Composicao/`.

---

## Targets SPM

| Target | Path | Produto |
| :--- | :--- | :--- |
| `LocacaoEspacos` | `src` (exclui `App` e `README.md`) | biblioteca |
| `App` | `src/App` | executável `locacao-espacos` |
| `LocacaoEspacosTests` | `Tests/LocacaoEspacosTests` | testes |
