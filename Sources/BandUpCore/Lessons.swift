import Foundation

public enum LessonBlock: Hashable, Sendable {
    case text(String)
    case heading(String)
    case bullets([String])
    /// A model answer or sample sentence, with a short label.
    case example(label: String, text: String)
    /// Useful phrases; the app shows a CEFR level for single words and listed phrases.
    case phrases([String])
    /// A common mistake and its fix.
    case mistake(wrong: String, right: String, why: String)
}

public enum LessonGroup: String, CaseIterable, Sendable {
    case exam = "The exam"
    case writing = "Writing"
    case speaking = "Speaking"
    case language = "Language"
}

public enum PracticeLink: Hashable, Sendable { case writing, speaking, quiz }

public struct Lesson: Identifiable, Hashable, Sendable {
    public let id: String
    public let group: LessonGroup
    public let title: String
    public let summary: String
    public let blocks: [LessonBlock]
    public var practice: PracticeLink?
}

/// Study material written for BandUp. Band descriptions are paraphrased summaries,
/// not the official IELTS wording.
public enum Lessons {
    public static let all: [Lesson] = [
        overview, bands,
        task2Types, task2Structure, task1, coherence,
        speakingPart1, speakingPart2, speakingPart3, fluency,
        upgradeVocab, mistakes,
    ]

    public static func lessons(in group: LessonGroup) -> [Lesson] { all.filter { $0.group == group } }

    // MARK: The exam

    static let overview = Lesson(
        id: "overview", group: .exam, title: "How IELTS works",
        summary: "Four papers, how long each takes, and how the overall band is worked out.",
        blocks: [
            .text("IELTS Academic and General Training share Listening and Speaking. Reading and Writing differ: Academic uses academic texts and a chart/diagram in Writing Task 1; General Training uses everyday texts and a letter."),
            .heading("The four papers"),
            .bullets([
                "Listening — about 30 minutes, 4 parts, 40 questions.",
                "Reading — 60 minutes, 3 passages, 40 questions.",
                "Writing — 60 minutes. Task 1 (150+ words, ~20 min) and Task 2 essay (250+ words, ~40 min). Task 2 counts for twice as much as Task 1.",
                "Speaking — 11–14 minutes, face to face with an examiner, in 3 parts.",
            ]),
            .heading("Scoring"),
            .text("Each paper gets a band from 0 to 9 in half bands. Your overall band is the average of the four, rounded to the nearest half band: an average ending in .25 rounds up to .5, and one ending in .75 rounds up to the next whole band."),
            .text("Writing and Speaking are marked on four criteria each, worth 25% apiece. That is why BandUp's feedback is split the same way."),
            .heading("What most targets look like"),
            .bullets([
                "Band 6–6.5: many undergraduate programmes and work visas.",
                "Band 7: competitive universities, many professional registrations.",
                "Band 7.5–8+: top programmes, some medical and legal roles.",
            ]),
        ])

    static let bands = Lesson(
        id: "bands", group: .exam, title: "What each band means",
        summary: "Plain-language summary of band 5 to band 8 for Writing and Speaking.",
        blocks: [
            .text("These are simplified summaries to help you aim. Examiners use the official public band descriptors."),
            .heading("Band 5"),
            .bullets([
                "Gets the message across, but ideas are limited or repetitive.",
                "Mostly simple sentences; frequent errors that sometimes confuse the reader.",
                "Vocabulary is basic (mostly A2–B1), with noticeable word-choice mistakes.",
            ]),
            .heading("Band 6"),
            .bullets([
                "Answers all parts of the question, though some ideas are not fully developed.",
                "Uses a mix of simple and complex sentences; errors happen but rarely block meaning.",
                "Enough vocabulary for the topic, with some attempt at less common words (B1–B2).",
                "Linking words are used, sometimes mechanically or not quite right.",
            ]),
            .heading("Band 7"),
            .bullets([
                "Clear position throughout; main ideas are extended and supported.",
                "Frequent error-free sentences and a variety of complex structures.",
                "Uses less common words and collocations with awareness of style (B2–C1).",
                "Logical organisation with a range of linking devices; paragraphs have clear central ideas.",
            ]),
            .heading("Band 8"),
            .bullets([
                "Fully developed, well-supported response.",
                "Wide range of structures; the majority of sentences are error-free.",
                "Skilful, precise use of uncommon vocabulary (C1+) with only occasional slips.",
                "Speaking: fluent, with only occasional hesitation for content, not language.",
            ]),
            .heading("The quickest wins from 6 to 7"),
            .bullets([
                "Develop every main idea with a reason AND a specific example.",
                "Replace A-level words with precise B2/C1 words — the summary in Writing shows your mix.",
                "Cut repeated errors: subject–verb agreement, articles, plurals.",
                "Use linking words naturally, not at the start of every sentence.",
            ]),
        ])

