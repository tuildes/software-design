import Foundation

final class RestricaoDeUso {
    let id: UUID
    let descricao: String
    let duracaoMaximaMinutos: Int
    let antecedenciaMinimaHoras: Int
    let apenasUsuariosAutorizados: Bool

    init(
        id: UUID = UUID(),
        descricao: String,
        duracaoMaximaMinutos: Int,
        antecedenciaMinimaHoras: Int,
        apenasUsuariosAutorizados: Bool
    ) {
        self.id = id
        self.descricao = descricao
        self.duracaoMaximaMinutos = duracaoMaximaMinutos
        self.antecedenciaMinimaHoras = antecedenciaMinimaHoras
        self.apenasUsuariosAutorizados = apenasUsuariosAutorizados
    }

    func validar(_ usuario: Usuario, _ periodo: PeriodoHorario) -> Bool {
        if !periodo.ehValido() {
            return false
        }
        if apenasUsuariosAutorizados && !usuario.ativo {
            return false
        }
        if duracaoMaximaMinutos > 0 && duracaoMinutos(periodo) > duracaoMaximaMinutos {
            return false
        }
        if antecedenciaMinimaHoras > 0 && horasAteInicio(periodo) < Double(antecedenciaMinimaHoras) {
            return false
        }
        return true
    }
}

private func duracaoMinutos(_ periodo: PeriodoHorario) -> Int {
    let inicio = periodo.horaInicio.hora * 60 + periodo.horaInicio.minuto
    let fim = periodo.horaFim.hora * 60 + periodo.horaFim.minuto
    return fim - inicio
}

private func horasAteInicio(_ periodo: PeriodoHorario, agora: Date = Date()) -> Double {
    var componentes = DateComponents()
    componentes.year = periodo.data.ano
    componentes.month = periodo.data.mes
    componentes.day = periodo.data.dia
    componentes.hour = periodo.horaInicio.hora
    componentes.minute = periodo.horaInicio.minuto
    guard let inicio = Calendar.current.date(from: componentes) else {
        return -1
    }
    return inicio.timeIntervalSince(agora) / 3600
}
