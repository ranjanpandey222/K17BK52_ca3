import Foundation

/// Short educational articles. General information only. Have a qualified
/// clinician (e.g. a Menopause Society Certified Practitioner) review this
/// content before launch; see docs/LAUNCH_CHECKLIST.md.
struct LearnArticle: Identifiable, Hashable {
    struct Section: Hashable {
        var heading: String?
        var paragraphs: [String] = []
        var bullets: [String] = []
    }

    let id: String
    let title: String
    let summary: String
    let systemImage: String
    let sections: [Section]
}

enum LearnLibrary {
    static let reviewNote = "General information, not medical advice. Talk to a clinician about your own situation."

    static let stages = LearnArticle(
        id: "stages",
        title: "The stages of menopause",
        summary: "Perimenopause, menopause and postmenopause, explained simply.",
        systemImage: "point.topleft.down.curvedto.point.bottomright.up",
        sections: [
            .init(paragraphs: [
                "Menopause isn't a single day. It's a transition that usually unfolds over several years as the ovaries gradually make less estrogen and progesterone."
            ]),
            .init(heading: "Perimenopause", paragraphs: [
                "The years leading up to menopause. It often starts in the 40s and can last several years. Hormone levels rise and fall unpredictably, so periods may become irregular and symptoms can come and go."
            ]),
            .init(heading: "Menopause", paragraphs: [
                "Menopause is reached after 12 months in a row without a period (when there's no other cause, such as pregnancy or certain medicines). In the US the average age is around 51 to 52, but anywhere from the mid-40s to mid-50s is common."
            ]),
            .init(heading: "Postmenopause", paragraphs: [
                "The years after menopause. Some symptoms, like hot flashes, may continue for years, while others, like vaginal dryness, can appear or increase. Bone and heart health become more important to look after."
            ]),
            .init(heading: "When to talk to a doctor", bullets: [
                "Any bleeding after 12 months without a period",
                "Very heavy bleeding, or periods much closer together than usual",
                "Symptoms that disrupt your sleep, work or relationships",
                "Signs of menopause before age 40"
            ])
        ]
    )

    static let symptoms = LearnArticle(
        id: "symptoms",
        title: "Common symptoms",
        summary: "Hot flashes are only part of it. Here's the wider picture.",
        systemImage: "list.bullet.rectangle",
        sections: [
            .init(paragraphs: [
                "Changing hormone levels affect many parts of the body, so symptoms vary a lot from person to person. Many people are surprised by how wide-ranging they can be."
            ]),
            .init(heading: "Often reported", bullets: [
                "Hot flashes and night sweats",
                "Trouble falling or staying asleep",
                "Mood changes, irritability, anxiety or low mood",
                "Brain fog and forgetfulness",
                "Joint and muscle aches",
                "Headaches",
                "Vaginal dryness and lower libido",
                "Bladder changes, such as urgency",
                "Heart palpitations",
                "Dry skin and hair changes"
            ]),
            .init(heading: "Why tracking helps", paragraphs: [
                "Symptoms that come and go are easy to forget or downplay at an appointment. A record of what you felt, how often and how strongly helps you and your clinician see the real pattern, and whether a treatment is helping."
            ])
        ]
    )

    static let hotFlashes = LearnArticle(
        id: "hot-flashes",
        title: "Hot flashes & night sweats",
        summary: "What they are and practical ways people manage them.",
        systemImage: "flame",
        sections: [
            .init(paragraphs: [
                "A hot flash is a sudden feeling of heat, often in the face, neck and chest, sometimes with flushing, sweating and a fast heartbeat. Night sweats are hot flashes during sleep. They are the most common menopause symptom and can last for several years."
            ]),
            .init(heading: "Common triggers to watch", bullets: [
                "Alcohol and caffeine",
                "Spicy food",
                "Stress",
                "Warm rooms, hot weather or heavy bedding"
            ]),
            .init(heading: "Everyday things that may help", bullets: [
                "Dress in layers you can remove",
                "Keep the bedroom cool and use breathable bedding",
                "Keep a cold drink or a small fan nearby",
                "Notice your own triggers: Ebb's patterns can help"
            ]),
            .init(heading: "Treatment options to ask about", paragraphs: [
                "Hormone therapy is the most effective treatment for hot flashes for many people. There are also several non-hormonal prescription options. A clinician can help you weigh the benefits and risks for your health history."
            ])
        ]
    )

