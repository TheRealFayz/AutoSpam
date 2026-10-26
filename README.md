# AutoSpam

AutoSpam posts your messages to chat on a timer so you don't have to. Set up your guild recruitment, raid LFM, or trade posts once, pick how often each one should go out, and let it run. Built for World of Warcraft 1.12 and Turtle WoW.

You can also download AutoSpam from OctoWoW's [Gitea](https://octowow.st/git/Fayz/AutoSpam).

## Features

- Weighted rotation of as many messages as you like
- Post to any mix of Say, Yell, Guild, Officer, Party, Raid, World or a custom channel
- Placeholders that fill in live, including local times converted to UTC
- Auto-invite and whisper auto-reply
- Share messages with other players
- Keeps posting while you're AFK and stops the idle logout
- Dry run mode to test without sending anything
- Item links, explicit save, and a resizable window

## Installation

1. Download the latest release.
2. Put the `AutoSpam` folder in `World of Warcraft\Interface\AddOns\`. If you downloaded the code as a zip from GitHub, the folder will be called `AutoSpam-main`. Rename it to `AutoSpam` or WoW won't load it.
3. Make sure the folder has `AutoSpam.toc`, `AutoSpam.lua`, `AutoSpamUI.lua`, and the `Textures` folder.
4. Restart WoW completely. A `/reload` won't pick up new files.

## Quick Start

1. Click the hourglass minimap button or type `/autospam`. You can move the minimap button by right-click dragging it.
2. On the **Messages** tab, type a name and click **Add**.
3. The **Editor** opens. Write your message, check one or more channels, set a weight, and click **Save**.
4. Back on **Messages**, check the box next to your message to enable it.
5. Click **Start**. The first post goes out right away.

The header shows which message posts next, how long you've been running, how many posts went out, and a countdown to the next one. Drag the grip in the bottom right corner to resize the window, or right-click it to reset.

## Messages

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Messages.png?raw=true" alt="AutoSpam Messages tab"></p>

Each row shows the message's channels, name, weight (if above 1), `(inv)` if auto-invite is on, and a preview of the text.

- **Checkbox** turns the message on or off in the rotation.
- **Click the row** to open it in the Editor.
- **Up and down arrows** change the order. Order is just for you; weight decides how often things post.
- **The X** deletes the message after you confirm.

## Writing a Message

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Editor.png?raw=true" alt="AutoSpam Editor tab"></p>

- **Message text** holds up to 511 characters, after placeholders are filled in. Line breaks become spaces since chat can't send them.
- **Channel** opens a list where you check every channel the message should go to. **World** looks for a channel named World, LookingForGroup or LFG, and **Custom Channel** posts to any channel you've joined, by name or number. Extra channels go out one second apart.
- **Weight** sets how often the message comes up. With weights 1, 5 and 2, the weight 5 message posts about five times as often as the weight 1 message.
- **Save** keeps your changes, **Revert** undoes them, and **Share** sends the message to someone else. Edits only stick when you click Save, and AutoSpam asks before throwing away unsaved changes.

To add an item link, click into the message text, then shift-click an item in your bags, on your character, or a link in chat.

### Placeholders

These fill in at the moment a message posts. Hover the line under the message box to see what each one would fill in right now.

- `{GROUP}` is how many people are in your group, like `23`
- `{ZONE}` is the zone you're in
- `{TIME}` is server time, like `8:05 PM`
- `{NAME}` is your character's name
- `{GUILD}` is your guild's name

So `LFM Molten Core {GROUP}/40` posts as `LFM Molten Core 23/40`, and keeps up as your raid fills.

### UTC time

Type a day and time in your own local time and AutoSpam posts it in UTC, so every reader can convert it to their own clock. `{UTC Sunday 1300}` posts as `Sunday 1800 UTC` on US Central daylight time. `{UTC Sat 7:30 PM}`, `{UTC 8pm}` and `{UTC 19:45}` work too, and the day is optional.

The conversion is worked out fresh every time the message posts, for the next time that day and time comes around. It uses the real date, so a daylight saving change before raid day is handled. Keep your PC's clock and time zone set correctly, since that's what AutoSpam reads.

### Auto-Invite

Each message has its own auto-invite settings.

- **Auto-invite on whisper** turns it on for that message.
- **Keywords** is a comma separated list, like `inv, +1, mc`. The whole whisper has to match a keyword, so "inv" works but "can you inv me" doesn't.
- **Convert to raid** turns your party into a raid when it's full so invites keep going out.

Invites only happen while posting is running and the message is checked. You need to be the group leader or a raid assistant, and the same player won't be invited twice within 10 seconds.

## Settings

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Settings.png?raw=true" alt="AutoSpam Settings tab"></p>

- **Post every** sets the time between posts, from 1 to 10 minutes. **Start** posts right away if the timer was idle, **Stop** pauses posting while the timer keeps counting, and **Post now** sends a message immediately and restarts the timer.
- **Dry run** prints posts to your own chat instead of sending them. A popup after each one counts down to the next and has a button to go live.
- **Reply to whispers while posting** sends your **Reply with** text to anyone who whispers you. It only replies while posting is running and the box is checked, and each player gets it once every 5 minutes. The reply can be as long as a message, and placeholders and item links work in it.
- **Debug messages** prints extra detail to chat if you're tracking down a problem.

## Sharing

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Share.png?raw=true" alt="AutoSpam Share window"></p>

Open a message in the Editor and click **Share**. **Send to player** sends it to anyone by name, and **Send to guild** offers it to everyone online in your guild. They need AutoSpam too.

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Receive.png?raw=true" alt="AutoSpam share popup"></p>

They get a popup to accept or decline, and you see their answer in chat. Shared messages arrive unchecked, so nothing posts until they turn it on. Auto-invite settings aren't shared.

## AFK and Logging Out

- Posts keep going out while you're AFK.
- While posting is on, AutoSpam stops the game from logging you out after 30 minutes idle and hides the game's repeating "You have been inactive" message. Logging out yourself still works like normal.
- If a World or custom channel post doesn't show up in chat, AutoSpam sends it once more and tells you if it still didn't make it.
- If you log out while posting is still on, nothing posts when you log back in. A popup gives you 2 minutes to choose **Post now**, otherwise AutoSpam turns itself off.

## In-Game Help

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Help.png?raw=true" alt="AutoSpam Help tab"></p>

The Help tab covers all of this in short form, right in the game.

## Slash Commands

- `/autospam` or `/aspam` opens the window
- `/autospam start` starts posting
- `/autospam stop` stops posting
- `/autospam now` posts right away
- `/autospam dryrun` toggles dry run
- `/autospam time` shows your PC time and UTC, if a converted time looks wrong

## Saved Data

Messages and settings are saved for your whole account in:

```
WTF\Account\[AccountName]\SavedVariables\AutoSpam.lua
```

## Tips

1. **Write a few versions** of the same message and enable them all. It reads a lot less like spam.
2. **Use the right channel.** Trade for selling, World or Guild for recruiting, LFG for groups.

## Bugs and Feature Requests

Open an issue on GitHub and I'll take a look: https://github.com/TheRealFayz/AutoSpam

If AutoSpam saves you some time, a star on GitHub helps other players find it.

Happy posting!
