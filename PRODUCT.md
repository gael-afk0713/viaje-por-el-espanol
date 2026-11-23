# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(Godot 4 game exported to the web with the Compatibility renderer; also runs natively on PC. UI is built in GDScript with Control nodes, not HTML.)

## Users

- Primary: students' parents at a school presentation, playing on an iPad in Safari with touch, often for the first time and without instructions.
- Secondary: the student and classmates on a PC with a keyboard.

## Product Purpose

A 2.5D platformer for a 7th-grade Spanish class assignment (Escola Concept). It covers the 21 Spanish-speaking countries, one level per country. It teaches regional vocabulary and how diverse Spanish is: the same idea gets a different word in each country (trabajo = chamba in México, laburo in Argentina). Success means a parent finishes a level, remembers a regional word, and understands that Spanish varies by country.

## Positioning

Every level is a trip through a real country. Locals speak in that country's slang, you answer with the word used *there*, and you collect each word in a personal album.

## Operating Context

- The game is shown live to parents, so short sessions on a borrowed iPad.
- Touch controls are on-screen buttons (left, right, jump) that hide when a keyboard key is pressed.
- Each level has:
  - two villages with 6 residents;
  - a dialogue with 3 answer buttons (keys 1/2/3);
  - two "jump on the right word" platform challenges;
  - monsters to stomp;
  - a flag at the end.
- The word album can be opened once per conversation (Tab), or freely from the menu.
- Progress is saved locally.

## Capabilities and Constraints

- 21 countries, 3 regional words each (63 words).
- The slang list is a draft that still needs the teacher's review.
- Screens:
  - main menu with a country grid;
  - HUD (country, words, people, monsters, album and menu buttons);
  - NPC dialogue with typewriter text and answer buttons;
  - toasts;
  - album/dictionary;
  - end-of-level summary;
  - touch controls.
- Must stay light for iPad web (Compatibility renderer).
- Deadline: about one week from Nov 2026.

## Brand Commitments

- The current name is "Viaje por el Español". The user allows changing anything, including the name.
- Language: on-screen text in Spanish, with short Portuguese hints for parents.
- School identity: the Escola Concept Salvador logo (`assets/escola/logo_concept.png`, taken from escolaconcept.com.br; white lettering, so only on dark surfaces) appears on the menu and the level-complete screen. It is a 7th-grade Spanish assignment, credited in the menu footer.
- 3D art is Kenney CC0 (Mini Characters, Platformer, Nature, Fantasy Town, Graveyard monsters), with a less-pastel, natural palette requested by the user.

## Evidence on Hand

- `scripts/game_data.gd`: countries, words, NPC lines, accent notes and facts.
- No testimonials or metrics exist. Do not invent them.

## Product Principles

1. A first-time parent on an iPad must understand every screen without being told.
2. The regional word is the hero of every screen it appears on.
3. The 21 countries are the map of the experience; progress across them should feel like a trip.
4. Never block play with UI. Overlays are short, dismissible and touch-sized.

## Accessibility & Inclusion

- Touch targets at least 44 pt on iPad.
- High contrast over a moving 3D background.
- Some NPCs use wheelchairs; keep that representation.
