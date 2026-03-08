import Foundation

// MARK: - Reply Pack

struct ReplyPack: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let emoji: String
    let color: String          // Semantic color name for accent
    let scenarios: [ReplyScenario]

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ReplyPack, rhs: ReplyPack) -> Bool { lhs.id == rhs.id }
}

// MARK: - Reply Scenario

struct ReplyScenario: Identifiable, Hashable {
    let id: String
    let message: String        // The incoming message
    let context: String        // Brief context about the situation
    let seedReplies: [String]  // Pre-built replies (work without AI)

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ReplyScenario, rhs: ReplyScenario) -> Bool { lhs.id == rhs.id }
}

// MARK: - Seed Data

enum ReplyPacks {
    static let all: [ReplyPack] = [awkwardFixes, replyToBoss, teacherParent, busyReplies]

    // MARK: Awkward Message Fixes

    static let awkwardFixes = ReplyPack(
        id: "awkward-fixes",
        title: "Awkward Message Fixes",
        description: "Smooth saves for those uncomfortable texting moments",
        emoji: "😬",
        color: "orange",
        scenarios: [
            ReplyScenario(
                id: "af-1",
                message: "Sorry I just saw this",
                context: "You took way too long to reply and need a smooth recovery.",
                seedReplies: [
                    "Hey! So sorry for the late reply — things have been hectic. What's up?",
                    "Just saw this, my bad! Still relevant or did I miss the boat?",
                    "Ugh, sorry! My notifications have been buried. I'm here now though!",
                ]
            ),
            ReplyScenario(
                id: "af-2",
                message: "Just checking in",
                context: "Someone's following up because you haven't responded yet.",
                seedReplies: [
                    "Hey! Thanks for the nudge — I've been meaning to get back to you. Here's where I'm at…",
                    "Appreciate you checking in! I haven't forgotten, just been swamped.",
                    "Thanks for following up! Let me circle back on this today.",
                ]
            ),
            ReplyScenario(
                id: "af-3",
                message: "Following up",
                context: "A more formal follow-up that needs a professional response.",
                seedReplies: [
                    "Thanks for following up — I appreciate your patience. I'll have an update for you by end of day.",
                    "Got it, thanks for the reminder. Let me look into this and get back to you shortly.",
                    "Apologies for the delay! I'm on it and will circle back within the hour.",
                ]
            ),
            ReplyScenario(
                id: "af-4",
                message: "My bad, I forgot",
                context: "Someone admits they forgot something — you need to respond gracefully.",
                seedReplies: [
                    "No worries at all! Happens to the best of us. Whenever you get a chance is fine.",
                    "All good! Life gets busy. Just let me know when you're ready.",
                    "Ha, no stress! I forget things all the time too. We're good!",
                ]
            ),
            ReplyScenario(
                id: "af-5",
                message: "Did you get my last message?",
                context: "They're wondering if you're ignoring them.",
                seedReplies: [
                    "I did! Sorry, I meant to reply and got sidetracked. Let me get back to you now.",
                    "Yes! So sorry — it slipped through the cracks. Here's what I was thinking…",
                    "Oops, yes I saw it! My bad for not responding sooner.",
                ]
            ),
            ReplyScenario(
                id: "af-6",
                message: "That came out wrong, sorry",
                context: "Someone said something awkward and is trying to fix it.",
                seedReplies: [
                    "Ha, no worries! I knew what you meant. We're all good!",
                    "All good, I didn't take it the wrong way at all!",
                    "Totally fine! Texting tone is tricky. No offense taken.",
                ]
            ),
            ReplyScenario(
                id: "af-7",
                message: "Wrong person, ignore that lol",
                context: "They sent a message meant for someone else.",
                seedReplies: [
                    "Haha no worries, already forgotten!",
                    "Lol I was so confused for a second! No worries.",
                    "Ha! That explains a lot. Consider it erased from my memory.",
                ]
            ),
            ReplyScenario(
                id: "af-8",
                message: "I didn't mean to leave you on read",
                context: "They realized they left you on read and feel bad.",
                seedReplies: [
                    "No worries! I honestly didn't even notice. What's up?",
                    "All good! I know how it goes — phones are overwhelming sometimes.",
                    "Ha, I do that all the time too. No hard feelings!",
                ]
            ),
            ReplyScenario(
                id: "af-9",
                message: "Are you mad at me?",
                context: "Someone thinks you're upset due to slow or short replies.",
                seedReplies: [
                    "Not at all! Just been busy lately. We're totally good!",
                    "No way! Sorry if my texts gave that vibe — everything's fine between us.",
                    "Of course not! I've just been in my own head. Nothing to do with you!",
                ]
            ),
            ReplyScenario(
                id: "af-10",
                message: "Sorry for the double text",
                context: "They feel awkward about sending multiple messages.",
                seedReplies: [
                    "Ha, double text away! I don't mind at all.",
                    "No need to apologize! I actually appreciate the follow-up.",
                    "I'm a serial double-texter too, no judgment here!",
                ]
            ),
            ReplyScenario(
                id: "af-11",
                message: "I hope this isn't weird to ask…",
                context: "Someone's about to ask something they think might be awkward.",
                seedReplies: [
                    "Not weird at all! Go for it.",
                    "No such thing as a weird question — ask away!",
                    "Ha, you can ask me anything! What's on your mind?",
                ]
            ),
            ReplyScenario(
                id: "af-12",
                message: "Can we pretend I didn't say that?",
                context: "They regret something they just said.",
                seedReplies: [
                    "Haha, said what? Already forgotten!",
                    "Consider it erased! What were we talking about again?",
                    "Lol, your secret is safe with me. Moving on!",
                ]
            ),
            ReplyScenario(
                id: "af-13",
                message: "I accidentally liked your old photo",
                context: "The classic social media deep-scroll embarrassment.",
                seedReplies: [
                    "Haha, I'll take the like! No judgment here.",
                    "Lol, a classic deep-scroll moment. Happens to everyone!",
                    "Ha! I'm flattered you were going through my old posts.",
                ]
            ),
            ReplyScenario(
                id: "af-14",
                message: "Was that sarcastic? I can't tell over text",
                context: "Your tone didn't come through in the message.",
                seedReplies: [
                    "Ha, totally not sarcastic! I genuinely meant it. Text tone is the worst.",
                    "Nope, 100% sincere! I really need to start using more emojis.",
                    "Lol fair question — I was being genuine! Hard to tell over text sometimes.",
                ]
            ),
            ReplyScenario(
                id: "af-15",
                message: "I know this is last minute, but…",
                context: "Someone's asking a favor with very little notice.",
                seedReplies: [
                    "No worries, what do you need? I'll see what I can do!",
                    "Last-minute plans are sometimes the best ones — what's up?",
                    "Ha, I'm used to last-minute! Let me know what you need.",
                ]
            ),
            ReplyScenario(
                id: "af-16",
                message: "I feel like I'm bothering you",
                context: "Someone thinks they're being a nuisance.",
                seedReplies: [
                    "You're not bothering me at all! I enjoy hearing from you.",
                    "Never! I'm just slow at replying sometimes. You're always welcome to reach out.",
                    "Not even a little bit! I'd tell you if you were, promise.",
                ]
            ),
            ReplyScenario(
                id: "af-17",
                message: "K",
                context: "Someone sent the dreaded single-letter reply.",
                seedReplies: [
                    "Cool, sounds good!",
                    "Great, let me know if anything changes!",
                    "Perfect, thanks!",
                ]
            ),
            ReplyScenario(
                id: "af-18",
                message: "We need to talk",
                context: "The most anxiety-inducing text ever sent.",
                seedReplies: [
                    "Sure, what's on your mind? Everything okay?",
                    "Of course — want to call or is texting fine?",
                    "Sounds serious! I'm all ears whenever you're ready.",
                ]
            ),
            ReplyScenario(
                id: "af-19",
                message: "No offense, but…",
                context: "Someone's about to say something potentially offensive.",
                seedReplies: [
                    "Go ahead, I can handle it! What's up?",
                    "Ha, that opener always makes me nervous, but sure — lay it on me.",
                    "I appreciate the honesty! What were you going to say?",
                ]
            ),
            ReplyScenario(
                id: "af-20",
                message: "Haha",
                context: "A dry reply that's hard to continue the conversation from.",
                seedReplies: [
                    "Right?! Anyway, what have you been up to lately?",
                    "Glad that got a laugh! So what's new with you?",
                    "Lol, so anyway — any fun plans this weekend?",
                ]
            ),
        ]
    )

