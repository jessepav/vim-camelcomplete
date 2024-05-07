vim9script

# Vim plugin for CamelCase, snake_case, and dash-words completion.
# Last Change: April 20, 2024
# Maintainer:	Jesse Pavel <jpavel@gmail.com>

                        #########################################
                        # CamelComplete, as in the days of old! #
                        #########################################

# Regexp definitions {{{1

# Regexp to gather word parts from a list of words.
#
# It's composed of divers parts:
#
#  1. Uppercase to lowercase transitions
#  2. A run of uppercase letters preceding an uppercase-to-lowercase transition
#  3. A run of all uppercase or all lowercase letters at the end of a word or before a separator
#  4. A run of lowercase letters at the start of a word
#  5. A digit
#  6. A run of lowercase letters after a separator
#

const word_parts_re = '\v' .. ['[A-Z][a-z]+',
                               '[A-Z]{-1,}\ze[A-Z][a-z]',
                               '%([A-Z]+|[a-z]+)\ze%(>|[\-_0-9])',
                               '<[a-z]+',
                               '\d',
                               '[\-_]\zs[a-z]+']->join('|')

# These regexps are used to gather identifiers from a buffer, depending on whether
# a dash '-' is a valid part of an identifier.
const identifier_nodash_re = '\%#=2\v<[A-Za-z_][A-Za-z0-9_]{3,}>'
const identifier_dash_re = '\%#=2\v<[A-Za-z_][A-Za-z0-9_\-]{3,}>'

# Script-scope variables {{{1

# Our main index, which maps {bufnr: [abbrev_dict, b:changetick, buffer name]}. An
# 'abbrev_dict', used throughout the plugin, is a mapping from an abbreviation, like 'aSD'
# to a list of possible completion entries, ex. ['allSaintsDay', 'avoidSomeDisaster']
var buffer_abbrev_table: dict<list<any>> = {}

# Used for regenerating our table if necessary
var last_refresh_mode: number = 0
var last_casefold: bool = false

# CamelComplete() and helpers {{{1
#
# A completion function (:h complete-functions), for use with 'completefunc' or 'omnifunc'
#
def CamelComplete(findstart: number, base_: string): any
  if findstart
    const pos = match(getline('.'), '\i\+\%.c')
    return pos >= 0 ? pos : -3
  endif

  final casefold: bool = get(g:, 'camelcomplete_casefold') ? true : false
  final prefixmatch: bool = get(g:, 'camelcomplete_prefix_match') ? true : false
  final base: string = casefold ? tolower(base_) : base_

  if last_refresh_mode == 0  # Make sure there's something to complete with
    RefreshAbbrevTable(1, true)
  elseif last_casefold != casefold
    Debugprint("CamelComplete(): casefold mode changed: refreshing abbreviation table...")
    RefreshAbbrevTable(3, true)
  endif

  # All the abbrev dicts that we'll examine in our loop below
  final abbrev_dicts: list<dict<list<string>>> = []

  # We add the current buffer's wordlist first, if it's available
  const cur_bufnr = string(bufnr())
  var need_sort = false  # indicates that we should sort the current buffer's words by line distance
  if has_key(buffer_abbrev_table, cur_bufnr)
    add(abbrev_dicts, buffer_abbrev_table[cur_bufnr][0])
    need_sort = true
  endif
  # And then add the rest
  for [bufnr, entry] in items(buffer_abbrev_table)
    if bufnr != cur_bufnr
      add(abbrev_dicts, entry[0])
    endif
  endfor

  var wordlist: list<string> = []  # The list of all candidate completions

  for abbrev_dict in abbrev_dicts
    if prefixmatch
      for abbrev in keys(abbrev_dict)
        if stridx(abbrev, base) == 0
          extend(wordlist, get(abbrev_dict, abbrev))
        endif
      endfor
    else
      extend(wordlist, get(abbrev_dict, base, []))
    endif
    if need_sort  # if present, the abbrev_dict for the current buffer will be first in abbrev_dicts
      SortByLineDistance(wordlist)
      need_sort = false
    endif
  endfor
  wordlist->filter((i, v) => v != base)   # do not suggest the base itself
  return wordlist
enddef

def SortByLineDistance(wordlist: list<string>)
  const curlnum = line('.')
  const stopline_back = max([1, curlnum - 200])
  const stopline_forw = min([line('$'), curlnum + 200])

  def LineDistance(word: string): number
    const searchbackline = search('\<' .. word .. '\>', 'bnWz', stopline_back)
    const searchforwline = search('\<' .. word .. '\>', 'nWz', stopline_forw)
    var backdist: number = searchbackline == 0 ? 100000 : abs(curlnum - searchbackline)
    var forwdist: number = searchforwline == 0 ? 100000 : abs(curlnum - searchforwline)
    return backdist < forwdist ? backdist : forwdist
  enddef

  var word_dists: list<list<any>> = []
  for word in wordlist
    word_dists->add([word, LineDistance(word)])
  endfor
  word_dists->sort((e1, e2) => e1[1] - e2[1])
  wordlist->filter('0')
  for entry in word_dists
    wordlist->add(entry[0])
  endfor
