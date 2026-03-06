import Foundation

// MARK: - Practice Scenario

struct PracticeScenario: Identifiable, Hashable {
    let id: String
    let category: PracticeCategory
    let title: String
    let message: String
    let context: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PracticeScenario, rhs: PracticeScenario) -> Bool { lhs.id == rhs.id }
}

// MARK: - Category

enum PracticeCategory: String, CaseIterable, Identifiable {
    case smallTalk      = "Small Talk"
    case weekendPlans   = "Weekend Plans"
    case workplaceBanter = "Workplace Banter"
    case sportsTalk     = "Sports Talk"
    case americanHumor  = "American Humor"
    case holidayGreetings = "Holiday Greetings"
    case foodDining     = "Food & Dining"
    case socialEvents   = "Social Events"
    case compliments    = "Compliments"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .smallTalk:        return "💬"
        case .weekendPlans:     return "🗓️"
        case .workplaceBanter:  return "💼"
        case .sportsTalk:       return "🏆"
        case .americanHumor:    return "😄"
        case .holidayGreetings: return "🎉"
        case .foodDining:       return "🍽️"
        case .socialEvents:     return "🎊"
        case .compliments:      return "⭐"
        }
    }
}

// MARK: - Scenario Data

enum PracticeScenarios {
    static let all: [PracticeScenario] = smallTalk + weekendPlans + workplaceBanter +
        sportsTalk + americanHumor + holidayGreetings + foodDining + socialEvents + compliments

    // MARK: Small Talk
    static let smallTalk: [PracticeScenario] = [
        PracticeScenario(
            id: "st-1",
            category: .smallTalk,
            title: "Monday check-in",
            message: "Hey! How was your weekend?",
            context: "A coworker or acquaintance asks on Monday morning."
        ),
        PracticeScenario(
            id: "st-2",
            category: .smallTalk,
            title: "Weather chat",
            message: "Can you believe this weather we're having?",
            context: "Classic American small talk opener."
        ),
        PracticeScenario(
            id: "st-3",
            category: .smallTalk,
            title: "Running late",
            message: "Running a bit late, sorry! Be there in 10.",
            context: "A friend texting on their way to meet you."
        ),
        PracticeScenario(
            id: "st-4",
            category: .smallTalk,
            title: "Long time no see",
            message: "Omg it's been forever! How have you been?",
            context: "An old friend reaching out on Instagram."
        ),
        PracticeScenario(
            id: "st-5",
            category: .smallTalk,
            title: "Checking in",
            message: "Just wanted to check in and see how you're doing!",
            context: "A thoughtful message from someone who cares."
        ),
        PracticeScenario(
            id: "st-6",
            category: .smallTalk,
            title: "Monday motivation",
            message: "Happy Monday! Hope you have a great week!",
            context: "Cheerful message to start the work week."
        ),
    ]

    // MARK: Weekend Plans
    static let weekendPlans: [PracticeScenario] = [
        PracticeScenario(
            id: "wp-1",
            category: .weekendPlans,
            title: "Friday invite",
            message: "Hey, wanna grab drinks this Friday after work?",
            context: "Casual invite from a friend or coworker."
        ),
        PracticeScenario(
            id: "wp-2",
            category: .weekendPlans,
            title: "Brunch group chat",
            message: "Anyone down for brunch Sunday? I'm thinking 11am at that new place downtown.",
            context: "Group chat message about weekend brunch."
        ),
        PracticeScenario(
            id: "wp-3",
            category: .weekendPlans,
            title: "Hiking invite",
            message: "We're doing a hike Saturday morning, you should come! It's super chill.",
            context: "Friend inviting you to an outdoor activity."
        ),
        PracticeScenario(
            id: "wp-4",
            category: .weekendPlans,
            title: "Movie night",
            message: "Movie night at mine on Saturday? I'll get snacks",
            context: "Casual invite for a cozy night in."
        ),
        PracticeScenario(
            id: "wp-5",
            category: .weekendPlans,
            title: "Game night",
            message: "We're doing game night Friday, you in? We need a 4th!",
            context: "They need you to make even teams."
        ),
    ]

