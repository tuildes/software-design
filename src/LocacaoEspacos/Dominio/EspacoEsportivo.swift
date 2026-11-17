import Foundation

final class EspacoEsportivo {
    let id: UUID
    let nome: String
    let tipo: String
    let capacidade: Int
    private(set) var emManutencao: Bool
    private(set) var periodosManutencao: [PeriodoHorario]
    private(set) var restricoesDeUso: [RestricaoDeUso]

    init(
        id: UUID = UUID(),
        nome: String,
        tipo: String,
        capacidade: Int,
        emManutencao: Bool = false,
        periodosManutencao: [PeriodoHorario] = [],
        restricoesDeUso: [RestricaoDeUso] = []
    ) {
        self.id = id
        self.nome = nome
        self.tipo = tipo
        self.capacidade = capacidade
        self.emManutencao = emManutencao
        self.periodosManutencao = periodosManutencao
        self.restricoesDeUso = restricoesDeUso
    }

    func estaDisponivelParaReserva(_ periodo: PeriodoHorario) -> Bool {
        if periodosManutencao.contains(where: { $0.sobrepoe(periodo) }) {
            return false
        }
        if emManutencao && periodosManutencao.isEmpty {
            return false
        }
        return true
    }

    func atendeRestricoes(_ usuario: Usuario, _ periodo: PeriodoHorario) -> Bool {
        restricoesDeUso.allSatisfy { $0.validar(usuario, periodo) }
    }

    func iniciarManutencao(_ periodo: PeriodoHorario) {
        emManutencao = true
        periodosManutencao.append(periodo)
    }

    func encerrarManutencao() {
        emManutencao = false
        periodosManutencao.removeAll()
    }

    func adicionarRestricao(_ restricao: RestricaoDeUso) {
        restricoesDeUso.append(restricao)
    }

    func definirRestricoes(_ restricoes: [RestricaoDeUso]) {
        restricoesDeUso = restricoes
    }
}
