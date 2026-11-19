import Foundation

struct Resposta {
    let status: Int
    let corpo: String
}

func objetoJson(_ dados: Data) -> [String: Any]? {
    (try? JSONSerialization.jsonObject(with: dados)) as? [String: Any]
}

func textoJson(_ valor: Any?) -> String? {
    valor as? String
}

func inteiroJson(_ valor: Any?) -> Int? {
    if let numero = valor as? Int {
        return numero
    }
    if let numero = valor as? NSNumber {
        return numero.intValue
    }
    return nil
}

func json(_ objeto: Any) -> String {
    guard JSONSerialization.isValidJSONObject(objeto),
          let dados = try? JSONSerialization.data(withJSONObject: objeto),
          let texto = String(data: dados, encoding: .utf8) else {
        return "{\"mensagem\":\"Erro interno\"}"
    }
    return texto
}

func respostaDeErro(_ status: Int, _ mensagem: String) -> Resposta {
    Resposta(status: status, corpo: json(["mensagem": mensagem]))
}

func uuidLimpo(_ texto: String) -> UUID? {
    let limpo = texto
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    return UUID(uuidString: limpo)
}
