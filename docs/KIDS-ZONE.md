# Kids Zone — Game Guide

Kids Zone is a browser-based collection of 10,000 family-friendly mini-games.

## Playing

1. Open [Kids Zone](https://huynhw19.github.io/kids-zone.html) and sign in.
2. Use the search field at the top to find games by title, series, or topic.
3. Choose **Play game** on a generated mini-game card.
4. Select an answer to see feedback, then choose **New round** to play again.

The first 20 games are hand-built interactive games. The remaining 9,980 are generated from reusable puzzle templates so the page can offer a large searchable collection without storing thousands of duplicate HTML blocks.

## Game families

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

The game catalog is generated client-side in `kids-zone.html`. The page creates 9,980 additional cards after the original 20 games, for a total of 10,000. To change the total, update the generation loop and the matching count labels together.

The Kids Zone uses the site's existing Supabase sign-in flow and does not introduce accounts, chat, public profiles, or purchases.
