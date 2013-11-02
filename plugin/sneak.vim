" sneak.vim - The missing motion
" Author:       Justin M. Keyes
" Version:      1.2
" License:      MIT

if exists('g:loaded_sneak_plugin') || &compatible || v:version < 700
  finish
endif
let g:loaded_sneak_plugin = 1

let s:cpo_save = &cpo
set cpo&vim

"persist state for repeat
let s:st = { 'search':'', 'op':'', 'reverse':0, 'count':0, 'bounds':[0,0] }

"options                                 v-- for backwards-compatibility
let s:opt = { 'f_reset' : get(g:, 'sneak#nextprev_f', get(g:, 'sneak#f_reset', 1))
      \ ,'t_reset'      : get(g:, 'sneak#nextprev_t', get(g:, 'sneak#t_reset', 1))
      \ ,'textobject_z' : get(g:, 'sneak#textobject_z', 1)
      \ ,'use_ic_scs'   : get(g:, 'sneak#use_ic_scs', 0)
      \ ,'map_netrw'    : get(g:, 'sneak#map_netrw', 1)
      \ }

"repeat *motion* (not operation)
func! sneak#rpt(op, count, reverse) range abort
  if empty(s:st.search) "state was reset by f/F/t/T
    exec "norm! ".(s:isvisualop(a:op) ? "gv" : "").a:count.(a:reverse ? "," : ";")
    return
  endif

  call sneak#to(a:op, s:st.search, a:count, 1,
        \ ((a:reverse && !s:st.reverse) || (!a:reverse && s:st.reverse)), s:st.bounds)
endf

