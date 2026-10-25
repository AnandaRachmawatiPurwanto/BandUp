import Foundation
import FoundationModels

// Result types are plain Codable structs so a cloud engine (OpenAI, Claude)
// can decode its JSON into them later. @Generable lets Apple's on-device
// model fill them directly.

@Generable
public struct WordExplanation: Codable, Sendable, Hashable {
    @Guide(description: "A simple English definition, under 15 words")
    public var definition: String
    @Guide(description: "One sentence in Bahasa Indonesia explaining what the word means")
    public var indonesian: String
    @Guide(description: "A natural example sentence an IELTS candidate could use")
    public var example: String
}

@Generable
public struct SentenceCheck: Codable, Sendable, Hashable {
    @Guide(description: "True if the target word is used with the right meaning and the sentence is grammatical")
    public var isCorrect: Bool
    @Guide(description: "The learner's own sentence with only the mistakes fixed. Keep their words, ideas and word order; change as little as possible. Repeat it unchanged if it is already correct")
    public var corrected: String
    @Guide(description: "One short sentence naming what was changed and why, or praising what works")
    public var comment: String
    @Guide(description: "Two more natural example sentences using the target word in other ways or contexts", .count(2))
    public var otherUses: [String]
}

@Generable
public struct WordUpgrade: Codable, Sendable, Hashable {
    @Guide(description: "A basic word or phrase the learner actually used")
    public var original: String
    @Guide(description: "A more precise, higher-level alternative that fits the same sentence")
    public var better: String
}

@Generable
public struct EssayFeedback: Codable, Sendable, Hashable {
    @Guide(description: "Estimated IELTS band for Task Response", .range(0...9))
    public var taskResponse: Double
    @Guide(description: "Estimated IELTS band for Coherence and Cohesion", .range(0...9))
    public var coherence: Double
    @Guide(description: "Estimated IELTS band for Lexical Resource", .range(0...9))
    public var lexical: Double
    @Guide(description: "Estimated IELTS band for Grammatical Range and Accuracy", .range(0...9))
    public var grammar: Double
    @Guide(description: "Two things the essay does well", .count(2))
    public var strengths: [String]
    @Guide(description: "Three concrete, specific changes that would raise the band", .count(3))
    public var improvements: [String]
    @Guide(description: "Up to five vocabulary upgrades taken from the essay", .maximumCount(5))
    public var upgrades: [WordUpgrade]
}

@Generable
public struct SpeakingFeedback: Codable, Sendable, Hashable {
    @Guide(description: "Estimated IELTS band for Fluency and Coherence", .range(0...9))
    public var fluency: Double
    @Guide(description: "Estimated IELTS band for Lexical Resource", .range(0...9))
    public var lexical: Double
    @Guide(description: "Estimated IELTS band for Grammatical Range and Accuracy", .range(0...9))
    public var grammar: Double
    @Guide(description: "Did the answer actually address the question and develop it?")
    public var answeredQuestion: Bool
    @Guide(description: "Three concrete tips for a better answer next time", .count(3))
    public var tips: [String]
    @Guide(description: "Up to four vocabulary upgrades taken from the answer", .maximumCount(4))
    public var upgrades: [WordUpgrade]
}

extension EssayFeedback {
    /// IELTS rounds the mean of the four criteria to the nearest half band.
    public var overall: Double { roundToHalf((taskResponse + coherence + lexical + grammar) / 4) }
}

extension SpeakingFeedback {
    public var overall: Double { roundToHalf((fluency + lexical + grammar) / 3) }
}

func roundToHalf(_ x: Double) -> Double { (x * 2).rounded() / 2 }

/// Anything that can give feedback. The app ships with Apple's on-device model;
/// a cloud engine can be added later by conforming to this protocol.
public protocol FeedbackEngine: Sendable {
    var name: String { get }
    func explain(_ word: Word) async throws -> WordExplanation
    func check(sentence: String, word: Word) async throws -> SentenceCheck
    func review(essay: String, prompt: WritingPrompt) async throws -> EssayFeedback
    func review(answer transcript: String, prompt: SpeakingPrompt) async throws -> SpeakingFeedback
}

/// Feedback from Apple Intelligence, running fully on the Mac.
public struct AppleFeedbackEngine: FeedbackEngine {
    public let name = "Apple Intelligence (on-device)"

    public init() {}

    public static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    private static let examiner = """
        You are an experienced, honest IELTS examiner and English tutor. \
        Judge strictly against the public IELTS band descriptors. \
        Be specific and quote the learner's own words when pointing out problems.
        """

    /// Caps the answer so a runaway generation can't overflow the 8k context.
    private static let options = GenerationOptions(maximumResponseTokens: 800)

    /// Asks the model, retrying once with relaxed guardrails: the default filter
    /// sometimes refuses ordinary learner sentences (e.g. ones using "despise").
    private func generate<T: Generable>(_ prompt: String, as type: T.Type) async throws -> T {
        do {
            return try await LanguageModelSession(instructions: Self.examiner)
                .respond(to: prompt, generating: type, options: Self.options).content
        } catch LanguageModelSession.GenerationError.guardrailViolation {
            let relaxed = SystemLanguageModel(guardrails: .permissiveContentTransformations)
            return try await LanguageModelSession(model: relaxed, instructions: Self.examiner)
                .respond(to: prompt, generating: type, options: Self.options).content
        }
    }

    public func explain(_ word: Word) async throws -> WordExplanation {
        try await generate("Explain the English \(word.pos) \"\(word.word)\" (CEFR \(word.level.rawValue)).",
                           as: WordExplanation.self)
    }

    public func check(sentence: String, word: Word) async throws -> SentenceCheck {
        let prompt = """
            The learner was asked to write one sentence using the \(word.pos) "\(word.word)".
            Their sentence: "\(sentence)"
            If it has mistakes, fix the learner's own sentence rather than writing a new one.
            """
        return try await generate(prompt, as: SentenceCheck.self)
    }

    public func review(essay: String, prompt: WritingPrompt) async throws -> EssayFeedback {
        let request = """
            IELTS Writing \(prompt.task) question: \(prompt.question)
            Minimum length: \(prompt.minWords) words.

            Candidate's essay:
            \(essay)
            """
        return try await generate(request, as: EssayFeedback.self)
    }

    public func review(answer transcript: String, prompt: SpeakingPrompt) async throws -> SpeakingFeedback {
        let request = """
            IELTS Speaking \(prompt.part.rawValue) question: \(prompt.question)
            Below is a speech-to-text transcript of the candidate's spoken answer. \
            Ignore missing punctuation and capitalisation; they come from the transcription.

            Transcript:
            \(transcript)
            """
        return try await generate(request, as: SpeakingFeedback.self)
    }
}
