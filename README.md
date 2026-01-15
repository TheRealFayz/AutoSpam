# AutoSpam

AutoSpam is an automated message posting addon for World of Warcraft 1.12 and Turtle WoW. Post custom messages at configurable intervals to various chat channels.

## Features

- **Minimap Button** - Easy access with draggable positioning (right-click drag)
- **Message Management** - Save, edit, delete, and navigate through multiple messages
- **Selective Posting** - Choose which messages to include in rotation
- **Channel Support** - Say, Yell, Guild, Officer, Party, Raid, and Custom channels
- **Flexible Intervals** - Set posting intervals from 1-10 minutes in 30-second increments
- **Immediate Posting** - Posts first message immediately when started
- **Compact UI** - Scrollable settings window that doesn't consume your screen
- **Debug Mode** - Built-in debugging for troubleshooting

## Installation

1. Download the latest release
2. Extract the `AutoSpam` folder to `World of Warcraft\Interface\AddOns\`
3. Restart WoW or type `/console reloadui` in-game

## Usage

### Opening Settings
- **Left-click** the chat bubble icon on your minimap
- **Right-click drag** to reposition the minimap button

### Creating Messages
1. Enter a **Message Name** (e.g., "Guild Recruit")
2. Enter your **Message Text**
3. Click **Save**
4. Use **< Prev** and **Next >** to browse saved messages
5. Click **Delete** to remove the current message

### Activating Messages
1. Check the box next to each message you want to include in rotation
2. Checked messages will be posted randomly at the set interval

### Selecting Channel
1. Click the **Channel Settings** dropdown
2. Select your desired channel (Say, Yell, Guild, Officer, Party, Raid)
3. For custom channels, enter the channel name in the **Custom Channel Name** field

### Starting AutoSpam
1. Set your **Post Interval** using the slider (1-10 minutes)
2. Ensure at least one message is checked as active
3. Click **Start Posting**
4. The first message posts immediately, then continues at your set interval
5. Click **Stop Posting** to pause

## Keyboard Shortcuts

- **Escape** - Close the settings window

## Debug Mode

Enable the **Debug Mode** checkbox at the top of settings to see detailed logging:
- Channel selection changes
- Message activation/deactivation
- Active message counts
- Posting events

Debug messages appear in your chat window.

## Configuration

All settings are saved per character in `WTF\Account\[AccountName]\[ServerName]\[CharacterName]\SavedVariables\AutoSpam.lua`

Saved settings include:
- Minimap button position
- All saved messages
- Active message selections
- Selected channel
- Post interval
- Enabled/disabled state

## Troubleshooting

**Minimap button not appearing:**
- Type `/console reloadui` to reload the UI
- Ensure the addon is enabled in the character select screen

**Messages not posting:**
- Verify at least one message is checked as active
- Check that you have permission to post in the selected channel
- Enable Debug Mode to see what's happening

**Checkboxes not responding:**
- This was a known issue in earlier versions - ensure you're using v1.17 or later

**Window appears behind other UI:**
- This should not occur in v1.4+, but try closing and reopening the window

## Compatibility

- **World of Warcraft:** 1.12 (Vanilla)
- **Turtle WoW:** Fully compatible
- **Lua Version:** 5.0

## Technical Notes

- Written in Lua 5.0 for WoW 1.12 compatibility
- Uses SavedVariables for persistent storage
- Frame strata and level management for proper UI layering
- Anonymous CheckButton frames to avoid frame reuse issues

## Version History

**v1.17** - Current stable release
- Fixed checkbox clicking via closure fix
- Removed test/debug checkboxes
- Production ready

**v1.0-v1.16** - Development versions
- Various bug fixes and improvements
- Resolved frame strata issues
- Fixed dropdown functionality
- Implemented scrolling

## Known Issues

- Dropdown checkmark doesn't move visually (selection still works correctly)
- Messages don't scroll within the Active Messages box (positioned absolutely)

## License

This addon is provided as-is for use with World of Warcraft 1.12 and Turtle WoW.

## Support

For bug reports or feature requests, please open an issue on the repository.

## Credits

Developed for the World of Warcraft 1.12 and Turtle WoW communities.
