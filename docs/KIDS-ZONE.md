# Kids Zone — Game and Storytelling Guide

Kids Zone is a browser-based collection of family-friendly games and creative activities for signed-in ConfigKit members.

## Games

1. Open [Kids Zone](https://huynhw19.github.io/kids-zone.html) and sign in.
2. Use the game search and age filter to find activities.
3. Choose **Play game** on a generated mini-game card.
4. Select an answer to see feedback, then choose **Next round**.

The page contains 10,000 games: 20 hand-built games and 9,980 generated games. Generated games are rendered in batches of 100 so mobile browsers do not need to create the entire catalogue at once. The first 5,000 generated games are two-player pass-and-play games. Players take turns on the same device; there is no online matchmaking, chat or cross-device multiplayer.

## Interactive Storytelling Studio

The Storytelling Studio adds three connected ways to create and explore:

- **5,000 interactive stories** with searchable titles, age bands, characters, settings, story challenges and branching choices.
- **Choose-your-own-adventure play** with decisions that lead to different scenes and hopeful endings. Children can restart a story or explore another adventure.
- **5,000 storytelling activities** with prompts for character creation, drawing story maps, kindness quests, magical objects, alternate viewpoints, short stories and more.

Stories and activities can be searched by keyword and filtered for ages 3–5, 6–8 and 9–10. Only a small batch of catalogue cards is rendered at a time. The story experience is generated locally in the browser and does not require a separate account, public profile, chat, upload or sharing feature.

Story writing is session-only: the Studio does not save children's free-text writing to a server. Children are reminded not to enter private information such as full names, addresses, school names or passwords. Parents and caregivers are encouraged to explore together and talk about kindness, feelings, safe choices and asking a trusted adult for help.

## Age groups and accessibility

- Age filters are available for 3–5, 6–8 and 9–10 across the storytelling catalogues.
- Search and result counts update as the user types or changes the age group.
- Interactive controls are native buttons and form fields and can be used with a keyboard.
- Story scenes and activity feedback use readable text and live status regions.
- The layout adapts to mobile and desktop screens and respects reduced-motion preferences.

## Social Interaction Studio

The Social Interaction Studio provides 168 short, age-banded pretend-play scenarios for ages 3–5, 6–8 and 9–10 (8 original scenarios plus 160 additional scenarios). Children can practise:
- Making friends and including others.
- Listening, sharing and taking turns.
- Recognising feelings and responding with empathy.
- Solving everyday disagreements with calm, fair choices.
- Keeping personal information private online and asking a trusted adult for help.

Children choose from suggested responses and receive supportive explanations. Scenarios run entirely in the browser: responses are not sent to Supabase, stored in a profile or shared with other users. The activities are learning prompts, not live chat or matchmaking. The existing Kids Messages service remains separate and is available only through the child profile's parent-approved friend connections.

## Family features

Kids Zone uses the site's existing Supabase sign-in flow. Existing family video playlists, child profiles and game progress behavior are unchanged. Generated storytelling content runs locally and does not add new database tables or collect children's story text.

## Development notes

The game catalogue is generated client-side in `kids-zone.html`. It contains 20 hand-built games plus 9,980 generated games, for 10,000 total. The first 5,000 generated entries support two-player pass-and-play. Game cards are rendered in batches of 100.

The storytelling catalogue is generated client-side from reusable, age-banded templates: 5,000 story records and 5,000 activity records. Story choices and endings are handled in the browser. Story and activity cards are rendered in small batches of 12. No external AI service or user-generated content endpoint is used.


## Family Dashboard storytelling progress

Parents can see a private per-child storytelling summary in the Family Dashboard: completed stories, completed creative activities, recently opened or completed items, age bands and favourites. Children can save a story as a favourite and mark a creative activity finished. The progress record stores catalogue item IDs, titles, age bands, completion state, favourite state and the selected ending—not children's free-text story writing. The `family_storytelling_progress` table is protected by row-level security: parents can read only their own children's records, and a child session can save progress only for its linked child profile. Apply `supabase/migrations/20261112143000_family_storytelling_progress.sql` before using cloud-saved storytelling progress.
