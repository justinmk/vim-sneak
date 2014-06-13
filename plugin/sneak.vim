" sneak.vim - The missing motion
" Author:       Justin M. Keyes
" Version:      1.7.2
" License:      MIT

if exists('g:loaded_sneak_plugin') || &compatible || v:version < 700
  finish
endif
let g:loaded_sneak_plugin = 1

let s:cpo_save = &cpo
set cpo&vim

"persist state for repeat
let s:st = { 'rst':1, 'input':'', 'inputlen':0, 'reverse':0, 'bounds':[0,0], 'inclusive':0 }

func! sneak#init()
  unlockvar g:sneak#opt
  "options                                 v-- for backwards-compatibility
  let g:sneak#opt = { 'f_reset' : get(g:, 'sneak#nextprev_f', get(g:, 'sneak#f_reset', 1))
      \ ,'t_reset'      : get(g:, 'sneak#nextprev_t', get(g:, 'sneak#t_reset', 1))
      \ ,'s_next'       : get(g:, 'sneak#s_next', 0)
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

func! sneak#is_sneaking()
  return exists("#SneakPlugin#CursorMoved#<buffer>")
endf

func! sneak#cancel()
  call sneak#hl#removehl()
  autocmd! SneakPlugin * <buffer>
  if maparg('<esc>', 'n') =~# 'sneak#cancel' "teardown temporary <esc> mapping
    silent! unmap <esc>
  endif
endf

" convenience wrapper for key bindings/mappings
func! sneak#wrap(op, inputlen, reverse, inclusive, streak) abort
  let cnt = v:count1 "get count before doing _anything_, else it gets overwritten.
  " don't clever-repeat the last 's' search if this is an 'f' search, etc.
  let is_similar_invocation = a:inputlen == s:st.inputlen && a:inclusive == s:st.inclusive

  if g:sneak#opt.s_next && is_similar_invocation && (sneak#util#isvisualop(a:op) || empty(a:op)) && sneak#is_sneaking()
    call sneak#rpt(a:op, a:reverse) " s goes to next match
  else " s invokes new search
    call sneak#to(a:op, s:getnchars(a:inputlen, a:op), a:inputlen, cnt, 0, a:reverse, a:inclusive, a:streak)
  endif
endf

"repeat *motion* (not operation)
func! sneak#rpt(op, reverse) abort
  if s:st.rst "reset by f/F/t/T
    exec "norm! ".(sneak#util#isvisualop(a:op) ? "gv" : "").v:count1.(a:reverse ? "," : ";")
    return
  endif

  call sneak#to(a:op, s:st.input, s:st.inputlen, v:count1, 1,
        \ ((a:reverse && !s:st.reverse) || (!a:reverse && s:st.reverse)), s:st.inclusive, 0)
endf

