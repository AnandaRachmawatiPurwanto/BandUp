import Foundation

public enum SpeakingPart: String, Codable, Sendable {
    case part1 = "Part 1", part2 = "Part 2", part3 = "Part 3"

    /// Suggested answer length in seconds.
    public var seconds: Int {
        switch self {
        case .part1: 30
        case .part2: 120
        case .part3: 60
        }
    }
}

public struct SpeakingPrompt: Hashable, Sendable {
    public let part: SpeakingPart
    public let question: String
}

public struct WritingPrompt: Hashable, Sendable {
    public let task: String
    public let question: String
    public let minWords: Int
}

/// IELTS-style practice questions, written for this app.
public enum Prompts {
    public static let speaking: [SpeakingPrompt] = [
        .init(part: .part1, question: "Do you work or are you a student? What do you enjoy most about it?"),
        .init(part: .part1, question: "How do you usually spend your weekends?"),
        .init(part: .part1, question: "Do you prefer reading books or watching films? Why?"),
        .init(part: .part1, question: "What kind of music do you listen to, and when?"),
        .init(part: .part1, question: "Is there a place in your city you like to visit often? Why?"),
        .init(part: .part1, question: "How often do you use your phone for learning?"),
        .init(part: .part1, question: "Do you like cooking? What was the last thing you cooked?"),
        .init(part: .part2, question: "Describe a skill you learned that took a long time. You should say what it was, why you learned it, how you learned it, and explain how you feel about it now."),
        .init(part: .part2, question: "Describe a time you helped someone. You should say who it was, what happened, how you helped, and explain how you felt afterwards."),
        .init(part: .part2, question: "Describe a place you would like to visit in the future. You should say where it is, how you know about it, what you would do there, and explain why you want to go."),
        .init(part: .part2, question: "Describe a piece of technology you find useful. You should say what it is, when you got it, how you use it, and explain why it is important to you."),
        .init(part: .part3, question: "Do you think technology makes people more or less creative? Why?"),
        .init(part: .part3, question: "Why do some people find it hard to learn a new language as adults?"),
        .init(part: .part3, question: "Should governments spend more on public transport or on roads?"),
        .init(part: .part3, question: "How has the way people work changed in the last twenty years?"),
    ]

    public static let writing: [WritingPrompt] = [
        .init(task: "Task 2", question: "Some people believe that university students should study whatever they like, while others think they should only study subjects useful for the future, such as science and technology. Discuss both views and give your own opinion.", minWords: 250),
        .init(task: "Task 2", question: "In many countries, people are spending more time working from home. Do the advantages of this outweigh the disadvantages?", minWords: 250),
        .init(task: "Task 2", question: "Some people think that the best way to reduce crime is to give longer prison sentences. Others believe there are better ways. Discuss both views and give your opinion.", minWords: 250),
        .init(task: "Task 2", question: "Social media has changed the way young people communicate. Is this a positive or negative development?", minWords: 250),
        .init(task: "Task 2", question: "Many cities are becoming overcrowded. What problems does this cause, and what solutions can you suggest?", minWords: 250),
        .init(task: "Task 2", question: "Some people say that children should learn a foreign language at primary school rather than secondary school. Do you agree or disagree?", minWords: 250),
    ]
}
