# AutoSpam

AutoSpam posts your messages to chat on a timer so you don't have to. Set up your guild recruitment, raid LFM, or trade posts once, pick how often each one should go out, and let it run. Built for World of Warcraft 1.12 and Turtle WoW.

You can also download AutoSpam from OctoWoW's [Gitea](https://octowow.st/git/Fayz/AutoSpam).

## Features

- **One window, four tabs.** Messages, Editor, Settings, and Help live on spellbook style tabs along the right edge.
- **Weighted rotation.** Give each message a weight from 1 to 10. Higher weight means it comes up more often.
- **See what's next.** The header shows which message posts next, how long you've been running, how many posts went out, and a countdown to the next one.
- **Any channels you want.** Check as many as you like per message: Say, Yell, Guild, Officer, Party, Raid, World, or a custom channel you've joined.
- **Placeholders.** Put `{GROUP}`, `{ZONE}`, `{TIME}`, `{NAME}` or `{GUILD}` in a message and it's filled in every time it posts. `{UTC Sunday 1300}` turns your local time into UTC so everyone can read it in their own time zone.
- **Auto-invite per message.** Turn it on for your raid LFM and leave it off for guild recruiting. Each message has its own keywords and its own convert to raid option.
- **Item links.** Shift-click items in your bags, on your character, or links in chat to drop them into a message.
- **Safe logins.** If you logged out with posting still on, nothing posts when you log back in. A popup gives you 2 minutes to choose Post now, otherwise AutoSpam turns itself off.
- **AFK friendly.** If you're flagged AFK when a post is due, AutoSpam clears the flag first so the message actually goes out.
- **Dry run.** Prints what would be posted to your own chat window and sends nothing. Each dry run post pops up a reminder that counts down to the next one and has a button to go live, so you can't forget it's on.
- **Explicit save.** Edits only stick when you click Save. If you try to leave with unsaved changes, it asks first.
- **Resizable.** Drag the grip in the bottom right corner to make the window bigger or smaller. Right-click it to reset.

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

## The Messages Tab

Each message shows its channels, name, weight (if above 1), `(inv)` if auto-invite is on, and a preview of the text.

- **Checkbox** turns the message on or off in the rotation.
- **Click the row** to open it in the Editor.
- **Up and down arrows** change the order. Order is just for you; weight decides how often things post.
- **The X** deletes the message after you confirm.

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Messages.png?raw=true" alt="AutoSpam Messages tab"></p>

## The Editor

- **Name** can be changed here. Names have to be unique.
- **Message text** holds up to 511 characters. Line breaks are turned into spaces since chat can't send them.
- **Channel** opens a list where you check every channel the message should go to. Click a channel again to uncheck it. Check Custom Channel to type a channel name.
- **Weight** sets how often it comes up compared to your other messages.
- **Auto-invite on whisper** turns on invites for this message. See below.
- **Save** keeps your changes. **Revert** puts the message back the way it was.

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Editor.png?raw=true" alt="AutoSpam Editor tab"></p>

## The Settings Tab

- **Post every** sets the time between posts, from 1 to 10 minutes in 30 second steps.
- **Dry run** prints posts to your own chat instead of sending them.
- **Debug messages** prints extra detail to chat if you're tracking down a problem.

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Settings.png?raw=true" alt="AutoSpam Settings tab"></p>

## The Help Tab

Everything in this README, in short form, right in the game.

<p align="center"><img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/AutoSpam_Help.png?raw=true" alt="AutoSpam Help tab"></p>

## How Weight Works

Say you have three messages enabled:

- Message A, weight 1
- Message B, weight 5
- Message C, weight 2

B posts about five times as often as A and about two and a half times as often as C. Messages with no text are skipped.

## Channels

- **Say, Yell, Guild, Officer, Party, Raid** go where you'd expect.
- **World** looks for a channel named World, LookingForGroup, or LFG.
- **Custom Channel** posts to any channel you've joined, by name or number.

