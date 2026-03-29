.PHONY: test app clean-dist

test:
	swift test

app:
	./scripts/package-app.sh

clean-dist:
	rm -rf dist