    // MARK: Workplace Banter
    static let workplaceBanter: [PracticeScenario] = [
        PracticeScenario(
            id: "wb-1",
            category: .workplaceBanter,
            title: "Meeting humor",
            message: "This meeting could've been an email lol",
            context: "A colleague venting in the team chat."
        ),
        PracticeScenario(
            id: "wb-2",
            category: .workplaceBanter,
            title: "Coffee station",
            message: "Someone finished the coffee and didn't make more again 😤",
            context: "Office group chat complaint about coffee."
        ),
        PracticeScenario(
            id: "wb-3",
            category: .workplaceBanter,
            title: "Friday energy",
            message: "Is it Friday yet? Asking for a friend",
            context: "Classic midweek exhaustion message."
        ),
        PracticeScenario(
            id: "wb-4",
            category: .workplaceBanter,
            title: "Lunch plans",
            message: "Anyone want to do a lunch run? I'm thinking tacos",
            context: "Spontaneous lunch invitation at work."
        ),
        PracticeScenario(
            id: "wb-5",
            category: .workplaceBanter,
            title: "Zoom fatigue",
            message: "I have 6 meetings today. Send help 😭",
            context: "Colleague joking about an overloaded calendar."
        ),
    ]

    // MARK: Sports Talk
    static let sportsTalk: [PracticeScenario] = [
        PracticeScenario(
            id: "sp-1",
            category: .sportsTalk,
            title: "Game day invite",
            message: "You watching the game Sunday? Come over!",
            context: "Friend inviting you to watch the big game."
        ),
        PracticeScenario(
            id: "sp-2",
            category: .sportsTalk,
            title: "Team lost",
            message: "Ugh that loss was painful to watch. Our defense is just terrible.",
            context: "Fan venting after a disappointing game."
        ),
        PracticeScenario(
            id: "sp-3",
            category: .sportsTalk,
            title: "Fantasy sports",
            message: "Dude your running back went OFF last night. I needed that for my fantasy team 😭",
            context: "Fantasy sports banter between friends."
        ),
        PracticeScenario(
            id: "sp-4",
            category: .sportsTalk,
            title: "Super Bowl party",
            message: "We're doing a Super Bowl party at ours! Can you bring wings?",
            context: "Super Bowl party planning message."
        ),
        PracticeScenario(
            id: "sp-5",
            category: .sportsTalk,
            title: "Sports bet",
            message: "I'm telling you, they're going all the way this year. Trust me on this one.",
            context: "Friend making a bold prediction about their team."
        ),
    ]

    // MARK: American Humor
    static let americanHumor: [PracticeScenario] = [
        PracticeScenario(
            id: "ah-1",
            category: .americanHumor,
            title: "Sarcasm",
            message: "Oh great, another Monday. My absolute favorite day of the week.",
            context: "Dry sarcasm about the start of the work week."
        ),
        PracticeScenario(
            id: "ah-2",
            category: .americanHumor,
            title: "Self-deprecating",
            message: "I just walked into a glass door in front of everyone at the office 🙃",
            context: "Embarrassing moment shared for a laugh."
        ),
        PracticeScenario(
            id: "ah-3",
            category: .americanHumor,
            title: "Gen Z slang",
            message: "Bro that meeting was giving total chaos energy and I am here for it",
            context: "Someone describing a chaotic work situation."
        ),
        PracticeScenario(
            id: "ah-4",
            category: .americanHumor,
            title: "Adulting struggle",
            message: "adulting is hard, who approved this?",
            context: "Relatable humor about grown-up responsibilities."
        ),
        PracticeScenario(
            id: "ah-5",
            category: .americanHumor,
            title: "Plot twist",
            message: "Plot twist: I actually liked the meeting today. The world is ending.",
            context: "Surprise at an unexpected outcome."
        ),
    ]

    // MARK: Holiday Greetings
    static let holidayGreetings: [PracticeScenario] = [
        PracticeScenario(
            id: "hg-1",
            category: .holidayGreetings,
            title: "Happy Thanksgiving",
            message: "Happy Thanksgiving! Hope you're having a great day with family 🦃",
            context: "Holiday greeting from a friend or coworker."
        ),
        PracticeScenario(
            id: "hg-2",
            category: .holidayGreetings,
            title: "Merry Christmas",
            message: "Merry Christmas! Hope Santa was good to you 🎄",
            context: "Christmas greeting, light and festive."
        ),
        PracticeScenario(
            id: "hg-3",
            category: .holidayGreetings,
            title: "New Year's Eve",
            message: "Can you believe it's almost New Year's?? Where did this year go?!",
            context: "Reflective message about the year ending."
        ),
        PracticeScenario(
            id: "hg-4",
            category: .holidayGreetings,
            title: "4th of July",
            message: "Happy 4th! You guys doing fireworks tonight?",
            context: "Independence Day check-in from a friend."
        ),
        PracticeScenario(
            id: "hg-5",
            category: .holidayGreetings,
            title: "Halloween",
            message: "Happy Halloween!! What are you dressing up as this year? 👻",
            context: "Excited Halloween message."
        ),
    ]

