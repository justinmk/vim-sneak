
func! sneak#hl#removehl() "remove highlighting
  silent! call matchdelete(w:sneak_hl_id)
  silent! call matchdelete(w:sneak_sc_hl)
endf

