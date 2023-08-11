module(..., package.seeall)

local rex = require('rex_pcre2')
local json = require('dkjson')

local utils = require("jessepav.utils")
local indexof = utils.indexof
local truthy = utils.truthy
local extend = utils.extend
local toarray = utils.toarray
local isdigit = utils.isdigit

-- Regexp definitions {{{1

-- These regexps are used to split a line into words
local line_words_nodash_re = rex.new([[\W+]])
local line_words_dash_re = rex.new([[[^\w-]+]])

-- Regex to split words into camelCase or snake_case parts.
--
-- It's composed of four parts:
--
--  1. lowercase to uppercase transition
--  2. underscore
--  3. digit to an alphabetic character transition
--  4. alphabetic character to a digit transition
--
local word_parts_re = rex.new(table.concat({
            [=[(?:(?<=[a-z])(?=[A-Z]))]=],
            [=[(?:_+)]=],
            [=[(?:(?<=[[:digit:]])(?=[[:alpha:]]))]=],
            [=[(?:(?<=[[:alpha:]])(?=[[:digit:]]))]=]
        }, '|'))

-- And if our words have dashes, we just use the dash pattern
local dash_parts_re = rex.new([[-+]])

-- Used to determine the start of the identifier before the cursor
local eol_word_re = rex.new([[\w+$]])

-- Utility functions {{{1

-- This assumes that the appropriate line_words_re weeded out non-word strings, so it just
-- matches words that begin with an alphabetic character and are at least 4 chars long
local worthy_word_re = rex.new([=[[[:alpha:]].{3,}]=])

local function worthy_word(word)
    return rex.match(word, worthy_word_re) ~= nil
end

-- Returns the non-empty results of a rex.split() as an array
local function gather_splits(s, re)
    local arr = {}
    for word in rex.split(s, re) do
        if #word ~= 0 then table.insert(arr, word) end
    end
    return arr
end

-- Module-scope variables {{{1

-- Our main index, which maps {bufnr = {abbrev_dict, b:changetick, buffer name}}.
-- An 'abbrev_dict', used throughout the plugin, is a mapping from an
-- abbreviation, like 'aSD' to an array of possible completion entries, ex.
-- {'allSaintsDay', 'avoidSomeDisaster'}
local buffer_abbrev_table = {}

-- Used for regenerating our table if necessary
local last_refresh_mode = 0
local last_casefold = false

-- camel_complete() {{{1
--
-- A completion function (:h complete-functions), for use with 'completefunc' or 'omnifunc'
-- See CamelCompleteFunc in plugin/camelcomplete.vim
--
function camel_complete(findstart, base)
    local win = vim.window()
    local buf = vim.buffer()
    if findstart ~= 0 then
        local col = win.col
        if col == 1 then return -1 end
        local s = buf[win.line]:sub(1,col-1)  -- the text from the start of the line to before the cursor
        local pos = rex.find(s, eol_word_re)
        -- Apparently the completion system expects the returned start-position to be
        -- 0-based, like byte offsets in a Vim string, rather than 1-based, like column
        -- numbers, hence the pos-1 below.
        return pos == nil and -3 or pos-1
    else
        local casefold = truthy(vim.g.camelcomplete_casefold)
        local prefixmatch = truthy(vim.g.camelcomplete_prefix_match)
        local base = casefold and base:tolower() or base

        if last_refresh_mode == 0 then
            refresh_abbrev_table(1, true)
        elseif last_casefold ~= casefold then
            refresh_abbrev_table(3, true)
        end

        local abbrev_dicts = {}  -- All the abbrev dicts that we'll examine in our loop below

        -- We do the current buffer's wordlist first, if it's available
        local cur_bufnr = buf.number
        if buffer_abbrev_table[cur_bufnr] then
            table.insert(abbrev_dicts, buffer_abbrev_table[cur_bufnr][1])
        end

        -- And then add the rest
        for bufnr, _ in pairs(buffer_abbrev_table) do
            if bufnr ~= cur_bufnr then
                table.insert(abbrev_dicts, buffer_abbrev_table[bufnr][1])
            end
        end

        local wordlist = {}  -- The list of all candidate completions
        local function nobase_filterfunc(el)
            return el ~= base  -- do not suggest the base itself
        end
        for _, abbrev_dict in ipairs(abbrev_dicts) do
            if prefixmatch then
                for abbrev, words in pairs(abbrev_dict) do
                    if abbrev:find(base, 1, true) == 1 then
                        extend(wordlist, abbrev_dict[abbrev], nobase_filterfunc)
                    end
                end
            else
                extend(wordlist, abbrev_dict[base], nobase_filterfunc)
            end
        end
        return vim.list(wordlist)
    end
end

-- refresh_abbrev_table() {{{1
--
-- Goes through all listed buffers to refresh our abbreviation table from the buffers
-- indicated by `mode`:
--
--   current buffer  = 1
--   visible buffers = 2
--   listed buffers  = 3
--
-- If `force` is true, we refresh without checking for buffer modification.
--
function refresh_abbrev_table(mode, force)
    local listed_bufinfo = vim.fn.getbufinfo(vim.dict({ buflisted = 1 }))
    local listed_bufnr_dict = {} -- Used to track which buffers still exist
    local bufinfos_to_examine = {}
    local casefold = truthy(vim.g.camelcomplete_casefold)

    -- If casefold has changed, we need to do a complete refresh (note that if force is true,
    -- we were already called synthetically by CamelComplete)
    if not force and casefold ~= last_casefold then
        mode = 3
        force = true
    end

    -- Go through all listed buffers to extract the buffer info of those that match our mode
    local cur_bufnr = vim.buffer().number
    for bufinfo in listed_bufinfo() do
        listed_bufnr_dict[bufinfo.bufnr] = true  -- Mark the buffer as present
        if mode == 1 and #bufinfos_to_examine == 0 then
            if bufinfo.bufnr == cur_bufnr then
                table.insert(bufinfos_to_examine, bufinfo)
                -- We do not break here because we need to keep updating our listed_bufnr_dict
            end
        elseif mode == 2 then
            if #bufinfo.windows ~= 0 then
                table.insert(bufinfos_to_examine, bufinfo)
            end
        elseif mode == 3 then
            table.insert(bufinfos_to_examine, bufinfo)
        end
    end

    -- Remove any entry in buffer_abbrev_table that is no longer listed
    for bufnr, _ in pairs(buffer_abbrev_table) do
        if not listed_bufnr_dict[bufnr] then
            buffer_abbrev_table[bufnr] = nil
        end
    end

    -- Now do the actual processing
    local bufs_processed = 0
    for _, bufinfo in ipairs(bufinfos_to_examine) do
        local bufnr = bufinfo.bufnr
        local bufentry = buffer_abbrev_table[bufnr]
        if not bufentry then
            local abbrev_dict = {}
            process_buffer(bufnr, abbrev_dict, casefold)
            buffer_abbrev_table[bufnr] = {abbrev_dict, bufinfo.changedtick, bufinfo.name}
            bufs_processed = bufs_processed + 1
        else
            if force or bufinfo.changedtick > bufentry[2] then
                bufentry[1] = {}
                process_buffer(bufnr, bufentry[1], casefold)
                bufentry[2] = bufinfo.changedtick
                bufentry[3] = bufinfo.name
                bufs_processed = bufs_processed + 1
            end
        end
    end

    last_refresh_mode = mode
    last_casefold = casefold
end


-- process_buffer() {{{1
--
-- Parses the text of buffer with number `bufnr` to find all applicable words and add
-- mappings in `abbrev_dict` from their abbreviations to a list of matching words.
-- If `casefold` is true, then abbreviations (i.e. the keys in the dict) will be lowercase.

function process_buffer(bufnr, abbrev_dict, casefold)
    local buf = vim.buffer(bufnr)
    -- If the language of a buffer has dashes in keywords (like CSS or HTML),
    -- then we will handle dashes in our abbreviations.
    local isk = vim.fn.getbufvar(bufnr, '&iskeyword')
    -- HTML normally doesn't have '-' in iskeyword, so we treat it specially.
    local dash_in_keywords = vim.fn.getbufvar(bufnr, '&filetype') == 'html' or
                    isk:find(',-', 1, true) or isk:find('-,', 1, true)
    local line_words_re = dash_in_keywords and line_words_dash_re or line_words_nodash_re
    -- Keep track of words we've already encountered, so that we don't process them multiple times.
    local seen_words = {}
    for i = 1, #buf do
        local line = buf[i]
        for word in rex.split(line, line_words_re) do
            if #word == 0 or seen_words[word] then goto nextword end
            seen_words[word] = true
            if not worthy_word(word) then goto nextword end
            local parts
            if dash_in_keywords and word:find('-') then
                parts = gather_splits(word, dash_parts_re)
            else
                parts = gather_splits(word, word_parts_re)
            end
            if #parts == 1 then goto nextword end  -- There's no point in indexing a 1-part word
            local abbrev = ""
            for _, part in ipairs(parts) do
                abbrev = abbrev .. (isdigit(part) and part or part:sub(1,1))
            end
            if casefold then abbrev = abbrev:lower() end
            local wordlist = abbrev_dict[abbrev]
            if not wordlist then
                abbrev_dict[abbrev] = {word}
            else
                table.insert(wordlist, word)
            end
            ::nextword::
        end -- for word
    end -- for lines in buf
end

-- dump_abbrev_map() {{{1

function dump_abbrev_map()
    -- Stick a non-integer key in the table so it's encoded as an object rather than an array
    buffer_abbrev_table['_'] = 'camelcomplete buffer_abbrev_table'
    print(json.encode(buffer_abbrev_table, { indent = true, keyorder = {'_'} }))
    buffer_abbrev_table['_'] = nil
end

-- clear_abbrev_map() {{{1
--
-- Clear the main abbreviation table -- useful during profiling. We remove all the entries
-- rather than create a new table so that its identity doesn't change.

function clear_abbrev_map()
    for k,_ in pairs(buffer_abbrev_table) do
        buffer_abbrev_table[k] = nil
    end
end