    static let sleep = LearnArticle(
        id: "sleep",
        title: "Sleep during menopause",
        summary: "Why sleep changes, and habits that support better nights.",
        systemImage: "moon.zzz",
        sections: [
            .init(paragraphs: [
                "Sleep problems are very common during the menopause transition. Night sweats can wake you up, and hormonal changes can affect sleep quality and mood, which in turn affect sleep."
            ]),
            .init(heading: "Habits that may help", bullets: [
                "Keep a regular sleep and wake time",
                "Keep the bedroom cool, dark and quiet",
                "Limit caffeine after midday and alcohol in the evening",
                "Get daylight and movement earlier in the day",
                "Wind down without screens before bed"
            ]),
            .init(heading: "Worth discussing with a clinician", paragraphs: [
                "If poor sleep continues for weeks, or you snore loudly or wake up gasping, talk to a clinician. Treating night sweats, and approaches such as cognitive behavioral therapy for insomnia (CBT-I), can help."
            ])
        ]
    )

    static let mood = LearnArticle(
        id: "mood",
        title: "Mood, anxiety & brain fog",
        summary: "You're not imagining it, and it's worth raising.",
        systemImage: "brain.head.profile",
        sections: [
            .init(paragraphs: [
                "Many people notice mood swings, irritability, anxiety, low mood or trouble concentrating during perimenopause. Poor sleep from night sweats can make all of these worse."
            ]),
            .init(heading: "Things that may help", bullets: [
                "Regular physical activity",
                "Protecting your sleep",
                "Talking with people you trust",
                "Noticing patterns, for example around stress or sleep"
            ]),
            .init(heading: "Get support", paragraphs: [
                "If low mood lasts more than two weeks, or you have thoughts of harming yourself, contact a health professional promptly. In the US you can call or text 988 to reach the Suicide & Crisis Lifeline at any time."
            ])
        ]
    )

    static let hormoneTherapy = LearnArticle(
        id: "hormone-therapy",
        title: "Hormone therapy basics",
        summary: "What HRT is, the main forms, and questions to ask.",
        systemImage: "pills",
        sections: [
            .init(paragraphs: [
                "Hormone therapy (HT or HRT) replaces some of the estrogen the body makes less of. People who still have a uterus usually also need a progestogen to protect the lining of the uterus."
            ]),
            .init(heading: "Common forms", bullets: [
                "Skin patches, gels and sprays",
                "Pills",
                "Vaginal creams, tablets and rings (low-dose, mainly for vaginal and urinary symptoms)"
            ]),
            .init(heading: "Benefits and risks", paragraphs: [
                "For many healthy people under 60, or within 10 years of menopause, the benefits for symptoms often outweigh the risks. Risks depend on age, health history, the type of hormone and how it's taken. That's why the decision is personal and best made with a clinician."
            ]),
            .init(heading: "Questions to ask", bullets: [
                "Am I a good candidate for hormone therapy?",
                "Which form and dose would suit me, and why?",
                "How long until I might notice a difference?",
                "How often should we review it?"
            ]),
            .init(paragraphs: [
                "Ebb can show how your symptoms change after starting or adjusting a treatment. Add it in the Treatments tab."
            ])
        ]
    )

    static let longTermHealth = LearnArticle(
        id: "long-term-health",
        title: "Bones, heart & long-term health",
        summary: "Why menopause is a good time for a health check-in.",
        systemImage: "heart.text.square",
        sections: [
            .init(paragraphs: [
                "Lower estrogen after menopause speeds up bone loss and is linked with changes in cholesterol and heart health. Small steps now pay off for decades."
            ]),
            .init(heading: "Habits that help", bullets: [
                "Weight-bearing and strength exercise a few times a week",
                "Enough calcium and vitamin D from food, plus supplements if advised",
                "Not smoking and limiting alcohol",
                "Knowing your blood pressure and cholesterol numbers"
            ]),
            .init(heading: "Ask your clinician about", bullets: [
                "When you should have a bone density scan",
                "Which heart health checks you need",
                "Other screenings recommended at your age"
            ])
        ]
    )

    static let doctorVisit = LearnArticle(
        id: "doctor-visit",
        title: "Getting the most from your appointment",
        summary: "How to be heard in a short visit.",
        systemImage: "stethoscope",
        sections: [
            .init(paragraphs: [
                "Appointments are often short, and symptoms that come and go are hard to describe on the spot. Preparing a little makes a big difference."
            ]),
            .init(heading: "Before you go", bullets: [
                "Create your Ebb doctor report (Insights → Create doctor report)",
                "Pick your top 2 or 3 concerns",
                "List your current medicines and supplements",
                "Write down what you want to leave with: answers, a plan or a referral"
            ]),
            .init(heading: "During the visit", bullets: [
                "Start with your biggest concern",
                "Share the report, which shows frequency and severity at a glance",
                "Ask what the next step is and when to follow up"
            ]),
            .init(heading: "If you don't feel heard", paragraphs: [
                "It's okay to ask for more time, a follow-up visit or a referral. Clinicians with specific menopause training, such as Menopause Society Certified Practitioners, can be found through The Menopause Society's online directory."
            ])
        ]
    )

    static let all: [LearnArticle] = [stages, symptoms, hotFlashes, sleep, mood, hormoneTherapy, longTermHealth, doctorVisit]
}