When a message has more than one channel checked, it goes to the first one right away and each of the others one second apart, so it doesn't hit the server as a burst.

## Placeholders

Type these into a message and AutoSpam fills them in at the moment it posts:

- `{GROUP}` is how many people are in your group, like `23`
- `{ZONE}` is the zone you're in, like `Orgrimmar`
- `{TIME}` is server time, like `8:05 PM`
- `{NAME}` is your character's name
- `{GUILD}` is your guild's name

So `LFM Molten Core {GROUP}/40, need heals` posts as `LFM Molten Core 23/40, need heals`, and the number keeps up as your raid fills. Hover the line under the message box in the Editor to see every placeholder and what it would fill in right now.

### UTC time

Type a day and time in your own local time and AutoSpam posts it in UTC, which is the same everywhere, so every reader can convert it to their own clock:

- `{UTC Sunday 1300}` posts as `Sunday 1800 UTC` if you're on US Central daylight time
- `{UTC Sat 7:30 PM}`, `{UTC 8pm}` and `{UTC 19:45}` work too. The day is optional
- The time comes back in the same style you typed it, and the day moves if the conversion crosses midnight

The time you type is always your own local time. The `UTC` in the braces just says what to convert it to.

Your saved message never changes. The conversion happens fresh every time the message posts:

- It always points at the next time that day and time comes around. Once Sunday 1300 has passed, posts point to the following Sunday.
- It works out the actual date of that next Sunday, so daylight saving is handled. If your clocks change before then, the UTC time changes to match. For example, on US Central time, `{UTC Sun 1300}` posts as `Sun 1800 UTC` up until 1:00 PM on the last Sunday before clocks fall back. From then on it posts `Sun 1900 UTC`, because the next Sunday is on standard time. Both are correct for the raid they point to.

Keep your PC's clock and time zone set correctly, since that's what AutoSpam reads. If AutoSpam can't read what you typed, it's posted exactly as written.

The 511 character limit applies after placeholders are filled in. If a message runs over, it's skipped and you'll get a note in chat.

## Timer

Set the interval on the **Settings** tab, anywhere from 1 to 10 minutes. The countdown in the header shows when the next post goes out.

1. **Start** begins posting. If the timer was idle, the first post goes out immediately.
2. **Stop** pauses posting but the timer keeps counting down.
3. If the timer runs out while you're stopped, it goes idle. The next **Start** posts right away.
4. **Post now** sends a message immediately and restarts the timer.

## Auto-Invite

Auto-invite is set up on each message in the Editor.

- **Auto-invite on whisper** turns it on for that message.
- **Keywords** is a comma separated list, like `inv, +1, mc`. The whole whisper has to match a keyword, so "inv" works but "can you inv me" doesn't.
- **Convert to raid** turns your party into a raid when it's full so invites keep going out.

Invites only happen while posting is running and the message is checked in the Messages list. You need to be the group leader (or a raid assistant) for invites to work, and the same player won't be invited twice within 10 seconds.

## Item Links

Click into the message text, then shift-click an item in your bags, an item on your character, or a link in chat. The link goes in at your cursor. Links count toward the 511 character limit.

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

Messages from older versions of AutoSpam carry over automatically.

## Tips

1. **Test with dry run first** so you can see your rotation without spamming anyone.
2. **Write a few versions** of the same message and enable them all. It reads a lot less like spam.
3. **Use the right channel.** Trade for selling, World or Guild for recruiting, LFG for groups.
4. **Forgot to stop before logging out?** No problem. When you log back in nothing posts. A popup counts down 2 minutes with **Stop posting** and **Post now** buttons, and if you don't click either one, AutoSpam turns itself off.

## Bugs and Feature Requests

Open an issue on GitHub and I'll take a look: https://github.com/TheRealFayz/AutoSpam

Happy posting!
