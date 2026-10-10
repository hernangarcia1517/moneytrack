import Foundation
import Testing
@testable import moneytrack

struct WireFormatTests {
    @Test(arguments: [
        ("42.1", "42.10"), ("42", "42.00"), ("0.5", "0.50"),
        ("1234567.8", "1234567.80"), ("0", "0.00"), ("9999999999.99", "9999999999.99"),
    ])
    func moneyAlwaysHasTwoDecimalsAndNoGrouping(input: String, expected: String) {
        let amount = Decimal(string: input, locale: Locale(identifier: "en_US_POSIX"))!
        #expect(WireFormat.money(amount) == expected)
    }

    @Test func moneyParsesWithoutFloatingPointDrift() {
        #expect(WireFormat.decimal(fromMoney: "132.18") == Decimal(string: "132.18", locale: Locale(identifier: "en_US_POSIX")))
        #expect(WireFormat.decimal(fromMoney: "abc") == nil)
    }

    @Test(arguments: [
        "America/Denver", "UTC", "Europe/Berlin", "Asia/Tokyo", "Pacific/Auckland", "Pacific/Kiritimati", "Pacific/Pago_Pago",
    ])
    func dayStringsRoundTripInEveryTimeZone(zone: String) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        for day in ["2026-10-31", "2026-11-01", "2026-12-31", "2027-01-01", "2028-02-29", "2026-03-08", "2026-11-01"] {
            let date = try #require(WireFormat.date(fromDay: day, calendar: calendar))
            #expect(WireFormat.day(date, calendar: calendar) == day)
        }
    }

    @Test func firstOfMonthStaysInItsOwnMonthEastOfUTC() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let date = try #require(WireFormat.date(fromDay: "2026-11-01", calendar: calendar))
        #expect(WireFormat.day(date, calendar: calendar) == "2026-11-01")
        #expect(Budget.monthKey(for: date, calendar: calendar) == "2026-11")
    }

    @Test(arguments: ["2026-02-30", "2026-13-01", "2026-10-31T00:00:00Z", "2026-1-5", "yesterday", ""])
    func invalidDaysAreRejected(input: String) {
        #expect(WireFormat.date(fromDay: input) == nil)
    }
}

