local utils = require 'mp.utils'
local options = require 'mp.options'

local messages = nil
local chat_overlay = nil
local chat_hidden = false

local is_windows = package.config:sub(1,1) ~= "/"
local xdg_data_home = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")

local opts = {}
opts['auto-load'] = false
opts['live-chat-directory'] = is_windows and 'C:/' or (xdg_data_home .. '/youtube-live-chats')
opts['yt-dlp-path'] = 'yt-dlp'
opts['show-author'] = true
opts['author-color'] = 'random'
opts['author-border-color'] = '000000'
opts['message-color'] = 'ffffff'
opts['message-border-color'] = '000000'
opts['font'] = mp.get_property_native('osd-font')
opts['font-size'] = 16
opts['border-size'] = 2
opts['message-duration'] = 10000
opts['max-message-line-length'] = 40
opts['message-gap'] = 10
opts['anchor'] = 1

options.read_options(opts)
options.read_options(opts, "mpv-youtube-chat")

local NORMAL = 0
local SUPERCHAT = 1

local delimiter_pattern = " %.,%-!%?"
local function split_string(input)
    local splits = {}

    for input in string.gmatch(input, "[^" .. delimiter_pattern .. "]+[" .. delimiter_pattern .. "]*") do
        table.insert(splits, input)
    end

    return splits
end

function break_message(message, initial_length)
    if opts['max-message-line-length'] <= 0 then
        return message
    end

    local current_length = initial_length
    local result = ''

    for _,v in ipairs(split_string(message)) do
        current_length = current_length + #v

        if current_length > opts['max-message-line-length'] then
            result = result .. '\n' .. v
            current_length = #v
        else
            result = result .. v
        end
    end

    return result
end

function format_message(message)
    local message_string = chat_message_to_string(message)
    local result = nil
    local lines = message_string:gmatch("([^\n]*)\n?")
    for line in lines do
        local formatting = '{\\an' .. opts['anchor'] .. '}'
                        .. '{\\fs' .. opts['font-size'] .. '}'
                        .. '{\\fn' .. opts['font'] .. '}'
                        .. '{\\bord' .. opts['border-size'] .. '}'
                        .. string.format(
                               '{\\1c&H%s&}',
                               swap_color_string(opts['message-color'])
                           )
                        .. string.format(
                               '{\\3c&H%s&}',
                               swap_color_string(opts['message-border-color'])
                           )
        if message.type == SUPERCHAT then
            formatting = formatting .. string.format(
                '{\\1c&H%s&}{\\3c&%s&}',
                swap_color_string(string.format('%06x', message.text_color)),
                swap_color_string(string.format('%06x', message.border_color))
            )
        end
        local message_string = formatting
                            .. line
        if result == nil then
            result = message_string
        else
            if opts['anchor'] <= 3 then
                result = message_string .. '\n' .. result
            else
                result = result .. '\n' .. message_string
            end
        end
    end
    return result or ''
end

function chat_message_to_string(message)
    if message.type == NORMAL then
        if opts['show-author'] then
            if opts['author-color'] == 'random' then
                return string.format(
                    '{\\1c&H%06x&}{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    message.author_color,
                    swap_color_string(opts['author-border-color']),
                    message.author,
                    swap_color_string(opts['message-color']),
                    swap_color_string(opts['message-border-color']),
                    break_message(message.contents, message.author:len() + 2)
                )
            elseif opts['author-color'] == 'none' then
                return string.format(
                    '{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    swap_color_string(opts['author-border-color']),
                    message.author,
                    swap_color_string(opts['message-color']),
                    swap_color_string(opts['message-border-color']),
                    break_message(message.contents, message.author:len() + 2)
                )
            else
                return string.format(
                    '{\\1c&H%s&}{\\3c&H%s&}%s{\\1c&H%s&}{\\3c&H%s&}: %s',
                    swap_color_string(opts['author-color']),
                    swap_color_string(opts['author-border-color']),
                    message.author,
                    swap_color_string(opts['message-color']),
                    swap_color_string(opts['message-border-color']),
                    break_message(message.contents, message.author:len() + 2)
                )
            end
        else
            return break_message(message.contents, 0)
        end
    elseif message.type == SUPERCHAT then
        if message.contents then
            return string.format(
                '%s %s: %s',
                message.author,
                message.money,
                break_message(message.contents, message.author:len() + message.money:len())
           )
       else
            return string.format(
                '%s %s',
                message.author,
                message.money
           )
       end
    end
