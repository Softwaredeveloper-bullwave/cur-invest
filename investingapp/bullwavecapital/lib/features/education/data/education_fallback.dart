import '../../../models/investment_doc_model.dart';

/// Bundled crypto/forex quizzes so Academy works before seed_education is on the server.
class EducationFallback {
  EducationFallback._();

  static const quizCategories = [
    InvestmentDocCategory(
      id: 'crypto-quizzes',
      title: 'Quizzes',
      subtitle: 'Test your knowledge',
      iconName: 'quiz',
      accentHex: '#14B8A6',
      quizzes: [
        InvestmentDocQuiz(
          id: 'quiz-crypto-beginner',
          categoryId: 'crypto-quizzes',
          title: 'Crypto beginner quiz',
          description: '5 questions on coins, wallets, and safe habits.',
          questions: [
            InvestmentQuizQuestion(
              prompt: 'Bitcoin is best described as…',
              options: [
                'An NSE-listed stock',
                'A digital asset on a public blockchain',
                'A mutual fund NAV',
                'A bank FD',
              ],
              correctIndex: 1,
              explanation: 'BTC is a cryptocurrency recorded on its blockchain.',
            ),
            InvestmentQuizQuestion(
              prompt: 'Losing a self-custody seed phrase typically means…',
              options: [
                'The exchange will reset it',
                'Permanent loss of those coins',
                'SEBI will recover funds',
                'Nothing — coins stay in demat',
              ],
              correctIndex: 1,
              explanation: 'Self-custody has no broker recovery for lost keys.',
            ),
            InvestmentQuizQuestion(
              prompt: 'BullWave Crypto trades in this app are…',
              options: [
                'Live on-chain withdrawals',
                'Paper / simulated orders',
                'MCX futures',
                'IPO applications',
              ],
              correctIndex: 1,
              explanation:
                  'The crypto book is paper trading unless live trading is explicitly enabled.',
            ),
            InvestmentQuizQuestion(
              prompt: 'A limit order lets you…',
              options: [
                'Buy at any price instantly',
                'Set your price and wait for a match',
                'Avoid all volatility',
                'Guarantee profit',
              ],
              correctIndex: 1,
              explanation: 'Limit orders execute at your price or better.',
            ),
            InvestmentQuizQuestion(
              prompt: 'Best first step for a new crypto learner?',
              options: [
                'Max leverage on an unknown alt',
                'Learn basics and start small on BTC/ETH',
                'Share your seed in a group chat',
                'All savings in one meme coin',
              ],
              correctIndex: 1,
              explanation: 'Education and small size reduce early mistakes.',
            ),
          ],
        ),
        InvestmentDocQuiz(
          id: 'quiz-crypto-risk',
          categoryId: 'crypto-quizzes',
          title: 'Crypto risk quiz',
          description: 'Position size, custody, and preservation.',
          questions: [
            InvestmentQuizQuestion(
              prompt: 'Risking 2% per trade refers to…',
              options: [
                '2% of the coin’s price',
                '2% of total trading capital at stop distance',
                'Buying 2 coins',
                'Doubling leverage',
              ],
              correctIndex: 1,
              explanation: 'Sizing ties risk to total capital.',
            ),
            InvestmentQuizQuestion(
              prompt: 'A stop-loss should be set…',
              options: [
                'After a dump emotionally',
                'Before entering',
                'Only on weekends',
                'Never',
              ],
              correctIndex: 1,
              explanation: 'Plan exits before entries.',
            ),
            InvestmentQuizQuestion(
              prompt: 'You should store a seed phrase…',
              options: [
                'In screenshots and WhatsApp',
                'Offline, never shared',
                'In the coin’s Twitter bio',
                'With your broker RM only',
              ],
              correctIndex: 1,
              explanation: 'Seeds must stay private and offline.',
            ),
          ],
        ),
      ],
    ),
    InvestmentDocCategory(
      id: 'forex-quizzes',
      title: 'Quizzes',
      subtitle: 'Test your knowledge',
      iconName: 'quiz',
      accentHex: '#14B8A6',
      quizzes: [
        InvestmentDocQuiz(
          id: 'quiz-forex-beginner',
          categoryId: 'forex-quizzes',
          title: 'Forex beginner quiz',
          description: '5 questions on pairs, pips, and safe habits.',
          questions: [
            InvestmentQuizQuestion(
              prompt: 'EUR/USD quotes…',
              options: [
                'How many euros one dollar buys only on NSE',
                'The euro versus the US dollar',
                'Gold in rupees',
                'Bitcoin versus ether',
              ],
              correctIndex: 1,
              explanation: 'It is the euro priced in US dollars.',
            ),
            InvestmentQuizQuestion(
              prompt: 'A pip is…',
              options: [
                'A brokerage plan',
                'A standard price increment on a pair',
                'A demat holding',
                'An IPO lot',
              ],
              correctIndex: 1,
              explanation: 'Pips measure small FX price changes.',
            ),
            InvestmentQuizQuestion(
              prompt: 'BullWave Forex trades in this app are…',
              options: [
                'Live bank FX conversions',
                'Paper / simulated orders',
                'MCX crude futures',
                'Mutual fund SIPs',
              ],
              correctIndex: 1,
              explanation: 'Forex here is paper trading.',
            ),
            InvestmentQuizQuestion(
              prompt: 'A limit order lets you…',
              options: [
                'Fill at any price instantly',
                'Set your price and wait for a match',
                'Remove overnight risk',
                'Guarantee profit',
              ],
              correctIndex: 1,
              explanation: 'Limit orders execute at your price or better.',
            ),
            InvestmentQuizQuestion(
              prompt: 'Best first step for a new FX learner?',
              options: [
                'Max leverage on an exotic pair',
                'Learn majors and start small',
                'Trade only during RBI holidays',
                'All capital in one cross',
              ],
              correctIndex: 1,
              explanation: 'Education and small size reduce early mistakes.',
            ),
          ],
        ),
        InvestmentDocQuiz(
          id: 'quiz-forex-risk',
          categoryId: 'forex-quizzes',
          title: 'Forex risk quiz',
          description: 'Position size, leverage, and preservation.',
          questions: [
            InvestmentQuizQuestion(
              prompt: 'Risking 2% per trade refers to…',
              options: [
                '2% of the pair’s price',
                '2% of total trading capital at stop distance',
                'Buying 2 lots always',
                'Doubling leverage',
              ],
              correctIndex: 1,
              explanation: 'Sizing ties risk to total capital.',
            ),
            InvestmentQuizQuestion(
              prompt: 'A stop-loss should be set…',
              options: [
                'After a loss emotionally',
                'Before entering',
                'Only in Tokyo session',
                'Never',
              ],
              correctIndex: 1,
              explanation: 'Plan exits before entries.',
            ),
            InvestmentQuizQuestion(
              prompt: 'High leverage mainly…',
              options: [
                'Removes spread',
                'Magnifies both gains and losses',
                'Guarantees bank-like returns',
                'Is required for majors',
              ],
              correctIndex: 1,
              explanation: 'Leverage scales P&L in both directions.',
            ),
          ],
        ),
      ],
    ),
  ];
}
