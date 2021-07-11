" NOTES:
"   problem:  cchar cannot be more than 1 character.
"   strategy: make fg/bg the same color, then conceal the other char.
"
"   problem:  [before 7.4.792] keyword highlight takes priority over conceal.
"   strategy: syntax clear | [do the conceal] | let &syntax=s:o_syntax

let g:sneak#target_labels = get(g:, 'sneak#target_labels', ";sftunq/SFGHLTUNRMQZ?0")

let s:clear_syntax = !has('patch-7.4.792')
let s:matchmap = {}
let s:match_ids = []
let s:orig_conceal_matches = []

if exists('*strcharpart')
  func! s:strchar(s, i) abort
    return strcharpart(a:s, a:i, 1)
  endf
else
  func! s:strchar(s, i) abort
    return matchstr(a:s, '.\{'.a:i.'\}\zs.')
  endf
endif

func! s:placematch(c, pos) abort
  let s:matchmap[a:c] = a:pos
  let pat = '\%'.a:pos[0].'l\%'.a:pos[1].'c.'
  if s:clear_syntax
    exec "syntax match SneakLabel '".pat."' conceal cchar=".a:c
  else
    let id = matchadd('Conceal', pat, 999, -1, { 'conceal': a:c })
    call add(s:match_ids, id)
  endif
endf

func! s:save_conceal_matches() abort
  for m in getmatches()
    if m.group ==# 'Conceal'
      call add(s:orig_conceal_matches, m)
      silent! call matchdelete(m.id)
    endif
  endfor
endf

func! s:restore_conceal_matches() abort
  for m in s:orig_conceal_matches
    let d = {}
    if has_key(m, 'conceal') | let d.conceal = m.conceal | endif
    if has_key(m, 'window') | let d.window = m.window | endif
    silent! call matchadd(m.group, m.pattern, m.priority, m.id, d)
  endfor
  let s:orig_conceal_matches = []
endf

func! sneak#label#to(s, v, label) abort
  let seq = ""
  while 1
    let choice = s:do_label(a:s, a:v, a:s._reverse, a:label)
    let seq .= choice
    if choice =~# "^\<S-Tab>\\|\<BS>$"
      call a:s.init(a:s._input, a:s._repeatmotion, 1)
    elseif choice ==# "\<Tab>"
      call a:s.init(a:s._input, a:s._repeatmotion, 0)
    else
      return seq
    endif
  endwhile
endf