    // MARK: Writing

    static let task2Types = Lesson(
        id: "task2-types", group: .writing, title: "Task 2: the five question types",
        summary: "Spot the type in the question, because each one needs a different answer.",
        blocks: [
            .heading("1. Opinion (agree / disagree)"),
            .text("Keywords: \"To what extent do you agree or disagree?\" Give a clear position in the introduction and keep it to the end."),
            .heading("2. Discussion (discuss both views)"),
            .text("Keywords: \"Discuss both views and give your own opinion.\" One body paragraph per view, and your opinion in the introduction and conclusion."),
            .heading("3. Advantages and disadvantages"),
            .text("If it asks \"Do the advantages outweigh the disadvantages?\" you must say which side is bigger and why. If it only asks \"What are the advantages and disadvantages?\" you can stay neutral."),
            .heading("4. Problem and solution (or cause and solution)"),
            .text("One paragraph for problems/causes, one for solutions. Match each solution to a problem you mentioned."),
            .heading("5. Two-part question"),
            .text("Two direct questions, e.g. \"Why is this happening? Is it positive or negative?\" Answer both, one per body paragraph."),
            .heading("Most common reason for a low Task Response"),
            .text("Answering a different question than the one asked. Underline every part of the question before you plan."),
        ],
        practice: .writing)

    static let task2Structure = Lesson(
        id: "task2-structure", group: .writing, title: "Task 2: a four-paragraph plan",
        summary: "A reliable structure for 250–290 words in 40 minutes.",
        blocks: [
            .heading("Timing"),
            .bullets(["5 min — read, decide your position, plan two main ideas.", "30 min — write.", "5 min — check verbs, plurals, articles."]),
            .heading("Paragraph 1 — Introduction (2 sentences)"),
            .bullets(["Paraphrase the question in your own words.", "State your answer or position clearly."]),
            .example(label: "Introduction", text: "In many countries, a growing number of employees now work remotely rather than commuting to an office. In my view, the benefits of this trend clearly outweigh its drawbacks."),
            .heading("Paragraphs 2 and 3 — Body (4–5 sentences each)"),
            .bullets([
                "Topic sentence: the main idea of the paragraph.",
                "Explain: why or how it is true.",
                "Example: something specific — a situation, a group of people, a result.",
                "Link back: how it answers the question.",
            ]),
            .example(label: "Body paragraph", text: "The most significant advantage is the time saved on commuting. Instead of spending up to two hours a day in traffic, remote workers can use this time to rest, exercise or spend it with their families. For instance, a worker in Jakarta who no longer travels across the city gains roughly ten hours a week. This improves well-being and, in turn, productivity."),
            .heading("Paragraph 4 — Conclusion (1–2 sentences)"),
            .text("Restate your position and the main reasons. Never add a new idea here."),
            .example(label: "Conclusion", text: "In conclusion, although remote work can isolate some employees, the time it saves and the flexibility it offers make it a positive development overall."),
        ],
        practice: .writing)

    static let task1 = Lesson(
        id: "task1", group: .writing, title: "Task 1 (Academic): describing data",
        summary: "Overview first, then the key numbers. Language for trends and comparisons.",
        blocks: [
            .heading("The structure"),
            .bullets([
                "Introduction: paraphrase what the chart shows (1 sentence).",
                "Overview: the 2 biggest patterns, with no numbers. This is the most important sentence for your band.",
                "Two detail paragraphs: group the data logically and quote key figures.",
            ]),
            .example(label: "Overview", text: "Overall, the proportion of people using public transport rose steadily, while car use fell over the period, and buses remained the most popular option throughout."),
            .heading("Trend language"),
            .phrases(["rose steadily", "increased sharply", "fell slightly", "declined dramatically", "remained stable", "fluctuated", "peaked at", "reached a low of", "levelled off"]),
            .heading("Comparison language"),
            .phrases(["twice as many as", "slightly higher than", "by far the largest", "compared with", "whereas", "in contrast", "accounted for", "the majority of"]),
            .heading("Watch out"),
            .bullets(["No opinions or reasons — describe only what is shown.", "Do not list every number; select and compare.", "Use the right tense: past dates → past tense; projections → will / is expected to."]),
        ])

