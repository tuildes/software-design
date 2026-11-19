import Foundation

struct DataLocal: Equatable {
    let ano: Int
    let mes: Int
    let dia: Int

    func texto() -> String {
        String(format: "%04d-%02d-%02d", ano, mes, dia)
    }

    static func interpretar(_ texto: String) -> DataLocal? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let partes = limpo.split(separator: "-")
        guard partes.count == 3,
              let ano = Int(partes[0]),
              let mes = Int(partes[1]),
              let dia = Int(partes[2]),
              ano >= 1,
              (1...12).contains(mes),
              (1...31).contains(dia) else {
            return nil
        }
        return DataLocal(ano: ano, mes: mes, dia: dia)
    }
}

struct HoraLocal: Equatable, Comparable {
    let hora: Int
    let minuto: Int

    func texto() -> String {
        String(format: "%02d:%02d", hora, minuto)
    }

    static func interpretar(_ texto: String) -> HoraLocal? {
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        let partes = limpo.split(separator: ":")
        guard partes.count == 2,
              let hora = Int(partes[0].trimmingCharacters(in: .whitespaces)),
              let minuto = Int(partes[1].trimmingCharacters(in: .whitespaces)),
              (0...23).contains(hora),
              (0...59).contains(minuto) else {
            return nil
        }
        return HoraLocal(hora: hora, minuto: minuto)
    }

    static func < (lhs: HoraLocal, rhs: HoraLocal) -> Bool {
        if lhs.hora != rhs.hora {
            return lhs.hora < rhs.hora
        }
        return lhs.minuto < rhs.minuto
    }
}

struct PeriodoHorario: Equatable {
    let data: DataLocal
    let horaInicio: HoraLocal
    let horaFim: HoraLocal

    func ehValido() -> Bool {
        horaInicio < horaFim
    }

    func sobrepoe(_ outro: PeriodoHorario) -> Bool {
        guard data == outro.data else { return false }
        return horaInicio < outro.horaFim && outro.horaInicio < horaFim
    }
}
