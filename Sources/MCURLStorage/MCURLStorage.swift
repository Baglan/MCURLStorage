import Foundation
import Combine

public struct MCURLStorage<Value: Codable> {
    let url: URL

    public init(url: URL) {
        self.url = url
    }
    
    enum MCURLStorageError: Error {
    case unexpectedNilValue
    }
    
    // MARK: - Basic sync read and write
    
    public func read() throws -> Value {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Value.self, from: data)
    }
    
    public func write(value: Value) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url)
    }
    
    // MARK: - Async read and write
    
    public func asyncRead(success: @escaping (_ value: Value) -> Void, failure: @escaping (_ error: Error) -> Void) {
        let callerQueue = OperationQueue.current ?? OperationQueue.main
        
        OperationQueue().addOperation {
            do {
                let v = try read()
                callerQueue.addOperation {
                    success(v)
                }
            } catch {
                callerQueue.addOperation {
                    failure(error)
                }
            }
        }
    }
    
    public func asyncWrite(_ value: Value, success: @escaping () -> Void, failure: @escaping (_ error: Error) -> Void) {
        let callerQueue = OperationQueue.current ?? OperationQueue.main
        
        OperationQueue().addOperation {
            do {
                try write(value: value)
                callerQueue.addOperation { success() }
            } catch {
                callerQueue.addOperation { failure(error) }
            }
        }
    }
    
    // MARK: - Futures
    
    @available(iOS 13.0, *)
    public func readFuture() -> Future<Value, Error> {
        return Future { promise in
            asyncRead { value in
                promise(.success(value))
            } failure: { error in
                promise(.failure(error))
            }
        }
    }
    
    @available(iOS 13.0, *)
    public func writeFuture(_ value: Value) -> Future<Void, Error> {
        return Future { promise in
            asyncWrite(value) {
                promise(.success(Void()))
            } failure: { error in
                promise(.failure(error))
            }
        }
    }
    
    // MARK: - Publishers
    
    @available(iOS 13.0, *)
    public func readPublisher() -> AnyPublisher<Value, Error> {
        return readFuture().eraseToAnyPublisher()
    }
    
    @available(iOS 13.0, *)
    public func writePublisher(_ value: Value) -> AnyPublisher<Void, Error> {
        return writeFuture(value).eraseToAnyPublisher()
    }
    
}
