" CamelComplete configuration {{{

let g:camelcomplete_casefold = 0     " Set to 1 to perform case-insensitive camel completion
let g:camelcomplete_prefix_match = 0 " Set to 1 to allow abbreviation prefixes to match (could be slow)

nnoremap <silent> <Leader>ccf :let g:camelcomplete_casefold = !g:camelcomplete_casefold<Bar>
    \ echo "CamelComplete casefolding is " .. (camelcomplete_casefold ? "enabled." : "disabled.")<CR>
nnoremap <silent> <Leader>ccp :let g:camelcomplete_prefix_match = !g:camelcomplete_prefix_match<Bar>
    \ echo "CamelComplete prefix matching is " .. (camelcomplete_prefix_match ? "enabled." : "disabled.")<CR>

inoremap <M-,> <Cmd>CamelCompleteRefreshBuffers 1<CR><C-X><C-U>
inoremap <M-.> <Cmd>CamelCompleteRefreshBuffers 2<CR><C-X><C-U>
inoremap <M-/> <Cmd>CamelCompleteRefreshBuffers 3<CR><C-X><C-U>
" A quick refresh-and-complete of the current buffer.
inoremap <M-m> <Cmd>CamelCompleteRefreshBuffers 1 200<CR><C-X><C-U>
" We also set up an imap for doing plain old <C-X><C-U>
inoremap <M-y> <C-X><C-U>
" Finally, if you want to update the abbrev index without actually performing completion
nmap <Leader>cc1 <Cmd>CamelCompleteRefreshBuffers 1<CR>
nmap <Leader>cc2 <Cmd>CamelCompleteRefreshBuffers 2<CR>
nmap <Leader>cc3 <Cmd>CamelCompleteRefreshBuffers 3<CR>
" And some debug commands
nmap <Leader>ccd <Cmd>CamelCompleteDumpBufAbbrevMap<CR>
nmap <Leader>cc0 <Cmd>CamelCompleteClearAbbrevMap<CR><Cmd>echo "CamelComplete abbrev-map cleared."<CR>

" CamelComplete configuration }}}