    // MARK: Food & Dining
    static let foodDining: [PracticeScenario] = [
        PracticeScenario(
            id: "fd-1",
            category: .foodDining,
            title: "Restaurant recommendation",
            message: "You have to try this new ramen place that opened up downtown, it's insane",
            context: "Food recommendation from an enthusiastic friend."
        ),
        PracticeScenario(
            id: "fd-2",
            category: .foodDining,
            title: "Dinner reservation",
            message: "Made a reservation for 7pm Saturday! Can't wait to catch up 🍷",
            context: "Confirming dinner plans."
        ),
        PracticeScenario(
            id: "fd-3",
            category: .foodDining,
            title: "Food delivery",
            message: "We're ordering Thai food, you want in? Last call!",
            context: "Group food order with a time limit."
        ),
        PracticeScenario(
            id: "fd-4",
            category: .foodDining,
            title: "Cooking experiment",
            message: "I tried to make that recipe and it was a disaster lol. How do you make it look so easy?",
            context: "Asking for cooking tips after a failed attempt."
        ),
        PracticeScenario(
            id: "fd-5",
            category: .foodDining,
            title: "Coffee order",
            message: "I'm making a coffee run, what do you want?",
            context: "Quick offer to grab coffee for someone."
        ),
    ]

    // MARK: Social Events
    static let socialEvents: [PracticeScenario] = [
        PracticeScenario(
            id: "se-1",
            category: .socialEvents,
            title: "Birthday party",
            message: "Don't forget — Sarah's birthday party is this Saturday at 7! Are you coming?",
            context: "Reminder about an upcoming birthday celebration."
        ),
        PracticeScenario(
            id: "se-2",
            category: .socialEvents,
            title: "Wedding RSVP",
            message: "Hey! Just wanted to confirm you got our wedding invite? We'd love to see you there 💕",
            context: "Gentle follow-up on a wedding RSVP."
        ),
        PracticeScenario(
            id: "se-3",
            category: .socialEvents,
            title: "Baby shower",
            message: "We're throwing a baby shower for Jessica next weekend! Can you make it?",
            context: "Invitation to a friend's baby shower."
        ),
        PracticeScenario(
            id: "se-4",
            category: .socialEvents,
            title: "Graduation party",
            message: "My graduation party is in two weeks — you're coming right?? It would mean a lot!",
            context: "Excited graduation celebration invite."
        ),
        PracticeScenario(
            id: "se-5",
            category: .socialEvents,
            title: "Housewarming",
            message: "We're finally in our new place! Housewarming party next Saturday, hope to see you there 🏠",
            context: "Exciting housewarming invitation."
        ),
    ]

    // MARK: Compliments
    static let compliments: [PracticeScenario] = [
        PracticeScenario(
            id: "co-1",
            category: .compliments,
            title: "Great work",
            message: "Just wanted to say — your presentation today was seriously impressive. You killed it!",
            context: "Sincere compliment after a work presentation."
        ),
        PracticeScenario(
            id: "co-2",
            category: .compliments,
            title: "Style compliment",
            message: "Okay where did you get that jacket?? You looked so good today!",
            context: "Fashion compliment from a friend."
        ),
        PracticeScenario(
            id: "co-3",
            category: .compliments,
            title: "Cooking praise",
            message: "That dinner you made last week was honestly one of the best meals I've had. You're so talented!",
            context: "Compliment about someone's cooking skills."
        ),
        PracticeScenario(
            id: "co-4",
            category: .compliments,
            title: "Thoughtful friend",
            message: "You're literally the most thoughtful person I know. Thanks for always being there 💙",
            context: "Heartfelt compliment about someone's character."
        ),
        PracticeScenario(
            id: "co-5",
            category: .compliments,
            title: "Inspiring",
            message: "I just wanted you to know you inspire me a lot. The way you handle everything is amazing.",
            context: "Someone expressing genuine admiration."
        ),
    ]
}
