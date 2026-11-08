import Foundation

/// Live pilot implementation of the `ConditionObserver` seam. POSTs crops to
/// the local pilot server, which holds the provider key. This struct never
/// sees, stores, or transmits any API key.
nonisolated struct LiveConditionObserver: ConditionObserver {
    /// Base URL of the pilot server, e.g. http://192.168.1.73:8080.
    var baseURL: URL

    func observe(crops: [ObservationCrop]) async throws -> [ConditionObservation] {
        let payload: [String: Any] = [
            "crops": crops.map { ["region": $0.region, "jpeg_b64": $0.jpeg.base64EncodedString()] },
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: baseURL.appendingPathComponent("observe"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        request.timeoutInterval = 300
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw LiveObserverError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let items = json["observations"] as? [[String: Any]]
        else {
            throw LiveObserverError.badPayload
        }
        return items.map { item in
            ConditionObservation(
                region: (item["region"] as? String) ?? "unknown",
                statement: (item["statement"] as? String) ?? "",
                limitation: (item["limitation"] as? String) ?? ""
            )
        }
    }
}

nonisolated enum LiveObserverError: LocalizedError {
    case badStatus(Int)
    case badPayload

    var errorDescription: String? {
        switch self {
        case .badStatus(let code) where code < 0:
            return "Could not reach the pilot server at all. Check Wi-Fi and the server URL."
        case .badStatus(let code):
            return "The pilot server answered HTTP \(code)."
        case .badPayload:
            return "The pilot server answered, but its reply did not parse."
        }
    }
}
