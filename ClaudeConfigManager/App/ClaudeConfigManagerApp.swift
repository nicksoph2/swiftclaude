import SwiftUI

@main
struct ClaudeConfigManagerApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var debugMonitor = AppDebugMonitor()
    private let schemaFetcherService: SchemaFetcherService

    init() {
        let preferences = AppPreferences()
        self.schemaFetcherService = SchemaFetcherService(preferences: preferences)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.bootstrapState {
                case .launching:
                    ProgressView("Launching Claude Config Manager...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            router.completeBootstrap()
                            Task {
                                _ = await schemaFetcherService.refreshSchema()
                            }
                        }
                case .ready:
                    RootSplitView()
                }
            }
            .frame(minWidth: 980, minHeight: 620)
            .environmentObject(router)
            .environmentObject(router.pipeline)
            .environmentObject(router.rootSelectionViewModel)
            .environmentObject(debugMonitor)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 760)

        Settings {
            RootPickerSettingsView(schemaFetcherService: schemaFetcherService)
                .environmentObject(router.rootSelectionViewModel)
                .frame(width: 620, height: 500)
        }
    }
}

private struct RootPickerSettingsView: View {
    let schemaFetcherService: SchemaFetcherService

    var body: some View {
        TabView {
            UserScopeView()
                .tabItem {
                    Label("Global Root", systemImage: "person.crop.circle")
                }

            ProjectScopeView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }

            SchemaFetcherPreferencesView(schemaFetcherService: schemaFetcherService)
                .tabItem {
                    Label("Schema", systemImage: "arrow.triangle.2.circlepath")
                }
        }
        .padding(16)
    }
}

final class AppPreferences: @unchecked Sendable {
    private enum Keys {
        static let schemaFetchingEnabled = "schema_fetcher.is_enabled"
        static let schemaFetchingAutoRefreshInterval = "schema_fetcher.auto_refresh_interval"
        static let schemaFetchingLastFetchedAt = "schema_fetcher.last_fetched_at"
        static let schemaFetchingCacheSchema = "schema_fetcher.cache_schema"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var schemaFetcherPreferences: SchemaFetcherPreferences {
        get {
            lock.lock()
            defer { lock.unlock() }

            let autoRefreshInterval: TimeInterval?
            if defaults.object(forKey: Keys.schemaFetchingAutoRefreshInterval) != nil {
                autoRefreshInterval = defaults.double(forKey: Keys.schemaFetchingAutoRefreshInterval)
            } else {
                autoRefreshInterval = nil
            }

            return SchemaFetcherPreferences(
                isEnabled: defaults.object(forKey: Keys.schemaFetchingEnabled) as? Bool ?? false,
                autoRefreshInterval: autoRefreshInterval,
                lastFetchedAt: defaults.object(forKey: Keys.schemaFetchingLastFetchedAt) as? Date,
                cacheSchema: defaults.object(forKey: Keys.schemaFetchingCacheSchema) as? Bool ?? true
            )
        }
        set {
            lock.lock()
            defer { lock.unlock() }

            defaults.set(newValue.isEnabled, forKey: Keys.schemaFetchingEnabled)

            if let autoRefreshInterval = newValue.autoRefreshInterval {
                defaults.set(autoRefreshInterval, forKey: Keys.schemaFetchingAutoRefreshInterval)
            } else {
                defaults.removeObject(forKey: Keys.schemaFetchingAutoRefreshInterval)
            }

            if let lastFetchedAt = newValue.lastFetchedAt {
                defaults.set(lastFetchedAt, forKey: Keys.schemaFetchingLastFetchedAt)
            } else {
                defaults.removeObject(forKey: Keys.schemaFetchingLastFetchedAt)
            }

            defaults.set(newValue.cacheSchema, forKey: Keys.schemaFetchingCacheSchema)
        }
    }
}

@MainActor
final class SchemaFetcherPreferencesViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case success(String)
        case failure(String)

        var symbolName: String {
            switch self {
            case .idle:
                return "circle.fill"
            case .success:
                return "checkmark.circle.fill"
            case .failure:
                return "xmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .idle:
                return .secondary
            case .success:
                return .green
            case .failure:
                return .red
            }
        }

        var message: String {
            switch self {
            case .idle:
                return "No remote schema has been loaded in this session."
            case .success(let message), .failure(let message):
                return message
            }
        }
    }

    @Published var isEnabled = false
    @Published private(set) var lastFetchedAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var status: Status = .idle

    private let service: SchemaFetcherService

    init(service: SchemaFetcherService) {
        self.service = service
    }

    func load() async {
        isEnabled = service.isFetchingEnabled
        lastFetchedAt = service.lastFetchedAt
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        service.isFetchingEnabled = enabled
    }

    func refreshNow() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await service.refreshSchema()
        lastFetchedAt = service.lastFetchedAt

        switch result {
        case .success(let schema):
            status = .success("Fetched \(schema.count) schema rules. \(service.newKeysDetected().count) new remote keys detected.")
        case .cachedSchema(let schema, let fetchedAt):
            status = .success("Using cached schema with \(schema.count) rules from \(Self.formatter.string(from: fetchedAt)).")
        case .fallbackToBuiltIn(let reason):
            status = .failure(reason)
        }
    }

    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct SchemaFetcherPreferencesView: View {
    @StateObject private var viewModel: SchemaFetcherPreferencesViewModel

    init(schemaFetcherService: SchemaFetcherService) {
        _viewModel = StateObject(
            wrappedValue: SchemaFetcherPreferencesViewModel(service: schemaFetcherService)
        )
    }

    var body: some View {
        Form {
            Toggle("Allow automatic schema updates", isOn: Binding(
                get: { viewModel.isEnabled },
                set: { viewModel.setEnabled($0) }
            ))

            Text("When enabled, the app will check for new settings keys from the server.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Text("Last updated")
                Spacer()
                Text(lastFetchLabel)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: viewModel.status.symbolName)
                    .foregroundStyle(viewModel.status.tint)
                Text(viewModel.status.message)
                    .foregroundStyle(.secondary)
            }

            Button(viewModel.isRefreshing ? "Refreshing..." : "Refresh Now") {
                Task {
                    await viewModel.refreshNow()
                }
            }
            .disabled(!viewModel.isEnabled || viewModel.isRefreshing)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }

    private var lastFetchLabel: String {
        guard let lastFetchedAt = viewModel.lastFetchedAt else {
            return "Not yet fetched"
        }
        return SchemaFetcherPreferencesViewModel.formatter.string(from: lastFetchedAt)
    }
}
