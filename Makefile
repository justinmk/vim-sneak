VIM = vim -N -u NORC -i NONE --cmd 'set rtp+=tests/vader rtp+=tests/repeat rtp+=$$PWD'

test: tests/vader tests/repeat
	$(VIM) '+Vader! tests/*.vader'

# https://github.com/junegunn/vader.vim/pull/75
testnvim: tests/vader tests/repeat
	VADER_OUTPUT_FILE=/dev/stderr n$(VIM) --headless '+Vader! tests/*.vader'

testinteractive: tests/vader tests/repeat
	$(VIM) '+Vader tests/*.vader'

tests/vader:
	git clone https://github.com/junegunn/vader.vim tests/vader || ( cd tests/vader && git pull --rebase; )

tests/repeat:
	git clone https://github.com/tpope/vim-repeat tests/repeat || ( cd tests/repeat && git pull --rebase; )

.PHONY: test testinteractive