    // MARK: Reply to Boss

    static let replyToBoss = ReplyPack(
        id: "reply-to-boss",
        title: "Reply to Boss",
        description: "Professional replies for when your manager messages you",
        emoji: "👔",
        color: "teal",
        scenarios: [
            ReplyScenario(
                id: "rb-1",
                message: "Can you send the report tonight?",
                context: "Your boss needs something after hours.",
                seedReplies: [
                    "Absolutely, I'll have it in your inbox by end of day.",
                    "Sure thing! I'll wrap it up and send it over this evening.",
                    "On it — I'll make sure it's ready before tonight.",
                ]
            ),
            ReplyScenario(
                id: "rb-2",
                message: "Can we jump on a call?",
                context: "Your boss wants to talk — could be anything.",
                seedReplies: [
                    "Of course! I'm free now, or would later work better for you?",
                    "Sure! I can hop on in about 10 minutes if that works.",
                    "Absolutely — want me to send a calendar invite?",
                ]
            ),
            ReplyScenario(
                id: "rb-3",
                message: "Please fix this",
                context: "Direct feedback on something that needs to be corrected.",
                seedReplies: [
                    "On it — I'll get this corrected and send the updated version shortly.",
                    "Thanks for catching that. I'll fix it right away and let you know when it's done.",
                    "Understood, I'll take care of it. Should have the fix ready within the hour.",
                ]
            ),
            ReplyScenario(
                id: "rb-4",
                message: "Did you complete the task?",
                context: "Your boss is checking on your progress.",
                seedReplies: [
                    "Yes, all done! I'll send it over now for your review.",
                    "Almost there — I'm putting the finishing touches on it. Should be ready within the hour.",
                    "I'm about 80% done. I'll have it completed and sent over by end of day.",
                ]
            ),
            ReplyScenario(
                id: "rb-5",
                message: "Good job on the presentation",
                context: "Your boss is giving you positive feedback.",
                seedReplies: [
                    "Thank you so much! I really appreciate the feedback. It was a great team effort.",
                    "Thanks! I'm glad it landed well. Happy to do more of these.",
                    "That means a lot, thank you! I spent extra time on the data section — glad it paid off.",
                ]
            ),
            ReplyScenario(
                id: "rb-6",
                message: "I need this ASAP",
                context: "Urgent request from your boss with no clear deadline.",
                seedReplies: [
                    "Understood — I'll prioritize this and get it to you as soon as possible.",
                    "On it right now. I'll send it over within the next 30 minutes.",
                    "Got it, making this my top priority. I'll keep you posted on progress.",
                ]
            ),
            ReplyScenario(
                id: "rb-7",
                message: "Can you stay late today?",
                context: "Your boss is asking you to work overtime.",
                seedReplies: [
                    "Sure, I can stay a bit later. What do you need me to focus on?",
                    "I can manage that today. What's the priority?",
                    "I have a commitment at 7, but I can stay until then. Will that work?",
                ]
            ),
            ReplyScenario(
                id: "rb-8",
                message: "Let's discuss this in our 1:1",
                context: "Your boss is deferring a conversation to your next meeting.",
                seedReplies: [
                    "Sounds good! I'll add it to our 1:1 agenda.",
                    "Perfect, I'll come prepared with some thoughts on this.",
                    "Great — I'll jot down some notes ahead of time so we can make the most of it.",
                ]
            ),
            ReplyScenario(
                id: "rb-9",
                message: "Why wasn't I looped in on this?",
                context: "Your boss feels left out of a decision or communication.",
                seedReplies: [
                    "That's my oversight — I should have kept you in the loop. I'll make sure to include you going forward.",
                    "Apologies for missing that. I'll send you a quick summary now and CC you on all future updates.",
                    "You're right, I should have flagged this earlier. Let me bring you up to speed right now.",
                ]
            ),
            ReplyScenario(
                id: "rb-10",
                message: "Can you take the lead on this project?",
                context: "Your boss is giving you more responsibility.",
                seedReplies: [
                    "I'd love to! Let me review the scope and come back with a plan by tomorrow.",
                    "Absolutely — I'll put together a timeline and share it with the team.",
                    "Happy to take this on. I'll set up a kickoff meeting to get things rolling.",
                ]
            ),
            ReplyScenario(
                id: "rb-11",
                message: "This isn't what I asked for",
                context: "Your deliverable missed the mark.",
                seedReplies: [
                    "I apologize for the misunderstanding. Can you clarify what you're looking for so I can revise it?",
                    "Sorry about that — let me revisit the requirements and get a corrected version to you today.",
                    "My apologies. I want to make sure I get this right — would a quick call help align on expectations?",
                ]
            ),
            ReplyScenario(
                id: "rb-12",
                message: "Are you available this weekend?",
                context: "Your boss is hinting at weekend work.",
                seedReplies: [
                    "I can be available for a bit on Saturday morning if needed. What's the situation?",
                    "I have some plans but can carve out a few hours. What do you need?",
                    "I can make myself available — is it something urgent?",
                ]
            ),
            ReplyScenario(
                id: "rb-13",
                message: "We need to talk about your performance",
                context: "A serious conversation about your work quality.",
                seedReplies: [
                    "I appreciate you bringing this up. I'm open to feedback — when works best for you?",
                    "Understood. I'd like to discuss this too and hear your perspective. When can we meet?",
                    "Of course. I want to make sure I'm meeting expectations — happy to discuss anytime.",
                ]
            ),
            ReplyScenario(
                id: "rb-14",
                message: "Can you cover for Sarah while she's out?",
                context: "Being asked to take on extra responsibilities temporarily.",
                seedReplies: [
                    "Of course! Can you share her priority list so I know what to focus on?",
                    "Happy to help. I'll connect with Sarah before she leaves to get up to speed.",
                    "Sure thing. I'll review her current tasks and make sure nothing falls through the cracks.",
                ]
            ),
            ReplyScenario(
                id: "rb-15",
                message: "I saw your email, let's chat",
                context: "Your boss wants to discuss something you sent.",
                seedReplies: [
                    "Sure! I'm free now if that works, or I can slot in whenever is convenient.",
                    "Sounds good — I'm available for the next hour. Want me to swing by your office?",
                    "Great, happy to discuss. Want to do a quick call or in person?",
                ]
            ),
            ReplyScenario(
                id: "rb-16",
                message: "Make sure the client is happy",
                context: "A directive to prioritize client satisfaction.",
                seedReplies: [
                    "Understood — I'll reach out to them today to check in and address any concerns.",
                    "On it. I'll schedule a call with them to make sure we're aligned on expectations.",
                    "Will do. I'll send them an update and make sure they feel taken care of.",
                ]
            ),
            ReplyScenario(
                id: "rb-17",
                message: "I'm forwarding you an email, handle it",
                context: "Your boss is delegating something directly to you.",
                seedReplies: [
                    "Got it — I'll review and take care of it today.",
                    "Received! I'll handle it and keep you posted on the outcome.",
                    "On it. I'll reply to them and CC you so you're in the loop.",
                ]
            ),
            ReplyScenario(
                id: "rb-18",
                message: "Great work this quarter",
                context: "End-of-quarter recognition from your boss.",
                seedReplies: [
                    "Thank you! It's been a rewarding quarter. I'm excited about what's next.",
                    "I really appreciate that! Couldn't have done it without the team's support.",
                    "Thanks so much — that means a lot coming from you. Looking forward to an even stronger next quarter.",
                ]
            ),
            ReplyScenario(
                id: "rb-19",
                message: "Can you mentor the new hire?",
                context: "Your boss trusts you to guide someone new.",
                seedReplies: [
                    "I'd be happy to! I'll set up some time with them this week to get started.",
                    "Absolutely — I remember how much it helped when I had a mentor starting out.",
                    "Sure thing. I'll put together an onboarding checklist for them.",
                ]
            ),
            ReplyScenario(
                id: "rb-20",
                message: "The deadline moved up",
                context: "Bad news — less time than expected.",
                seedReplies: [
                    "Understood. I'll reprioritize and do my best to meet the new timeline. What's the new deadline?",
                    "Got it — I'll adjust my schedule accordingly. Can we cut scope anywhere to make this work?",
                    "Noted. I'll put together a revised plan and flag any risks by end of day.",
                ]
            ),
        ]
    )

