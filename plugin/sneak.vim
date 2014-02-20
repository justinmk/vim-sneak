" sneak.vim - The missing motion
" Author:       Justin M. Keyes
" Version:      1.7.1
" License:      MIT

if exists('g:loaded_sneak_plugin') || &compatible || v:version < 700
  finish
endif
let g:loaded_sneak_plugin = 1

let s:cpo_save = &cpo
set cpo&vim

"persist state for repeat
let s:st = { 'rst':1, 'input':'', 'inputlen':0, 'op':'', 'reverse':0, 'count':0, 'bounds':[0,0], 'inclusive':0 }

func! sneak#init()
  unlockvar g:sneak#opt
  "options                                 v-- for backwards-compatibility
  let g:sneak#opt = { 'f_reset' : get(g:, 'sneak#nextprev_f', get(g:, 'sneak#f_reset', 1))
      \ ,'t_reset'      : get(g:, 'sneak#nextprev_t', get(g:, 'sneak#t_reset', 1))
      \ ,'s_next'       : get(g:, 'sneak#s_next', 1)
      \ ,'textobject_z' : get(g:, 'sneak#textobject_z', 1)
      \ ,'use_ic_scs'   : get(g:, 'sneak#use_ic_scs', 0)
      \ ,'map_netrw'    : get(g:, 'sneak#map_netrw', 1)
      \ ,'streak'       : get(g:, 'sneak#streak', 0) && (v:version >= 703) && has("conceal")
      \ }

  for k in ['f', 't'] "if user mapped f/t to Sneak, then disable f/t reset.
    if maparg(k, 'n') =~# 'Sneak'
      let g:sneak#opt[k.'_reset'] = 0
    endif
  endfor
  lockvar g:sneak#opt
endf

call sneak#init()

func! s:is_sneaking()
  return exists("#SneakPlugin#CursorMoved#<buffer>")
endf

" convenience wrapper for key bindings/mappings
func! sneak#wrap(op, inputlen, reverse, inclusive, streak) range abort
  " don't repeat the last 's' search if this is an 'f' search, etc.
  let is_similar_invocation = a:inputlen == s:st.inputlen && a:inclusive == s:st.inclusive
  let v = sneak#util#isvisualop(a:op)
  "TRICKY: use v:prevcount for visual mapping because we <esc> before the ex command.
  let l:count = max([1, v ? v:prevcount : v:count1])

  if g:sneak#opt.s_next && (v || empty(a:op)) && s:is_sneaking() && is_similar_invocation
    call sneak#rpt(a:op, l:count, a:reverse) " s goes to next match
  else " s invokes new search
    call sneak#to(a:op, s:getnchars(a:inputlen, a:op), a:inputlen, l:count, 0, a:reverse, a:inclusive, a:streak)
  endif
endf

"repeat *motion* (not operation)
func! sneak#rpt(op, count, reverse) range abort
  if s:st.rst "reset by f/F/t/T
    exec "norm! ".(sneak#util#isvisualop(a:op) ? "gv" : "").a:count.(a:reverse ? "," : ";")
    return
  endif

  call sneak#to(a:op, s:st.input, s:st.inputlen, a:count, 1,
        \ ((a:reverse && !s:st.reverse) || (!a:reverse && s:st.reverse)), s:st.inclusive, 0)
endf

