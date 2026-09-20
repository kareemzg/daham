# PROJECT BRIEF

Design the main screens, art direction, pattern library and hero character for an Arabic word-puzzle game.
Working title, placeholder only, not decided: «رحلة الشاوي».

Core loop: a wheel of letters sits at the bottom of the screen. The player drags through letters to spell words that fill a crossword grid above. Every letter on the wheel belongs to at least one grid word. Extra valid words that are not in the grid are "bonus words".

Platforms: iOS and Android in portrait, and desktop for Steam in landscape.
Audience: Arabic speakers aged 10 and up, played by families. Tone: playful, warm and illustrated, but this is NOT a children's app. Think a cozy puzzle game with a hand-made feel.
Everything is right-to-left and in Arabic.

# PREMISE

The hero is «الشاوي» (Alshawi), a young manuscript restorer from Deir ez-Zor, Syria, a city on the Euphrates. He leaves home to restore lost pages in the great libraries of the Arab world: بيت الحكمة in Baghdad, القرويين in Fez, Cordoba, Timbuktu and Cairo. He returns home between chapters. Deir ez-Zor is both the home hub and the first chapter.

The city's identity must be present on every screen, not only on the hub:
- The Euphrates river (نهر الفرات), wide, blue-green, with reeds at the banks.
- The suspension bridge (الجسر المعلق): a pedestrian bridge with two tall steel lattice towers and hanging cables. In this game the bridge is being rebuilt by the player's progress (see THE BRIDGE below). It is shown either whole or under construction, never damaged.
- The green Hawiqa island (الحويقة), date palms, mudbrick riverside houses.
- Deiri kebab (كباب ديري): minced meat skewers grilled over charcoal with drifting smoke.
- Bamia (بامية): okra stew in a clay pot.

# THE BRIDGE (meta progression, a tribute)

The home hub shows the suspension bridge being rebuilt as the player advances through the home chapter (دير الزور, 20 levels). This is a tribute to the city, so the rules are strict: show construction and hope, never destruction. No rubble, no collapsed spans, no damage, no war imagery, ever. The starting state must read as "being built", not "broken".

Build stages, each unlocked by progress in chapter 1:
- Stage 0 (start): the river with two stone abutments on the banks, wooden scaffolding, and a small wooden ferry carrying people across.
- Stage 1 (level 5): the two steel lattice towers rise.
- Stage 2 (level 10): the main cables are strung between the towers.
- Stage 3 (level 15): the hangers and the walkway deck are laid.
- Stage 4 (level 20, chapter complete): the finished bridge with lamps lit and people crossing. A celebration moment titled «عاد الجسر». From here on the bridge stays whole forever, and later chapters add life around it: boats, a busier kebab stall, evening lights.

The title screen always shows the finished bridge at sunset, as the game's promise.

# DESIGN SYSTEM

Colors (use only these):
- Euphrates blue-green #2E7D8C, primary. Deep river #1B4F5C for dark surfaces and night.
- Palm green #4F8A3A. Okra green #7CB342 for bonus and success states.
- Mudbrick #B5651D. Sand #E8D5A8. Paper cream #F6EEDC for backgrounds and the grid sheet.
- Ember orange #E8641B for primary action buttons and kebab coals.
- Coal black #2B2620 for text and ink. Ink drops (lives) are coal black with a lapis sheen.
- Manuscript gold #C9A227 and lapis #2C4FA3, reserved for chapter cards, restored pages and achievement frames.

Type:
- Amiri for the title, manuscript pages, restored text, and the connected-script preview strip during play.
- IBM Plex Sans Arabic for all UI: buttons, HUD, labels, numbers. Fallback: Cairo.
- Eastern Arabic numerals (١٢٣) everywhere.

Shape and surface:
- Chunky rounded cards (radius 20 to 24), pill buttons, thick letter tiles with soft shadows.
- Surfaces are paper, sand and mudbrick textures with subtle grain, never flat white.
- Icons are hand-drawn ink-line icons with visible stroke weight. No generic stock icon sets.

# ART AND PATTERN LIBRARY (its own artboard)

