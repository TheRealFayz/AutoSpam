# AutoSpam

AutoSpam is a powerful automated message posting addon for World of Warcraft 1.12 and Turtle WoW. Manage multiple messages with weighted frequency control and post them automatically to various chat channels at customizable intervals.
<img src="https://github.com/TheRealFayz/AutoSpam/blob/main/Images/GUI.png?raw=true">

## Features

### Core Functionality
- **Weighted Message System** - Set weight (1-10) for each message to control posting frequency
- **Multiple Channels** - Say, Yell, Guild, Officer, Party, Raid, World, and Custom channels
- **Smart Timer** - Continues counting even when posting is stopped, resumes seamlessly
- **Immediate First Post** - Posts instantly when starting if timer is at full interval
- **Post Now Button** - Manually trigger a post outside the schedule
- **Weighted Random Selection** - Messages with higher weight appear more frequently in rotation

### Message Management
- **Create & Edit** - Add unlimited messages with up to 255 characters each
- **Rename Messages** - Change message names without recreating them
- **Enable/Disable** - Checkbox toggle for each message
- **Reorder Messages** - Up/Down arrows to organize your message list
- **Weight Display** - Messages show "(x3)", "(x5)" etc. to indicate frequency multiplier
- **Character Counter** - Real-time count with red warning at 255 characters

### User Interface
- **Minimap Button** - "AS" text button with right-click drag positioning
- **Scrollable Lists** - Clean message list with dark backgrounds
- **Edit Windows** - Dedicated window for each message with all settings
- **Help System** - Comprehensive built-in documentation
- **Gold Theme** - Consistent gold text styling throughout

## Quick Start Guide

### 1. Create Your First Message
1. Click the **"AS"** minimap button to open settings
2. Type a name in "Message Name:" field (e.g., "Guild Recruitment")
3. Click **Add**
4. Click **Edit** next to your new message
5. Type your message text (max 255 characters)
6. Select a channel from the dropdown
7. Set the weight (1 = normal, 10 = posts 10x as often)
8. Click **Save**

### 2. Enable and Start Posting
1. Check the box next to your message to enable it
2. Set your **Post Interval** slider (1-10 minutes)
3. Click **Start Posting**
4. First post goes out immediately!

## How Weight Works

Weight determines how often a message posts compared to others:

**Example:**
- Message A: Weight 1 (enabled)
- Message B: Weight 5 (enabled)
- Message C: Weight 2 (enabled)

Message B will post ~5 times as often as Message A, and ~2.5 times as often as Message C.

**Behind the scenes:** AutoSpam creates a weighted pool where each message appears N times based on its weight, then randomly selects from that pool.

## Channel Options

- **Say** - Local say chat
- **Yell** - Yell (larger radius than say)
- **Guild** - Guild chat
- **Officer** - Officer chat only
- **Party** - Party chat
- **Raid** - Raid chat
- **World** - World channel (searches for World, LookingForGroup, LFG)
- **Custom Channel** - Enter any channel name (e.g., "Trade", "General")

## Timer Behavior

The timer in AutoSpam has smart behavior:

1. Timer **starts** when you click "Start Posting"
2. Timer **counts down continuously** once started
3. Timer **does NOT stop** when you click "Stop Posting"
4. Timer **only stops** when it hits 0 while posting is disabled
5. Click "Start Posting" again to resume posting at current timer position

**Why?** This prevents spam and allows you to pause/resume without resetting your interval.

## Message Management Features

### Editing Messages
- Click **Edit** to open a dedicated edit window
- Change message text, channel, and weight
- Click **Save** to save changes (window stays open)
- Click **X** to close

### Renaming Messages
1. Click **Edit** on a message
2. Click **Rename** button next to the title
3. Type new name and press Enter or click **Save**
4. Press Escape to cancel

### Reordering Messages
- Use **Up/Down arrows** to change message order in the list
- Order doesn't affect posting frequency (weight does)
- Organize for your convenience

### Deleting Messages
- Click **Remove** to permanently delete a message
- No confirmation prompt - be sure before clicking!

## Keyboard Shortcuts

- **Escape** - Close any AutoSpam window
- **Enter** - Save changes when renaming a message
- **Ctrl+C** - Copy (use in text fields)
- **Ctrl+A** - Select all (use in text fields)

## Help Window

Click the **Help** button (next to X) in the main window for comprehensive built-in documentation including:
- Getting Started guide
- Message Settings details
- Weight System explanation
- Timer & Posting behavior
- Managing Messages tips
- Best Practices
- GitHub link for support

## Configuration

All settings are saved per character in:
```
WTF\Account\[AccountName]\[ServerName]\[CharacterName]\SavedVariables\AutoSpam.lua
```

## Best Practices

1. **Test First** - Create test messages with short intervals before going live
2. **Use Weights Strategically** - Higher weights for important messages, lower for promotional content
3. **Vary Your Messages** - Create multiple versions to avoid spam appearance
4. **Watch the Timer** - Check countdown before logging out
5. **Appropriate Channels** - Use Trade for selling, World/Guild for recruitment, etc.
6. **Character Limit** - Keep messages under 255 characters (turns red if over)

*Happy posting!*