func! s:do_label(s, v, reverse, label) abort "{{{
  let w = winsaveview()
  call s:before()
  let search_pattern = (a:s.prefix).(a:s.search).(a:s.get_onscreen_searchpattern(w))

  let i = 0
  let overflow = [0, 0]  " Position of the next match (if any) after we have run out of target labels.
  while 1
    " searchpos() is faster than 'norm! /'
    let p = searchpos(search_pattern, a:s.search_options_no_s, a:s.get_stopline())
    let skippedfold = sneak#util#skipfold(p[0], a:reverse)  " Note: 'set foldopen-=search' does not affect search().

    if 0 == p[0] || -1 == skippedfold
      break
    elseif 1 == skippedfold
      continue
    endif

    if i < s:maxmarks
      let c = s:strchar(g:sneak#target_labels, i)
      call s:placematch(c, p)
    else  " We have exhausted the target labels; grab the first non-labeled match.
      let overflow = p
      break
    endif

    let i += 1
  endwhile

  call winrestview(w) | redraw
  let choice = empty(a:label) ? sneak#util#getchar() : a:label
  call s:after()

  let mappedto = maparg(choice, a:v ? 'x' : 'n')
  let mappedtoNext = (g:sneak#opt.absolute_dir && a:reverse)
        \ ? mappedto =~# '<Plug>Sneak\(_,\|Previous\)'
        \ : mappedto =~# '<Plug>Sneak\(_;\|Next\)'

  if choice =~# "\\v^\<Tab>|\<S-Tab>|\<BS>$"  " Decorate next N matches.
    if (!a:reverse && choice ==# "\<Tab>") || (a:reverse && choice =~# "^\<S-Tab>\\|\<BS>$")
      call cursor(overflow[0], overflow[1])
    endif  " ...else we just switched directions, do not overflow.
  elseif (strlen(g:sneak#opt.label_esc) && choice ==# g:sneak#opt.label_esc)
        \ || -1 != index(["\<Esc>", "\<C-c>"], choice)
    return "\<Esc>"  " Exit label-mode.
  elseif !mappedtoNext && !has_key(s:matchmap, choice)  " Fallthrough: press _any_ invalid key to escape.
    call sneak#util#removehl()
    call feedkeys(choice)  " Exit label-mode, fall through to Vim.
    return ""
  else  " Valid target was selected.
    let p = mappedtoNext ? s:matchmap[s:strchar(g:sneak#target_labels, 0)] : s:matchmap[choice]
    call cursor(p[0], p[1])
  endif

  return choice
endf "}}}

func! s:after() abort
  autocmd! sneak_label_cleanup
  try | call matchdelete(s:sneak_cursor_hl) | catch | endtry
  call map(s:match_ids, 'matchdelete(v:val)')
  let s:match_ids = []
  " Remove temporary highlight links.
  exec 'hi! link Conceal '.s:orig_hl_conceal
  call s:restore_conceal_matches()
  exec 'hi! link Sneak '.s:orig_hl_sneak

  if s:clear_syntax
    let &l:synmaxcol=s:o_synmaxcol
    " Always clear before restore, in case user has `:syntax off`. #200
    syntax clear
    silent! let &l:foldmethod=s:o_fdm
    silent! let &l:syntax=s:o_syntax
    " Force Vim to reapply 'spell' (must set 'spelllang'). #110
    let [&l:spell,&l:spelllang]=[s:o_spell,s:o_spelllang]
    call s:restore_conceal_in_other_windows()
  endif

  let [&l:concealcursor,&l:conceallevel]=[s:o_cocu,s:o_cole]
endf

func! s:disable_conceal_in_other_windows() abort
  for w in range(1, winnr('$'))
    if 'help' !=# getwinvar(w, '&buftype') && w != winnr()
        \ && empty(getbufvar(winbufnr(w), 'dirvish'))
      call setwinvar(w, 'sneak_orig_cl', getwinvar(w, '&conceallevel'))
      call setwinvar(w, '&conceallevel', 0)
    endif
  endfor
endf
func! s:restore_conceal_in_other_windows() abort
  for w in range(1, winnr('$'))
    if 'help' !=# getwinvar(w, '&buftype') && w != winnr()
        \ && empty(getbufvar(winbufnr(w), 'dirvish'))
      call setwinvar(w, '&conceallevel', getwinvar(w, 'sneak_orig_cl'))
    endif
  endfor
endf

func! s:before() abort
  let s:matchmap = {}
  for o in ['spell', 'spelllang', 'cocu', 'cole', 'fdm', 'synmaxcol', 'syntax']
    exe 'let s:o_'.o.'=&l:'.o
  endfor

  setlocal concealcursor=ncv conceallevel=2

  " Highlight the cursor location (because cursor is hidden during getchar()).
  let s:sneak_cursor_hl = matchadd("SneakScope", '\%#', 11, -1)

  if s:clear_syntax
    setlocal nospell
    " Prevent highlighting in other windows showing the same buffer.
    ownsyntax sneak_label
    " Avoid broken folds when we clear syntax below.
    if &l:foldmethod ==# 'syntax'
      setlocal foldmethod=manual
    endif
    syntax clear
    " This is fast because we cleared syntax.  Allows Sneak to work on very long wrapped lines.
    setlocal synmaxcol=0
    call s:disable_conceal_in_other_windows()
  endif

  let s:orig_hl_conceal = sneak#util#links_to('Conceal')
  call s:save_conceal_matches()
  let s:orig_hl_sneak   = sneak#util#links_to('Sneak')
  " Set temporary link to our custom 'conceal' highlight.
  hi! link Conceal SneakLabel
  " Set temporary link to hide the sneak search targets.
  hi! link Sneak SneakLabelMask

  augroup sneak_label_cleanup
    autocmd!
    autocmd CursorMoved * call <sid>after()
  augroup END
endf

" Returns 1 if a:key is invisible or special.
func! s:is_special_key(key) abort
  return -1 != index(["\<Esc>", "\<C-c>", "\<Space>", "\<CR>", "\<Tab>"], a:key)
    \ || maparg(a:key, 'n') =~# '<Plug>Sneak\(_;\|_,\|Next\|Previous\)'
    \ || (g:sneak#opt.s_next && maparg(a:key, 'n') =~# '<Plug>Sneak\(_s\|Forward\)')
endf

" We must do this because:
"  - Don't know which keys the user assigned to Sneak_;/Sneak_,
"  - Must reserve special keys like <Esc> and <Tab>
func! sneak#label#sanitize_target_labels() abort
  let nrbytes = len(g:sneak#target_labels)
  let i = 0
  while i < nrbytes
    " Intentionally using byte-index for use with substitute().
    let k = strpart(g:sneak#target_labels, i, 1)
    if s:is_special_key(k)  " Remove the char.
      let g:sneak#target_labels = substitute(g:sneak#target_labels, '\%'.(i+1).'c.', '', '')
      " Move ; (or s if 'clever-s' is enabled) to the front.
      if !g:sneak#opt.absolute_dir
            \ && ((!g:sneak#opt.s_next && maparg(k, 'n') =~# '<Plug>Sneak\(_;\|Next\)')
            \     || (maparg(k, 'n') =~# '<Plug>Sneak\(_s\|Forward\)'))
        let g:sneak#target_labels = k . g:sneak#target_labels
      else
        let nrbytes -= 1
        continue
      endif
    endif
    let i += 1
  endwhile
endf

call sneak#label#sanitize_target_labels()
let s:maxmarks = sneak#util#strlen(g:sneak#target_labels)
