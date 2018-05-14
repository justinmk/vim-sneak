VIM = vim -N -u NORC -i NONE --cmd 'set rtp+=tests/vim-vader rtp+=tests/vim-repeat rtp+=tests/vim-surround rtp+=$$PWD'

test: tests/vim-vader tests/vim-repeat tests/vim-surround
	$(VIM) '+Vader! tests/*.vader'

# https://github.com/junegunn/vader.vim/pull/75
testnvim: tests/vim-vader tests/vim-repeat tests/vim-surround
	VADER_OUTPUT_FILE=/dev/stderr n$(VIM) --headless '+Vader! tests/*.vader'

testinteractive: tests/vim-vader tests/vim-repeat tests/vim-surround
	$(VIM) '+Vader tests/*.vader'

tests/vim-vader:
	git clone https://github.com/junegunn/vader.vim tests/vim-vader || ( cd tests/vim-vader && git pull --rebase; )

tests/vim-repeat:
	git clone https://github.com/tpope/vim-repeat tests/vim-repeat || ( cd tests/vim-repeat && git pull --rebase; )

tests/vim-surround:
	git clone https://github.com/tpope/vim-surround tests/vim-surround || ( cd tests/vim-surround && git pull --rebase; )

.PHONY: test testnvim testinteractive