    static let coherence = Lesson(
        id: "coherence", group: .writing, title: "Linking words that sound natural",
        summary: "Cohesive devices by job, with their levels, and how not to overuse them.",
        blocks: [
            .text("Examiners reward linking that helps the reader, not linking words at the start of every sentence. Two or three per paragraph is usually enough."),
            .heading("Adding a point"),
            .phrases(["also", "in addition", "furthermore", "moreover", "what is more", "not only … but also"]),
            .heading("Contrast"),
            .phrases(["but", "however", "although", "whereas", "nevertheless", "on the other hand", "despite"]),
            .heading("Cause and effect"),
            .phrases(["because", "so", "as a result", "therefore", "consequently", "this leads to", "owing to"]),
            .heading("Examples"),
            .phrases(["for example", "for instance", "such as", "a case in point is", "to illustrate"]),
            .heading("Referencing (a band 7 habit)"),
            .text("Refer back with this/these + noun instead of repeating: \"Many cities are expanding. This growth puts pressure on housing.\""),
        ])

    // MARK: Speaking

    static let speakingPart1 = Lesson(
        id: "speaking-part1", group: .speaking, title: "Part 1: short, personal answers",
        summary: "4–5 minutes of familiar topics. Answer, explain, add a detail.",
        blocks: [
            .text("The examiner asks about you: home, work or study, hobbies, daily life. Aim for 2–3 sentences per answer (about 20–30 seconds)."),
            .heading("The A-R-E pattern"),
            .bullets(["Answer directly.", "Reason: why.", "Extra: an example, a detail, or how it has changed."]),
            .example(label: "Do you like cooking?", text: "Yes, I really enjoy it, especially at the weekend. It helps me switch off after a busy week, and I like trying recipes from different regions — last Sunday I made rendang for the first time."),
            .heading("Avoid"),
            .bullets(["One-word answers (\"Yes.\").", "Memorised speeches — examiners notice and it hurts fluency scores.", "Long silences: use a natural filler instead."]),
            .heading("Natural fillers"),
            .phrases(["That's an interesting question.", "Let me think…", "I've never really thought about it, but…", "To be honest,"]),
        ],
        practice: .speaking)

    static let speakingPart2 = Lesson(
        id: "speaking-part2", group: .speaking, title: "Part 2: the 2-minute talk",
        summary: "One minute to plan, then talk for up to two minutes from a cue card.",
        blocks: [
            .heading("Planning in 60 seconds"),
            .bullets([
                "Choose quickly — a true story is easier to talk about.",
                "Write keywords only, one line per bullet on the card.",
                "Add one feeling word and one detail word for each point.",
            ]),
            .heading("A shape that fills two minutes"),
            .bullets([
                "Set the scene: when, where, who (20 s).",
                "Tell what happened, in order (40 s).",
                "Go deeper on the most interesting moment (30 s).",
                "Explain the last bullet — usually how you felt or why it matters (30 s).",
            ]),
            .heading("Useful language"),
            .phrases(["I'd like to talk about…", "This happened a couple of years ago, when…", "What made it memorable was…", "Looking back,", "If I'm honest, I didn't expect…"]),
            .text("Keep talking until the examiner stops you. Running short costs more than running long."),
        ],
        practice: .speaking)

    static let speakingPart3 = Lesson(
        id: "speaking-part3", group: .speaking, title: "Part 3: abstract discussion",
        summary: "Bigger questions about society. Show you can explain, compare and speculate.",
        blocks: [
            .text("Questions move from \"you\" to \"people\" and \"society\". Answers should be longer (40–60 seconds) and more analytical."),
            .heading("Moves that score well"),
            .bullets([
                "Give a view, then a reason: \"I'd say…, mainly because…\"",
                "Compare: past vs now, young vs old, cities vs villages.",
                "Speculate: \"In the future, it's likely that…\"",
                "Show balance: \"That said, it depends on…\"",
            ]),
            .phrases(["It depends on", "Generally speaking,", "One reason might be", "On the whole,", "It's likely that", "That said,", "From a broader perspective,"]),
            .example(label: "Why do adults find languages hard?", text: "I'd say it's mainly about time and confidence rather than ability. Children pick things up through play, whereas adults usually study around a job and worry more about making mistakes. That said, adults are often better at grammar because they can understand rules explicitly."),
        ],
        practice: .speaking)

