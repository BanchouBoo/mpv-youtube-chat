# mpv-youtube-chat

Display chat replays overlayed on top of the video for past Youtube livestreams and premiers using [yt-dlp](https://github.com/yt-dlp/yt-dlp)

## Notes
- Untested on platforms other than Linux. If you are not using Linux you may need to manually set the script options `live-chat-directory` and/or `yt-dlp-path`.
- Does not currenly work for streams are premiers that are currently airing as the live chat won't finish downloading until the stream/premier finishes. If you try to load the chat in one that is active it will still start downloading the live chat, so keep that in mind.
- Downloading live chats can take awhile, especially for videos that have a very active chat and/or videos that are very long.

## Requirements
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) is required to download the live_chat.json

## Usage
Binding `load-chat` to a keybinding and press it in a video. If the video is being played locally it will look for `video_filename_without_extension.live_chat.json` and load that if it exists. Otherwise, if you're watching from a URL, it will check if the video has a subtitle with the language `live_chat` and if so, it will download it to the path stored in `live-chat-directory` (see [Options](#Options)) with the filename `video_id.live_chat.json` if it does not already exist in that path, otherwise it will just load it from disk.

## Bindable actions
- `load-chat` -> attempts to load the live chat replay as specified in [Usage](#Usage)
- `unload-chat` -> unloads the currently loaded live chat
- `chat-hidden` -> toggles the visibility of the live chat, optionally takes `yes` or `no` as a parameter to set it to that value instead of toggling it
- `chat-anchor` -> cycle the `chat-anchor` (see [Options](#Options)) option from 1 through 9, optionally takes a value to set it directly

To bind an action, use `script-message` (e.g. `CTRL+j script-message load-chat`)

## Options
- `auto-load` (default `no`) -> attempt to automatically load live chat when a video loads
- `live-chat-directory` (default `C:/` on Windows and `XDG_DATA_HOME/youtube-live-chats` on all other platforms) -> the directory to download `live_chat.json` files to
- `yt-dlp-path` (default `yt-dlp`) -> the path to your `yt-dlp` executable
- `show-author` (default `yes`) -> show the author's name with their message
- `author-color` (default `random`) -> color of the author's name in the message, available values are `random`, `none`, or a specific hex value (without a #)
- `author-border-color` (default `000000`) -> color of the borders around the author's name
- `message-color` (default to `ffffff`) -> color of the body text of a message
- `message-border-color` (default `000000`) -> color of the borders around the body text of a message
- `font` (default to the osd font) -> font to use for chat messages
- `font-size` (default `16`) -> font size for chat messages
- `border-size` (default `2`) -> border size for chat messages
- `message-duration` (default `10000`) -> duration that each message is shown for in miliseconds
- `max-message-line-length` (default `40`) -> the amount of characters before a message breaks into a new line, with messages only breaking at word boundaries
- `message-gap` (default `10`) -> additional spacing between chat messages, given as a percentage of the font height
- `anchor` (default `1`) -> where chat displays on the screen in numpad notation (`1` is bottom-left, `7` is top-left, `9` is top-right, etc.)

## Plans
- ~~Parse live chats as they download, circumventing the need to wait for the whole thing to download before loading the chat~~ and also allowing currently active streams and premiers to be supported. Because yt-dlp downloads live chats to a fragment file first before merging it to the main JSON file, most recent chats in active streams aren't displayed. You need to seek the stream back ~20s to get them shown.
- Support more chat message types. Currently regular messages and superchats (possible that some might be missed as of right now, there seems to be multiple formats for different kinds of messages and I'm not entirely sure what the difference is between these message formats are, if any) both work, I still need to add support memberships and paid stickers and possibly other kinds of messages I'm unaware of.
- Better message rendering. If chat is anchored to the right, every line of every message will also be anchored to the right which looks rather unpleasant. See if I can have the chat be anchored to the right while allowing individual lines to be anchored to the left
