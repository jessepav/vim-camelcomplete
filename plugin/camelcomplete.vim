vim9script

# Vim plugin for completing CamelCase and snake_case words from their abbreviations.
# Last Change: January 11, 2023
# Maintainer:	Jesse Pavel <jpavel@gmail.com>

                        #########################################
                        # CamelComplete, as in the days of old! #
                        #########################################

# pattern to gather up applicable words (in this case, those over 4 letters) from buffers
const gather_words_re = '\w\{4,}'

# and once we gather words, we split them into camelCase or snake_case parts
const split_word_re   = '\%([a-z]\zs\ze[A-Z]\)\|_\+\|\%(\d\zs\ze\a\)\|\%(\a\zs\ze\d\)'

# Our main index, which maps {bufnr: [b:changetick, abbrev_dict]}
var buffer_abbrev_table: dict<list<any>> = {}

# Used for regenerating our table if necessary
var last_refresh_mode: number = 0
var last_casefold: bool = false

#
# A completion function (:h complete-functions), for use with 'completefunc' or 'omnifunc'
#
def CamelComplete(findstart: number, base_: string): any
  if findstart
    const pos = match(getline('.'), '\w\+\%.c')
    return pos >= 0 ? pos : -3
  else
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

    # We do the current buffer's wordlist first
    const cur_bufnr = string(bufnr())
    add(abbrev_dicts, buffer_abbrev_table[cur_bufnr][1])
    # And then add the rest
    for bufnr in keys(buffer_abbrev_table)
      if bufnr !=# cur_bufnr
        add(abbrev_dicts, buffer_abbrev_table[bufnr][1])
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
    endfor
    return wordlist
  endif
enddef

# Goes through all listed buffers to refresh our abbreviation table from the buffers
# indicated by `mode`:
#
#   current buffer  = 1
#   visible buffers = 2
#   listed buffers  = 3
#
# If `force` is true, we refresh without checking for buffer modification.
#
def RefreshAbbrevTable(mode_: number, force_: bool = false)
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
    if !has_key(buffer_abbrev_table, bufnr_str)
      final abbrev_dict = {}
      ProcessBuffer(bufinfo.bufnr, abbrev_dict, casefold)
      buffer_abbrev_table[bufnr_str] = [bufinfo.changedtick, abbrev_dict]
      bufs_processed += 1
    else
      final bufentry: list<any> = get(buffer_abbrev_table, bufnr_str)
      if force || bufinfo.changedtick > bufentry[0]
        filter(bufentry[1], (k, v) => false)   # Clear the abbrev dict
        ProcessBuffer(bufinfo.bufnr, bufentry[1], casefold)
        bufentry[0] = bufinfo.changedtick
        bufs_processed += 1
      endif
    endif
  endfor
  Debugprint($"RefreshAbbrevTable(): processed {bufs_processed} buffers, skipped {len(bufinfos_to_examine) - bufs_processed}")

  last_refresh_mode = mode
  last_casefold = casefold
enddef

#
# Parses the text of buffer with number `bufnr` to find all applicable words and add
# mappings in `abbrev_dict` from their abbreviations to a list of matching words.
# If `casefold` is true, then abbreviations (i.e. the keys in the dict) will be lowercase.
#
def ProcessBuffer(bufnr: number, abbrev_dict: dict<list<string>>, casefold: bool)
  # Keep track of words we've already encountered, so that we can `continue` the loop
  # early and avoid the expensive splitting and joining further down.
  final seen_words: dict<bool> = {}
  for line in getbufline(bufnr, 1, '$')
    for word in MatchAll(line, gather_words_re)
      if has_key(seen_words, word)
        continue
      endif
      var parts = split(word, split_word_re, false)
      if len(parts) == 1  # There's no point in indexing this
        continue
      endif
      var abbrev = join(map(parts, (k, v) => v[0]), '')
      if casefold
        abbrev = tolower(abbrev)
      endif
      final wordlist: list<string> = get(abbrev_dict, abbrev, null_list)
      if wordlist == null_list
        abbrev_dict[abbrev] = [word]
      else  # We are guaranteed not to have seen the word before
        add(wordlist, word)
      endif
      seen_words[word] = true
    endfor
  endfor
enddef

#
# Returns a list of all the matches of `pattern` in `str`
#
def MatchAll(str: string, pattern: string): list<string>
  var matches: list<string> = []
  var pos = 0
  while pos != -1
    const [mstr, start, end] = matchstrpos(str, pattern, pos)
    pos = end
    if pos != -1
      add(matches, mstr)
    endif
  endwhile
  return matches
enddef

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

def Debugprint(msg: string)
  if exists("g:camelcomplete_debug") && g:camelcomplete_debug != 0
    echo msg
    if mode() == 'i'
      exe $"sleep {g:camelcomplete_debug}m"
    endif
  endif
enddef
# ----------------- Mappings and such --------------------

nnoremap <Plug>CamelCompleteRefreshCurrentBuffer  <ScriptCmd>RefreshAbbrevTable(1)<CR>
nnoremap <Plug>CamelCompleteRefreshVisibleBuffers <ScriptCmd>RefreshAbbrevTable(2)<CR>
nnoremap <Plug>CamelCompleteRefreshAllBuffers     <ScriptCmd>RefreshAbbrevTable(3)<CR>
inoremap <Plug>CamelCompleteRefreshCurrentBuffer  <ScriptCmd>RefreshAbbrevTable(1)<CR>
inoremap <Plug>CamelCompleteRefreshVisibleBuffers <ScriptCmd>RefreshAbbrevTable(2)<CR>
inoremap <Plug>CamelCompleteRefreshAllBuffers     <ScriptCmd>RefreshAbbrevTable(3)<CR>

inoremap <Plug>CamelCompleteRefreshAndComplete    <ScriptCmd>RefreshAbbrevTable(3)<CR><C-X><C-U>

command! -nargs=? CamelCompleteDumpBufAbbrevMap   DumpBufAbbrevMap(<args>)
command! -nargs=0 CamelCompleteInstall            set completefunc=CamelComplete

if empty(&completefunc)
  set completefunc=CamelComplete
endif

# vim: set tw=90 sw=2 ts=2:
