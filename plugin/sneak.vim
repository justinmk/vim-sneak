" sneak.vim - Vertical motion for Vim
" Author:       Justin M. Keyes
" Version:      1.0
" http://www.reddit.com/r/vim/comments/1io1bs/how_do_you_move_around_vertically/
" http://www.reddit.com/r/vim/comments/1j9gm1/serious_question_what_do_you_all_think_is_a/
" TODO: add to VAM pool https://github.com/MarcWeber/vim-addon-manager

if exists('g:loaded_sneak_plugin') || &compatible || v:version < 700
  finish
endif
let g:loaded_sneak_plugin = 1

let s:cpo_save = &cpo
set cpo&vim

" http://stevelosh.com/blog/2011/09/writing-vim-plugins/
" TODO: map something other than F10
func! SneakToString(op, s, count, isrepeat, isreverse, bounds) range abort
  if empty(a:s) "user canceled
    redraw | echo '' | return
  endif

  "highlight tasks:
  "  - highlight actual matches at or below (above) the cursor position
  "  - highlight the vertical "tunnel" that the search is scoped-to

  let l:search = escape(a:s, '"\')
  let l:gt_lt = a:isreverse ? '<' : '>'
  " [left_bound, right_bound] 
  let l:bounds = deepcopy(a:bounds)
  let l:count = a:count
  " example: highlight string "ab" after line 42, column 5 
  "          matchadd('foo', 'ab\%>42l\%5c', 1)
  let l:match_pattern = ''
  " pattern used to highlight the vertical "scope"
  let l:scope_pattern = ''
  " do not wrap
  let l:searchoptions = 'W'
  " search backwards
  if a:isreverse | let l:searchoptions .= 'b' | endif
  " save the jump on the initial invocation, _not_ repeats.
  if !a:isrepeat | let l:searchoptions .= 's' | endif

  if l:count > 0 || max(l:bounds) > 0 "narrow the search to a column of width +/- the specified range (v:count)
    if !empty(a:op)
      echo 'sneak: range not supported in visual mode or operator-pending mode' | return
    endif
    " use provided bounds if any, otherwise derive bounds from range
    if max(l:bounds) <= 0
      "these are the _logical_ bounds highlighted in 'scope' mode
      let l:bounds[0] =  max([0, (virtcol('.') - l:count - 1)])
      let l:bounds[1] =  l:count + virtcol('.') + 1
    endif
    "matches *all* chars in the scope.
    "important: use \%<42v (virtual column) instead of \%<42c (byte column)
    let l:scope_pattern .= '\%>'.l:bounds[0].'v\%<'.l:bounds[1].'v'
  endif

  if max(l:bounds) > 0
    "adjust logical left-bound for the _match_ pattern by -len(s) so that if _any_
    "char is within the logical bounds, it is considered a match.
    let l:leftbound = max([0, (bounds[0] - len(a:s)) + 1])
    let l:match_pattern .= '\%>'.l:leftbound.'v\%<'.l:bounds[1].'v'
  endif

  if !a:isrepeat
    "this is a new search; set up the repeat mappings.
    "do this even if the search fails, because the direction might be reversed after the initial failure.
    call <sid>map('n', ';', "",   l:search, l:count,  a:isreverse, l:bounds)
    call <sid>map('n', '\', "",   l:search, l:count, !a:isreverse, l:bounds)
    call <sid>xmap('x', ';', l:search, l:count,  a:isreverse, l:bounds)
    call <sid>xmap('x', '\', l:search, l:count, !a:isreverse, l:bounds)

    "if f/F/t/T is invoked, unmap the temporary repeat mappings
    if empty(maparg("f", "n").maparg("F", "n").maparg("t", "n").maparg("T", "n"))
      nmap <silent> f <F10>f|nmap <silent> F <F10>F|nmap <silent> t <F10>t|nmap <silent> T <F10>T
    endif
  endif

  if !empty(a:op) && !<sid>isvisualop(a:op) "operator-pending invocation
    let l:histreg = @/
    try
      "until we can find a better way, just invoke / and restore the history immediately after
      let s:last_op = 'norm! '.a:op.(a:isreverse ? '?' : '/').'\C\V'.l:search."\<cr>"
      call <sid>sneak_perform_last_operation()
    catch E486
      echo 'not found: '.a:s | return
    finally
      call histdel("/", histnr("/")) "delete the last search from the history
      let @/ = l:histreg
    endtry
  else "jump to the first match, or exit
    let l:matchpos = searchpos('\C\V'.l:match_pattern.'\zs'.l:search, l:searchoptions)
    if 0 == max(l:matchpos)
      if max(l:bounds) > 0
        echo printf('not found (in columns %d-%d): %s', l:bounds[0], l:bounds[1], a:s) | return
      else
        echo 'not found: '.a:s | return
      endif
    endif
  endif
  "search succeeded

  "if the user was in visual mode, extend the selection.
  if <sid>isvisualop(a:op)
    norm! gv
    call cursor(l:matchpos[0], l:matchpos[1])
  endif

  silent! call matchdelete(w:sneak_hl_id)
  silent! call matchdelete(w:sneak_sc_hl)

  "position _after_ completed search
  let l:start_lin_str = string(line('.') + (a:isreverse ? 1 : -1))

  "Might as well scope to window height (+/- 40). TODO: profile this
  let l:top = max([0, line('w0')-40])
  let l:bot = min([line('$'), line('w$')+40])
  let l:restrict_top_bot = '\%'.l:gt_lt.l:start_lin_str.'l\%>'.l:top.'l\%<'.l:bot.'l'
  let l:scope_pattern .= l:restrict_top_bot
  let l:match_pattern .= l:restrict_top_bot
  let l:curln_pattern  = l:restrict_top_bot

  if l:count > 0
    "perform the scoped highlight...
    let w:sneak_sc_hl = matchadd('SneakPluginScope', l:scope_pattern, 1, get(w:, 'sneak_sc_hl', -1))
  endif

  augroup SneakPlugin
    autocmd!
    autocmd InsertEnter <buffer> silent! call matchdelete(w:sneak_hl_id) | 
          \ silent! call matchdelete(w:sneak_sc_hl) |
          \ autocmd! SneakPlugin
    "set up *nested* CursorMoved autocmd to avoid the _first_ CursorMoved event.
    autocmd CursorMoved <buffer> autocmd SneakPlugin CursorMoved <buffer> silent! call matchdelete(w:sneak_hl_id) |
          \ silent! call matchdelete(w:sneak_sc_hl) |
          \ autocmd! SneakPlugin
  augroup END

  "perform the match highlight...
  "  - scope to window because matchadd() highlight is per-window.
  "  - re-use w:sneak_hl_id if it exists (-1 lets matchadd() choose).
  let w:sneak_hl_id = matchadd('SneakPluginMatch', '\C\V'.l:match_pattern.'\zs'.l:search, 2, get(w:, 'sneak_hl_id', -1))
endf

func! s:sneak_perform_last_operation()
  if !exists('s:last_op') | return | endif
  exec s:last_op
  silent! call repeat#set("\<Plug>SneakRepeat")
endf
nnoremap <silent> <Plug>SneakRepeat :<c-u>call <sid>sneak_perform_last_operation()<cr>
func! s:map(mode, keyseq, op, search, count, isreverse, bounds)
  exec printf('%snoremap <silent> %s :<c-u>call SneakToString("%s", "%s", %d, 1, %d, [%d, %d])'."\<cr>",
        \ a:mode, a:keyseq, a:op, a:search, a:count, a:isreverse, a:bounds[0], a:bounds[1])
endf
func! s:xmap(mode, keyseq, search, count, isreverse, bounds)
  exec printf('%snoremap <silent> %s <esc>:<c-u>call SneakToString(visualmode(), "%s", %d, 1, %d, [%d, %d])'."\<cr>",
        \ a:mode, a:keyseq, a:search, a:count, a:isreverse, a:bounds[0], a:bounds[1])
endf
func! s:isvisualop(op)
  return -1 != index(["V", "v", "\<c-v>"], a:op)
endf
func! s:getInputChar()
  let l:c = getchar()
  return type(l:c) == type(0) ? nr2char(l:c) : l:c
endf
func! s:getNextNChars(n)
  let l:s = ''
  for i in range(1, a:n)
    let l:c = <sid>getInputChar()
    if -1 != index(["\<esc>", "\<c-c>", "\<backspace>", "\<del>"], l:c)
      return ""
    endif
    let l:s .= l:c
    redraw | echo l:s
  endfor
  return l:s
endf
func! SneakDebugReport()
  redir => l:s
    silent echo 'buftype='.&buftype
    silent echo 'virtualedit='.&virtualedit
    silent exec 'verbose map s | map S | map z | map Z'
  redir END
  enew
  silent put=l:s
  "set nomodified
endf

augroup SneakPluginInit
  autocmd!
  highlight SneakPluginMatch guifg=white guibg=magenta ctermfg=white ctermbg=magenta
  autocmd ColorScheme * highlight SneakPluginMatch guifg=white guibg=magenta ctermfg=white ctermbg=magenta

  if &background ==# 'dark'
    highlight SneakPluginScope guifg=black guibg=white ctermfg=black ctermbg=white
    autocmd ColorScheme * highlight SneakPluginScope guifg=black guibg=white ctermfg=black ctermbg=white
  else
    highlight SneakPluginScope guifg=white guibg=black ctermfg=white ctermbg=black
    autocmd ColorScheme * highlight SneakPluginScope guifg=white guibg=black ctermfg=white ctermbg=black
  endif
augroup END

nnoremap <F10> :<c-u>unmap f<bar>unmap F<bar>unmap t<bar>unmap T<bar>unmap ;<bar>exe 'unmap \'<bar>silent! call matchdelete(w:sneak_hl_id)<cr>
nnoremap <silent> s      :<c-u>call SneakToString('',           <sid>getNextNChars(2), v:count, 0, 0, [0,0])<cr>
nnoremap <silent> S      :<c-u>call SneakToString('',           <sid>getNextNChars(2), v:count, 0, 1, [0,0])<cr>
nnoremap <silent> yz     :<c-u>call SneakToString('y',          <sid>getNextNChars(2), v:count, 0, 0, [0,0])<cr>
nnoremap <silent> yZ     :<c-u>call SneakToString('y',          <sid>getNextNChars(2), v:count, 0, 1, [0,0])<cr>
onoremap <silent> z      :<c-u>call SneakToString(v:operator,   <sid>getNextNChars(2), v:count, 0, 0, [0,0])<cr>
onoremap <silent> Z      :<c-u>call SneakToString(v:operator,   <sid>getNextNChars(2), v:count, 0, 1, [0,0])<cr>
xnoremap <silent> s <esc>:<c-u>call SneakToString(visualmode(), <sid>getNextNChars(2), v:count, 0, 0, [0,0])<cr>
xnoremap <silent> Z <esc>:<c-u>call SneakToString(visualmode(), <sid>getNextNChars(2), v:count, 0, 1, [0,0])<cr>


let &cpo = s:cpo_save
unlet s:cpo_save