struct MappingTests {
    @Test func transactionResponseMapsToDomain() throws {
        let json = """
        {"id":"ca87e489-fc73-4f20-963c-6907492400ac","budgetId":"c0281640-552a-48b5-9f17-4374e0543cbc",
         "date":"2026-10-08","merchant":"Trader Joe's","amount":"42.10","note":"weekly shop"}
        """
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: Data(json.utf8))
        let transaction = try dto.toDomain()
        #expect(transaction.id == UUID(uuidString: "CA87E489-FC73-4F20-963C-6907492400AC"))
        #expect(transaction.budgetID == UUID(uuidString: "c0281640-552a-48b5-9f17-4374e0543cbc"))
        #expect(transaction.amount == Decimal(string: "42.10", locale: Locale(identifier: "en_US_POSIX")))
        #expect(WireFormat.day(transaction.date) == "2026-10-08")
        #expect(transaction.merchant == "Trader Joe's")
        #expect(transaction.note == "weekly shop")
    }

    @Test func malformedTransactionResponseThrows() throws {
        let json = #"{"id":"ca87e489-fc73-4f20-963c-6907492400ac","budgetId":"c0281640-552a-48b5-9f17-4374e0543cbc","date":"2026-10-08T14:30:00.000Z","merchant":"x","amount":"1.00","note":""}"#
        let dto = try JSONDecoder().decode(TransactionDTO.self, from: Data(json.utf8))
        #expect(throws: APIError.self) { try dto.toDomain() }
    }

    @Test func transactionRequestBodyUsesTheWireFormats() throws {
        let transaction = Transaction(
            date: try #require(WireFormat.date(fromDay: "2026-10-31")),
            merchant: "Shop",
            budgetID: UUID(),
            amount: Decimal(string: "42.1", locale: Locale(identifier: "en_US_POSIX"))!,
            note: ""
        )
        let data = try JSONEncoder().encode(TransactionBody(transaction))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["date"] as? String == "2026-10-31")
        #expect(object["amount"] as? String == "42.10")
        #expect(object["note"] as? String == "")
        #expect(Set(object.keys) == ["budgetId", "date", "merchant", "amount", "note"])
    }

    @Test func budgetResponseNeedsACapToMapToBudgetWithCap() throws {
        let withCap = try JSONDecoder().decode(BudgetDTO.self, from: Data(#"{"id":"c0281640-552a-48b5-9f17-4374e0543cbc","name":"Groceries","budgetGroup":"Needs","cap":"350.00"}"#.utf8))
        let withoutCap = try JSONDecoder().decode(BudgetDTO.self, from: Data(#"{"id":"c0281640-552a-48b5-9f17-4374e0543cbc","name":"Groceries","budgetGroup":"Wants"}"#.utf8))
        #expect(try withCap.withCap().cap == 350)
        #expect(withoutCap.summary().group == .wants)
        #expect(throws: APIError.self) { try withoutCap.withCap() }
    }

    @Test func updateBudgetBodyOmitsFieldsThatAreNotChanging() throws {
        let data = try JSONEncoder().encode(UpdateBudgetBody(name: nil, budgetGroup: .wants))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["budgetGroup"])
    }
}

@Suite(.serialized)
struct APIClientTests {
    private func client(status: Int = 200, body: String = "{}", error: URLError? = nil, onRequest: ((URLRequest) -> Void)? = nil) -> APIClient {
        StubURLProtocol.handler = { request in
            onRequest?(request)
            if let error { throw error }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(body.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(baseURL: URL(string: "http://test.invalid")!, session: URLSession(configuration: configuration))
    }

    @Test func ownErrorShapeBecomesAServerError() async {
        let api = client(status: 404, body: #"{"error":"Budget not found"}"#)
        await #expect(throws: APIError.server(status: 404, message: "Budget not found")) { try await api.delete("budgets/x") }
    }

    @Test func validationErrorShapeBecomesAServerError() async {
        let api = client(status: 400, body: #"{"statusCode":400,"code":"FST_ERR_VALIDATION","error":"Bad Request","message":"body/amount must be string"}"#)
        let result: Result<[String: String], Error> = await Result { try await api.get("budgets") }
        guard case .failure(let error as APIError) = result, case .server(let status, let message) = error else {
            Issue.record("expected a server error"); return
        }
        #expect(status == 400)
        #expect(message == "body/amount must be string")
    }

    @Test func connectionFailuresBecomeUnreachable() async {
        let api = client(error: URLError(.cannotConnectToHost))
        await #expect(throws: APIError.unreachable) { try await api.delete("budgets/x") }
    }

    @Test(arguments: [URLError.Code.timedOut, .notConnectedToInternet, .cannotFindHost, .networkConnectionLost])
    func connectivityFailuresAreUnreachable(code: URLError.Code) async {
        let api = client(error: URLError(code))
        await #expect(throws: APIError.unreachable) { try await api.delete("budgets/x") }
    }

    @Test func otherTransportFailuresKeepTheirCode() async {
        let api = client(error: URLError(.appTransportSecurityRequiresSecureConnection))
        await #expect(throws: APIError.connection(.appTransportSecurityRequiresSecureConnection)) { try await api.delete("budgets/x") }
    }

    @Test func httpMethodsAreSentAsGiven() async throws {
        nonisolated(unsafe) var methods: [String?] = []
        let api = client(body: "{}") { methods.append($0.httpMethod) }
        let _: [String: String] = try await api.get("a")
        for method in [HTTPMethod.post, .put, .patch] {
            let _: [String: String] = try await api.send(method, "a", body: CapBody(amount: "1.00"))
        }
        try await api.delete("a")
        #expect(methods == ["GET", "POST", "PUT", "PATCH", "DELETE"])
    }

    @Test func aCancelledRequestStaysACancellation() async {
        let api = client(error: URLError(.cancelled))
        await #expect(throws: CancellationError.self) { try await api.delete("budgets/x") }
    }

    @Test func unreadableBodyBecomesInvalidResponse() async {
        let api = client(body: "not json")
        let result: Result<[String: String], Error> = await Result { try await api.get("budgets") }
        guard case .failure(let error as APIError) = result, case .invalidResponse = error else {
            Issue.record("expected invalidResponse"); return
        }
    }

    @Test func getAndDeleteSendNoContentTypeButBodiesDo() async throws {
        nonisolated(unsafe) var headers: [String?] = []
        let api = client(body: "[]") { headers.append($0.value(forHTTPHeaderField: "Content-Type")) }
        let _: [String] = try await api.get("transactions", query: [URLQueryItem(name: "month", value: "2026-10")])
        try await api.delete("transactions/x")
        let _: [String] = try await api.send(.post, "transactions", body: CapBody(amount: "1.00"))
        #expect(headers == [nil, nil, "application/json"])
    }

    @Test func monthGoesInTheQueryString() async throws {
        nonisolated(unsafe) var url: URL?
        let api = client(body: "[]") { url = $0.url }
        let _: [String] = try await api.get("transactions", query: [URLQueryItem(name: "month", value: "2026-10")])
        #expect(url?.absoluteString == "http://test.invalid/transactions?month=2026-10")
    }
}

extension Result where Failure == Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}

nonisolated final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
