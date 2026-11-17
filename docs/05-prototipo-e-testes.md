# 5. Protótipo Funcional e Análise de Evolução

## 1. Fatia vertical do protótipo

Não se implementa o sistema completo. A fatia mínima (Seções 7–8 do enunciado) é:

| # | Exigência | Como aparece na solução |
| :--- | :--- | :--- |
| 1 | Caso de uso que **modifica estado** | `ReservaController` → `ReservaService.realizarReserva` (cria e persiste `Reserva`) |
| 2 | **Consulta** | `consultarHorariosDisponiveis` (RF07) |
| 3 | **Fluxo alternativo / erro** | Horário já reservado (RF05); espaço em manutenção / restrição (RF04, RF09); usuário inapto (`403`) |
| 4 | **Persistência** | Adaptador de `ReservaRepository` (ex.: SQLite/Postgres) + `InMemory` nos testes |
| 5 | **Dependência externa substituível** | Porta `Notificador` com `EmailNotificador` e `NotificadorFake` |

Fluxo feliz resumido:

```text
criar reserva → validar usuário/espaço/restrições → checar conflito
  → persistir → notificar → 201
```

Consulta paralela: disponibilidade de horários no espaço.  
Erros relevantes: `409` (conflito/indisponível/restrição), `403` (usuário inapto).

O código deve permanecer coerente com os diagramas e com a arquitetura (Cliente–Servidor + Hexagonal + Camadas + Repository Architecture).

**Fora do escopo do protótipo** (salvo se necessário para demonstrar uma decisão): login completo, CRUD de tudo, painel admin completo, UI sofisticada.

---

## 2. Análise de evolução

*Questão do enunciado:* se uma tecnologia ou integração principal precisasse ser substituída, quais partes seriam afetadas?

### 2.1 E-mail → WhatsApp (`EmailNotificador` → `WhatsAppNotificador`)

* **Afetados:** novo adaptador secundário + wiring de injeção/configuração.
* **Inalterados:** entidades, `*Service`, controllers, portas `*Repository`, testes do núcleo com Fake.
* **Ajuda:** Hexagonal + DIP (`Notificador`).
* **Atenção:** o contrato deve falar em destinatário genérico (não só “endereço de e-mail”); `Usuario.telefone` já está previsto no modelo.

### 2.2 PostgreSQL/SQLite → outro mecanismo de persistência

* **Afetados:** adaptadores `*Repository` concretos, schema/migrações, config de conexão.
* **Inalterados:** domínio, services, portas, controllers, testes InMemory.
* **Ajuda:** Repository Pattern como porta no hexágono.
* **Dificulta:** Repository Architecture (schema único compartilhado) — mudanças profundas de tabela afetam todos os adaptadores que usam o mesmo esquema.

### 2.3 Inclusão de cliente mobile (além de Web/CLI)

* **Afetados:** novo cliente consumindo a API REST (e, se preciso, novos adaptadores primários).
* **Inalterados:** núcleo, portas secundárias, persistência, notificação.
* **Ajuda:** Cliente–Servidor + API uniforme + hexágono (mesmo `ReservaService`).
* **Dificulta:** monólito + banco único — pico de carga escala a aplicação como um todo e pressiona o banco central.
