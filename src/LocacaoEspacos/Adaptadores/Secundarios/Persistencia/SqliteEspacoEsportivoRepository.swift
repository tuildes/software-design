import Foundation

final class SqliteEspacoEsportivoRepository: EspacoEsportivoRepository {
    private let banco: BancoSqlite

    init(banco: BancoSqlite) {
        self.banco = banco
    }

    func salvar(_ espaco: EspacoEsportivo) {
        banco.transacao {
            banco.executar(
                """
                INSERT INTO espacos (id, nome, tipo, capacidade, em_manutencao)
                VALUES (?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    nome = excluded.nome,
                    tipo = excluded.tipo,
                    capacidade = excluded.capacidade,
                    em_manutencao = excluded.em_manutencao
                """,
                [
                    espaco.id.uuidString,
                    espaco.nome,
                    espaco.tipo,
                    String(espaco.capacidade),
                    espaco.emManutencao ? "1" : "0",
                ]
            )
            banco.executar("DELETE FROM periodos_manutencao WHERE espaco_id = ?", [espaco.id.uuidString])
            banco.executar("DELETE FROM restricoes WHERE espaco_id = ?", [espaco.id.uuidString])
            for periodo in espaco.periodosManutencao {
                banco.executar(
                    "INSERT INTO periodos_manutencao (espaco_id, data, hora_inicio, hora_fim) VALUES (?, ?, ?, ?)",
                    [espaco.id.uuidString, periodo.data.texto(), periodo.horaInicio.texto(), periodo.horaFim.texto()]
                )
            }
            for restricao in espaco.restricoesDeUso {
                banco.executar(
                    """
                    INSERT INTO restricoes (
                        id, espaco_id, descricao, duracao_maxima_minutos,
                        antecedencia_minima_horas, apenas_usuarios_autorizados
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    [
                        restricao.id.uuidString,
                        espaco.id.uuidString,
                        restricao.descricao,
                        String(restricao.duracaoMaximaMinutos),
                        String(restricao.antecedenciaMinimaHoras),
                        restricao.apenasUsuariosAutorizados ? "1" : "0",
                    ]
                )
            }
        }
    }

    func buscarPorId(_ id: UUID) -> EspacoEsportivo? {
        let linhas = banco.consultar(
            "SELECT id, nome, tipo, capacidade, em_manutencao FROM espacos WHERE id = ?",
            [id.uuidString]
        )
        guard let linha = linhas.first else { return nil }
        return montar(linha)
    }

    func listarTodos() -> [EspacoEsportivo] {
        banco.consultar("SELECT id, nome, tipo, capacidade, em_manutencao FROM espacos", []).compactMap(montar)
    }

    private func montar(_ linha: [String: String]) -> EspacoEsportivo? {
        guard let id = UUID(uuidString: linha["id"] ?? ""),
              let capacidade = Int(linha["capacidade"] ?? "") else {
            print("Erro de persistencia: espaco invalido")
            return nil
        }
        let periodos = banco.consultar(
            "SELECT data, hora_inicio, hora_fim FROM periodos_manutencao WHERE espaco_id = ?",
            [id.uuidString]
        ).compactMap { linhaPeriodo -> PeriodoHorario? in
            guard let data = DataLocal.interpretar(linhaPeriodo["data"] ?? ""),
                  let inicio = HoraLocal.interpretar(linhaPeriodo["hora_inicio"] ?? ""),
                  let fim = HoraLocal.interpretar(linhaPeriodo["hora_fim"] ?? "") else {
                return nil
            }
            return PeriodoHorario(data: data, horaInicio: inicio, horaFim: fim)
        }
        let restricoes = banco.consultar(
            """
            SELECT id, descricao, duracao_maxima_minutos, antecedencia_minima_horas, apenas_usuarios_autorizados
            FROM restricoes WHERE espaco_id = ?
            """,
            [id.uuidString]
        ).compactMap { linhaRestricao -> RestricaoDeUso? in
            guard let identificador = UUID(uuidString: linhaRestricao["id"] ?? ""),
                  let duracao = Int(linhaRestricao["duracao_maxima_minutos"] ?? ""),
                  let antecedencia = Int(linhaRestricao["antecedencia_minima_horas"] ?? "") else {
                return nil
            }
            return RestricaoDeUso(
                id: identificador,
                descricao: linhaRestricao["descricao"] ?? "",
                duracaoMaximaMinutos: duracao,
                antecedenciaMinimaHoras: antecedencia,
                apenasUsuariosAutorizados: (linhaRestricao["apenas_usuarios_autorizados"] ?? "0") == "1"
            )
        }
        return EspacoEsportivo(
            id: id,
            nome: linha["nome"] ?? "",
            tipo: linha["tipo"] ?? "",
            capacidade: capacidade,
            emManutencao: (linha["em_manutencao"] ?? "0") == "1",
            periodosManutencao: periodos,
            restricoesDeUso: restricoes
        )
    }
}