Create a reusable set of motifs drawn from Deir ez-Zor and from manuscript art, and show each applied to a UI element:
1. Bridge lattice: the crisscross steel truss of the suspension bridge turned into a repeating diamond border, used for dividers, card edges and the HUD bar.
2. Euphrates waves and reed lines as background bands and footers.
3. Date palm fronds as corner ornaments on cards and modals.
4. Keffiyeh check, red-and-white and black-and-white, as small accents: badges, tab indicators, the streak marker.
5. Deiri embroidery: gold-thread geometric embroidery from the women's traditional dress, used for achievement badges and chapter frames.
6. Illuminated manuscript borders (tazhib) in gold and lapis for library chapters and restored pages.
7. Reward illustrations: kebab skewers on a charcoal grill with smoke, a clay pot of bamia, a tray of tea glasses.
8. The riverfront hub backdrop: the five bridge build stages at sunset, plus the finished bridge at morning and at night.

# CHARACTER SHEET: الشاوي (its own artboard)

A young man in his early twenties, warm, friendly and expressive, with slightly stylized proportions. Human and respectful, never a caricature. He wears a cream dishdasha, a red-and-white ghutra with a black agal, and a dark bisht in chapter cards. He carries a leather satchel with rolled scrolls, and a reed pen (qalam) is tucked behind his ear.

Deliver a turnaround (front, three-quarter, side) and these poses, each used in the game:
- Idle, breathing, on the hub.
- Thinking, hand on chin, when the player has been stuck for a while.
- Celebrating, arms raised, on level complete.
- Encouraging, pointing at the wheel, next to the hint button.
- Disappointed, when an ink drop is lost.
- Walking, for the journey map.
- Sitting by the grill with a kebab skewer, for the daily reward moment.
Plus six facial expressions.

# SCREENS

Design in this order. Mobile portrait at 390×844 for every screen. Desktop landscape at 1440×900 for the hub, the map, gameplay and level complete. All text is real Arabic, RTL.

1. Title screen. The title in Amiri calligraphy over the finished bridge at sunset, Alshawi standing on the riverbank in front. One primary button «العب», a small «الإعدادات» gear.

2. Home hub. A riverfront scene: the bridge at its current build stage (design the hub at stage 2, cables strung, and show stage 0 and stage 4 as variants), Hawiqa island, palms, mudbrick houses, a kebab stall with smoke. Alshawi idle at the bank. Top HUD: ink drops (٥ max) with a regeneration timer, coins with a «+» chip, total stars, and a bridge-progress chip «الجسر ١٢ / ٢٠». Cards: «تابع الرحلة» showing «الفصل ١: دير الزور · المستوى ١٢», «التحدي اليومي» with today's date, «الإنجازات», «المتجر». Show the bamia pot bonus indicator in the HUD.

3. Journey map. A winding river path. Stops are illustrated cards in order: دير الزور (home, first chapter), بغداد · بيت الحكمة, فاس · القرويين, قرطبة, تمبكتو, القاهرة. Locked stops show a rolled scroll with a lock. Each stop shows chapter progress, for example «١٢ / ٢٠». Alshawi stands on the current stop.

4. Gameplay, the most important screen.
- Top HUD: back, «المستوى ١٢», ink drops, coins, bamia pot.
- Middle: the crossword grid on a paper manuscript sheet. One letter per cell in ISOLATED letterform. Across words run right to left. Down words run top to bottom.
- Use this real level: wheel letters ك ت ا ب. Grid words: كتاب، كاتب، كتب، تاب، بات. Show the state where كتاب and كتب are already found.
- Preview strip above the wheel: the current selection rendered in CONNECTED script in Amiri, for example «كتا» while dragging.
- Bottom: the wheel with four thick round tiles showing isolated letters, a drag trail in Euphrates blue-green, a free shuffle button in the center, a hint button «تلميح» with its coin price, and the bamia pot at the side.
- Show these states as variants: correct word, word already found, bonus word, wrong word, hint reveal.
- Desktop landscape: grid on the right half, wheel on the left half, HUD across the top. Show a typed-input affordance: when the player types a letter on the keyboard, the matching tile highlights.

