.PHONY: tag

# Used by the tag target to create matching commits and tags with the contents
# of the Changelog.
TAG_VERSION =

tag:
	@if [[ -z "$(TAG_VERSION)" ]]; then echo "No TAG_VERSION set"; false; fi
	@which parse-changelog >/dev/null
	@if git describe --exact-match v$(TAG_VERSION) &>/dev/null; then \
		echo "$(TAG_VERSION) already exists"; \
		false; \
	fi
	@if [[ -z "$$(parse-changelog --prefix-format v CHANGELOG.md $(TAG_VERSION))" ]]; then \
		echo "No changelog entry for $(TAG_VERSION)"; \
		false; \
	fi
	@git -c core.commentchar=: commit -a -m v$(TAG_VERSION) \
		-m "$$(parse-changelog --prefix-format v CHANGELOG.md $(TAG_VERSION))"
	@git -c core.commentchar=: tag -a -m v$(TAG_VERSION) \
		-m "$$(parse-changelog --prefix-format v CHANGELOG.md $(TAG_VERSION))" \
		v$(TAG_VERSION)

push-release:
	@if [[ -z "$(TAG_VERSION)" ]]; then echo "No TAG_VERSION set"; false; fi
	@which gh >/dev/null
	@gh release create v$(TAG_VERSION) --notes-from-tag --verify-tag