    static let fluency = Lesson(
        id: "fluency", group: .speaking, title: "Fluency: speaking without stopping",
        summary: "What examiners mean by fluency, and drills you can do with BandUp.",
        blocks: [
            .text("Fluency is not speed. It is keeping going, with pauses only to think about ideas, not to search for basic words."),
            .bullets([
                "Target about 120–160 words per minute; BandUp's Speaking window shows yours.",
                "Self-correct briefly (\"…he go — he went…\") and move on.",
                "Use chunks (\"as far as I know\", \"the main reason is\") so you don't build every sentence word by word.",
            ]),
            .heading("Daily drill (5 minutes)"),
            .bullets([
                "Pick a Part 1 question in BandUp and answer it three times.",
                "Each time, try to add one more detail and one B2+ word.",
                "Check the transcript for repeated words, then replace them next time.",
            ]),
        ],
        practice: .speaking)

    // MARK: Language

    static let upgradeVocab = Lesson(
        id: "upgrade-vocab", group: .language, title: "Upgrading A-level words",
        summary: "Swap the basic words examiners see most for precise B2–C1 choices.",
        blocks: [
            .text("Lexical Resource rewards precise, less common words used correctly. Don't force rare words — use ones you are sure of. Each phrase shows its level so you can see the jump."),
            .heading("Instead of good / bad"),
            .phrases(["beneficial", "valuable", "effective", "harmful", "damaging", "detrimental"]),
            .heading("Instead of big / small"),
            .phrases(["significant", "substantial", "considerable", "minor", "slight", "negligible"]),
            .heading("Instead of think / say"),
            .phrases(["believe", "argue", "claim", "suggest", "maintain", "point out"]),
            .heading("Instead of get / make"),
            .phrases(["obtain", "acquire", "achieve", "create", "generate", "cause"]),
            .heading("Instead of very"),
            .phrases(["extremely", "highly", "deeply", "particularly", "remarkably"]),
            .heading("Collocations examiners like"),
            .phrases(["play a vital role in", "have a significant impact on", "raise awareness of", "pose a threat to", "address the issue", "a growing number of"]),
        ],
        practice: .quiz)

    static let mistakes = Lesson(
        id: "mistakes", group: .language, title: "Common mistakes for Indonesian speakers",
        summary: "Patterns that come from Bahasa Indonesia, and how to fix them.",
        blocks: [
            .text("Bahasa Indonesia has no verb tenses, no plural endings on most nouns, and no articles, so these are the errors examiners see most from Indonesian candidates."),
            .mistake(wrong: "My brother work from home.", right: "My brother works from home.", why: "Third-person singular present needs -s."),
            .mistake(wrong: "Yesterday I go to the market.", right: "Yesterday I went to the market.", why: "Past time needs a past-tense verb; \"yesterday\" alone is not enough in English."),
            .mistake(wrong: "There are many problem in big city.", right: "There are many problems in big cities.", why: "Countable nouns after many/several/two need the plural -s."),
            .mistake(wrong: "Government should build more hospital.", right: "The government should build more hospitals.", why: "Singular countable nouns need an article (a/an/the); \"the government\" is fixed."),
            .mistake(wrong: "I very like reading.", right: "I really like reading. / I like reading very much.", why: "\"Very\" cannot go directly before a verb."),
            .mistake(wrong: "It can make people become lazy.", right: "It can make people lazy.", why: "make + object + adjective; no \"become\"."),
            .mistake(wrong: "Although it is expensive, but many people buy it.", right: "Although it is expensive, many people buy it.", why: "Use although OR but, not both (meskipun … tetapi)."),
            .mistake(wrong: "I am agree with this opinion.", right: "I agree with this opinion.", why: "\"Agree\" is a verb, so no \"am\"."),
            .mistake(wrong: "People in my country is friendly.", right: "People in my country are friendly.", why: "\"People\" is plural."),
        ],
        practice: .quiz)
}
