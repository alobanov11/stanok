import Foundation
import GhosttyKit
import StanokKit

enum GhosttySurfaceConfigBuilder {

    static func makeSurface(
        app: ghostty_app_t,
        config: inout ghostty_surface_config_s,
        workingDirectory: URL?,
        processLabel: String
    ) -> ghostty_surface_t? {
        let directoryPath = readablePath(workingDirectory)

        return ShellProcessLabelStore.environmentVariable.withCString { keyPointer in
            processLabel.withCString { valuePointer in
                var envVar = ghostty_env_var_s()
                envVar.key = keyPointer
                envVar.value = valuePointer

                return withUnsafeMutablePointer(to: &envVar) { envVarPointer in
                    config.env_vars = envVarPointer
                    config.env_var_count = 1

                    guard let directoryPath else { return ghostty_surface_new(app, &config) }

                    return directoryPath.withCString { path in
                        config.working_directory = path
                        return ghostty_surface_new(app, &config)
                    }
                }
            }
        }
    }

    private static func readablePath(_ url: URL?) -> String? {
        guard let url else { return nil }

        var isDirectory: ObjCBool = false
        let path = url.path(percentEncoded: false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            Log.terminal.error("working directory is gone: \(path)")
            return nil
        }

        return isDirectory.boolValue ? path : nil
    }
}