5. Level complete. A restored manuscript fragment revealed on the sheet, three stars, coins earned, bonus words found, «التالي» button, Alshawi celebrating. During the home chapter, add a bridge-progress strip under the stars, for example «الجسر ١٢ / ٢٠», with a tiny preview of the next build stage. Add a variant for a chapter's final level, where the whole restored page appears with a proverb, for example «العلم في الصغر كالنقش على الحجر». Add a second variant for the end of chapter 1: the finished bridge with lamps lighting one by one, the title «عاد الجسر», and Alshawi walking across.

6. Out of ink drops. Modal with an empty inkwell, a timer to the next drop, and the options «انتظر», «تعبئة بالعملات», «شاهد إعلاناً». Note: the ad option exists on mobile only. The desktop build is premium with no ads.

7. Hint shop. A bottom sheet: «اكشف حرفاً» ٥٠, «اكشف أول حرف من كل كلمة» ١٢٠, «اختر خلية» ٩٠, «اكشف كلمة» ٢٠٠, coin balance, «شراء عملات».

8. Daily puzzle. «التحدي اليومي» with the date, one special grid on an evening riverfront sheet, and a streak shown as a kebab skewer that gains one piece per day, seven pieces per week. Also design the share card: a 1080×1080 square with the completed grid shown as filled cells with NO letters revealed, the bridge silhouette, the date and the game title.

9. Achievements. A grid of embroidered badges. Locked badges appear as stitched outlines. Categories: الرحلة، الكلمات الإضافية، بلا تلميحات، التحدي اليومي. Each badge shows its coin reward.

10. Settings, minimal: الصوت، الموسيقى، الاهتزاز، الحفظ السحابي، تواصل معنا.

# MOTION SPEC

Prototype the micro-interactions the tool allows. Annotate the rest as a motion spec.
- Hub: river shimmer loop, gentle sway of the bridge cables, palm fronds moving, kebab smoke drifting, day-to-night tint following device time. Alshawi breathes and blinks.
- Gameplay: the drag trail is an ink brush stroke. On a correct word the tiles pulse, the letters fly to their cells and settle with a small ink bloom. A bonus word sends an okra pod arcing into the pot. A wrong word shakes for three frames and leaves a soft smudge that fades. Hint reveals stamp the letter into the cell.
- Level complete: an ink-reveal wipe uncovers the page, stars land like wax seals, coins fly to the HUD.
- Bridge build stages: when a stage unlocks on the hub, the new part draws itself in like an ink stroke: towers rise, cables draw across, deck planks lay down from right to left. At stage 4 the lamps light one by one and people start crossing.
- Map: the camera pans along the river to the next stop while Alshawi walks.
- Screen transitions: a paper page-turn, 250 to 350 ms, ease-out.

# HARD CONSTRAINTS

- RTL layout everywhere. Arabic only. Eastern Arabic numerals.
- No lorem ipsum, no Latin placeholder text, no mirrored English UI.
- Isolated letterforms on tiles and in grid cells. Connected script only in the preview strip, prose and titles.
- No purple gradients, no glassmorphism, no generic stock icons, no flat white cards.
- Do not copy the reference shots. Borrow only their attributes: chunky rounded cards, a present mascot, a card-based map, clear reward moments.
- Never show the bridge damaged, collapsed or as rubble. It is shown whole, or under construction with scaffolding.
- Use only the colors and fonts in the design system.

# DELIVERABLES

1. Mobile artboards for all ten screens and desktop artboards for hub, map, gameplay and level complete.
2. A clickable flow: title → hub → map → gameplay → level complete → hub.
3. The art and pattern library artboard, including the five bridge build stages.
4. The Alshawi character sheet.
5. A token sheet: color tokens, type scale for Amiri and IBM Plex Sans Arabic, spacing on a 4-point grid, radii, shadows, and a components row (buttons, tiles, grid cells, cards, modals, HUD chips), so the system can be rebuilt one-to-one in the game engine.