end

function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        f:close()
        return true
    else
        return false
    end
end

function download_live_chat(url, filename)
    if file_exists(filename) then return end
    mp.command_native({
        name = "subprocess",
        args = {
            opts['yt-dlp-path'],
            '--skip-download',
            '--sub-langs=live_chat',
            url,
            '--write-sub',
            '-o',
            '%(id)s',
            '-P',
            opts['live-chat-directory']
        }
    })
end

-- TODO: better way to do this that gives more consistent brightness in colors?
function string_to_color(str)
    local hash = 5381
    for i = 1,str:len() do
        hash = (33 * hash + str:byte(i)) % 16777216
    end
    return hash
end

function swap_color_string(str)
    local r = str:sub(1, 2)
    local g = str:sub(3, 4)
    local b = str:sub(5, 6)
    return b .. g .. r
end

function generate_messages(live_chat_json)

    local result = {}
    for line in io.lines(live_chat_json) do
        local entry = utils.parse_json(line)
        if entry.replayChatItemAction then
            local time = tonumber(
                entry.videoOffsetTimeMsec or
                entry.replayChatItemAction.videoOffsetTimeMsec
            )
            for _,action in ipairs(entry.replayChatItemAction.actions) do
                if action.addChatItemAction then
                    if action.addChatItemAction.item.liveChatTextMessageRenderer then
                        local liveChatTextMessageRenderer = action.addChatItemAction.item.liveChatTextMessageRenderer

                        local id = liveChatTextMessageRenderer.authorExternalChannelId
                        local color = string_to_color(id)

                        local author
                        if liveChatTextMessageRenderer.authorName then
                            author = liveChatTextMessageRenderer.authorName.simpleText or 'NAME_ERROR'
                        else
                            author = '-'
                        end

                        local message_data = liveChatTextMessageRenderer.message
                        local message = ""
                        for _,data in ipairs(message_data.runs) do
                            if data.text then
                                message = message .. data.text
                            elseif data.emoji then
                                if data.emoji.isCustomEmoji then
                                    message = message .. data.emoji.shortcuts[1]
                                else
                                    message = message .. data.emoji.emojiId
                                end
                            end
                        end

                        result[#result+1] = {
                            type = NORMAL,
                            author = author,
                            author_color = color,
                            contents = message,
                            time = time
                        }
                    elseif action.addChatItemAction.item.liveChatPaidMessageRenderer then
                        local liveChatPaidMessageRenderer = action.addChatItemAction.item.liveChatPaidMessageRenderer

                        local border_color = liveChatPaidMessageRenderer.bodyBackgroundColor - 0xff000000
                        local text_color = liveChatPaidMessageRenderer.bodyTextColor - 0xff000000
                        local money = liveChatPaidMessageRenderer.purchaseAmountText.simpleText

                        local author
                        if liveChatPaidMessageRenderer.authorName then
                            author = liveChatPaidMessageRenderer.authorName.simpleText or 'NAME_ERROR'
                        else
                            author = '-'
                        end

                        local message_data = liveChatPaidMessageRenderer.message
                        local message = ""
                        if message_data ~= nil then
                            for _,data in ipairs(message_data.runs) do
                                if data.text then
                                    message = message .. data.text
                                elseif data.emoji then
                                    if data.emoji.isCustomEmoji then
                                        message = message .. data.emoji.shortcuts[1]
                                    else
                                        message = message .. data.emoji.emojiId
                                    end
                                end
                            end
                        else
                            message = nil
                        end

                        result[#result+1] = {
                            type = SUPERCHAT,
                            author = author,
                            money = money,
                            border_color = border_color,
                            text_color = text_color,
                            contents = message,
                            time = time
                        }
                    end
                end
            end
        end
    end
    return result
end

