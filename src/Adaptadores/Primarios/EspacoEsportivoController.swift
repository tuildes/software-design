import Foundation

final class EspacoEsportivoController {
    private let espacoPort: EspacoPort

    init(espacoPort: EspacoPort) {
        self.espacoPort = espacoPort
    }

    func cadastrarEspaco(corpo: Data) -> Resposta {
        guard let objeto = objetoJson(corpo),
              let nome = textoJson(objeto["nome"]), !nome.isEmpty,
              let tipo = textoJson(objeto["tipo"]), !tipo.isEmpty,
              let capacidade = inteiroJson(objeto["capacidade"]), capacidade > 0 else {
            return respostaDeErro(400, "Requisicao invalida")
        }
        let espaco = espacoPort.cadastrarEspaco(nome: nome, tipo: tipo, capacidade: capacidade)
        return Resposta(
            status: 201,
            corpo: json([
                "id": espaco.id.uuidString,
                "nome": espaco.nome,
                "tipo": espaco.tipo,
                "capacidade": espaco.capacidade,
            ])
        )
    }
}
