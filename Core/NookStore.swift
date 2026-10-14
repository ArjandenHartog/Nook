import Foundation
import SQLite3

struct OpenLoop: Identifiable, Equatable {
    var id: String
    var title: String
    var source: String
    var created: Date
    var due: Date?
}

/// Het geheugen van Nook: open punten en een logboek van alles wat Nook doet. Alles blijft lokaal.
final class NookStore {
    private var db: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init() {
        guard sqlite3_open(NookPaths.databaseURL.path, &db) == SQLITE_OK else {
            NSLog("Nook: database openen mislukt")
            return
        }
        exec("""
        CREATE TABLE IF NOT EXISTS loops (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            source TEXT NOT NULL,
            created REAL NOT NULL,
            due REAL,
            done INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS audit (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            tool TEXT NOT NULL,
            args TEXT NOT NULL,
            result TEXT NOT NULL
        );
        """)
    }

    deinit { sqlite3_close(db) }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK, let err {
            NSLog("Nook sqlite: \(String(cString: err))")
            sqlite3_free(err)
        }
    }

    // MARK: Open punten

    @discardableResult
    func addLoop(title: String, source: String, due: Date?) -> OpenLoop {
        let loop = OpenLoop(id: UUID().uuidString, title: title, source: source, created: Date(), due: due)
        var stmt: OpaquePointer?
        let sql = "INSERT INTO loops (id, title, source, created, due, done) VALUES (?, ?, ?, ?, ?, 0)"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, loop.id, -1, transient)
            sqlite3_bind_text(stmt, 2, loop.title, -1, transient)
            sqlite3_bind_text(stmt, 3, loop.source, -1, transient)
            sqlite3_bind_double(stmt, 4, loop.created.timeIntervalSince1970)
            if let due { sqlite3_bind_double(stmt, 5, due.timeIntervalSince1970) } else { sqlite3_bind_null(stmt, 5) }
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        return loop
    }

    func openLoops() -> [OpenLoop] {
        var result: [OpenLoop] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id, title, source, created, due FROM loops WHERE done = 0 ORDER BY created ASC"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let title = String(cString: sqlite3_column_text(stmt, 1))
                let source = String(cString: sqlite3_column_text(stmt, 2))
                let created = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3))
                var due: Date?
                if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
                    due = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                }
                result.append(OpenLoop(id: id, title: title, source: source, created: created, due: due))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func completeLoop(id: String) {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "UPDATE loops SET done = 1 WHERE id = ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, id, -1, transient)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: Logboek

    func audit(tool: String, args: String, result: String) {
        var stmt: OpaquePointer?
        let sql = "INSERT INTO audit (ts, tool, args, result) VALUES (?, ?, ?, ?)"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
            sqlite3_bind_text(stmt, 2, tool, -1, transient)
            sqlite3_bind_text(stmt, 3, String(args.prefix(2000)), -1, transient)
            sqlite3_bind_text(stmt, 4, String(result.prefix(2000)), -1, transient)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
}
