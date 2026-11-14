/// Draft legal pages. They describe what the app really does, so a lawyer
/// can check them rather than start from nothing. They are English only until
/// a reviewed Nepali version exists, and every page says it is a draft.
///
/// When any page changes in a way people must agree to, change
/// [termsVersion]: everyone agrees again at their next login.
library;

const termsVersion = '2026-11-13';

/// "{company}" is replaced with the registered company name, once an admin
/// enters it, and "the company operating Subidha360" until then.
class LegalSection {
  const LegalSection(this.heading, this.paragraphs);

  final String heading;
  final List<String> paragraphs;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.summary,
    required this.sections,
  });

  final String title;
  final String summary;
  final List<LegalSection> sections;
}

const terms = LegalDocument(
  title: 'Terms of use',
  summary:
      'The rules for customers and providers using Subidha360, and what we do '
      'when something goes wrong.',
  sections: [
    LegalSection('Who we are', [
      'Subidha360 is run by {company}. We connect people who need work done at '
          'home ("customers") with people who do it ("providers"). We are not '
          'the provider of the work itself: each job is an agreement between '
          'the customer and the provider, and we hold the payment until it is done.',
      'By logging in you agree to these terms and to our privacy policy. If you '
          'do not agree, do not use Subidha360.',
    ]),
    LegalSection('Your account', [
      'You log in with a code sent to your mobile number. Keep your phone and '
          'codes to yourself: you are responsible for what is done from your account.',
      'You must be at least 18 years old, and give your real name.',
      'Providers must describe their skills honestly. The Verified badge means our '
          'team checked a provider\'s citizenship card; it is not a guarantee of '
          'their work.',
    ]),
    LegalSection('Jobs, bids and prices', [
      'Customers describe a job and providers offer a price. Guide prices on the '
          'site are only typical ranges; the price is the one in the bid the '
          'customer accepts.',
      'A bid says whether parts are included. Extra work or parts not in the bid '
          'must be agreed in the app chat before they are done.',
    ]),
    LegalSection('Paying', [
      'When a customer accepts a bid, the full price moves from their wallet and '
          'is held by us. The provider is paid when both confirm the job is done, '
          'or 72 hours after one of them confirms, unless the other raises a dispute.',
      'Subidha360 keeps a platform fee of 10% of what the provider is paid. The '
          'customer pays the bid price and nothing more.',
      'All payments must go through the app. Asking for, or agreeing to, payment '
          'outside the app breaks these terms, loses the protection of our '
          'guarantee, and can lead to the account being suspended.',
    ]),
    LegalSection('Cancelling and disputes', [
      'How money is returned when a job is cancelled is set out in our refund policy.',
      'If a customer and provider disagree about a job, either can raise a '
          'dispute in the app before payment is released. Our team looks at the '
          'job details, the chat and anything both sides send, and decides how '
          'the held payment is split. We tell both sides the decision.',
    ]),
    LegalSection('Our 30-day guarantee', [
      'For 30 days after a job is completed, a customer can claim if the same '
          'problem comes back because of the work done. We arrange for it to be '
          'put right. Details are on the guarantee page.',
    ]),
    LegalSection('What you must not do', [
      'Do not harass, threaten or discriminate against anyone; give false '
          'information; post jobs or bids you do not mean; share someone else\'s '
          'personal details; or try to get around our fees.',
      'Our team may suspend an account that breaks these rules, or that people '
          'report for good reason. Waiting bids from a suspended account are '
          'withdrawn. You can ask us to review a suspension through Help.',
    ]),
    LegalSection('Safety', [
      'Chat messages are checked automatically for phone numbers and talk of '
          'paying outside the app, so our team can protect both sides. In an '
          'emergency, call the police on 100 first.',
    ]),
    LegalSection('Responsibility', [
      'Providers are responsible for the quality and safety of their work, and '
          'for any damage it causes. To the extent Nepal\'s law allows, our '
          'responsibility for a job is limited to the amount paid for it through '
          'Subidha360.',
      'Nothing in these terms takes away rights you have under the Consumer '
          'Protection Act, 2075.',
    ]),
    LegalSection('Changes and law', [
      'We may change these terms. If a change matters, we ask you to agree again '
          'when you next log in.',
      'These terms are governed by the laws of Nepal, and disputes go to the '
          'courts of Kathmandu.',
    ]),
  ],
);

