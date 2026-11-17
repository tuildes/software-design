import Foundation
import XCTest
@testable import LocacaoEspacos

func periodo(_ data: String, _ inicio: String, _ fim: String) -> PeriodoHorario {
    PeriodoHorario(
        data: DataLocal.interpretar(data)!,
        horaInicio: HoraLocal.interpretar(inicio)!,
        horaFim: HoraLocal.interpretar(fim)!
    )
}

func arquivoTemporario() -> String {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("locacao-\(UUID().uuidString).sqlite")
        .path
}

func usuarioCliente(email: String = "ana@exemplo.com", perfil: TipoPerfil = .cliente, ativo: Bool = true) -> Usuario {
    Usuario(nome: "Ana", email: email, telefone: "11999999999", perfil: perfil, ativo: ativo)
}

func preparar(_ nucleo: Nucleo, email: String = "ana@exemplo.com", perfil: TipoPerfil = .cliente, ativo: Bool = true) -> (Usuario, EspacoEsportivo) {
    let usuario = usuarioCliente(email: email, perfil: perfil, ativo: ativo)
    nucleo.usuarios.salvar(usuario)
    let espaco = EspacoEsportivo(nome: "Quadra 1", tipo: "poliesportiva", capacidade: 14)
    nucleo.espacos.salvar(espaco)
    return (usuario, espaco)
}

func corpoJson(_ campos: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: campos)
}

func objetoDaResposta(_ resposta: Resposta) throws -> [String: Any] {
    try XCTUnwrap(objetoJson(Data(resposta.corpo.utf8)))
}

func notificadorFake(_ nucleo: Nucleo) throws -> NotificadorFake {
    try XCTUnwrap(nucleo.notificador as? NotificadorFake)
}
