SHELL := /bin/bash
DIR := ${CURDIR}

vscodePhpDebugVersion := '1.34.0'
vscodePhpDebugUrl := 'https://github.com/xdebug/vscode-php-debug/releases/download/v1.34.0/php-debug-1.34.0.vsix'

.ONESHELL:
install-vscode-php-debug:
	set -e
	$(DIR)/bin/dap-adapter-utils install xdebug vscode-php-debug $(vscodePhpDebugVersion) $(vscodePhpDebugUrl)
	$(DIR)/bin/dap-adapter-utils setAsCurrent vscode-php-debug $(vscodePhpDebugVersion)

composer:
	composer install

start: install-vscode-php-debug composer
	/usr/bin/nvim -u init.lua -c 'source test.lua'

run: install-vscode-php-debug composer
	/usr/bin/nvim -u init.lua
