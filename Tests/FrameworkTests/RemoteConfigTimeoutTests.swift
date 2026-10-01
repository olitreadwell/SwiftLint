import Testing

@testable import SwiftLintFramework

@Suite
struct RemoteConfigTimeoutTests {
    @Test
    func acceptsIntegerTimeouts() throws {
        let config = try YamlParser.parse(
            "remote_timeout: 5\nremote_timeout_if_cached: 1",
            env: [:]
        )

        #expect(
            Configuration.FileGraph.timeInterval(from: config["remote_timeout"]) == 5,
            "A whole-number remote_timeout must be honored"
        )
        #expect(
            Configuration.FileGraph.timeInterval(from: config["remote_timeout_if_cached"]) == 1,
            "A whole-number remote_timeout_if_cached must be honored"
        )
    }

    @Test
    func acceptsFractionalTimeouts() throws {
        let config = try YamlParser.parse("remote_timeout: 2.5", env: [:])

        #expect(Configuration.FileGraph.timeInterval(from: config["remote_timeout"]) == 2.5)
    }

    @Test
    func ignoresUnsupportedTimeouts() {
        #expect(Configuration.FileGraph.timeInterval(from: "2") == nil)
        #expect(Configuration.FileGraph.timeInterval(from: nil) == nil)
        #expect(Configuration.FileGraph.timeInterval(from: true) == nil)
    }
}
