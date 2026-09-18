.DEFAULT_GOAL := help

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: help install install-intl install-cn update update-intl update-cn check check-intl check-cn

help:
	@printf '%s\n' \
	  'make install       Build/install the international package' \
	  'make install-cn    Build/install the mainland-China package' \
	  'make update        Check/download/build the international update' \
	  'make update-cn     Check/download/build the mainland-China update' \
	  'make check         Check the international API without changing files' \
	  'make check-cn      Check the mainland-China API without changing files'

install: install-intl

install-intl:
	cd $(ROOT)intl && makepkg -si

install-cn:
	cd $(ROOT)cn && makepkg -si

update: update-intl

update-intl:
	$(ROOT)update.sh intl

update-cn:
	$(ROOT)update.sh cn

check: check-intl

check-intl:
	$(ROOT)check-upstream.sh intl

check-cn:
	$(ROOT)check-upstream.sh cn
