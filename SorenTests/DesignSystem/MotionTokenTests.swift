import Testing
@testable import Soren

@Suite("Motion Tokens — Animation Timing")
struct MotionTokenTests {

    @Test("Fast duration is under 200ms")
    func fastDuration() {
        #expect(MotionTokens.fast > 0)
        #expect(MotionTokens.fast < 0.2)
    }

    @Test("Standard duration is between 200-400ms")
    func standardDuration() {
        #expect(MotionTokens.standard >= 0.2)
        #expect(MotionTokens.standard <= 0.4)
    }

    @Test("Slow duration is over 300ms")
    func slowDuration() {
        #expect(MotionTokens.slow > 0.3)
    }

    @Test("Duration hierarchy: fast < standard < slow")
    func durationHierarchy() {
        #expect(MotionTokens.fast < MotionTokens.standard)
        #expect(MotionTokens.standard < MotionTokens.slow)
    }

    @Test("No duration exceeds 1 second — we're not making a movie")
    func noDurationTooSlow() {
        #expect(MotionTokens.fast < 1.0)
        #expect(MotionTokens.standard < 1.0)
        #expect(MotionTokens.slow < 1.0)
    }
}
