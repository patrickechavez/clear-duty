//
//  AppDependencies.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

@MainActor
final class AppDependencies {

    let session: SessionManager
    let deepLinks: DeepLinkParser
    let analytics: any AnalyticsTracking
    let crashes: any CrashReporting
    let network: NetworkMonitor

    private let auth: any AuthRepository
    private let users: any UserRepository
    private let employees: any EmployeeRepository
    private let imageLoader: any ImageLoading
    private let tokenStore: any TokenStore

    // One capture session for the app, built the first time the kiosk asks.
    private lazy var camera = KioskCamera()

    // The analyser this terminal is paired to, kept across kiosk rebuilds.
    private lazy var analyzers = AnalyzerLink(hub: SimulatedAnalyzerHub())

    init(
        session: SessionManager,
        auth: any AuthRepository,
        users: any UserRepository,
        employees: any EmployeeRepository,
        imageLoader: any ImageLoading,
        tokenStore: any TokenStore,
        deepLinks: DeepLinkParser,
        analytics: any AnalyticsTracking,
        crashes: any CrashReporting,
        network: NetworkMonitor = NetworkMonitor()
    ) {
        self.session = session
        self.auth = auth
        self.users = users
        self.employees = employees
        self.imageLoader = imageLoader
        self.tokenStore = tokenStore
        self.deepLinks = deepLinks
        self.analytics = analytics
        self.crashes = crashes
        self.network = network
    }

    // Mock dependencies under the Demo scheme, live ones otherwise.
    static func forLaunch() -> AppDependencies {
        #if DEVELOPMENT
        if AppEnvironment.isDemo { return demo() }
        #endif
        return live()
    }

    static func live(tokenStore: any TokenStore = KeychainTokenStore()) -> AppDependencies {
        // No plist, or no Firebase at all, so the no-op adapters take over.
        let (analytics, crashes) = FirebaseBootstrap.start()
            ?? (NoopAnalyticsTracker(), NoopCrashReporter())

        Observability.install(analytics: analytics, crashes: crashes)

        let link = SessionLink()
        let session = Self.urlSession()

        let metadata = MetadataInterceptor()
        let logging = LoggingInterceptor()

        // nil unless the environment targets Supabase. Selects Live* below.
        let supabaseAPIKey = APIConfig.supabaseAnonKey.map(SupabaseAPIKeyInterceptor.init(anonKey:))

        var refreshInterceptors: [any RequestInterceptor] = [metadata]
        if let supabaseAPIKey { refreshInterceptors.append(supabaseAPIKey) }
        refreshInterceptors.append(logging)

        let refreshClient = URLSessionAPIClient(
            session: session,
            interceptors: refreshInterceptors,
            retryPolicy: .none
        )

        let tokenRefresher = LiveTokenRefresher(api: refreshClient)

        let coordinator = TokenRefreshCoordinator(
            store: tokenStore,
            refresher: tokenRefresher,
            link: link
        )

        var apiInterceptors: [any RequestInterceptor] = [metadata]
        if let supabaseAPIKey { apiInterceptors.append(supabaseAPIKey) }
        apiInterceptors.append(AuthInterceptor(coordinator: coordinator))
        apiInterceptors.append(SessionPolicyInterceptor(link: link))
        apiInterceptors.append(logging)

        let api = URLSessionAPIClient(session: session, interceptors: apiInterceptors)

        let users = LiveUserRepository(api: api)

        let sessionManager = SessionManager(
            tokenStore: tokenStore,
            users: users,
            crashes: crashes
        )

        // The one place the link is set. Everything above already holds it.
        link.session = sessionManager

        return AppDependencies(
            session: sessionManager,
            auth: LiveAuthRepository(api: api),
            users: users,
            employees: LiveEmployeeRepository(api: api),
            imageLoader: ImageLoader.shared,
            tokenStore: tokenStore,
            deepLinks: DeepLinkParser(),
            analytics: analytics,
            crashes: crashes
        )
    }

    #if DEVELOPMENT

    // Mock data only: no network, no keychain, no Firebase, no camera.
    static func demo() -> AppDependencies {
        let tokenStore = InMemoryTokenStore()
        let users = MockUserRepository()

        return AppDependencies(
            session: SessionManager(tokenStore: tokenStore, users: users),
            auth: MockAuthRepository(),
            users: users,
            employees: MockEmployeeRepository(),
            imageLoader: MockImageLoader(),
            tokenStore: tokenStore,
            deepLinks: DeepLinkParser(),
            analytics: NoopAnalyticsTracker(),
            crashes: NoopCrashReporter()
        )
    }

    // The demo starts already paired, so the kiosk works on the first screen.
    private static func demoLink() -> AnalyzerLink {
        let pairing = PairedAnalyzerStore(defaults: UserDefaults(suiteName: "demo") ?? .standard)
        pairing.serial = AnalyzerDevice.simulated.serial
        return AnalyzerLink(hub: SimulatedAnalyzerHub(), pairing: pairing)
    }

    #endif

    private static func urlSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = APIConfig.timeout

        configuration.timeoutIntervalForResource = 300

        configuration.waitsForConnectivity = false

        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        let languages = Locale.preferredLanguages.prefix(3).joined(separator: ", ")
        configuration.httpAdditionalHeaders = ["Accept-Language": languages]

        let pinner = CertificatePinner(pinnedHashes: APIConfig.pinnedPublicKeyHashes)
        return URLSession(configuration: configuration, delegate: pinner, delegateQueue: nil)
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(auth: auth, session: session, analytics: analytics)
    }

    // The simulator stands in until a CoreBluetooth analyser exists.
    func makeKioskViewModel() -> KioskViewModel {
        #if DEVELOPMENT
        // The demo has no camera, so presence and the photo are simulated too.
        if AppEnvironment.isDemo {
            return KioskViewModel(
                terminalName: "Cubao terminal",
                link: Self.demoLink(),
                employees: employees
            )
        }
        #endif

        return KioskViewModel(
            terminalName: "Cubao terminal",
            link: analyzers,
            employees: employees,
            presenceDetector: camera,
            photos: camera,
            camera: camera
        )
    }

}
