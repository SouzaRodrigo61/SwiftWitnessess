import Foundation

protocol Discountable {
    func discounted() -> Double
}

struct Purchase {
    var amount: Double
    var shippingAmount: Double

    func discounted() -> Double {
        amount * 0.9
    }
}
//
//func printDiscount<D>(_ discountable: Discountable) -> String {
//    let discount = discountable.discounted()
//    return "Discount: \(discount)"
//}

let purchase = Purchase(amount: 200, shippingAmount: 100)

// MARK: - Protocol Witness

struct Discounting<A> {
    let discounted: (A) -> Double
}

extension Discounting where A == Purchase {
    static let tenPercentOff: Self = Discounting<Double>
        .tenPercentOff
        .pullback(\.amount)

    static let tenPercentOffShipping: Self = Discounting<Double>
            .fiveDollarsOff
            .pullback(\.shippingAmount)
}

extension Discounting where A == Double {
    static let tenPercentOff = Self { amount in
        amount * 0.9
    }

    static let fiveDollarsOff = Self { amount in
        amount - 5
    }
    
    static let TwenthPercentOff = Self { amount in
        amount * 0.8
    }
}

extension Discounting {
    func pullback<B>(_ function: @escaping (B) -> A) -> Discounting<B> {
        .init { other -> Double in
            self.discounted(function(other))
        }
    }
}


func printDiscount<A>(_ item: A, with discount: Discounting<A>) -> String {
    let discount = discount.discounted(item)
    return "Discount: \(discount)"
}

printDiscount(purchase, with: .tenPercentOff)
printDiscount(purchase, with: .tenPercentOffShipping)


// MARK: - JSON Encoded - Witnesses

public func printJSON(_ data: Data) {
    print(String(data: data, encoding: .utf8)!)
}

import Foundation

struct User {
    let id: UUID
    let name: String
    let ageInYears: Int
}

extension User: Encodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ageInYears = "age"
    }
    
    enum AltCodingKeys: String, CodingKey {
        case id = "ID"
        case name = "UserName"
        case ageInYears = "UserAge"
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = .prettyPrinted

let user = User(id: .init(), name: "Tim Cook", ageInYears: 60)

printJSON(try encoder.encode(user))

struct Encoding<Input> {
    let encode: (Input, Encoder) throws -> Void
}

extension Encoding where Input == User {
    static var defaultEncoding = Encoding<User> { (user, encoder) in
        var container = encoder.container(keyedBy: User.CodingKeys.self)
        try container.encode(user.id, forKey: .id)
        try container.encode(user.name, forKey: .name)
        try container.encode(user.ageInYears, forKey: .ageInYears)
    }
    
    static var altEncoding = Encoding<User> { (user, encoder) in
        var container = encoder.container(keyedBy: User.AltCodingKeys.self)
        try container.encode(user.id, forKey: .id)
        try container.encode(user.name, forKey: .name)
        try container.encode(user.ageInYears, forKey: .ageInYears)
    }
}

//userEncoder.encode(user, encoder)

//printJSON(try encoder.encode(proxy))

extension JSONEncoder {
    struct EncodingProxy<T>: Encodable {
        let value: T
        let encoding: Encoding<T>
        
        func encode(to encoder: Encoder) throws {
            try encoding.encode(value, encoder)
        }
    }
    
    func encode<Input>(_ input: Input, as encoding: Encoding<Input>) throws -> Data {
        let proxy = EncodingProxy(value: input, encoding: encoding)
        return try encode(proxy)
    }
}

printJSON(try encoder.encode(user, as: .defaultEncoding))
printJSON(try encoder.encode(user, as: .altEncoding))

extension Encoding where Input == Int {
    static var singleValue = Encoding<Int> { int, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(int)
    }
    
    static func keyed<Key: CodingKey>(as key: Key) -> Self {
        .init { int, encoder in
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(int, forKey: key)
        }
    }
}

extension Encoding where Input == String {
    static var singleValue = Encoding<String> { string, encoder in
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
    
    static func keyed<Key: CodingKey>(as key: Key) -> Self {
        .init { string, encoder in
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(string, forKey: key)
        }
    }
    
    static func lowercased<Key: CodingKey>(as key: Key) -> Self {
        keyed(as: key)
            .pullback { $0.lowercased() }
    }
}

extension Encoding where Input == UUID {
    static func keyed<Key: CodingKey>(as key: Key) -> Self {
        .init { uuid, encoder in
            var container = encoder.container(keyedBy: Key.self)
            try container.encode(uuid, forKey: key)
        }
    }
    
    static func lowercased<Key: CodingKey>(as key: Key) -> Self {
        Encoding<String>
            .lowercased(as: key)
            .pullback(\.uuidString)
    }
}

extension Encoding {
    func pullback<NewInput>( _ f: @escaping (NewInput) -> Input) -> Encoding<NewInput> {
        .init { newInput, encoder in
            try self.encode(f(newInput), encoder)
        }
    }
}

extension Encoding where Input == User {
    static var id: Self = Encoding<UUID>
        .lowercased(as: User.CodingKeys.id)
        .pullback(\.id)

    static var name: Self = Encoding<String>
        .keyed(as: User.CodingKeys.name)
        .pullback(\.name)
    
    static var ageInYears: Self = Encoding<Int>
        .keyed(as: User.CodingKeys.ageInYears)
        .pullback(\.ageInYears)
}

printJSON(try encoder.encode(user, as: .id))

extension Encoding {
    static func combine(_ encodings: Encoding<Input>...) -> Self {
        .init { input, encoder in
            for encoding in encodings {
                try encoding.encode(input, encoder)
            }
        }
    }
}

extension Encoding where Input == User {
    static var defaultEncodingTwo = combine(id, name, ageInYears)
    static var forUpdates = combine(name, ageInYears)
}

printJSON(try encoder.encode(user, as: .forUpdates))
printJSON(try encoder.encode(user, as: .defaultEncodingTwo))


// MARK: - Closure


struct Student {
    let name: String
    var testScore: Int
}

let students = [
    Student(name: "Luke", testScore: 88),
    Student(name: "Han", testScore: 73),
    Student(name: "Leia", testScore: 99),
    Student(name: "Anakin", testScore: 30),
    Student(name: "Yoda", testScore: 200),
    Student(name: "Obi-Wan", testScore: 65)
]

struct Filtering<Context> {
    let filtered: ([Context]) -> [Context]
}

extension Filtering where Context == Student {
    static let topStudentFilter = Self { students in
        students.filter{ $0.testScore > 80 }
    }
    
    static let higherStudentFilter = Self { students in
        students.filter{ $0.testScore > 95 }
    }
}

func printFiltering<Context>(of item: [Context], with filter: Filtering<Context>) -> [Context] {
    return filter.filtered(item)
}

let topStudents = printFiltering(of: students, with: .topStudentFilter)
let higherStudents = printFiltering(of: students, with: .higherStudentFilter)