    // MARK: Teacher / Parent Replies

    static let teacherParent = ReplyPack(
        id: "teacher-parent",
        title: "Teacher / Parent Replies",
        description: "Thoughtful responses to school-related messages",
        emoji: "📚",
        color: "green",
        scenarios: [
            ReplyScenario(
                id: "tp-1",
                message: "Your child forgot their homework",
                context: "A teacher notifying you about missing homework.",
                seedReplies: [
                    "Thank you for letting me know. I'll make sure they complete it tonight and bring it in tomorrow.",
                    "I appreciate the heads-up! We'll work on it at home and have it ready for the next class.",
                    "Oh no, sorry about that! I'll follow up with them and make sure it doesn't happen again.",
                ]
            ),
            ReplyScenario(
                id: "tp-2",
                message: "Please sign the form",
                context: "A reminder to sign a permission slip or school form.",
                seedReplies: [
                    "Will do — I'll sign it tonight and send it back with them tomorrow.",
                    "Thanks for the reminder! I'll get it signed and returned first thing in the morning.",
                    "Got it! Consider it done. Is there anything else I need to look at?",
                ]
            ),
            ReplyScenario(
                id: "tp-3",
                message: "Reminder about tomorrow's event",
                context: "A school event reminder from a teacher or PTA.",
                seedReplies: [
                    "Thank you for the reminder! We'll be there. Is there anything we should bring?",
                    "Got it, thanks! Looking forward to it. What time should we arrive?",
                    "Appreciate the reminder — it's on our calendar! See you tomorrow.",
                ]
            ),
            ReplyScenario(
                id: "tp-4",
                message: "Your child did great on the test!",
                context: "Positive feedback from a teacher.",
                seedReplies: [
                    "That's wonderful to hear! Thank you for letting us know — we're so proud!",
                    "Amazing! Thanks for sharing the good news. They've been working really hard.",
                    "That makes my day! Thank you for the encouragement — it means a lot to them.",
                ]
            ),
            ReplyScenario(
                id: "tp-5",
                message: "Can we schedule a parent-teacher conference?",
                context: "A teacher wants to meet with you about your child.",
                seedReplies: [
                    "Of course! I'm available Tuesday or Thursday after 3pm. Would either of those work?",
                    "Absolutely — I'd love to connect. What times are available this week?",
                    "Happy to! Can we do it over Zoom, or would you prefer in person?",
                ]
            ),
            ReplyScenario(
                id: "tp-6",
                message: "Your child has been having trouble focusing in class",
                context: "A teacher raising a concern about behavior or attention.",
                seedReplies: [
                    "Thank you for bringing this to my attention. We'll talk to them at home and work on strategies together.",
                    "I appreciate you reaching out. Has this been recent, or an ongoing pattern? I'd love to help.",
                    "Thanks for the heads-up. Could we schedule a call to discuss what might help?",
                ]
            ),
            ReplyScenario(
                id: "tp-7",
                message: "Picture day is next Friday",
                context: "A reminder about upcoming school picture day.",
                seedReplies: [
                    "Thanks for the heads-up! We'll make sure they're ready.",
                    "Noted — we'll have them looking their best! Do we order online?",
                    "Great, thanks for the reminder! Is there a dress code or theme?",
                ]
            ),
            ReplyScenario(
                id: "tp-8",
                message: "We're looking for parent volunteers",
                context: "The school needs help with an event or activity.",
                seedReplies: [
                    "I'd love to help! What days and times are you looking for?",
                    "Count me in! Just let me know the details and I'll make it work.",
                    "I might be able to volunteer depending on the schedule — can you share more info?",
                ]
            ),
            ReplyScenario(
                id: "tp-9",
                message: "Your child was involved in a minor incident today",
                context: "The school is reporting a behavioral issue.",
                seedReplies: [
                    "Thank you for letting me know. Can you share more details so I can address it at home?",
                    "I appreciate the call. I'll talk to them tonight and we'll work on this together.",
                    "Thanks for reaching out. I take this seriously — what happened and how can we help?",
                ]
            ),
            ReplyScenario(
                id: "tp-10",
                message: "Book fair starts next week!",
                context: "Announcement about an upcoming school book fair.",
                seedReplies: [
                    "Exciting! We'll make sure they have some money to pick out a few books.",
                    "They're going to be thrilled! Thanks for the heads-up.",
                    "Love it! Is there a wish list option for families who can't attend in person?",
                ]
            ),
            ReplyScenario(
                id: "tp-11",
                message: "School is closed tomorrow due to weather",
                context: "Weather-related school closure announcement.",
                seedReplies: [
                    "Thanks for the early notice! Will there be remote learning, or is it a full day off?",
                    "Got it — we'll plan accordingly. Stay safe everyone!",
                    "Noted, thank you! Will missed work need to be made up?",
                ]
            ),
            ReplyScenario(
                id: "tp-12",
                message: "Your child needs new supplies",
                context: "Teacher requesting additional school supplies.",
                seedReplies: [
                    "Thanks for letting me know! I'll pick them up this weekend. Can you send the list?",
                    "Got it — I'll make sure they have everything by next week.",
                    "No problem! Is there a specific brand or type you recommend?",
                ]
            ),
            ReplyScenario(
                id: "tp-13",
                message: "Report cards go home Friday",
                context: "Notification about upcoming report cards.",
                seedReplies: [
                    "Thanks for the heads-up! We'll review it together over the weekend.",
                    "Good to know — looking forward to seeing how they're doing!",
                    "Great, thanks! Should we schedule a follow-up if we have questions?",
                ]
            ),
            ReplyScenario(
                id: "tp-14",
                message: "Field trip permission slip is due",
                context: "A deadline reminder for a field trip form.",
                seedReplies: [
                    "Sending it in tomorrow — thanks for the reminder!",
                    "Done! I'll put it in their backpack tonight. Do they need a packed lunch?",
                    "Got it, signing it now. Is parent chaperoning still available?",
                ]
            ),
            ReplyScenario(
                id: "tp-15",
                message: "Your child has been a wonderful helper in class",
                context: "Positive note about your child being helpful.",
                seedReplies: [
                    "That's so sweet to hear! We'll make sure to tell them how proud we are.",
                    "Aww, thank you! That really makes our day. They love your class!",
                    "What a lovely message — thank you for taking the time to share that!",
                ]
            ),
            ReplyScenario(
                id: "tp-16",
                message: "Please send lunch money for the cafeteria",
                context: "Reminder about cafeteria balance or lunch payment.",
                seedReplies: [
                    "Will do — I'll add funds to their account today. Thanks!",
                    "Thanks for the reminder! Can I pay online, or does it need to be cash?",
                    "On it! I'll send it with them tomorrow morning.",
                ]
            ),
            ReplyScenario(
                id: "tp-17",
                message: "End-of-year party planning has started",
                context: "Invitation to help plan a class celebration.",
                seedReplies: [
                    "How exciting! I'd love to help. What's still needed?",
                    "Count us in! We can bring snacks or decorations — whatever helps!",
                    "Fun! I can help coordinate. Is there a sign-up sheet?",
                ]
            ),
            ReplyScenario(
                id: "tp-18",
                message: "Your child's reading level has improved!",
                context: "Great news about academic progress.",
                seedReplies: [
                    "That's fantastic news! We've been reading together at home every night.",
                    "So proud of them! Thanks for the encouragement — it makes a real difference.",
                    "Wonderful! Thank you for all the work you do in class. It clearly pays off!",
                ]
            ),
            ReplyScenario(
                id: "tp-19",
                message: "Please update your emergency contact info",
                context: "Administrative request from the school.",
                seedReplies: [
                    "Thanks for the reminder — I'll update it on the portal tonight.",
                    "Will do! Is there a form to fill out, or can I update it online?",
                    "Got it, I'll take care of that today. Thanks!",
                ]
            ),
            ReplyScenario(
                id: "tp-20",
                message: "Your child seems tired in class lately",
                context: "A teacher expressing concern about energy levels.",
                seedReplies: [
                    "Thank you for noticing — we'll adjust their bedtime routine and see if that helps.",
                    "I appreciate the concern. They've had some late nights recently but we're getting back on track.",
                    "Good to know, thanks. We'll make sure they're getting enough rest. Any other concerns?",
                ]
            ),
        ]
    )

