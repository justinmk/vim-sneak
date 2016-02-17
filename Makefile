test: tests/vader tests/repeat
	vim -N -u tests/vimrc '+Vader! tests/*.vader'

tests/vader:
	git clone https://github.com/junegunn/vader.vim tests/vader

tests/repeat:
	git clone https://github.com/tpope/vim-repeat tests/repeat

.PHONY: test
