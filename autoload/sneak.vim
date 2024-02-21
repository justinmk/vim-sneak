" Persist state for repeat.
"     opfunc    : &operatorfunc at g@ invocation.
"     opfunc_st : State during last 'operatorfunc' (g@) invocation.
let s:st = { 'rst':1, 'input':'', 'inputlen':0, 'reverse':0, 'bounds':[0,0],
      \'inclusive':0, 'label':'', 'opfunc':'', 'opfunc_st':{} }

if exists('##OptionSet')
  augroup sneak_optionset
    autocmd!
    autocmd OptionSet operatorfunc let s:st.opfunc = &operatorfunc | let s:st.opfunc_st = {}
  augroup END
endif

func! sneak#state() abort
  return deepcopy(s:st)
endf

func! sneak#is_sneaking() abort
  return exists("#sneak#CursorMoved")
endf

func! sneak#cancel() abort
  call sneak#util#removehl()
  augroup sneak
    autocmd!
  augroup END
  if maparg('<esc>', 'n') =~# "'s'\\.'neak#cancel'"  " Remove temporary mapping.
    silent! unmap <esc>
  endif
  return ''
endf

" Entrypoint for `s`.
func! sneak#wrap(op, inputlen, reverse, inclusive, label) abort
  let save_cmdheight = &cmdheight
  try
    if &cmdheight < 1
      set cmdheight=1
    endif

    let [cnt, reg] = [v:count1, v:register] "get count and register before doing _anything_, else they get overwritten.
    let is_similar_invocation = a:inputlen == s:st.inputlen && a:inclusive == s:st.inclusive

    if g:sneak_opt.s_next && is_similar_invocation && (sneak#util#isvisualop(a:op) || empty(a:op)) && sneak#is_sneaking()
      " Repeat motion (clever-s).
      call sneak#rpt(a:op, a:reverse)
    elseif a:op ==# 'g@' && !empty(s:st.opfunc_st) && !empty(s:st.opfunc) && s:st.opfunc ==# &operatorfunc
      " Replay state from the last 'operatorfunc'.
      call sneak#to(a:op, s:st.opfunc_st.input, s:st.opfunc_st.inputlen, cnt, reg, 1, s:st.opfunc_st.reverse, s:st.opfunc_st.inclusive, s:st.opfunc_st.label)
    else
      if exists('#User#SneakEnter')
        doautocmd <nomodeline> User SneakEnter
        redraw
      endif
      " Prompt for input.
      call sneak#to(a:op, s:getnchars(a:inputlen, a:op), a:inputlen, cnt, reg, 0, a:reverse, a:inclusive, a:label)
      if exists('#User#SneakLeave')
        doautocmd <nomodeline> User SneakLeave
      endif
    endif
  finally
    let &cmdheight = save_cmdheight
  endtry
endf

" Repeats the last motion.
func! sneak#rpt(op, reverse) abort
  if s:st.rst "reset by f/F/t/T
    exec "norm! ".(sneak#util#isvisualop(a:op) ? "gv" : "").v:count1.(a:reverse ? "," : ";")
    return
  endif

  let l:relative_reverse = (a:reverse && !s:st.reverse) || (!a:reverse && s:st.reverse)
  call sneak#to(a:op, s:st.input, s:st.inputlen, v:count1, v:register, 1,
        \ (g:sneak_opt.absolute_dir ? a:reverse : l:relative_reverse), s:st.inclusive, 0)
endf

" input:      may be shorter than inputlen if the user pressed <enter> at the prompt.
" inclusive:  0: t-like, 1: f-like, 2: /-like
func! sneak#to(op, input, inputlen, count, register, repeatmotion, reverse, inclusive, label) abort "{{{
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

  " [count] means 'skip to this match' _only_ for operators/repeat-motion/1-char-search
  "   sanity check: max out at 999, to avoid searchpos() OOM.
  let skip = (is_op || a:repeatmotion || a:inputlen < 2) ? min([999, a:count]) : 0

  let l:gt_lt = a:reverse ? '<' : '>'
  let bounds = a:repeatmotion ? s:st.bounds : [0,0] " [left_bound, right_bound]
  let l:scope_pattern = '' " pattern used to highlight the vertical 'scope'
  let l:match_bounds  = ''

  "scope to a column of width 2*(v:count1)+1 _except_ for operators/repeat-motion/1-char-search
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

    " Set temporary hooks on f/F/t/T so that we know when to reset Sneak.
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

  if 0 == max(matchpos)
    if nudge
      call sneak#util#nudge(a:reverse) "undo nudge for t
    endif

    let km = empty(&keymap) ? '' : ' ('.&keymap.' keymap)'
    call sneak#util#echo('not found'.(max(bounds) ? printf(km.' (in columns %d-%d): %s', bounds[0], bounds[1], a:input) : km.': '.a:input))
    return
  endif
  "search succeeded

  call sneak#util#removehl()

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

  "highlight actual matches at or beyond the cursor position
  "  - store in w: because matchadd() highlight is per-window.
  let w:sneak_hl_id = matchadd('Sneak',
        \ (s.prefix).(s.match_pattern).(s.search).'\|'.curln_pattern.(s.search))

  " Clear with <esc>. Use a funny mapping to avoid false positives. #287
  if (has('nvim') || has('gui_running')) && maparg('<esc>', 'n') ==# ""
    nnoremap <expr> <silent> <esc> call('s'.'neak#cancel',[]) . "\<esc>"
  endif

  " Operators always invoke label-mode.
  " If a:label is a string set it as the target, without prompting.
  let label = a:label !~# '[012]' ? a:label : ''
  let target = (2 == a:label || !empty(label) || (a:label && g:sneak_opt.label && (is_op || s.hasmatches(1)))) && !max(bounds)
        \ ? sneak#label#to(s, is_v, label) : ""

  if nudge
    call sneak#util#nudge(a:reverse) "undo nudge for t
  endif

  if is_op && 2 != a:inclusive && !a:reverse
    " f/t operations do not apply to the current character; nudge the cursor.
    call sneak#util#nudge(1)
  endif

  if is_op || '' != target
    call sneak#util#removehl()
  endif

  if is_op && a:op !=# 'y'
    let change = a:op !=? "c" ? "" : "\<c-r>.\<esc>"
    let args = sneak#util#strlen(a:input) . a:reverse . a:inclusive . (2*!empty(target))
    if a:op !=# 'g@'
      let args .= a:input . target . change
    endif
    let seq = a:op . "\<Plug>SneakRepeat" . args
    silent! call repeat#setreg(seq, a:register)
    silent! call repeat#set(seq, a:count)

    let s:st.label = target
    if empty(s:st.opfunc_st)
      let s:st.opfunc_st = filter(deepcopy(s:st), 'v:key !=# "opfunc_st"')
    endif
  endif
endf "}}}

func! s:attach_autocmds() abort
  augroup sneak
    autocmd!
    autocmd InsertEnter,WinLeave,BufLeave * call sneak#cancel()
    "_nested_ autocmd to skip the _first_ CursorMoved event.
    "NOTE: CursorMoved is _not_ triggered if there is typeahead during a macro/script...
    autocmd CursorMoved * autocmd sneak CursorMoved * call sneak#cancel()
  augroup END
endf

func! sneak#reset(key) abort
  let c = sneak#util#getchar()

  let s:st.rst = 1
  let s:st.reverse = 0
  for k in ['f', 't'] "unmap the temp mappings
    if g:sneak_opt[k.'_reset']
      silent! exec 'unmap '.k
      silent! exec 'unmap '.toupper(k)
    endif
  endfor

  "count is prepended implicitly by the <expr> mapping
  return a:key.c
endf

func! s:map_reset_key(key, mode) abort
  exec printf("%snoremap <silent> <expr> %s sneak#reset('%s')", a:mode, a:key, a:key)
endf

" Sets temporary mappings to 'hook' into f/F/t/T.
func! s:ft_hook() abort
  for k in ['f', 't']
    for m in ['n', 'x']
      "if user mapped anything to f or t, do not map over it; unfortunately this
      "also means we cannot reset ; or , when f or t is invoked.
      if g:sneak_opt[k.'_reset'] && maparg(k, m) ==# ''
        call s:map_reset_key(k, m) | call s:map_reset_key(toupper(k), m)
      endif
    endfor
  endfor
endf

func! s:getnchars(n, mode) abort
  let s = ''
  echo g:sneak_opt.prompt | redraw
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
    redraw | echo g:sneak_opt.prompt . s
  endfor
  return s
endf