" input:      may be shorter than inputlen if the user pressed <enter> at the prompt.
" inclusive:  0 => like t, 1 => like f, 2 => like /
func! sneak#to(op, input, inputlen, count, repeatmotion, reverse, inclusive, streak) abort "{{{
  if empty(a:input) "user canceled
    redraw | echo '' | return
  endif

  let is_v  = sneak#util#isvisualop(a:op)
  let [curlin, curcol] = [line('.'), virtcol('.')] "initial position
  let is_op = !empty(a:op) && !is_v "operator-pending invocation
  let s = g:sneak#search#instance
  call s.init(a:input, a:repeatmotion, a:reverse)

  if is_v && a:repeatmotion
    norm! gv
  endif

  " [count] means 'skip this many' _only_ for operators/repeat-motion/2-char-search
  "   sanity check: max out at 999, to avoid searchpos() OOM.
  let skip = (is_op || a:repeatmotion || a:inputlen < 2) ? min([999, a:count]) : 0

  let l:gt_lt = a:reverse ? '<' : '>'
  let bounds = a:repeatmotion ? s:st.bounds : [0,0] " [left_bound, right_bound]
  let l:scope_pattern = '' " pattern used to highlight the vertical 'scope'
  let l:match_bounds  = ''

  "scope to a column of width 2*(v:count1) _except_ for operators/repeat-motion/1-char-search
  if ((!skip && a:count > 1) || max(bounds)) && !is_op
    if !max(bounds) "derive bounds from count (_logical_ bounds highlighted in 'scope')
      let bounds[0] = max([0, (virtcol('.') - a:count - 1)])
      let bounds[1] = a:count + virtcol('.') + 1
    endif
    "Match *all* chars in scope. Use \%<42v (virtual column) instead of \%<42c (byte column).
    let l:scope_pattern .= '\%>'.bounds[0].'v\%<'.bounds[1].'v'
  endif

  if max(bounds)
    "adjust logical left-bound for the _match_ pattern by -length(s) so that if _any_
    "char is within the logical bounds, it is considered a match.
    let l:leftbound = max([0, (bounds[0] - a:inputlen) + 1])
    let l:match_bounds   = '\%>'.l:leftbound.'v\%<'.bounds[1].'v'
    let s.match_pattern .= l:match_bounds
  endif

  "TODO: refactor vertical scope calculation into search.vim,
  "      so this can be done in s.init() instead of here.
  call s.initpattern()

  if !a:repeatmotion "this is a new (not repeat) invocation
    "persist even if the search fails, because the _reverse_ direction might have a match.
    let s:st.rst = 0 | let s:st.input = a:input | let s:st.inputlen = a:inputlen
    let s:st.reverse = a:reverse | let s:st.bounds = bounds | let s:st.inclusive = a:inclusive

    "set temporary hooks on f/F/t/T so that we know when to reset Sneak.
    call s:ft_hook()
  endif

  if is_op && 2 != a:inclusive
    norm! v
  endif

  let nextchar = searchpos('\_.', 'n'.(s.search_options_no_s))
  let nudge = !a:inclusive && a:repeatmotion && nextchar == s.dosearch('n')
  if nudge
    let nudge = sneak#util#nudge(!a:reverse) "special case for t
  endif

  for i in range(1, max([1, skip])) "jump to the [count]th match
    let matchpos = s.dosearch()
    if 0 == max(matchpos)
      break
    else
      let nudge = !a:inclusive
    endif
  endfor

  if nudge && (!is_v || max(matchpos) > 0)
    call sneak#util#nudge(a:reverse) "undo nudge for t
  endif

  if 0 == max(matchpos)
    let km = empty(&keymap) ? '' : ' ('.&keymap.' keymap)'
    call sneak#util#echo('not found'.(max(bounds) ? printf(km.' (in columns %d-%d): %s', bounds[0], bounds[1], a:input) : km.': '.a:input))
    return
  endif
  "search succeeded

  call sneak#hl#removehl()

  if (!is_op || a:op ==# 'y') "position _after_ search
    let curlin = string(line('.'))
    let curcol = string(virtcol('.') + (a:reverse ? -1 : 1))
  endif

  "Might as well scope to window height (+/- 99).
  let l:top = max([0, line('w0')-99])
  let l:bot = line('w$')+99
  let l:restrict_top_bot = '\%'.l:gt_lt.curlin.'l\%>'.l:top.'l\%<'.l:bot.'l'
  let l:scope_pattern .= l:restrict_top_bot
  let s.match_pattern .= l:restrict_top_bot
  let curln_pattern  = l:match_bounds.'\%'.curlin.'l\%'.l:gt_lt.curcol.'v'

  "highlight the vertical 'tunnel' that the search is scoped-to
  if max(bounds) "perform the scoped highlight...
    let w:sneak_sc_hl = matchadd('SneakPluginScope', l:scope_pattern)
  endif

  call s:attach_autocmds()

  "highlight actual matches at or below the cursor position
  "  - store in w: because matchadd() highlight is per-window.
  let w:sneak_hl_id = matchadd('SneakPluginTarget',
        \ (s.prefix).(s.match_pattern).(s.search).'\|'.curln_pattern.(s.search))

  "let user deactivate with <esc>
  if maparg('<esc>', 'n') ==# ""|nmap <silent> <esc> :<c-u>call sneak#cancel()<cr><esc>|endif

  "enter streak-mode iff there are >=2 _additional_ on-screen matches.
  let target = (2 == a:streak || (a:streak && g:sneak#opt.streak)) && !max(bounds) && s.hasmatches(2)
        \ ? sneak#streak#to(s, is_v, a:reverse): ""

  if !is_op
    if "" != target && "\<Esc>" != target
      call sneak#hl#removehl()
    endif
  elseif a:op !=# 'y'
    let change = a:op !=? "c" ? "" : "\<c-r>.\<esc>"
    let rpt_input = a:input . (a:inputlen > sneak#util#strlen(a:input) ? "\<cr>" : "")
    silent! call repeat#set(a:op."\<Plug>SneakRepeat".a:inputlen.a:reverse.a:inclusive.(2*!empty(target)).rpt_input.target.change, a:count)
  endif
endf "}}}

func! s:attach_autocmds()
  augroup SneakPlugin
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave <buffer> call sneak#cancel()
    "_nested_ autocmd to skip the _first_ CursorMoved event.
    "NOTE: CursorMoved is _not_ triggered if there is 'typeahead', i.e. during a macro or script...
    autocmd CursorMoved <buffer> autocmd SneakPlugin CursorMoved <buffer> call sneak#cancel()
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
      if 1 == &iminsert && sneak#util#strlen(s) >= a:n
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
xnoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 1)<cr>
xnoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_s :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 1)<cr>
onoremap <silent> <Plug>Sneak_S :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 1)<cr>

onoremap <silent> <Plug>SneakRepeat :<c-u>call sneak#wrap(v:operator, sneak#util#getc(), sneak#util#getc(), sneak#util#getc(), sneak#util#getc())<cr>

" explicit repeat (as opposed to 'clever-s' implicit repeat)
nnoremap <silent> <Plug>SneakNext     :<c-u>call sneak#rpt('', 0)<cr>
nnoremap <silent> <Plug>SneakPrevious :<c-u>call sneak#rpt('', 1)<cr>
xnoremap <silent> <Plug>SneakNext     :<c-u>call sneak#rpt(visualmode(), 0)<cr>
xnoremap <silent> <Plug>SneakPrevious :<c-u>call sneak#rpt(visualmode(), 1)<cr>
onoremap <silent> <Plug>SneakNext     :<c-u>call sneak#rpt(v:operator, 0)<cr>
onoremap <silent> <Plug>SneakPrevious :<c-u>call sneak#rpt(v:operator, 1)<cr>

if g:sneak#opt.textobject_z
  omap z  <Plug>Sneak_s
  omap Z  <Plug>Sneak_S
endif

" 1-char sneak, inclusive
nnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap('', 1, 0, 1, 0)<cr>
nnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap('', 1, 1, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(visualmode(), 1, 0, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(visualmode(), 1, 1, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(v:operator, 1, 0, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(v:operator, 1, 1, 1, 0)<cr>

" 1-char sneak, exclusive
nnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap('', 1, 0, 0, 0)<cr>
nnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap('', 1, 1, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(visualmode(), 1, 0, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(visualmode(), 1, 1, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(v:operator, 1, 0, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(v:operator, 1, 1, 0, 0)<cr>

nnoremap <silent> <Plug>(SneakStreak)         :<c-u>call sneak#wrap('', 2, 0, 2, 2)<cr>
nnoremap <silent> <Plug>(SneakStreakBackward) :<c-u>call sneak#wrap('', 2, 1, 2, 2)<cr>
xnoremap <silent> <Plug>(SneakStreak)         :<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 2)<cr>
xnoremap <silent> <Plug>(SneakStreakBackward) :<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 2)<cr>
onoremap <silent> <Plug>(SneakStreak)         :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 2)<cr>
onoremap <silent> <Plug>(SneakStreakBackward) :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 2)<cr>

if !hasmapto('<Plug>SneakForward') && !hasmapto('<Plug>Sneak_s', 'n') && mapcheck('s', 'n') ==# ''
  nmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>SneakBackward') && !hasmapto('<Plug>Sneak_S', 'n') && mapcheck('S', 'n') ==# ''
  nmap S <Plug>Sneak_S
endif

if !hasmapto('<Plug>SneakNext', 'n') && mapcheck(';', 'n') ==# ''
  nmap ; <Plug>SneakNext
  omap ; <Plug>SneakNext
  xmap ; <Plug>SneakNext
endif
if !hasmapto('<Plug>SneakPrevious', 'n')
  if mapcheck(',', 'n') ==# ''
    nmap , <Plug>SneakPrevious
    omap , <Plug>SneakPrevious
    xmap , <Plug>SneakPrevious
  elseif mapcheck('\', 'n') ==# '' || mapcheck('\', 'n') ==# ','
    nmap \ <Plug>SneakPrevious
    omap \ <Plug>SneakPrevious
    xmap \ <Plug>SneakPrevious
  endif
endif

if !hasmapto('<Plug>VSneakForward') && !hasmapto('<Plug>Sneak_s', 'v') && mapcheck('s', 'x') ==# ''
  xmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>VSneakBackward') && !hasmapto('<Plug>Sneak_S', 'v') && mapcheck('Z', 'x') ==# ''
  xmap Z <Plug>Sneak_S
endif

" redundant legacy mappings for backwards compatibility (must come _after_ the hasmapto('<Plug>Sneak_S') checks above)
nmap <Plug>SneakForward   <Plug>Sneak_s
nmap <Plug>SneakBackward  <Plug>Sneak_S
xmap <Plug>VSneakForward  <Plug>Sneak_s
xmap <Plug>VSneakBackward <Plug>Sneak_S
xmap <Plug>VSneakNext     <Plug>SneakNext
xmap <Plug>VSneakPrevious <Plug>SneakPrevious

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
