import Foundation
import Testing
@testable import demonincpromptgen_songanalysis

struct PKCETests {
    /// Testvektor aus RFC 7636, Anhang B.
    @Test func challengeMatchesRFC7636Vector() {
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func generatedVerifierIsValid() {
        let pkce = PKCE.generate()
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        #expect((43...128).contains(pkce.codeVerifier.count))
        #expect(pkce.codeVerifier.allSatisfy(allowed.contains))
        #expect(PKCE.challenge(for: pkce.codeVerifier) == pkce.codeChallenge)
        #expect(PKCE.generate().codeVerifier != pkce.codeVerifier)
    }
}
