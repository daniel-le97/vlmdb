
.PHONY: docs fmt test run

docs:
	rm -rf ./docs
	v doc ./src -comments -f markdown -o docs.md
	v doc ./src -f html -o ./docs/
	mv ./docs/vlmdb.html ./docs/index.html
	python3 -m http.server --directory ./docs

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


