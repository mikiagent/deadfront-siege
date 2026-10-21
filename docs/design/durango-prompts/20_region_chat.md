# 20. Region chat (owner, 2026-10-20)

Owner's words, verbatim: "region chat"

Reference: `docs/reference/durango-region-chat.webp`. The rest of this file is the orchestrator's reading.

- **Left column:** channels "Region" (selected, gold text in yellow corner brackets) and "System", separated by dotted lines. A "+ New Group" button sits at the bottom.
- **Right panel header:** the channel title "Region", a gold eye toggle (show or hide chat over the game), and a close X.
- **Message rows:** the sender's name in gold, then an emote sticker (white smiley or skull) or text ("hi", ":)"), then a small grey relative time ("1h 28m ago"). Consecutive messages from one sender stack under one name. Rows alternate light and dark tints over the blurred world.
- **Input bar:** an "Enter message" field, a "+" button (emotes and stickers), and a "Send" button.
- **Binding text:**
  - PRD:70: "Islands themselves are still separate load spaces (local chat ...)".
  - PRD:938: "Nearby / island chat (island population visible ...)".
  - contracts.md §7: chat.
- **Base:** claude/mmo-net has island-room chat. net_chat.gd takes `chat.send {text}` and sends `evt chat {from, id, text, ts}` to everyone in the room. The branch has not been merged and is far behind the base.
