import Foundation

enum SiteCredentialStoreAndArchiveTests {
    static func run() {
        print("SiteCredentialStore & ArchiveExtraction Tests")

        testSiteCredentialBasicAuth()
        testSiteCredentialBearerAuth()
        testSiteCredentialWildcardMatching()
        testSiteCredentialPersistence()
        testArchiveIdentification()

        print("  ok – all SiteCredentialStore & Archive tests passed")
    }

    private static func testSiteCredentialBasicAuth() {
        let cred = SiteCredential(
            host: "api.example.com",
            username: "admin",
            secret: "secret123",
            authType: .basic
        )
        // "admin:secret123" in base64 is "YWRtaW46c2VjcmV0MTIz"
        assert(cred.authorizationHeaderValue == "Basic YWRtaW46c2VjcmV0MTIz", "Basic auth header mismatch")
        print("  ok – Basic auth header generation")
    }

    private static func testSiteCredentialBearerAuth() {
        let cred = SiteCredential(
            host: "secure.example.com",
            username: "",
            secret: "my-jwt-token-xyz",
            authType: .bearer
        )
        assert(cred.authorizationHeaderValue == "Bearer my-jwt-token-xyz", "Bearer header mismatch")
        print("  ok – Bearer auth header generation")
    }

    private static func testSiteCredentialWildcardMatching() {
        SiteCredentialStore.save(SiteCredential(
            host: "*.download-portal.org",
            username: "vip_user",
            secret: "pass",
            authType: .basic
        ))

        let url1 = URL(string: "https://node1.download-portal.org/file.zip")!
        let match1 = SiteCredentialStore.credential(for: url1)
        assert(match1 != nil, "Wildcard subdomain should match")
        assert(match1?.username == "vip_user", "Matched username mismatch")

        let url2 = URL(string: "https://download-portal.org/file.zip")!
        let match2 = SiteCredentialStore.credential(for: url2)
        assert(match2 != nil, "Wildcard base domain should match")

        let otherUrl = URL(string: "https://other.com/file.zip")!
        assert(SiteCredentialStore.credential(for: otherUrl) == nil, "Unrelated domain should not match")

        SiteCredentialStore.remove(host: "*.download-portal.org")
        print("  ok – Wildcard domain matching and removal")
    }

    private static func testSiteCredentialPersistence() {
        let host = "test-persist.example.com"
        let cred = SiteCredential(
            host: host,
            username: "john",
            secret: "doe123",
            authType: .basic
        )
        SiteCredentialStore.save(cred)

        let loaded = SiteCredentialStore.credential(forHost: host)
        assert(loaded?.username == "john", "Persisted username should match")
        assert(loaded?.secret == "doe123", "Persisted secret should match")

        SiteCredentialStore.remove(host: host)
        assert(SiteCredentialStore.credential(forHost: host) == nil, "Credential should be removed")
        print("  ok – Persistence and deletion")
    }

    private static func testArchiveIdentification() {
        assert(ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/archive.zip")!), "zip should be archive")
        assert(ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/data.tar.gz")!), "tar.gz should be archive")
        assert(ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/bundle.tgz")!), "tgz should be archive")
        assert(ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/package.7z")!), "7z should be archive")

        assert(!ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/image.png")!), "png should not be archive")
        assert(!ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/app.dmg")!), "dmg should not be archive")
        assert(!ArchiveExtractionService.isArchive(url: URL(string: "https://example.com/doc.pdf")!), "pdf should not be archive")
        print("  ok – Archive identification")
    }
}