const privacy = LegalDocument(
  title: 'Privacy policy',
  summary:
      'What we collect, why, who can see it, how long we keep it, and how to '
      'ask us to change or delete it.',
  sections: [
    LegalSection('Who is responsible', [
      '{company} decides how your information is used and is responsible for '
          'it under the Individual Privacy Act, 2075. Contact us through Help '
          'in the app.',
    ]),
    LegalSection('What we collect', [
      'Your mobile number and name, to log you in and show who is on a job.',
      'Job details: the problem, photos you add, the address and map pin, and '
          'the time you want. Providers who are only offered a job see an '
          'approximate area; the exact place is shown to the provider you choose.',
      'Chat messages between customer and provider, and messages to our team.',
      'For providers: services, work area, working hours, photos of past work, '
          'and, if you ask to be verified, photos of your citizenship card and '
          'certificates.',
      'While a provider has the job screen open on a booked job, their live '
          'location, so the customer can see them arrive. It is deleted when '
          'the job ends.',
      'Wallet payments and withdrawals, including bank or eWallet details you '
          'give for a withdrawal.',
      'Reviews, reports and guarantee claims.',
      'Which pages are visited, counted per day without cookies and without '
          'anything that identifies you.',
    ]),
    LegalSection('Why we use it', [
      'To run jobs from posting to payment; to keep payments safe and settle '
          'disputes; to prevent fraud and keep people safe; to answer you when '
          'you contact us; and to meet legal and tax duties.',
      'We do not sell your information, and we do not use it for advertising.',
    ]),
    LegalSection('Who can see it', [
      'The other person on your job sees your name, and what they need for the '
          'job. Providers never see a customer\'s phone number through the app.',
      'Our staff see what they need to support you, settle disputes and check '
          'safety. Citizenship cards are seen only by staff, never by customers.',
      'Services we use to run Subidha360: MongoDB Atlas (database), Upstash '
          '(temporary data), Sparrow SMS (login codes and urgent messages), '
          'Google Firebase (notifications) and OpenStreetMap (map tiles, which '
          'see the area of the map you view). They process information only to '
          'provide their service to us.',
      'The police or courts, when the law requires it.',
    ]),
    LegalSection('How long we keep it', [
      '[To confirm with a lawyer] Payment and wallet records are kept as long as '
          'tax law requires. Citizenship card photos are deleted when a provider '
          'replaces them, and [within 90 days] of an account being closed. Other '
          'account information is deleted [within 90 days] of you asking us to '
          'close your account, except what we must keep by law or to settle an '
          'open dispute.',
      'Backups are encrypted and replaced on a schedule, so deleted information '
          'leaves them within [35 days].',
    ]),
    LegalSection('Your rights', [
      'You can ask to see the information we hold about you, to correct it, or '
          'to delete your account. Write to us through Help. We answer within '
          '[15 days].',
    ]),
    LegalSection('Keeping it safe', [
      'Information travels encrypted. Access by our staff is limited and every '
          'admin action is recorded. If a breach puts your information at risk, '
          'we will tell you and the authorities as the law requires.',
    ]),
    LegalSection('Changes', [
      'If we change this policy in a way that matters, we ask you to agree again '
          'when you next log in.',
    ]),
  ],
);

const refunds = LegalDocument(
  title: 'Refund and cancellation policy',
  summary:
      'What happens to your money when a job is cancelled, disputed or not '
      'done properly.',
  sections: [
    LegalSection('Before a provider is chosen', [
      'Nothing has been paid, so you can cancel any time at no cost.',
    ]),
    LegalSection('After choosing a provider, before work starts', [
      'Either side can cancel. The full payment returns to the customer\'s wallet '
          'at once.',
    ]),
    LegalSection('After work has started', [
      'If the provider cancels, the full payment returns to the customer.',
      'If the customer cancels, the payment is held while our team looks at what '
          'was done. If we have not decided within 72 hours, it is split evenly '
          'between the provider and the customer.',
    ]),
    LegalSection('Disputes', [
      'If you are unhappy with the work, raise a dispute in the app before the '
          'payment is released. The payment stays on hold, with no time limit, '
          'until our team decides how to split it. A share paid to the provider '
          'has the platform fee taken from it; the rest returns to the customer.',
    ]),
    LegalSection('Guarantee claims', [
      'For 30 days after completion, if the same problem returns because of the '
          'work done, claim in the app and we arrange for it to be put right.',
    ]),
    LegalSection('Where refunds go', [
      'Refunds go to your Subidha360 wallet straight away, where you can use '
          'them for your next job. [To decide once eSewa and Khalti are connected: '
          'how customers withdraw wallet money, and how long it takes.]',
    ]),
  ],
);
