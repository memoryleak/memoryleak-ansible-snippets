NPROCS := 1
OS := $(shell uname)
export NPROCS

ifeq ($J,)

ifeq ($(OS),Linux)
  NPROCS := $(shell grep -c ^processor /proc/cpuinfo)
else ifeq ($(OS),Darwin)
  NPROCS := $(shell system_profiler | awk '/Number of CPUs/ {print $$4}{next;}')
endif # $(OS)

else
  NPROCS := $J
endif # $J

BUILDDIR=build
MODULE_SNIPPETS_DIR=$(BUILDDIR)/module-snippets-json
SUBLIME_SNIPPETS_DIR=$(BUILDDIR)/module-snippets-sublime
VSCODE_SNIPPETS_DIR=$(BUILDDIR)/module-snippets-code
YAML_SNIPPETS_DIR=$(BUILDDIR)/module-snippets-yaml
ARTIFACTS_DIR=artifacts
PARALLEL_COMMAND=parallel --eta -a $(BUILDDIR)/modules.txt -j $(NPROCS) -I% --max-args 1
CONSOLE_SNIPPET_COMMAND=php -d xdebug.mode=off src/bin/console generate:snippet
CONSOLE_EXTRA_COMMAND=php -d xdebug.mode=off src/bin/console generate:extra

prepare:
	composer2 install -d src/
	mkdir -p $(MODULE_SNIPPETS_DIR)
	ansible-doc -l | cut -d " " -f1 | tr ' ' '\n' | sort | uniq > $(BUILDDIR)/modules.txt
	$(PARALLEL_COMMAND) 'PYTHONWARNINGS="ignore" ansible-doc -j "%" 1> $(MODULE_SNIPPETS_DIR)/%.json'

yaml:
	@echo "Creating YAML snippets..."
	@mkdir -p $(YAML_SNIPPETS_DIR)
	$(PARALLEL_COMMAND) "$(CONSOLE_SNIPPET_COMMAND) snippet.yml.twig $(MODULE_SNIPPETS_DIR)/%.json $(YAML_SNIPPETS_DIR)/%.yml"

sublime-extra:
	$(CONSOLE_EXTRA_COMMAND) sublime-extra.xml.twig src/extra/become.yml $(SUBLIME_SNIPPETS_DIR)/become.sublime-snippet
	$(CONSOLE_EXTRA_COMMAND) sublime-extra.xml.twig src/extra/block.yml $(SUBLIME_SNIPPETS_DIR)/block.sublime-snippet
	$(CONSOLE_EXTRA_COMMAND) sublime-extra.xml.twig src/extra/loop_control.yml $(SUBLIME_SNIPPETS_DIR)/loop-control.sublime-snippet
	$(CONSOLE_EXTRA_COMMAND) sublime-extra.xml.twig src/extra/playbook.yml $(SUBLIME_SNIPPETS_DIR)/playbook.sublime-snippet

sublime: 
	@echo "Creating Sublime Text snippets..."
	@mkdir -p  $(SUBLIME_SNIPPETS_DIR)
	$(PARALLEL_COMMAND) "$(CONSOLE_SNIPPET_COMMAND) sublime.xml.twig $(MODULE_SNIPPETS_DIR)/%.json $(SUBLIME_SNIPPETS_DIR)/%.sublime-snippet"
	

code-extra:
	$(CONSOLE_EXTRA_COMMAND) code-extra.json.twig src/extra/become.yml $(VSCODE_SNIPPETS_DIR)/become.json
	$(CONSOLE_EXTRA_COMMAND) code-extra.json.twig src/extra/block.yml $(VSCODE_SNIPPETS_DIR)/block.json
	$(CONSOLE_EXTRA_COMMAND) code-extra.json.twig src/extra/loop_control.yml $(VSCODE_SNIPPETS_DIR)/loop-control.json
	$(CONSOLE_EXTRA_COMMAND) code-extra.json.twig src/extra/playbook.yml $(VSCODE_SNIPPETS_DIR)/playbook.json

code:
	@echo "Generate Visual Studio Code snippets"
	@mkdir -p $(VSCODE_SNIPPETS_DIR)
	$(PARALLEL_COMMAND) "$(CONSOLE_SNIPPET_COMMAND) code.json.twig $(MODULE_SNIPPETS_DIR)/%.json $(VSCODE_SNIPPETS_DIR)/%.json"

sublime-build:
	mkdir -p $(ARTIFACTS_DIR)
	rm -f $(BUILDDIR)/AnsibleSnippets.sublime-package
	zip -q -j -u $(BUILDDIR)/AnsibleSnippets.sublime-package $(SUBLIME_SNIPPETS_DIR)/*.sublime-snippet
	cp $(BUILDDIR)/AnsibleSnippets.sublime-package $(ARTIFACTS_DIR)/AnsibleSnippets.sublime-package

code-build:
	mkdir -p $(ARTIFACTS_DIR)
	cat $(VSCODE_SNIPPETS_DIR)/*.json |  tr -d '[:cntrl:]' | jq  -rs 'reduce .[] as $$item ({}; . * $$item)' > $(VSCODE_SNIPPETS_DIR)/ansible.json
	cp $(VSCODE_SNIPPETS_DIR)/ansible.json $(ARTIFACTS_DIR)/ansible.code-snippets

clean:
	rm -rf $(BUILDDIR)/module-snippets-json $(BUILDDIR)/module-snippets-code $(BUILDDIR)/module-snippets-sublime $(BUILDDIR)/module-snippets-yaml src/vendor

install:
	cp $(ARTIFACTS_DIR)/AnsibleSnippets.sublime-package ~/.config/sublime-text-3/Installed\ Packages/AnsibleSnippets.sublime-package
	cp $(ARTIFACTS_DIR)/ansible.code-snippets ~/.config/Code/User/snippets/ansible.code-snippets

all: prepare build
build: sublime code sublime-extra code-extra code-build sublime-build
sublime-text: prepare build sublime sublime-extra sublime-build