import Fluent
import Vapor

struct UsersController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api")
        api.post("register", use: register)
        api.post("login", use: login)

    }

    func register(req: Request) async throws -> RegisterResponseDTO {
        
        //validate the user
        try User.validate(content: req)
        
        let user = try req.content.decode(User.self)
        
        //find if exists already
        if let _ = try await User.query(on: req.db)
            .filter(\.$username == user.username)
            .first() {
            throw Abort(.conflict, reason: "Username is already taken")
        }
        
        //hash the password
        user.password = try req.password.hash(user.password)
        
        //save the user to database
        try await user.save(on: req.db)
        
        return RegisterResponseDTO(error: false)
        
    }
    
    func login(req: Request) async throws -> LoginResponseDTO {
        
        let user = try req.content.decode(User.self)
        
        guard let existingUser = try await User.query(on: req.db)
            .filter(\.$username == user.username)
            .first() else {
                throw Abort(.badRequest)
            }
        
        let result = try req.password.verify(user.password, created: existingUser.password)
        
        if !result {
            throw Abort(.unauthorized)
        }
        
        // generate token and return it to the user
        let authPayload = try AuthPayload(expiration: .init(value: .distantFuture), userID: existingUser.requireID())
        return try LoginResponseDTO(error: false, token: req.jwt.sign(authPayload), userID: existingUser.requireID())

    }
}
