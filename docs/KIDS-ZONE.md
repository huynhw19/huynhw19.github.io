# Kids Zone — Game Guide

Kids Zone is a browser-based collection of 100,000 family-friendly mini-games.

## Playing

1. Open [Kids Zone](https://huynhw19.github.io/kids-zone.html) and sign in.
2. Use the search field at the top to find games by title, series, or topic.
3. Choose **Play game** on a generated mini-game card.
4. Select an answer to see feedback, then choose **New round** to play again.

The first 20 games are hand-built interactive games. The remaining 99,980 are generated from reusable puzzle templates. Only 100 generated cards are rendered at a time; use **Load more games** to browse in batches. This keeps the page responsive despite the large catalog.

## Multiplayer games\n\nThere are 5,000 two-player pass-and-play games in the generated catalog. Players take turns answering on the same device, and each game tracks Player 1 and Player 2 scores locally. These are not online matches: no player accounts, matchmaking, chat, or cross-device synchronization are provided.\n\n## Game families

Generated games rotate through these families:

- Number Quest — arithmetic practice
- Pattern Patrol — number patterns
- Word Wizard — word unscrambling
- Alphabet Ace — alphabet sequence questions
- Quick Science — basic science facts
- World Wonders — geography questions
- Logic Lab — shapes, numbers, and reasoning
- Animal Academy — animal facts
- Shape Shifter — geometry basics
- Memory Master — simple memory and reasoning questions

## Search and accessibility

- Search filters the game cards as you type and updates the visible game count.
- Game answers and feedback are presented in the page.
- Buttons are keyboard-focusable and game feedback uses live regions where appropriate.
- The layout adapts to desktop and mobile screens.

## Development notes

The game catalog is generated client-side in `kids-zone.html`. The catalog contains 99,980 generated entries plus the original 20 games, for 100,000 total. The first 5,000 generated entries are two-player pass-and-play games. Generated cards are rendered in batches of 100; search filters the catalog index before rendering matching cards.

The Kids Zone uses the site's existing Supabase sign-in flow and does not introduce accounts, chat, public profiles, or purchases.
