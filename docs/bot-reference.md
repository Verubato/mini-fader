# MiniFader - bot reference

## What it does

MiniFader hides (fades out) selected pieces of the default Blizzard UI and fades them back
in when you mouse over them, for a cleaner, minimal UI. Supported frames: bags bar, micro
menu, objective/quest tracker, raid manager flyout, XP and reputation bars, the buffs
collapse/expand arrow, chat tabs/buttons/background, Blizzard's damage meter windows, the
action bars, and the player frame. The action bars and player frame only fade while out of
combat and outside instances.

## Facts

| Item | Value |
|---|---|
| Version | 1.8.1 |
| Interface versions (.toc) | 120100 (retail only: Midnight 12.1) |
| Saved variables | MiniFaderDB, account wide (settings shared across characters) |
| Slash commands | /fade, /minifade, /minifader, /mfade, /mfader (all open the settings panel) |
| Settings location | Game Menu -> Options -> AddOns -> MiniFader |
| Support | Discord: https://discord.gg/UruPTPHHxK |

## How fading works

- A frame with fading enabled sits at alpha 0 (invisible) until the mouse enters it, then
  fades in over 0.5 seconds.
- After the mouse leaves, the frame waits 3 seconds (2 seconds for chat elements), then
  fades out over 1 second. Hovering again during the wait cancels the fade-out.
- Toggling a checkbox in the options applies instantly: the frame snaps to invisible
  (enabled) or visible (disabled).
- A frame that stops fading because the game changed (combat starting, a loading screen)
  appears instantly; one that starts fading for the same reason eases out over 1 second
  instead of snapping, unless the mouse is on it.
- Each action bar fades on its own: hovering one brings back that bar and nothing else.
- Faded frames still occupy their screen position; hover where the frame normally is to
  bring it back.
- Frames are picked up once on loading screen entry; a frame that does not exist on your
  client/UI simply is not registered.

## Settings reference

Section "Main" (all checkboxes):

| UI label | Default | What it fades | Tooltip |
|---|---|---|---|
| Objective tracker | ON | ObjectiveTrackerFrame (quest tracker) | "Fade the objective/quests tracker, but show it inside instances." |
| Bags | ON | Bags bar | "Fade the bags bar." |
| Micro Menu | ON | Micro menu buttons | "Fade the micro menu." |
| Chat | OFF | Chat tabs, side buttons, background, social button | "Fade the chat tabs." |
| XP and Reputation | ON | XP/reputation status bars | "Fade the XP and Reputation bars." |
| Raid manager | ON | CompactRaidFrameManager flyout on the left screen edge | "Fade the raid manager flyout (left of screen flyout menu)." |
| Buffs button | OFF | The collapse/expand arrow next to buffs | "Fade the collapse/expand buffs arrow button." |
| Damage meter | OFF | Blizzard damage meter windows | "Fade the Blizzard damage meter." |
| Player frame | OFF | The player's health/power frame, out of combat and outside instances only | "Fade the player's health and power bars while out of combat and outside instances." |

Section "Objective Tracker Options":

| UI label | Default | Effect |
|---|---|---|
| Fade in PvP | ON | Also fade the objective tracker inside battlegrounds and arenas |
| Fade in PvE | OFF | Also fade the objective tracker inside dungeons/raids/other PvE instances |

Section "Action Bars", one checkbox per bar, all OFF by default. Each fades that bar out of
combat and outside instances only. UI labels: "Action bar 1" through "Action bar 8", then
"Stance bar", "Pet bar", and "Possess bar". Tooltip is "Fade <label in lower case> while out
of combat and outside instances."

## Per-frame behaviour details

- Objective tracker: outside instances it always fades (when enabled). Inside a
  battleground or arena it fades only if "Fade in PvP" is on (default on). Inside any
  other instance it fades only if "Fade in PvE" is on (default off), so by default it
  stays visible in dungeons and raids. Re-evaluated on every loading screen.
- Damage meter: fades Blizzard's damage meter session windows, and only while NOT in an
  instance; inside instances the meter stays visible regardless of the setting.
- Buffs button: the arrow also fades in when hovering anywhere over the buff frame, not
  just the arrow itself.
- Chat: hides the chat tab, the window border/background textures and Blizzard's
  background, replacing the background with a subtle black one (25% alpha) that appears on
  hover over the chat frame. The chat side buttons and the social/Quick Join toast button
  fade with it. Tabs are faded rather than hidden, so they stay clickable, and every tab's
  alpha is put back when the setting is turned off. Applies to all chat windows/tabs, and
  toggling it takes effect without a reload.
- Micro menu: fades the whole menu and includes a fix for Blizzard's hover animation that
  could otherwise leave icons invisible after fast mouse movements (fixed in 1.5.0).
- Objective tracker and XP bars have mouse interactivity enabled by the addon so hover
  can be detected.
- Action bars: all eight action bars plus the stance, pet, and possess bars, each with its
  own checkbox rather than one for the lot. Each is found by frame name (MainActionBar on
  12.1, MainMenuBar before that), or through the frame its buttons hang off when the client
  has none of the names it knows. They show the moment combat starts and fade again when it
  ends. Each bar fades on its own, so hovering a bar (or any button on it) brings back that
  bar and leaves every other bar where it was. Mouse interactivity is not added: the buttons
  already have it, so clicks still pass through the empty parts of a bar.
- Player frame: fades outside combat and outside instances, and shows instantly when combat
  starts. The pet frame fades with it because it is part of the player frame.
- Minimap: not supported. Its blips and location icons are drawn by the client rather than
  by a frame, so they ignore alpha and would stay put over a faded map.

## Troubleshooting by symptom

- "Frame X is gone / I can't find it": it is faded, not removed; move the mouse to where
  it normally sits and it fades back in. Or untick its checkbox in /fade.
- "The quest tracker still shows in dungeons": default behaviour; "Fade in PvE" is off by
  default. Enable it under "Objective Tracker Options".
- "The quest tracker is hidden in battlegrounds and I want it": turn off "Fade in PvP"
  under "Objective Tracker Options".
- "The damage meter doesn't fade in raids/dungeons": intentional; the damage meter only
  fades outside instances.
- "My action bars vanish out of combat": that is that bar's checkbox under "Action Bars";
  they come back in combat or on mouseover. Untick it to stop.
- "The action bars don't fade in combat, or in a dungeon/raid/battleground": intentional; the
  action bars and player frame only fade out of combat and outside instances.
- "A frame isn't fading at all": confirm its checkbox is on in /fade; the addon only hooks
  frames that exist when you first enter the world, so a frame created later by another
  addon or a UI reload mid-session may need a /reload. Also note MiniFader targets the
  default Blizzard frames; bars replaced by addons like Bartender or ElvUI are not
  supported frames.
- "Micro menu icons are invisible after mousing over quickly": fixed in 1.5.0; update the
  addon if on an older version.
- "Settings are the same on all my characters": yes, settings are account wide.
- "Does it work on Classic?": no; the .toc lists retail 12.1 only.
- "Can I change the fade delay or speed?": no options for that; timings are fixed
  (0.5s in, 1s out, 3s delay, 2s for chat).