function load_live_chat(filename, interactive)
    reset()

    local generating_overlay = mp.create_osd_overlay("ass-events")

    local path = mp.get_property_native('path')
    if filename == nil then
        local is_network = path:find('^http://') ~= nil or
                           path:find('^https://') ~= nil
        if is_network then
            local track_list = mp.get_property_native("track-list")
            for _,v in pairs(track_list) do
                if v.type == 'sub' and v.lang == 'live_chat' then
                    local external_filename = v['external-filename']
                    external_filename = external_filename:gsub(".*http", "http")

                    local id = external_filename:gsub("^.*\\?v=", ""):gsub("&.*", "")
                    filename = string.format(
                        "%s/%s.live_chat.json",
                        opts['live-chat-directory'],
                        id
                    )

                    generating_overlay.data = 'Downloading live chat replay...'
                    generating_overlay:update()

                    download_live_chat(external_filename, filename)
                    break
                end
            end
        else
            local base_path = path:match('(.+)%..+$') or path
            filename = base_path .. '.live_chat.json'
        end
    end

    generating_overlay.data = 'Parsing live chat replay...'
    generating_overlay:update()

    if filename ~= nil and file_exists(filename) then
        messages = generate_messages(filename)
    else
        generating_overlay:remove()
        if interactive then
            mp.command('show-text "Unable to find live chat replay file!"')
        end
        return
    end

    generating_overlay:remove()

    if not chat_overlay then
        chat_overlay = mp.create_osd_overlay("ass-events")
        chat_overlay.z = -1
    end

    update_chat_overlay(mp.get_property_native("time-pos"))
end

function _load_live_chat(_, filename)
    load_live_chat(filename)
end

function update_chat_overlay(time)
    if chat_hidden or chat_overlay == nil or messages == nil or time == nil then
        return
    end

    local msec = time * 1000

    chat_overlay.data = ''
    for i=1,#messages do
        local message = messages[i]
        if message.time > msec then
            break
        elseif msec <= message.time + opts['message-duration'] then
            local message_string = format_message(message)
            if opts['anchor'] <= 3 then
                chat_overlay.data =    message_string
                                    .. '\n'
                                    .. '{\\fscy' .. opts['message-gap'] .. '}{\\fscx0}\\h{\fscy\fscx}'
                                    .. chat_overlay.data
            else
                chat_overlay.data =    chat_overlay.data
                                    .. '{\\fscy' .. opts['message-gap'] .. '}{\\fscx0}\\h{\fscy\fscx}'
                                    .. '\n'
                                    .. message_string
            end
        end
    end
    chat_overlay:update()
end

function _update_chat_overlay(_, time)
    update_chat_overlay(time)
end

function load_live_chat_interactive(filename)
    load_live_chat(filename, true)
end

function set_chat_hidden(state)
    if state == nil then
        chat_hidden = not chat_hidden
    else
        chat_hidden = state == 'yes'
    end

    if chat_overlay ~= nil then
        if chat_hidden then
            mp.command('show-text "Youtube chat replay hidden"')
            chat_overlay:remove()
        else
            mp.command('show-text "Youtube chat replay unhidden"')
            update_chat_overlay(mp.get_property_native("time-pos"))
        end
    end
end

function set_chat_anchor(anchor)
    if anchor == nil then
        opts['anchor'] = (opts['anchor'] % 9) + 1
    else
        opts['anchor'] = tonumber(anchor)
    end
    if chat_overlay then
        update_chat_overlay(mp.get_property_native("time-pos"))
    end
end

function reset()
    messages = nil
    if chat_overlay then
        chat_overlay:remove()
    end
    chat_overlay = nil
end

mp.add_key_binding(nil, "load-chat", load_live_chat_interactive)
mp.add_key_binding(nil, "unload-chat", reset)
mp.add_key_binding(nil, "chat-hidden", set_chat_hidden)
mp.add_key_binding(nil, "chat-anchor", set_chat_anchor)

if opts['auto-load'] then
    mp.register_event("file-loaded", _load_live_chat)
end
mp.observe_property("time-pos", "native", _update_chat_overlay)
mp.register_event("end-file", reset)
