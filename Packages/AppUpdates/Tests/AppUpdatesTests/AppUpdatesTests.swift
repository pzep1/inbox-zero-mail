import Testing
@testable import AppUpdates

@Test
func appUpdatesModuleLoads() {
    _ = AppUpdateController.self
}
