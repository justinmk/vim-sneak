

func! s:dbgflag(settingname)
  exec 'let value='.a:settingname
  silent echo a:settingname.'='.value
endf

func! s:dbgfeat(featurename)
  silent echo 'has("'.a:featurename.'")='.has(a:featurename)
endf

func! s:dbgfunc(funcname)
  silent echo exists("*".a:funcname) ? "defined:     ".a:funcname
                                   \ : "not defined: ".a:funcname
endf

func! sneak#debug#profile()
  profile start profile.log
  profile func sneak*
  "trace all sneak script files
  profile file *sneak/*
  autocmd VimLeavePre * profile pause
endf

func! sneak#debug#report()
  redir => vimversion
    silent version
  redir END
  let vimversion = join(split(vimversion, "\n")[0:3], "\n")
  redir => output
    call s:dbgfeat('autocmd')
    call s:dbgflag('&magic')
    call s:dbgflag('&buftype')
    call s:dbgflag('&virtualedit')
    call s:dbgflag('&ignorecase')
    call s:dbgflag('&smartcase')
    call s:dbgflag('&background')
    call s:dbgflag('&keymap')
    call s:dbgflag('g:mapleader')
    silent echo ""
    call s:dbgfunc("sneak#to")
    call s:dbgfunc("sneak#rpt")
    call s:dbgfunc("sneak#search#new")
    call s:dbgfunc("sneak#hl#removehl")
    call s:dbgfunc("sneak#util#echo")
    silent echo ""
    echo "sneak#opt: ".string(g:sneak#opt)
    silent exec 'verbose map f | map F | map t | map T | map s | map S | map z | map Z | map ; '
  redir END
  enew
  silent put=vimversion
  silent put=output
  "setlocal nomodified
endf
