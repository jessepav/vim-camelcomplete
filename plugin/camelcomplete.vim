" Vim plugin for completing CamelCase and snake_case words from their abbreviations.
" Last Change: August 7, 2023
" Maintainer:	Jesse Pavel <jpavel@gmail.com>

                        """""""""""""""""""""""""""""""""""""""""
                        " CamelComplete, as in the days of old! "
                        """""""""""""""""""""""""""""""""""""""""

if !has("lua")
  echom "camelcomplete: has('lua') required"
else
  lua << EOF
    local status = pcall(function()
      require("camelcomplete")
    end)
    vim.g['camelcomplete_lua_requires_present'] = status
EOF
  if !g:camelcomplete_lua_requires_present
    echom "camelcomplete: required Lua modules not available - check LUA_PATH and LUA_CPATH"
    unlet! g:camelcomplete_lua_requires_present
    finish
  endif
  unlet! g:camelcomplete_lua_requires_present
endif

function! CamelCompleteFunc(findstart, base)
  return luaeval("camelcomplete.camel_complete(_A[1], _A[2])", [a:findstart, a:base])
endfunction

nnoremap <Plug>CamelCompleteRefreshCurrentBuffer  <Cmd>lua camelcomplete.refresh_abbrev_table(1)<CR>
nnoremap <Plug>CamelCompleteRefreshVisibleBuffers <Cmd>lua camelcomplete.refresh_abbrev_table(2)<CR>
nnoremap <Plug>CamelCompleteRefreshAllBuffers     <Cmd>lua camelcomplete.refresh_abbrev_table(3)<CR>
inoremap <Plug>CamelCompleteRefreshCurrentBuffer  <Cmd>lua camelcomplete.refresh_abbrev_table(1)<CR>
inoremap <Plug>CamelCompleteRefreshVisibleBuffers <Cmd>lua camelcomplete.refresh_abbrev_table(2)<CR>
inoremap <Plug>CamelCompleteRefreshAllBuffers     <Cmd>lua camelcomplete.refresh_abbrev_table(3)<CR>

inoremap <Plug>CamelCompleteRefreshAndComplete    <Cmd>lua camelcomplete.refresh_abbrev_table(3)<CR><C-X><C-U>

command! -nargs=0 CamelCompleteDumpBufAbbrevMap   lua camelcomplete.dump_abbrev_map()<CR>
command! -nargs=0 CamelCompleteClearAbbrevMap     lua camelcomplete.clear_abbrev_map()<CR>

if empty(&completefunc)
  set completefunc=CamelCompleteFunc
endif

" Debug functions

if !exists("*ReloadCamelComplete")
  function! ReloadCamelComplete()
lua << EOF
  package.loaded['camelcomplete'] = nil
  package.loaded['jessepav.utils'] = nil
  require 'camelcomplete'
EOF
    source <script>
  endfunction
endif

" vim: set tw=90 sw=2 ts=2 fdm=marker syntax=off:
