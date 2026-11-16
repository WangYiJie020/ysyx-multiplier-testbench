# Git tracer, modeled on the ysyx-workbench Makefile.
# Every traced step snapshots the whole working tree (respecting .gitignore) as a commit on the
# tracer branch, without touching the work branch, working tree or index.
#
# STUID/STUNAME are written into every tracer commit message: fill in your own below
# (or override on the command line, e.g. `make STUID=ysyx_12345678 STUNAME='Zhang San'`).
STUID   ?= ysyx_00000000
STUNAME ?= Your Name

# DO NOT modify the following code!!!

TRACER = tracer-ysyx
GITFLAGS = -q --author='$(TRACER) <tracer@ysyx.org>' --no-verify --allow-empty

YSYX_HOME     = $(CURDIR)
WORK_BRANCH   = $(shell git symbolic-ref -q --short HEAD 2>/dev/null)
WORK_HEAD     = $(shell git rev-parse --verify HEAD 2>/dev/null)
WORK_REF      = $(if $(WORK_BRANCH),$(WORK_BRANCH),$(WORK_HEAD))
WORK_KEY      = $(shell printf '%s' '$(if $(WORK_BRANCH),b:$(WORK_BRANCH),h:$(WORK_HEAD))' | git hash-object --stdin)
WORK_INDEX    = $(YSYX_HOME)/.git/index.$(WORK_KEY)
TRACER_BRANCH = $(TRACER)

LOCK_DIR = $(YSYX_HOME)/.git/

# prototype: git_soft_checkout(ref)
define git_soft_checkout
	git checkout --detach -q && git reset --soft $(1) -q -- && git checkout $(1) -q --
endef

# Plain shell commands, usable inside a larger recipe line.
# prototype: git_commit_cmd(msg)
define git_commit_cmd
flock $(LOCK_DIR) $(MAKE) --no-print-directory -s -C $(YSYX_HOME) -f scripts/tracer.mk .git_commit MSG='$(1)'; sync $(LOCK_DIR)
endef
# The commit message is the content of the file; its first line is the subject.
# prototype: git_commit_file_cmd(file)
define git_commit_file_cmd
flock $(LOCK_DIR) $(MAKE) --no-print-directory -s -C $(YSYX_HOME) -f scripts/tracer.mk .git_commit MSG_FILE=$(1); sync $(LOCK_DIR)
endef

# prototype: git_commit(msg)
define git_commit
	-@+$(call git_commit_cmd,$(1))
endef

.git_commit:
	-@while (test -e .git/index.lock); do sleep 0.1; done;               `# wait for other git instances`
	-@git branch $(TRACER_BRANCH) -q 2>/dev/null || true                 `# create tracer branch if not existent`
	-@cp -a .git/index $(WORK_INDEX)                                     `# backup git index`
	-@$(call git_soft_checkout, $(TRACER_BRANCH))                        `# switch to tracer branch`
	-@git add . -A --ignore-errors                                       `# add files to commit`
	-@(if test -n '$(MSG_FILE)'; then sed '1s/^/> /' '$(MSG_FILE)'; else echo "> $(MSG)"; fi \
	  && echo $(STUID) $(STUNAME) && uname -a && uptime `# generate commit msg`) \
	                | git commit -F - $(GITFLAGS)                        `# commit changes in tracer branch`
	-@$(call git_soft_checkout, $(WORK_REF))                             `# switch to work ref`
	-@mv $(WORK_INDEX) .git/index                                        `# restore git index`

.clean_index:
	rm -f $(WORK_INDEX)

.PHONY: .git_commit .clean_index
