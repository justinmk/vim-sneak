test: tests/vader tests/repeat
	vim -N -u tests/vimrc '+Vader! tests/*.vader'

# https://github.com/junegunn/vader.vim/pull/75
testnvim: tests/vader tests/repeat
	VADER_OUTPUT_FILE=/dev/stderr nvim --headless -N -u tests/vimrc '+Vader! tests/*.vader'

testinteractive: tests/vader tests/repeat
	vim -N -u tests/vimrc '+Vader tests/*.vader'

tests/vader:
	git clone https://github.com/junegunn/vader.vim tests/vader || ( cd tests/vader && git pull --rebase; )

tests/repeat:
	git clone https://github.com/tpope/vim-repeat tests/repeat || ( cd tests/repeat && git pull --rebase; )

.PHONY: test testinteractive
