

func! s:dbgflag(settingname)
  exec 'let value='.a:settingname
  silent echo a:settingname.'='.value
endf

func! s:dbgfeat(featurename)
  silent echo 'has("'.a:featurename.'")='.has(a:featurename)
endf

func! sneak#debug#report()
  redir => vimversion
    silent version
  redir END
  let vimversion = join(split(vimversion, "\n")[0:3], "\n")
  redir => output
    " silent exec 'echo sneak#state = '
    call s:dbgfeat('autocmd')
    call s:dbgflag('&magic')
    call s:dbgflag('&buftype')
    call s:dbgflag('&virtualedit')
    call s:dbgflag('&ignorecase')
    call s:dbgflag('&smartcase')
    call s:dbgflag('&background')
    silent exec 'verbose map s | map S | map z | map Z'
  redir END
  enew
  silent put=vimversion
  silent put=output
  "set nomodified
endf
