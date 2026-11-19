import Foundation

final class SqliteReservaRepository: ReservaRepository {
    private let banco: BancoSqlite
    private let usuarios: SqliteUsuarioRepository
    private let espacos: SqliteEspacoEsportivoRepository

    init(banco: BancoSqlite, usuarios: SqliteUsuarioRepository, espacos: SqliteEspacoEsportivoRepository) {
        self.banco = banco
        self.usuarios = usuarios
        self.espacos = espacos
    }

    func salvar(_ reserva: Reserva) {
        banco.executar(
            """
            INSERT INTO reservas (id, espaco_id, usuario_id, data, hora_inicio, hora_fim, status)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                espaco_id = excluded.espaco_id,
                usuario_id = excluded.usuario_id,
                data = excluded.data,
                hora_inicio = excluded.hora_inicio,
                hora_fim = excluded.hora_fim,
                status = excluded.status
            """,
            [
                reserva.id.uuidString,
                reserva.espacoEsportivo.id.uuidString,
                reserva.usuario.id.uuidString,
                reserva.periodoHorario.data.texto(),
                reserva.periodoHorario.horaInicio.texto(),
                reserva.periodoHorario.horaFim.texto(),
                reserva.status.rawValue,
            ]
        )
    }

    func buscarPorId(_ id: UUID) -> Reserva? {
        let linhas = banco.consultar(
            "SELECT id, espaco_id, usuario_id, data, hora_inicio, hora_fim, status FROM reservas WHERE id = ?",
            [id.uuidString]
        )
        guard let linha = linhas.first else { return nil }
        return montar(linha)
    }

    func listarTodas() -> [Reserva] {
        banco.consultar(
            "SELECT id, espaco_id, usuario_id, data, hora_inicio, hora_fim, status FROM reservas",
            []
        ).compactMap(montar)
    }

    func listarPorEspacoEData(_ espacoId: UUID, _ data: DataLocal) -> [Reserva] {
        banco.consultar(
            """
            SELECT id, espaco_id, usuario_id, data, hora_inicio, hora_fim, status
            FROM reservas WHERE espaco_id = ? AND data = ?
            """,
            [espacoId.uuidString, data.texto()]
        ).compactMap(montar)
    }

    func listarAtivasPorPeriodo(_ periodo: PeriodoHorario) -> [Reserva] {
        banco.consultar(
            "SELECT id, espaco_id, usuario_id, data, hora_inicio, hora_fim, status FROM reservas WHERE status = ?",
            [StatusReserva.confirmada.rawValue]
        ).compactMap(montar).filter { $0.conflitaCom(periodo) }
    }

    private func montar(_ linha: [String: String]) -> Reserva? {
        guard let id = UUID(uuidString: linha["id"] ?? ""),
              let espacoId = UUID(uuidString: linha["espaco_id"] ?? ""),
              let usuarioId = UUID(uuidString: linha["usuario_id"] ?? ""),
              let data = DataLocal.interpretar(linha["data"] ?? ""),
              let inicio = HoraLocal.interpretar(linha["hora_inicio"] ?? ""),
              let fim = HoraLocal.interpretar(linha["hora_fim"] ?? ""),
              let status = StatusReserva(rawValue: linha["status"] ?? ""),
              let espaco = espacos.buscarPorId(espacoId),
              let usuario = usuarios.buscarPorId(usuarioId) else {
            print("Erro de persistencia: reserva invalida")
            return nil
        }
        return Reserva(
            id: id,
            espacoEsportivo: espaco,
            usuario: usuario,
            periodoHorario: PeriodoHorario(data: data, horaInicio: inicio, horaFim: fim),
            status: status
        )
    }
}
