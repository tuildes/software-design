# Locação de Espaços Esportivos

Protótipo do Tema 14 (disciplina de Projeto de Software): sistema de reservas de espaços esportivos com API HTTP e CLI, em Swift.

**Arquitetura:** Cliente–Servidor + Hexagonal (Ports & Adapters) + Camadas + Repository Architecture (SQLite único).

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

Guia prático (por que API, endpoints, como rodar e apresentar): **[`docs/api.md`](docs/api.md)**.  
Estrutura do código: **[`src/README.md`](src/README.md)**.

## Documentação

| Documento | Conteúdo |
| :--- | :--- |
| [`docs/api.md`](docs/api.md) | API HTTP, motivo da escolha e como executar |
| [`docs/01-problema-e-requisitos.md`](docs/01-problema-e-requisitos.md) | Problema e requisitos |
| [`docs/02-modelo-de-dominio.md`](docs/02-modelo-de-dominio.md) | Modelo de domínio |
| [`docs/03-proposta-arquitetural.md`](docs/03-proposta-arquitetural.md) | Proposta arquitetural |
| [`docs/04-alternativas-e-tradeoffs.md`](docs/04-alternativas-e-tradeoffs.md) | Alternativas e trade-offs |
| [`docs/05-prototipo-e-testes.md`](docs/05-prototipo-e-testes.md) | Protótipo e evolução |
| [`docs/diagramas/`](docs/diagramas/) | Diagramas |
| [`docs/adr/`](docs/adr/) | ADRs |