    // MARK: Busy Replies

    static let busyReplies = ReplyPack(
        id: "busy-replies",
        title: "Busy Replies",
        description: "Quick responses when you're too busy to chat",
        emoji: "🏃",
        color: "red",
        scenarios: [
            ReplyScenario(
                id: "br-1",
                message: "Can't talk right now",
                context: "You need to let someone know you're unavailable.",
                seedReplies: [
                    "Hey! Super tied up at the moment — can I get back to you later today?",
                    "In the middle of something right now! I'll text you when I'm free.",
                    "Can't chat right now but I'll reach out as soon as I can!",
                ]
            ),
            ReplyScenario(
                id: "br-2",
                message: "I'll get back to you later",
                context: "You want to defer a conversation without being rude.",
                seedReplies: [
                    "No rush! Take your time and get back to me whenever.",
                    "Sounds good — just ping me when you're free!",
                    "All good! I'll be around whenever you have a minute.",
                ]
            ),
            ReplyScenario(
                id: "br-3",
                message: "Running late",
                context: "You need to tell someone you're behind schedule.",
                seedReplies: [
                    "Running about 10 minutes behind — so sorry! Be there soon.",
                    "Stuck in traffic, be there ASAP! Go ahead and start without me.",
                    "On my way, just running a bit late. Thanks for your patience!",
                ]
            ),
            ReplyScenario(
                id: "br-4",
                message: "Hey, got a minute?",
                context: "Someone wants your attention when you're busy.",
                seedReplies: [
                    "Not right this second — can I circle back in about an hour?",
                    "In a meeting right now, but I'm free after 3. Can it wait?",
                    "Super slammed at the moment — can you text me the details and I'll look when I'm free?",
                ]
            ),
            ReplyScenario(
                id: "br-5",
                message: "Can you call me?",
                context: "Someone wants a phone call when you can't take one.",
                seedReplies: [
                    "Can't hop on a call right now — is texting okay? I'll call you later tonight.",
                    "Not a great time for a call — is everything okay? I can text for now.",
                    "I'll call you in about an hour when I'm free. Is it urgent?",
                ]
            ),
            ReplyScenario(
                id: "br-6",
                message: "Are you free tonight?",
                context: "An invite when you already have plans or need to rest.",
                seedReplies: [
                    "I wish! I'm swamped tonight but let's plan something this weekend?",
                    "Not tonight unfortunately — rain check? I'm free Thursday!",
                    "I'm pretty wiped today. Can we do tomorrow instead?",
                ]
            ),
            ReplyScenario(
                id: "br-7",
                message: "Can you help me with something?",
                context: "A favor request when you're stretched thin.",
                seedReplies: [
                    "I'd love to but I'm totally slammed right now. Can it wait until tomorrow?",
                    "What do you need? I might be able to squeeze it in if it's quick!",
                    "I'm a bit maxed out today — but send me the details and I'll try to help when I can.",
                ]
            ),
            ReplyScenario(
                id: "br-8",
                message: "Did you see my email?",
                context: "Follow-up when you haven't had time to check email.",
                seedReplies: [
                    "Not yet — I've been in back-to-back meetings. I'll check it in the next hour!",
                    "I saw it come in but haven't had a chance to read it yet. I'll get to it today!",
                    "Just got to it! Let me review and I'll get back to you shortly.",
                ]
            ),
            ReplyScenario(
                id: "br-9",
                message: "When are you available?",
                context: "Someone trying to schedule time with you.",
                seedReplies: [
                    "I'm pretty booked today but I have a window tomorrow between 2-4pm.",
                    "Things are tight this week — how does early next week look for you?",
                    "I can do a quick 15 minutes at noon, or we can find a longer slot later this week.",
                ]
            ),
            ReplyScenario(
                id: "br-10",
                message: "Sorry to bother you",
                context: "Someone feels bad about reaching out to you.",
                seedReplies: [
                    "You're never a bother! I'm just a bit tied up — I'll get back to you soon.",
                    "No bother at all! Just busy at the moment but I'll respond properly later.",
                    "Don't apologize! I want to give you a proper response — let me circle back shortly.",
                ]
            ),
            ReplyScenario(
                id: "br-11",
                message: "Can you do me a quick favor?",
                context: "A request that probably isn't that quick.",
                seedReplies: [
                    "Depends on how quick! What do you need?",
                    "I'll try! Shoot me the details and I'll let you know.",
                    "If it's truly quick, sure! What's up?",
                ]
            ),
            ReplyScenario(
                id: "br-12",
                message: "I need your opinion on something",
                context: "Someone wants input but you don't have bandwidth.",
                seedReplies: [
                    "Send it over and I'll take a look when I get a break!",
                    "I'd love to weigh in — just give me until tonight to give it proper thought.",
                    "Fire away! I might be slow to respond but I'll definitely get back to you.",
                ]
            ),
            ReplyScenario(
                id: "br-13",
                message: "Long time no talk! What have you been up to?",
                context: "An old friend reaching out when you're busy.",
                seedReplies: [
                    "So good to hear from you! I've been crazy busy but would love to catch up — free this weekend?",
                    "I know, it's been way too long! Life has been hectic. Let's plan a call soon!",
                    "Hey!! I've missed talking to you. Things are nuts right now but let's definitely connect soon.",
                ]
            ),
            ReplyScenario(
                id: "br-14",
                message: "Can you review this document?",
                context: "A work request when you're overloaded.",
                seedReplies: [
                    "I can get to it by end of day tomorrow — does that timeline work?",
                    "Sure! I'm a bit backed up but I'll prioritize it. When do you need feedback by?",
                    "Send it over! I'll review it as soon as I clear my current tasks.",
                ]
            ),
            ReplyScenario(
                id: "br-15",
                message: "Hey! Miss you! We should hang out soon!",
                context: "A friend wanting to reconnect when you're overwhelmed.",
                seedReplies: [
                    "Miss you too!! Let me get through this crazy week and I'll reach out to plan something!",
                    "Yes, absolutely! Things are wild right now but I'm free next weekend if you are!",
                    "Ugh I know, I've been MIA! Let's lock in a date — what works for you?",
                ]
            ),
            ReplyScenario(
                id: "br-16",
                message: "Wanna grab lunch?",
                context: "A lunch invite when you're too busy to step away.",
                seedReplies: [
                    "I wish! Eating at my desk today. Rain check for later this week?",
                    "Can't today — slammed with deadlines. Tomorrow work?",
                    "I'd love to but I'm stuck in meetings. Save me a spot next time!",
                ]
            ),
            ReplyScenario(
                id: "br-17",
                message: "Can I call you real quick?",
                context: "Someone wants to call when you're in the zone.",
                seedReplies: [
                    "Give me 20 minutes and I'll call you back?",
                    "I'm in the middle of something — can you text me what it's about?",
                    "Not the best time for a call but I can text! What's up?",
                ]
            ),
            ReplyScenario(
                id: "br-18",
                message: "Any updates on that thing?",
                context: "Someone following up on something you haven't gotten to.",
                seedReplies: [
                    "Still working on it! I'll have an update for you by tomorrow.",
                    "Not yet — it's on my list for today. I'll ping you when I have something.",
                    "Getting to it! Just been putting out fires. I'll circle back soon.",
                ]
            ),
            ReplyScenario(
                id: "br-19",
                message: "You've been so MIA lately!",
                context: "Someone calling you out for being hard to reach.",
                seedReplies: [
                    "I know, I'm the worst! Things have been insane but I'm still here!",
                    "Guilty! Life has been crazy but I promise I'm not disappearing on you.",
                    "I know, I'm sorry! Let me make it up to you — coffee this weekend?",
                ]
            ),
            ReplyScenario(
                id: "br-20",
                message: "Can we reschedule?",
                context: "Someone asking to move plans you didn't have time for anyway.",
                seedReplies: [
                    "Honestly, that works better for me too! When are you thinking?",
                    "No problem at all! Let's find another time that works for both of us.",
                    "Totally fine! I was actually a bit stretched this week anyway. What day works?",
                ]
            ),
        ]
    )
}