enddef

# RefreshAbbrevTable() {{{1
#
# Goes through all listed buffers to refresh our abbreviation table from the buffers
# indicated by `mode`:
#
#   current buffer  = 1
#   visible buffers = 2
#   listed buffers  = 3
#
# If `force` is true, we refresh without checking for buffer modification.
#
# If curbuf_surrounding_lines > 0, and the current buffer already has an entry in the
# buffer_abbrev_table, we search only the given number of lines around the cursor, instead
# of refreshing the whole buffer. This is useful for large files.

def RefreshAbbrevTable(mode_: number, force_: bool = false, curbuf_surrounding_lines: number = 0)
  final listed_bufinfo = getbufinfo({ buflisted: 1 })
  final listed_bufnr_dict: dict<bool> = {} # Used to track which buffers still exist
  final bufinfos_to_examine: list<dict<any>> = []
  final casefold: bool = get(g:, 'camelcomplete_casefold') ? true : false

  # We do this since arguments are immutable
  var mode = mode_
  var force = force_

  # If casefold has changed, we need to do a complete refresh (note that if force is true,
  # we were already called synthetically by CamelComplete)
  if !force && casefold != last_casefold
    Debugprint("RefreshAbbrevTable(): casefold mode changed: refreshing abbreviation table...")
    mode = 3
    force = true
  endif

  # Go through all listed buffers to extract the buffer info of those that match our mode
  for bufinfo in listed_bufinfo
    listed_bufnr_dict[bufinfo.bufnr] = true  # Mark the buffer as present
    if mode == 1 && empty(bufinfos_to_examine)
      if bufinfo.bufnr == bufnr()
        add(bufinfos_to_examine, bufinfo)
        # We do not break here because we need to keep updating our listed_bufnr_dict
      endif
    elseif mode == 2
      if !empty(bufinfo.windows)
        add(bufinfos_to_examine, bufinfo)
      endif
    elseif mode == 3
      add(bufinfos_to_examine, bufinfo)
    endif
  endfor

  # Remove any entry in buffer_abbrev_table that is no longer listed
  for bufnr_str in keys(buffer_abbrev_table)
    if !has_key(listed_bufnr_dict, bufnr_str)
      remove(buffer_abbrev_table, bufnr_str)
    endif
  endfor

  # Now do the actual processing
  var bufs_processed = 0
  for bufinfo in bufinfos_to_examine
    const bufnr_str = string(bufinfo.bufnr)  # Since dicts are keyed by strings
    final bufentry: list<any> = buffer_abbrev_table->get(bufnr_str, null_list)
    if bufentry == null_list
      final abbrev_dict = {}
      ProcessBuffer(bufinfo.bufnr, abbrev_dict, casefold, 1, bufinfo.linecount)
      buffer_abbrev_table[bufnr_str] = [abbrev_dict, bufinfo.changedtick, bufinfo.name]
      bufs_processed += 1
    else
      if force || bufinfo.changedtick > bufentry[1]
        final abbrev_dict = bufentry[0]
        if bufinfo.bufnr == bufnr() && curbuf_surrounding_lines > 0
          # (We leave the abbrev dict alone on purpose.)
          const curline = line('.')
          ProcessBuffer(bufinfo.bufnr, abbrev_dict, casefold,
                        max([1, curline - curbuf_surrounding_lines]),
                        min([bufinfo.linecount, curline + curbuf_surrounding_lines]))
        else
          filter(abbrev_dict, (i, v) => false)   # Clear the abbrev dict
          ProcessBuffer(bufinfo.bufnr, abbrev_dict, casefold, 1, bufinfo.linecount)
        endif
        bufentry[1] = bufinfo.changedtick
        bufs_processed += 1
      endif
    endif
  endfor
  Debugprint($"RefreshAbbrevTable(): processed {bufs_processed} buffers, skipped {len(bufinfos_to_examine) - bufs_processed}")

  last_refresh_mode = mode
  last_casefold = casefold
enddef

# ProcessBuffer() {{{1
#
# Parses the text of buffer with number `bufnr` to find all applicable words and add
# mappings in `abbrev_dict` from their abbreviations to a list of matching words.
# If `casefold` is true, then abbreviations (i.e. the keys in the dict) will be lowercase.
#
# first_line and last_line give the range of line numbers in the buffer to process.

