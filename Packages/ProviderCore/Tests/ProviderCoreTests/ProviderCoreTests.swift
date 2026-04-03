import Foundation
import Testing
@testable import ProviderCore

@Test
func emulatorEnvironmentCarriesDistinctKind() {
    let environment = ProviderEnvironment.emulator(apiBaseURL: URL(string: "http://localhost:4402")!)
    #expect(environment.kind == .emulator)
}
