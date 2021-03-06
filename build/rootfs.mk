# Copyright (c) 2015, Plume Design Inc. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    1. Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#    2. Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#    3. Neither the name of the Plume Design Inc. nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL Plume Design Inc. BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

ROOTFS_SOURCE_DIRS ?= rootfs $(VENDOR_DIR)/rootfs
ROOTFS_COMPONENTS  ?= common target/$(TARGET) $(ROOTFS_PROFILE_COMPONENTS)

# $(1) = source rootfs base dir
# $(2) = component (profile or target dir)
define rootfs_prepare_dir
	$(Q)if [ -d $(1)/$(2) ]; then \
		echo "$(call color_install,prepare) rootfs $(call color_profile,$(1)/$(2)) -> $(BUILD_ROOTFS_DIR)"; \
		(cd $(1)/$(2) && tar chf - . --exclude=.keep) | (cd $(BUILD_ROOTFS_DIR) && tar xf -); \
	fi

endef

define rootfs_prepare
	$(foreach DIR,$(ROOTFS_SOURCE_DIRS),\
		$(foreach COMPONENT,$(ROOTFS_COMPONENTS),\
			$(call rootfs_prepare_dir,$(DIR),$(COMPONENT))))
endef

define rootfs_install_to_target
	$(Q)echo "$(call color_install,install) rootfs $(call color_profile,$(BUILD_ROOTFS_DIR) => $(INSTALL_ROOTFS_DIR))"
	$(Q)cp -a $(BUILD_ROOTFS_DIR)/. $(INSTALL_ROOTFS_DIR)/.

endef

# $1 = target rootfs dir
# $2 = script path-name (post-install)
define rootfs_run_hook_script
	$(Q)if [ -x "$2" ]; then \
		echo "$(call color_install,hooks) rootfs $(call color_profile,$2) in $1"; \
		$2 $1; \
	fi
endef

# $1 = target rootfs dir
# $2 = hooks dir
# $3 = script-name (post-install)
define rootfs_run_hooks_in_dir
	$(call rootfs_run_hook_script,$1,"$2/$3")
	$(call rootfs_run_hook_script,$1,"$2/$3.$(TARGET)")

endef

# $1 = target rootfs dir
# $2 = source rootfs base dir
# $3 = component (profile or target dir)
# $4 = script-name (post-install)
define rootfs_run_hooks_in
	$(call rootfs_run_hooks_in_dir,$1,$2/hooks/$3,$4)
endef

# $1 = target rootfs dir
# $2 = script-name (post-install)
define rootfs_run_hooks
	$(foreach DIR,$(ROOTFS_SOURCE_DIRS),\
		$(foreach COMPONENT,$(ROOTFS_COMPONENTS),\
			$(call rootfs_run_hooks_in,$1,$(DIR),$(COMPONENT),$2)))
endef

ROOTFS_PREPARE_HOOK_SCRIPT ?= pre-install
ROOTFS_INSTALL_HOOK_SCRIPT ?= post-install

define rootfs_run_hooks_prepare
	$(if $(ROOTFS_PREPARE_HOOK_SCRIPT),$(call rootfs_run_hooks,$(BUILD_ROOTFS_DIR),$(ROOTFS_PREPARE_HOOK_SCRIPT)))
endef

define rootfs_run_hooks_install
	$(if $(ROOTFS_INSTALL_HOOK_SCRIPT),$(call rootfs_run_hooks,$(INSTALL_ROOTFS_DIR),$(ROOTFS_INSTALL_HOOK_SCRIPT)))
endef

.PHONY: rootfs rootfs-prepare rootfs-install rootfs-install-only
.PHONY: rootfs-prepare-prepend rootfs-prepare-main rootfs-prepare-append
.PHONY: rootfs-install-prepend rootfs-install-main rootfs-install-append

# rootfs: create rootfs in work-area (BUILD_ROOTFS_DIR)
#   - unit-install: build and install bins and libs
#   - ovsdb-create: create ovsdb
#   - rootfs-prepare: copy source rootfs skeleton

rootfs: build_all rootfs-prepare ovsdb-create

# empty targets -prepend and -append allow inserting additional commands
rootfs-prepare-prepend: workdirs

rootfs-prepare-main: rootfs-prepare-prepend
	$(call rootfs_prepare)
	$(call rootfs_run_hooks_prepare)

rootfs-prepare-append: rootfs-prepare-main

rootfs-prepare: rootfs-prepare-prepend rootfs-prepare-main rootfs-prepare-append

# rootfs-install:
#   - copy work-area rootfs to INSTALL_ROOTFS_DIR (can be SDK_ROOTFS)
#   - run post-install hooks on INSTALL_ROOTFS_DIR

.PHONY: rootfs-install-dir
rootfs-install-dir:
	$(Q)mkdir -p $(INSTALL_ROOTFS_DIR)

rootfs-install-prepend: rootfs-install-dir

rootfs-install-main: rootfs-install-prepend
	$(call rootfs_install_to_target)
	$(call rootfs_run_hooks_install)

rootfs-install-append: rootfs-install-main

rootfs-install-only: rootfs-install-prepend rootfs-install-main rootfs-install-append

rootfs-install: rootfs rootfs-install-only