" input:      may be shorter than inputlen if the user pressed <enter> at the prompt.
" inclusive:  0 => like t, 1 => like f, 2 => like /
func! sneak#to(op, input, inputlen, count, repeatmotion, reverse, inclusive, streak) range abort "{{{
  if empty(a:input) "user canceled
    redraw | echo '' | return
  endif

  let is_op = !empty(a:op) && !sneak#util#isvisualop(a:op) "operator-pending invocation
  let s = g:sneak#search#instance
  call s.init(a:input, a:repeatmotion, a:reverse)

  " [count] means 'skip this many' _only_ for operators/repeat-motion/2-char-search
  "   sanity check: max out at 999, to avoid searchpos() OOM.
  let skip = (is_op || a:repeatmotion || a:inputlen < 2) ? min([999, a:count]) : 0

  let l:gt_lt = a:reverse ? '<' : '>'
  let l:bounds = a:repeatmotion ? s:st.bounds : [0,0] " [left_bound, right_bound]
  let l:scope_pattern = '' " pattern used to highlight the vertical 'scope'
  let l:match_bounds  = ''

  "scope to a column of width 2*(v:count1) _except_ for operators/repeat-motion/1-char-search
  if ((!skip && a:count > 1) || max(l:bounds) > 0) && !is_op
    " use current bounds if any, otherwise derive bounds from range
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
    "adjust logical left-bound for the _match_ pattern by -length(s) so that if _any_
    "char is within the logical bounds, it is considered a match.
    let l:leftbound = max([0, (bounds[0] - a:inputlen) + 1])
    let l:match_bounds   = '\%>'.l:leftbound.'v\%<'.l:bounds[1].'v'
    let s.match_pattern .= l:match_bounds
  endif

  if !a:repeatmotion "this is a new (not repeat) invocation
    "persist even if the search fails, because the _reverse_ direction might have a match.
    let s:st.rst = 0 | let s:st.input = a:input | let s:st.inputlen = a:inputlen | let s:st.op = a:op
    let s:st.reverse = a:reverse | let s:st.count = a:count | let s:st.bounds = l:bounds | let s:st.inclusive = a:inclusive

    "set temporary hooks on f/F/t/T so that we know when to reset Sneak.
    call s:ft_hook()
  endif

    for i in range(1, max([1, skip])) "jump to the [count]th match
      let matchpos = s.dosearch()
      if 0 == max(matchpos)
        break
      endif
    endfor

    "if the user was in visual mode, extend the selection.
    if sneak#util#isvisualop(a:op)
      norm! gv
      if max(matchpos) > 0 | call cursor(matchpos) | endif
    endif

    if 0 == max(matchpos)
      let km = empty(&keymap) ? '' : ' ('.&keymap.' keymap)'
      call sneak#util#echo('not found'.((max(l:bounds) > 0) ? printf(km.' (in columns %d-%d): %s', l:bounds[0], l:bounds[1], a:input) : km.': '.a:input))
      return
    endif
  "search succeeded

  call sneak#hl#removehl()

  "position _after_ completed search
  let l:curlin = string(line('.'))
  let l:curcol = string(virtcol('.') + (a:reverse ? -1 : 1))

  "Might as well scope to window height (+/- 99).
  let l:top = max([0, line('w0')-99])
  let l:bot = line('w$')+99
  let l:restrict_top_bot = '\%'.l:gt_lt.l:curlin.'l\%>'.l:top.'l\%<'.l:bot.'l'
  let l:scope_pattern .= l:restrict_top_bot
  let s.match_pattern .= l:restrict_top_bot
  let l:curln_pattern  = l:match_bounds.'\%'.l:curlin.'l\%'.l:gt_lt.l:curcol.'v'

  "highlight the vertical 'tunnel' that the search is scoped-to
  if max(l:bounds) > 0 "perform the scoped highlight...
    let w:sneak_sc_hl = matchadd('SneakPluginScope', l:scope_pattern)
  endif

  call s:attach_autocmds()

  "highlight actual matches at or below the cursor position
  "  - store in w: because matchadd() highlight is per-window.
  let w:sneak_hl_id = matchadd('SneakPluginTarget',
        \ (s.prefix).s.match_pattern.'\zs'.(s.search).'\|'.l:curln_pattern.(s.search))

  "enter streak-mode iff there are >=2 _additional_ on-screen matches.
  let target = (2 == a:streak || (a:streak && g:sneak#opt.streak)) && 0 == max(l:bounds) && s.hasmatches(2)
        \ ? sneak#streak#to(s, s:st): ""

  if is_op && a:op !=# 'y'
    "TODO: account for 't'/inclusive/exclusive
    let change = a:op !=? "c" ? "" : "\<c-r>.\<esc>"
    let rpt_input = a:input . (a:inputlen > sneak#util#strlen(a:input) ? "\<cr>" : "")
    silent! call repeat#set(a:op."\<Plug>SneakRepeat".a:inputlen.a:reverse.a:inclusive.(2*!empty(target)).rpt_input.target.change, a:count)
  endif
endf "}}}

func! s:attach_autocmds()
  augroup SneakPlugin
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave <buffer> call sneak#hl#removehl() | autocmd! SneakPlugin * <buffer>
    "_nested_ autocmd to skip the _first_ CursorMoved event.
    "NOTE: CursorMoved is _not_ triggered if there is 'typeahead', which means during a macro or other script...
    autocmd CursorMoved <buffer> autocmd SneakPlugin CursorMoved <buffer> call sneak#hl#removehl() | autocmd! SneakPlugin * <buffer>
  augroup END
endf

func! sneak#reset(key)
  let c = sneak#util#getchar()

  let s:st.rst = 1
  let s:st.reverse = 0
  for k in ['f', 't'] "unmap the temp mappings
    if g:sneak#opt[k.'_reset']
      silent! exec 'unmap '.k
      silent! exec 'unmap '.toupper(k)
    endif
  endfor

  "count is prepended implicitly by the <expr> mapping
  return a:key.c
endf

func! s:map_reset_key(key, mode)
  exec printf("%snoremap <silent> <expr> %s sneak#reset('%s')", a:mode, a:key, a:key)
endf

func! s:ft_hook() "set up temporary mappings to 'hook' into f/F/t/T
  for k in ['f', 't']
    for m in ['n', 'x']
      "if user mapped anything to f or t, do not map over it; unfortunately this
      "also means we cannot reset ; or , when f or t is invoked.
      if g:sneak#opt[k.'_reset'] && maparg(k, m) ==# ''
        call s:map_reset_key(k, m) | call s:map_reset_key(toupper(k), m)
      endif
    endfor
  endfor
endf

func! s:getnchars(n, mode)
  let s = ''
  echo '>'
  for i in range(1, a:n)
    if sneak#util#isvisualop(a:mode) | exe 'norm! gv' | endif "preserve selection
    let c = sneak#util#getchar()
    if -1 != index(["\<esc>", "\<c-c>", "\<backspace>", "\<del>"], c)
      return ""
    endif
    if c == "\<CR>"
      if i > 1 "special case: accept the current input (#15)
        break
      else "special case: repeat the last search (useful for streak-mode).
        return s:st.input
      endif
    else
      let s .= c
      if &iminsert && sneak#util#strlen(s) >= a:n
        "HACK: this can happen if the user entered multiple characters while we
        "were waiting to resolve a multi-char keymap.
        "example for keymap 'bulgarian-phonetic':
        "    e:: => ё    | resolved, strwidth=1
        "    eo  => eo   | unresolved, strwidth=2
        break
      endif
    endif
    redraw | echo '>'.s
  endfor
  return s
endf

" 2-char sneak
nnoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap('', 2, 0, 2, 1)<cr>
nnoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap('', 2, 1, 2, 1)<cr>
xnoremap <silent> <Plug>Sneak_s <esc>:<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 1)<cr>
xnoremap <silent> <Plug>Sneak_S <esc>:<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 1)<cr>

onoremap <silent> <Plug>SneakRepeat :<c-u>call sneak#wrap(v:operator, sneak#util#getc(), sneak#util#getc(), sneak#util#getc(), sneak#util#getc())<cr>

" explicit repeat (as opposed to 'clever-s' implicit repeat)
nnoremap <silent> <Plug>SneakNext      :<c-u>call sneak#rpt('', v:count1, 0)<cr>
nnoremap <silent> <Plug>SneakPrevious  :<c-u>call sneak#rpt('', v:count1, 1)<cr>
xnoremap <silent> <Plug>VSneakNext     <esc>:<c-u>call sneak#rpt(visualmode(), max([1, v:prevcount]), 0)<cr>
xnoremap <silent> <Plug>VSneakPrevious <esc>:<c-u>call sneak#rpt(visualmode(), max([1, v:prevcount]), 1)<cr>
onoremap <silent> <Plug>SneakNext      :<c-u>call sneak#rpt(v:operator, v:count1, 0)<cr>
onoremap <silent> <Plug>SneakPrevious  :<c-u>call sneak#rpt(v:operator, v:count1, 1)<cr>

if g:sneak#opt.textobject_z
  omap z  <Plug>Sneak_s
  omap Z  <Plug>Sneak_S
endif

" 1-char sneak, inclusive
nnoremap <silent> <Plug>Sneak_f      :<c-u>call sneak#wrap('', 1, 0, 1, 0)<cr>
nnoremap <silent> <Plug>Sneak_F      :<c-u>call sneak#wrap('', 1, 1, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_f <esc>:<c-u>call sneak#wrap(visualmode(), 1, 0, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_F <esc>:<c-u>call sneak#wrap(visualmode(), 1, 1, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_f      :<c-u>call sneak#wrap(v:operator, 1, 0, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_F      :<c-u>call sneak#wrap(v:operator, 1, 1, 1, 0)<cr>

" 1-char sneak, exclusive
nnoremap <silent> <Plug>Sneak_t      :<c-u>call sneak#wrap('', 1, 0, 0, 0)<cr>
nnoremap <silent> <Plug>Sneak_T      :<c-u>call sneak#wrap('', 1, 1, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_t <esc>:<c-u>call sneak#wrap(visualmode(), 1, 0, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_T <esc>:<c-u>call sneak#wrap(visualmode(), 1, 1, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_t      :<c-u>call sneak#wrap(v:operator, 1, 0, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_T      :<c-u>call sneak#wrap(v:operator, 1, 1, 0, 0)<cr>

nnoremap <Plug>SneakStreak :<c-u>call sneak#wrap('', 2, 0, 0, 0, 2)<cr>
nnoremap <Plug>SneakStreakBackward :<c-u>call sneak#wrap('', 2, 0, 0, 0, 2)<cr>

if !hasmapto('<Plug>SneakForward') && !hasmapto('<Plug>Sneak_s', 'n') && mapcheck('s', 'n') ==# ''
  nmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>SneakBackward') && !hasmapto('<Plug>Sneak_S', 'n') && mapcheck('S', 'n') ==# ''
  nmap S <Plug>Sneak_S
endif

if !hasmapto('<Plug>SneakNext', 'n') && mapcheck(';', 'n') ==# ''
  nmap ; <Plug>SneakNext
endif
if !hasmapto('<Plug>SneakPrevious', 'n')
  if mapcheck(',', 'n') ==# ''
    nmap , <Plug>SneakPrevious
  elseif mapcheck('\', 'n') ==# '' || mapcheck('\', 'n') ==# ','
    nmap \ <Plug>SneakPrevious
  endif
endif

if !hasmapto('<Plug>SneakNext', 'o') && mapcheck(';', 'o') ==# ''
  omap ; <Plug>SneakNext
endif
if !hasmapto('<Plug>SneakPrevious', 'o')
  if mapcheck(',', 'o') ==# ''
    omap , <Plug>SneakPrevious
  elseif mapcheck('\', 'o') ==# '' || mapcheck('\', 'o') ==# ','
    omap \ <Plug>SneakPrevious
  endif
endif

if !hasmapto('<Plug>VSneakForward') && !hasmapto('<Plug>Sneak_s', 'v') && mapcheck('s', 'x') ==# ''
  xmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>VSneakBackward') && !hasmapto('<Plug>Sneak_S', 'v') && mapcheck('Z', 'x') ==# ''
  xmap Z <Plug>Sneak_S
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

" redundant legacy mappings for backwards compatibility (must come _after_ the hasmapto('<Plug>Sneak_S') checks above)
nmap <Plug>SneakForward   <Plug>Sneak_s
nmap <Plug>SneakBackward  <Plug>Sneak_S
xmap <Plug>VSneakForward  <Plug>Sneak_s
xmap <Plug>VSneakBackward <Plug>Sneak_S

if g:sneak#opt.map_netrw && -1 != stridx(maparg("s", "n"), "Sneak")
  func! s:map_netrw_key(key)
    if -1 != stridx(maparg(a:key,"n"), "_Net")
      exec 'nnoremap <buffer> <silent> <leader>'.a:key.' '.maparg(a:key,'n')
      "unmap netrw's buffer-local mapping to allow Sneak's global mapping.
      silent! exe 'nunmap <buffer> '.a:key
    endif
  endf

  augroup SneakPluginNetrw
    autocmd!
    autocmd FileType netrw autocmd SneakPluginNetrw CursorMoved <buffer>
          \ call <sid>map_netrw_key('s') | call <sid>map_netrw_key('S') | autocmd! SneakPluginNetrw * <buffer>
  augroup END
endif


let &cpo = s:cpo_save
unlet s:cpo_save
