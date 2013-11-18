

func! sneak#util#getchar()
  let c = getchar()
  return type(c) == type(0) ? nr2char(c) : c
endf

