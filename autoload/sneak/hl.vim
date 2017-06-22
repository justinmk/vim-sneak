
func! sneak#hl#removehl() abort "remove highlighting
  silent! call matchdelete(w:sneak_hl_id)
  silent! call matchdelete(w:sneak_sc_hl)
endf

" gets the 'links to' value of the specified highlight group, if any.
func! sneak#hl#links_to(hlgroup) abort
  redir => hl | exec 'silent highlight '.a:hlgroup | redir END
  let s = substitute(matchstr(hl, 'links to \zs.*'), '\s', '', 'g')
  return empty(s) ? 'NONE' : s
endf

func! sneak#hl#get(hlgroup) abort "gets the definition of the specified highlight
  if !hlexists(a:hlgroup)
    return ""
  endif
  redir => hl | exec 'silent highlight '.a:hlgroup | redir END
  return matchstr(hl, '\%(.*xxx\)\?\%(.*cleared\)\?\s*\zs.*')
endf

func! s:default_color(hlgroup, what, mode) abort
  let c = synIDattr(synIDtrans(hlID(a:hlgroup)), a:what, a:mode)
  return !empty(c) && c != -1 ? c : (a:what ==# 'bg' ? 'magenta' : 'white')
endfunc

func! s:init() abort
  exec "highlight default Sneak guifg=white guibg=magenta ctermfg=white ctermbg=".(&t_Co < 256 ? "magenta" : "201")

  if &background ==# 'dark'
    highlight default SneakScope guifg=black guibg=white ctermfg=0     ctermbg=255
  else
    highlight default SneakScope guifg=white guibg=black ctermfg=255   ctermbg=0
  endif

  highlight default link Cursor SneakScope

  let guibg   = s:default_color('Sneak', 'bg', 'gui')
  let guifg   = s:default_color('Sneak', 'fg', 'gui')
  let ctermbg = s:default_color('Sneak', 'bg', 'cterm')
  let ctermfg = s:default_color('Sneak', 'fg', 'cterm')
  exec 'highlight default SneakLabel gui=bold cterm=bold guifg='.guifg.' guibg='.guibg.' ctermfg='.ctermfg.' ctermbg='.ctermbg

  let guibg   = s:default_color('SneakLabel', 'bg', 'gui')
  let ctermbg = s:default_color('SneakLabel', 'bg', 'cterm')
  " fg same as bg
  exec 'highlight default SneakLabelMask guifg='.guibg.' guibg='.guibg.' ctermfg='.ctermbg.' ctermbg='.ctermbg
endf

augroup sneak_colorscheme " re-init if :colorscheme is changed at runtime. #108
  autocmd!
  autocmd ColorScheme * call <sid>init()
augroup END

call s:init()