func! sneak#to(op, s, count, repeatmotion, reverse, bounds) range abort
  if empty(a:s) "user canceled
    redraw | echo '' | return
  endif

  "highlight tasks:
  "  - highlight actual matches at or below (above) the cursor position
  "  - highlight the vertical 'tunnel' that the search is scoped-to

  let l:search = escape(a:s, '"\')

  " {count} prefix means 'skip this many' _only_ on repeat-motion.
  "   sanity check: max out at 999, to avoid searchpos() OOM.
  let skip = a:repeatmotion ? min([999, a:count]) : 0

  let sprefix = (s:opt.use_ic_scs ? '' : '\C').'\V'
  let l:gt_lt = a:reverse ? '<' : '>'
  let l:bounds = deepcopy(a:bounds) " [left_bound, right_bound]
  " example: highlight string "ab" after line 42, column 5 
  "          matchadd('foo', 'ab\%>42l\%5c', 1)
  let l:match_pattern = ''
  " pattern used to highlight the vertical 'scope'
  let l:scope_pattern = ''
  let l:match_bounds  = ''
  " do not wrap
  let l:searchoptions = 'W'
  " search backwards
  if a:reverse | let l:searchoptions .= 'b' | endif
  " save the jump on the initial invocation, _not_ repeats.
  if !a:repeatmotion | let l:searchoptions .= 's' | endif

  "scope to a column of width 2*(v:count1) _unless_ this is a repeat-motion.
  if ((!skip && a:count > 1) || max(l:bounds) > 0) && (empty(a:op) || s:isvisualop(a:op))
    " use provided bounds if any, otherwise derive bounds from range
    if max(l:bounds) <= 0
      "these are the _logical_ bounds highlighted in 'scope' mode
      let l:bounds[0] =  max([0, (virtcol('.') - a:count - 1)])
      let l:bounds[1] =  a:count + virtcol('.') + 1
    endif
    "matches *all* chars in the scope.
    "important: use \%<42v (virtual column) instead of \%<42c (byte column)
    let l:scope_pattern .= '\%>'.l:bounds[0].'v\%<'.l:bounds[1].'v'
  endif

  if max(l:bounds) > 0
    "adjust logical left-bound for the _match_ pattern by -len(s) so that if _any_
    "char is within the logical bounds, it is considered a match.
    let l:leftbound = max([0, (bounds[0] - len(a:s)) + 1])
    let l:match_bounds   = '\%>'.l:leftbound.'v\%<'.l:bounds[1].'v'
    let l:match_pattern .= l:match_bounds
  endif

  if !a:repeatmotion "this is a new (not repeat) invocation
    "persist even if the search fails, because the _reverse_ direction might have a match.
    let s:st.search = a:s | let s:st.op = a:op | let s:st.count = a:count | let s:st.bounds = l:bounds | let s:st.reverse = a:reverse

    "set temporary hooks on f/F/t/T so that we know when to reset Sneak.
    call s:ft_hook()
  endif

  if !empty(a:op) && !s:isvisualop(a:op) "operator-pending invocation
    let l:histreg = @/
    let wrap = &wrapscan | let &wrapscan = 0

    try
      " invoke / and restore the history immediately after
      silent! exec 'norm! '.a:op.(a:reverse ? '?' : '/').sprefix.l:search."\<cr>"
      if a:op !=# 'y'
        let s:last_op = deepcopy(s:st)
        " repeat c as d (this matches Vim default behavior)
        if a:op =~# '^[cd]$' | let s:last_op.op = 'd' | endif
        silent! call repeat#set("\<Plug>SneakRepeat")
      endif
    catch E486
      call s:notfound(': '.a:s) | return
    finally
      call histdel("/", histnr("/")) "delete the last search from the history
      let @/ = l:histreg
      let &wrapscan = wrap
    endtry
  else "jump to the first match, or exit
    for i in range(1, max([1, skip]))
      let matchpos = searchpos(sprefix.l:match_pattern.'\zs'.l:search, l:searchoptions)
      if 0 == max(matchpos)
        break
      endif
    endfor

    "if the user was in visual mode, extend the selection.
    if s:isvisualop(a:op)
      norm! gv
      if max(matchpos) > 0 | call cursor(matchpos) | endif
    endif

    if 0 == max(matchpos)
      call s:notfound((max(l:bounds) > 0) ? printf(' (in columns %d-%d): %s', l:bounds[0], l:bounds[1], a:s) : ': '.a:s)
      return
    endif
  endif
  "search succeeded

  call s:removehl()

  "position _after_ completed search
  let l:curlin = string(line('.'))
  let l:curcol = string(virtcol('.') + (a:reverse ? -1 : 1))

  "Might as well scope to window height (+/- 99). TODO: profile this
  let l:top = max([0, line('w0')-99])
  let l:bot = min([line('$'), line('w$')+99])
  let l:restrict_top_bot = '\%'.l:gt_lt.l:curlin.'l\%>'.l:top.'l\%<'.l:bot.'l'
  let l:scope_pattern .= l:restrict_top_bot
  let l:match_pattern .= l:restrict_top_bot
  let l:curln_pattern  = l:match_bounds.'\%'.l:curlin.'l\%'.l:gt_lt.l:curcol.'v'

  if max(l:bounds) > 0 "perform the scoped highlight...
    let w:sneak_sc_hl = matchadd('SneakPluginScope', l:scope_pattern, 1, get(w:, 'sneak_sc_hl', -1))
  endif

  call s:attach_autocmds()

  "perform the match highlight...
  "  - scope to window because matchadd() highlight is per-window.
  "  - re-use w:sneak_hl_id if it exists (-1 lets matchadd() choose).
  let w:sneak_hl_id = matchadd('SneakPluginTarget',
        \ sprefix.l:match_pattern.'\zs'.l:search.'\|'.l:curln_pattern.l:search,
        \ 2, get(w:, 'sneak_hl_id', -1))
endf

func! s:notfound(msg)
  redraw | echo 'not found'.a:msg
  augroup SneakNotFound "clear 'not found' message at next opportunity.
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave * redraw | echo '' | autocmd! SneakNotFound
    autocmd CursorMoved * redraw | echo '' | autocmd! SneakNotFound
  augroup END
endf

func! s:attach_autocmds()
  augroup SneakPlugin
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave <buffer> call <sid>removehl() | autocmd! SneakPlugin * <buffer>
    "set up *nested* CursorMoved autocmd to skip the _first_ CursorMoved event.
    autocmd CursorMoved <buffer> autocmd SneakPlugin CursorMoved <buffer> call <sid>removehl() | autocmd! SneakPlugin * <buffer>
  augroup END
endf

func! s:init()
  for k in ['f', 't']
    if maparg(k, 'n') =~# '<Plug>Sneak'
      let s:opt[k.'_reset'] = 0
    endif
  endfor
endf
call s:init()

func! sneak#reset(count, visual, key)
  if a:visual
    norm! gv
  endif
  let s:st.search = ""
  let s:st.reverse = 0
  for k in ['f', 'F', 't', 'T'] "unmap _all_ temp mappings to mitigate #21.
    silent! exec 'unmap '.k
  endfor
  "feed the keys exactly once, with the correct count
  call feedkeys(max([1, a:count]).a:key)
endf

func! s:map_reset_key(key, mode)
  "if user mapped anything to f or t, do not map over it; unfortunately this
  "also means we cannot reset ; or , when f or t is invoked.
  if mapcheck(a:key, a:mode) ==# ''
    let v = ("x" ==# a:mode)
    "use v:prevcount for visual mapping because we <esc> before the ex command.
    let c = v ?  'v:prevcount' : 'v:count1'
    exec printf("%snoremap <silent> %s %s:<c-u>call sneak#reset(%s, %d, '%s')\<cr>",
          \ a:mode, a:key, (v ? "<esc>" : ""), c, v, a:key)
  endif
endf

func! s:ft_hook() "set up temporary mappings to 'hook' into f/F/t/T
  if s:opt.f_reset
    call s:map_reset_key("f", "n") | call s:map_reset_key("F", "n")
    call s:map_reset_key("f", "x") | call s:map_reset_key("F", "x")
  endif
  if s:opt.t_reset
    call s:map_reset_key("t", "n") | call s:map_reset_key("T", "n")
    call s:map_reset_key("t", "x") | call s:map_reset_key("T", "x")
  endif
endf

func! s:removehl() "remove highlighting
  silent! call matchdelete(w:sneak_hl_id)
  silent! call matchdelete(w:sneak_sc_hl)
endf

func! s:repeat_last_op()
  let st = s:last_op
  call sneak#to(st.op, st.search, st.count, 0, st.reverse, st.bounds)
  silent! call repeat#set("\<Plug>SneakRepeat")
endf

func! s:isvisualop(op)
  return a:op =~# "^[vV\<C-v>]"
endf

func! s:getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

func! s:getnchars(n, mode)
  let s = ''
  echo '>'
  for i in range(1, a:n)
    "preserve existing selection
    if s:isvisualop(a:mode) | exe 'norm! gv' | endif
    let c = s:getchar()
    if -1 != index(["\<esc>", "\<c-c>", "\<backspace>", "\<del>"], c)
      return ""
    endif
    if i > 1 && c ==# "\<CR>"
      "special case: accept the current input (feature #15)
      break
    else
      let s .= c
    endif
    redraw | echo '>'.s
  endfor
  return s
endf

func! s:cnt(...) "if an arg is passed, it means 'visual mode'
  "TRICKY: use v:prevcount for visual mapping because we <esc> before the ex command.
  return max([1, a:0 ? v:prevcount : v:count1])
endf

augroup SneakPluginColors
  autocmd!

  if 0 == hlID("SneakPluginTarget")
    highlight SneakPluginTarget guifg=white guibg=magenta ctermfg=white ctermbg=magenta
    autocmd ColorScheme * highlight SneakPluginTarget guifg=white guibg=magenta ctermfg=white ctermbg=magenta
  endif

  if 0 == hlID("SneakPluginScope")
    if &background ==# 'dark'
      highlight SneakPluginScope guifg=black guibg=white ctermfg=black ctermbg=white
      autocmd ColorScheme * highlight SneakPluginScope guifg=black guibg=white ctermfg=black ctermbg=white
    else
      highlight SneakPluginScope guifg=white guibg=black ctermfg=white ctermbg=black
      autocmd ColorScheme * highlight SneakPluginScope guifg=white guibg=black ctermfg=white ctermbg=black
    endif
  endif
augroup END

nnoremap <silent> <Plug>SneakForward   :<c-u>call sneak#to('', <sid>getnchars(2, ''), <sid>cnt(), 0, 0, [0,0])<cr>
nnoremap <silent> <Plug>SneakBackward  :<c-u>call sneak#to('', <sid>getnchars(2, ''), <sid>cnt(), 0, 1, [0,0])<cr>
nnoremap <silent> <Plug>SneakNext      :<c-u>call sneak#rpt('', <sid>cnt(), 0)<cr>
nnoremap <silent> <Plug>SneakPrevious  :<c-u>call sneak#rpt('', <sid>cnt(), 1)<cr>

xnoremap <silent> <Plug>VSneakForward  <esc>:<c-u>call sneak#to(visualmode(), <sid>getnchars(2, visualmode()), <sid>cnt(1), 0, 0, [0,0])<cr>
xnoremap <silent> <Plug>VSneakBackward <esc>:<c-u>call sneak#to(visualmode(), <sid>getnchars(2, visualmode()), <sid>cnt(1), 0, 1, [0,0])<cr>
xnoremap <silent> <Plug>VSneakNext     <esc>:<c-u>call sneak#rpt(visualmode(), <sid>cnt(1), 0)<cr>
xnoremap <silent> <Plug>VSneakPrevious <esc>:<c-u>call sneak#rpt(visualmode(), <sid>cnt(1), 1)<cr>

if s:opt.textobject_z
  nnoremap <silent> yz :<c-u>call sneak#to('y',        <sid>getnchars(2, 'y'), <sid>cnt(), 0, 0, [0,0])<cr>
  nnoremap <silent> yZ :<c-u>call sneak#to('y',        <sid>getnchars(2, 'y'), <sid>cnt(), 0, 1, [0,0])<cr>
  onoremap <silent> z  :<c-u>call sneak#to(v:operator, <sid>getnchars(2, v:operator), <sid>cnt(), 0, 0, [0,0])<cr>
  onoremap <silent> Z  :<c-u>call sneak#to(v:operator, <sid>getnchars(2, v:operator), <sid>cnt(), 0, 1, [0,0])<cr>
endif

nnoremap <silent> <Plug>SneakRepeat :<c-u>call <sid>repeat_last_op()<cr>

if !hasmapto('<Plug>SneakForward') && mapcheck('s', 'n') ==# ''
  nmap s <Plug>SneakForward
endif
if !hasmapto('<Plug>SneakBackward') && mapcheck('S', 'n') ==# ''
  nmap S <Plug>SneakBackward
endif

if !hasmapto('<Plug>SneakNext') && mapcheck(';', 'n') ==# ''
  nmap ; <Plug>SneakNext
endif
if !hasmapto('<Plug>SneakPrevious')
  if mapcheck(',', 'n') ==# ''
    nmap , <Plug>SneakPrevious
  elseif mapcheck('\', 'n') ==# ''
    nmap \ <Plug>SneakPrevious
  endif
endif

if !hasmapto('<Plug>VSneakForward') && mapcheck('s', 'x') ==# ''
  xmap s <Plug>VSneakForward
endif
if !hasmapto('<Plug>VSneakBackward') && mapcheck('Z', 'x') ==# ''
  xmap Z <Plug>VSneakBackward
endif

if !hasmapto('<Plug>VSneakNext') && mapcheck(';', 'x') ==# ''
  xmap ; <Plug>VSneakNext
endif
if !hasmapto('<Plug>VSneakPrevious')
  if mapcheck(',', 'x') ==# ''
    xmap , <Plug>VSneakPrevious
  elseif mapcheck('\', 'x') ==# ''
    xmap \ <Plug>VSneakPrevious
  endif
endif

if s:opt.map_netrw && -1 != stridx(maparg("s", "n"), "Sneak")
  func! s:map_netrw_key(key)
    if -1 != stridx(maparg(a:key,"n"), "_Net")
      exec 'nnoremap <buffer> <silent> <leader>'.a:key.' '.maparg(a:key,'n')
      "unmap netrw's buffer-local mapping to allow Sneak's global mapping.
      silent! exe 'nunmap <buffer> '.a:key
    endif
  endf

  augroup SneakPluginNetrw
    autocmd!
    autocmd filetype netrw autocmd SneakPluginNetrw CursorMoved <buffer>
          \ call <sid>map_netrw_key('s') | call <sid>map_netrw_key('S') | autocmd! SneakPluginNetrw * <buffer>
  augroup END
endif


let &cpo = s:cpo_save
unlet s:cpo_save
