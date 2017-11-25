" sneak.vim - The missing motion
" Author:       Justin M. Keyes
" Version:      1.8
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
      \ ,'absolute_dir' : get(g:, 'sneak#absolute_dir', 0)
      \ ,'use_ic_scs'   : get(g:, 'sneak#use_ic_scs', 0)
      \ ,'map_netrw'    : get(g:, 'sneak#map_netrw', 1)
      \ ,'label'        : get(g:, 'sneak#label', get(g:, 'sneak#streak', 0)) && (v:version >= 703) && has("conceal")
      \ ,'label_esc'    : get(g:, 'sneak#label_esc', get(g:, 'sneak#streak_esc', "\<space>"))
      \ ,'prompt'       : get(g:, 'sneak#prompt', '>')
      \ }

  for k in ['f', 't'] "if user mapped f/t to Sneak, then disable f/t reset.
    if maparg(k, 'n') =~# 'Sneak'
      let g:sneak#opt[k.'_reset'] = 0
    endif
  endfor
  lockvar g:sneak#opt
endf

call sneak#init()

func! sneak#state()
  return deepcopy(s:st)
endf

func! sneak#is_sneaking()
  return exists("#SneakPlugin#CursorMoved")
endf

func! sneak#cancel()
  call sneak#hl#removehl()
  augroup SneakPlugin
    autocmd!
  augroup END
  if maparg('<esc>', 'n') =~# 'sneak#cancel' "teardown temporary <esc> mapping
    silent! unmap <esc>
  endif
  return ''
endf

" convenience wrapper for key bindings/mappings
func! sneak#wrap(op, inputlen, reverse, inclusive, label) abort
  let cnt = v:count1 "get count before doing _anything_, else it gets overwritten.
  " don't clever-repeat the last 's' search if this is an 'f' search, etc.
  let is_similar_invocation = a:inputlen == s:st.inputlen && a:inclusive == s:st.inclusive

  if g:sneak#opt.s_next && is_similar_invocation && (sneak#util#isvisualop(a:op) || empty(a:op)) && sneak#is_sneaking()
    call sneak#rpt(a:op, a:reverse) " s goes to next match
  else " s invokes new search
    call sneak#to(a:op, s:getnchars(a:inputlen, a:op), a:inputlen, cnt, 0, a:reverse, a:inclusive, a:label)
  endif
endf

