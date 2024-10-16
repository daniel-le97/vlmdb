
.PHONY: docs fmt test run

docs:
	rm -rf ./docs
	v doc ./src -comments -f markdown -o ./docs/markdown
	v doc ./src -f html -o ./docs/html
	mv ./docs/html/lmdb.html ./docs/html/index.html
	python3 -m http.server --directory ./docs/html

fmt:
	v fmt -w .

test:
	v -stats test ./tests

run:
	v run .

symlink:
	ln -s $(CURDIR) $(HOME)/.vmodules/vlmdb

clean-symlink:
	rm -rf $(HOME)/.vmodules/vlmdb