def ProcessBuffer(bufnr: number, abbrev_dict: dict<list<string>>, casefold: bool,
                  first_line: number, last_line: number)
  # If the language of a buffer has dashes in keywords (like CSS or HTML),
  # then we will handle dashes in our abbreviations.
  const isk = getbufvar(bufnr, '&iskeyword')
  # HTML normally doesn't have '-' in iskeyword, so we treat it specially.
  const dash_in_keywords: bool =
          getbufvar(bufnr, '&filetype') == 'html' ||
          stridx(isk, ',-') != -1 || stridx(isk, '-,') != -1
  const identifier_re = dash_in_keywords ? identifier_dash_re : identifier_nodash_re

  # First we gather all the unique words into a list
  final bufwords: list<string> = []
  final seen_words: dict<bool> = {}
  if !empty(abbrev_dict)  # We might have some words in there already
    for wordlist in abbrev_dict->values()
      for word in wordlist
        seen_words[word] = true
      endfor
    endfor
  endif
  const bufpath = getbufinfo(bufnr)[0].name
  if get(g:, 'camelcomplete_use_rg') != 0 && !bufpath->empty()
    # The identifier_re indicies are to strip off Vim-specific syntax
    final matches = systemlist($"rg -wo '{identifier_re[8 : -2]}' '{bufpath}'")
    for word in matches
      if !has_key(seen_words, word)
        bufwords->add(word)
        seen_words[word] = true
      endif
    endfor
  else
    final matches = matchbufline(bufnr, identifier_re, first_line, last_line)
    for match in matches
      const word = match.text
      if !has_key(seen_words, word)
        bufwords->add(word)
        seen_words[word] = true
      endif
    endfor
  endif

  # Now we process the word parts
  def ProcessWordParts(wordparts: list<string>, word: string)
    if len(wordparts) < 2  # there's no point in indexing this
      return
    endif
    var abbrev = join(map(wordparts, (k, v) => v[0]), '')
    if casefold
      abbrev = tolower(abbrev)
    endif
    final wordlist: list<string> = abbrev_dict->get(abbrev, null_list)
    if wordlist == null_list
      abbrev_dict[abbrev] = [word]
    else
      add(wordlist, word)
    endif
  enddef

  var curidx = 0
  var wordparts = []
  final word_part_matches = matchstrlist(bufwords, word_parts_re)
  for partmatch in word_part_matches
    if partmatch.idx != curidx  # We've gathered a whole word's parts
      ProcessWordParts(wordparts, bufwords[curidx])
      wordparts = []
      curidx = partmatch.idx
    endif
    wordparts->add(partmatch.text)
  endfor
  if len(wordparts) != 0
    ProcessWordParts(wordparts, bufwords[-1])
  endif
enddef

# DumpBufAbbrevMap() {{{1
#
# Print out our main abbreviation table. If `prettyprint` is true, use `jq` to format the
# abbreviation table as JSON
#
def DumpBufAbbrevMap(prettyprint: bool = false)
  if prettyprint
    echo system('jq', json_encode(buffer_abbrev_table))
  else
    echo buffer_abbrev_table
  endif
enddef

# ClearAbbrevMap() {{{1
#
# Clear the main abbreviation table -- useful during profiling.
#
def ClearAbbrevMap()
  filter(buffer_abbrev_table, (i, v) => false)
enddef

# Debugprint() {{{1
#
def Debugprint(msg: string)
  if exists("g:camelcomplete_debug") && g:camelcomplete_debug != 0
    echo msg
    if mode() == 'i'
      exe $"sleep {g:camelcomplete_debug}m"
    endif
  endif
enddef

# Mappings and commands -------------------- {{{1

# Marshals strings to numbers and passes them along to RefreshAbbrevTable()
def RefreshBuffersCommand(mode: string, curbuf_surrounding_lines: string = "0")
  RefreshAbbrevTable(str2nr(mode), false, str2nr(curbuf_surrounding_lines))
enddef

def ExportCompletionFunction(name: string)
  g:[name] = CamelComplete
enddef

command! -nargs=0 CamelCompleteInstall            set completefunc=CamelComplete
command! -nargs=+ CamelCompleteRefreshBuffers     RefreshBuffersCommand(<f-args>)
command! -nargs=? CamelCompleteDumpBufAbbrevMap   DumpBufAbbrevMap(<args>)
command! -nargs=0 CamelCompleteClearAbbrevMap     ClearAbbrevMap()
command! -nargs=1 CamelCompleteExportFunc         ExportCompletionFunction(<f-args>)

if empty(&completefunc)
  set completefunc=CamelComplete
endif

# vim: set tw=90 sw=2 ts=2 fdm=marker:
