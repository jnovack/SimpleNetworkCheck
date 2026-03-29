.PHONY: test app clean-dist

test:
	swift test

app:
	./scripts/package-dmg.sh

clean-dist:
	rm -rf dist