"repeat *motion* (not operation)
func! sneak#rpt(op, reverse) abort
  if s:st.rst "reset by f/F/t/T
    exec "norm! ".(sneak#util#isvisualop(a:op) ? "gv" : "").v:count1.(a:reverse ? "," : ";")
    return
  endif

  let l:relative_reverse = (a:reverse && !s:st.reverse) || (!a:reverse && s:st.reverse)
  call sneak#to(a:op, s:st.input, s:st.inputlen, v:count1, 1,
        \ (g:sneak#opt.absolute_dir ? a:reverse : l:relative_reverse), s:st.inclusive, 0)
endf

" input:      may be shorter than inputlen if the user pressed <enter> at the prompt.
" inclusive:  0: t-like, 1: f-like, 2: /-like
func! sneak#to(op, input, inputlen, count, repeatmotion, reverse, inclusive, label) abort "{{{
  if empty(a:input) "user canceled
    if a:op ==# 'c'  " user <esc> during change-operation should return to previous mode.
      call feedkeys((col('.') > 1 && col('.') < col('$') ? "\<RIGHT>" : '') . "\<C-\>\<C-G>", 'n')
    endif
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

  let s:st.rptreverse = a:reverse
  if !a:repeatmotion "this is a new (not repeat) invocation
    "persist even if the search fails, because the _reverse_ direction might have a match.
    let s:st.rst = 0 | let s:st.input = a:input | let s:st.inputlen = a:inputlen
    let s:st.reverse = a:reverse | let s:st.bounds = bounds | let s:st.inclusive = a:inclusive

    "set temporary hooks on f/F/t/T so that we know when to reset Sneak.
    call s:ft_hook()
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
    let w:sneak_sc_hl = matchadd('SneakScope', l:scope_pattern)
  endif

  call s:attach_autocmds()

  "highlight actual matches at or below the cursor position
  "  - store in w: because matchadd() highlight is per-window.
  let w:sneak_hl_id = matchadd('Sneak',
        \ (s.prefix).(s.match_pattern).(s.search).'\|'.curln_pattern.(s.search))

  "Let user deactivate with <esc>
  if (has('nvim') || has('gui_running')) && maparg('<esc>', 'n') ==# ""
    nmap <expr> <silent> <esc> sneak#cancel() . "\<esc>"
  endif

  " Operators always invoke label-mode; also for 2+ on-screen matches.
  let target = (2 == a:label || (a:label && g:sneak#opt.label && (is_op || s.hasmatches(2)))) && !max(bounds)
        \ ? sneak#label#to(s, is_v) : ""

  if is_op && 2 != a:inclusive && !a:reverse
    " f/t operations do not apply to the current character; nudge the cursor.
    call sneak#util#nudge(1)
  endif

  if is_op || "" != target
    call sneak#hl#removehl()
  endif

  if is_op && a:op !=# 'y'
    let change = a:op !=? "c" ? "" : "\<c-r>.\<esc>"
    let rpt_input = a:input . (a:inputlen > sneak#util#strlen(a:input) ? "\<cr>" : "")
    silent! call repeat#set(a:op."\<Plug>SneakRepeat".a:inputlen.a:reverse.a:inclusive.(2*!empty(target)).rpt_input.target.change, a:count)
  endif
endf "}}}

func! s:attach_autocmds()
  augroup SneakPlugin
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave * call sneak#cancel()
    "_nested_ autocmd to skip the _first_ CursorMoved event.
    "NOTE: CursorMoved is _not_ triggered if there is typeahead during a macro/script...
    autocmd CursorMoved * autocmd SneakPlugin CursorMoved * call sneak#cancel()
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
  echo g:sneak#opt.prompt
  for i in range(1, a:n)
    if sneak#util#isvisualop(a:mode) | exe 'norm! gv' | endif "preserve selection
    let c = sneak#util#getchar()
    if -1 != index(["\<esc>", "\<c-c>", "\<c-g>", "\<backspace>",  "\<del>"], c)
      return ""
    endif
    if c == "\<CR>"
      if i > 1 "special case: accept the current input (#15)
        break
      else "special case: repeat the last search (useful for label-mode).
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
    redraw | echo g:sneak#opt.prompt . s
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

" repeat motion (explicit--as opposed to implicit 'clever-s')
nnoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt('', 0)<cr>
nnoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt('', 1)<cr>
xnoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt(visualmode(), 0)<cr>
xnoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt(visualmode(), 1)<cr>
onoremap <silent> <Plug>Sneak_; :<c-u>call sneak#rpt(v:operator, 0)<cr>
onoremap <silent> <Plug>Sneak_, :<c-u>call sneak#rpt(v:operator, 1)<cr>

" 1-char 'enhanced f' sneak
nnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap('', 1, 0, 1, 0)<cr>
nnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap('', 1, 1, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(visualmode(), 1, 0, 1, 0)<cr>
xnoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(visualmode(), 1, 1, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_f :<c-u>call sneak#wrap(v:operator, 1, 0, 1, 0)<cr>
onoremap <silent> <Plug>Sneak_F :<c-u>call sneak#wrap(v:operator, 1, 1, 1, 0)<cr>

" 1-char 'enhanced t' sneak
nnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap('', 1, 0, 0, 0)<cr>
nnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap('', 1, 1, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(visualmode(), 1, 0, 0, 0)<cr>
xnoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(visualmode(), 1, 1, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_t :<c-u>call sneak#wrap(v:operator, 1, 0, 0, 0)<cr>
onoremap <silent> <Plug>Sneak_T :<c-u>call sneak#wrap(v:operator, 1, 1, 0, 0)<cr>

nnoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap('', 2, 0, 2, 2)<cr>
nnoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap('', 2, 1, 2, 2)<cr>
xnoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap(visualmode(), 2, 0, 2, 2)<cr>
xnoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap(visualmode(), 2, 1, 2, 2)<cr>
onoremap <silent> <Plug>SneakLabel_s :<c-u>call sneak#wrap(v:operator, 2, 0, 2, 2)<cr>
onoremap <silent> <Plug>SneakLabel_S :<c-u>call sneak#wrap(v:operator, 2, 1, 2, 2)<cr>

if !hasmapto('<Plug>SneakForward') && !hasmapto('<Plug>Sneak_s', 'n') && mapcheck('s', 'n') ==# ''
  nmap s <Plug>Sneak_s
endif
if !hasmapto('<Plug>SneakBackward') && !hasmapto('<Plug>Sneak_S', 'n') && mapcheck('S', 'n') ==# ''
  nmap S <Plug>Sneak_S
endif
if !hasmapto('<Plug>Sneak_s', 'o') && mapcheck('z', 'o') ==# ''
  omap z <Plug>Sneak_s
endif
if !hasmapto('<Plug>Sneak_S', 'o') && mapcheck('Z', 'o') ==# ''
  omap Z <Plug>Sneak_S
endif

if !hasmapto('<Plug>Sneak_;', 'n') && !hasmapto('<Plug>SneakNext', 'n') && mapcheck(';', 'n') ==# ''
  nmap ; <Plug>Sneak_;
  omap ; <Plug>Sneak_;
  xmap ; <Plug>Sneak_;
endif
if !hasmapto('<Plug>Sneak_,', 'n') && !hasmapto('<Plug>SneakPrevious', 'n')
  if mapcheck(',', 'n') ==# ''
    nmap , <Plug>Sneak_,
    omap , <Plug>Sneak_,
    xmap , <Plug>Sneak_,
  elseif mapcheck('\', 'n') ==# '' || mapcheck('\', 'n') ==# ','
    nmap \ <Plug>Sneak_,
    omap \ <Plug>Sneak_,
    xmap \ <Plug>Sneak_,
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
xmap <Plug>VSneakNext     <Plug>Sneak_;
xmap <Plug>VSneakPrevious <Plug>Sneak_,
nmap <Plug>(SneakStreak)         <Plug>SneakLabel_s
nmap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
xmap <Plug>(SneakStreak)         <Plug>SneakLabel_s
xmap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
omap <Plug>(SneakStreak)         <Plug>SneakLabel_s
omap <Plug>(SneakStreakBackward) <Plug>SneakLabel_S
nmap <Plug>SneakNext     <Plug>Sneak_;
nmap <Plug>SneakPrevious <Plug>Sneak_,
xmap <Plug>SneakNext     <Plug>Sneak_;
xmap <Plug>SneakPrevious <Plug>Sneak_,
omap <Plug>SneakNext     <Plug>Sneak_;
omap <Plug>SneakPrevious <Plug>Sneak_,

if g:sneak#opt.map_netrw && -1 != stridx(maparg("s", "n"), "Sneak")
  func! s:map_netrw_key(key)
    let expanded_map = maparg(a:key,'n')
    if !strlen(expanded_map) || expanded_map =~# '_Net\|FileBeagle'
      if strlen(expanded_map) > 0 "else, mapped to <nop>
        silent exe (expanded_map =~# '<Plug>' ? 'nmap' : 'nnoremap').' <buffer> <silent> <leader>'.a:key.' '.expanded_map
      endif
      "unmap the default buffer-local mapping to allow Sneak's global mapping.
      silent! exe 'nunmap <buffer> '.a:key
    endif
  endf

  augroup SneakPluginNetrw
    autocmd!
    autocmd FileType netrw,filebeagle autocmd SneakPluginNetrw CursorMoved <buffer>
          \ call <sid>map_netrw_key('s') | call <sid>map_netrw_key('S') | autocmd! SneakPluginNetrw * <buffer>
  augroup END
endif


let &cpo = s:cpo_save
unlet s:cpo_save
