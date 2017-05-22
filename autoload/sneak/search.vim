func! sneak#search#new() abort
  let s = {}

  func! s.init(input, repeatmotion, reverse) abort
    let self._input = a:input
    let self._repeatmotion = a:repeatmotion
    let self._reverse = a:reverse
    " search pattern modifiers (case-sensitivity, magic)
    let self.prefix = sneak#search#get_cs(a:input, g:sneak#opt.use_ic_scs).'\V'
    " the escaped user input to search for
    let self.search = substitute(escape(a:input, '"\'), '\a', '\\[[=\0=]]', 'g')
    " example: highlight string 'ab' after line 42, column 5
    "          matchadd('foo', 'ab\%>42l\%5c', 1)
    let self.match_pattern = ''
    " do not wrap                     search backwards
    let self._search_options = 'W' . (a:reverse ? 'b' : '')
    let self.search_options_no_s = self._search_options
    " save the jump on the initial invocation, _not_ repeats or consecutive invocations.
    if !a:repeatmotion && !sneak#is_sneaking() | let self._search_options .= 's' | endif
  endf

  func! s.initpattern() abort
    let self._searchpattern = (self.prefix).(self.match_pattern).'\zs'.(self.search)
  endf

  func! s.dosearch(...) abort " a:1 : extra search options
    return searchpos(self._searchpattern
          \, self._search_options.(a:0 ? a:1 : '')
          \, 0
          \)
  endf

  func! s.get_onscreen_searchpattern(w) abort
    if &wrap
      return ''
    endif
    let wincol_lhs = a:w.leftcol "this is actually just to the _left_ of the first onscreen column.
    let wincol_rhs  = 2 + (winwidth(0) - sneak#util#wincol1()) + wincol_lhs
    "restrict search to window
    return '\%>'.(wincol_lhs).'v'.'\%<'.(wincol_rhs+1).'v'
  endf

  func! s.get_stopline() abort
    return self._reverse ? line("w0") : line("w$")
  endf

  " returns 1 if there are n _on-screen_ matches in the search direction.
  func! s.hasmatches(n) abort
    let w = winsaveview()
    let searchpattern = (self._searchpattern).(self.get_onscreen_searchpattern(w))
    let visiblematches = 0

    while 1
      let matchpos = searchpos(searchpattern, self.search_options_no_s, self.get_stopline())
      if 0 == matchpos[0] "no more matches
        break
      elseif 0 != sneak#util#skipfold(matchpos[0], self._reverse)
        continue
      endif
      let visiblematches += 1
      if visiblematches == a:n
        break
      endif
    endwhile

    call winrestview(w)
    return visiblematches >= a:n
  endf

  return s
endf

" gets the case sensitivity modifier for the search
func! sneak#search#get_cs(input, use_ic_scs) abort
  if !a:use_ic_scs || !&ignorecase || (&smartcase && sneak#util#has_upper(a:input))
    return '\C'
  endif
  return '\c'
endf

"search object singleton
let g:sneak#search#instance = sneak#search#new()
