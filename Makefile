
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

include $(DEVKITARM)/base_tools
include Makefile.common

# Base definitions
export VERSION	:=	$(shell git describe --tags --abbrev=8)
export DBUILTS	:=	$(shell date +'%Y%m%d%H%M%S')
export DBUILTL  :=	$(shell date +'%Y-%m-%d %H:%M:%S')

export OUTDIR := output
export RELDIR := release
export COMMON_DIR := ../common

# Definitions for initial RAM disk
VRAM_TAR    := $(OUTDIR)/vram0.tar
VRAM_DATA   := data
VRAM_FLAGS  := --make-new --path-limit 99
ifeq ($(NTRBOOT),1)
	VRAM_SCRIPTS := resources/gm9/scripts
endif

ifeq ($(OS),Windows_NT)
	ifeq ($(TERM),cygwin)
		PY3 := py -3 # Windows / CMD/PowerShell
	else
		PY3 := python3 # Windows / MSYS2
	endif
else
	PY3 := python3 # Unix-like
endif

# Definitions for ARM binaries
export INCLUDE := -I"$(shell pwd)/common"

export ASFLAGS := -g -x assembler-with-cpp $(INCLUDE)
export CFLAGS  := -DDBUILTS="\"$(DBUILTS)\"" -DDBUILTL="\"$(DBUILTL)\"" -DVERSION="\"$(VERSION)\"" -DFLAVOR="\"$(FLAVOR)\"" \
                  -g -Os -Wall -Wextra -Wcast-align -Wformat=2 -Wno-main \
                  -fomit-frame-pointer -ffast-math -std=gnu11 -MMD -MP \
                  -Wno-unused-function -Wno-format-truncation -Wno-format-nonliteral $(INCLUDE) -ffunction-sections -fdata-sections
export LDFLAGS := -Tlink.ld -nostartfiles -Wl,--gc-sections,-z,max-page-size=4096
ELF := arm9/arm9.elf arm11/arm11.elf

.PHONY: all firm $(VRAM_TAR) elf release clean
all: firm

clean:
	@set -e; for elf in $(ELF); do \
	    $(MAKE) --no-print-directory -C $$(dirname $$elf) clean; \
	done
	@rm -rf $(OUTDIR) $(RELDIR) $(FIRM) $(FIRMD) $(VRAM_TAR)

unmarked_readme: .FORCE
	@$(PY3) utils/unmark.py -f README.md data/README_internal.md

release: clean unmarked_readme
	@$(MAKE) --no-print-directory firm
	@$(MAKE) --no-print-directory firm NTRBOOT=1

	@mkdir -p $(RELDIR)
	@mkdir -p $(RELDIR)/ntrboot
	@mkdir -p $(RELDIR)/elf

	@cp $(FIRM) $(RELDIR)
	@cp $(OUTDIR)/$(FLAVOR)_ntr.firm $(RELDIR)/ntrboot/
	@cp $(OUTDIR)/$(FLAVOR)_ntr.firm.sha $(RELDIR)/ntrboot/
	@cp $(OUTDIR)/$(FLAVOR)_ntr_dev.firm $(RELDIR)/ntrboot/
	@cp $(OUTDIR)/$(FLAVOR)_ntr_dev.firm.sha $(RELDIR)/ntrboot/
	@cp $(OUTDIR)/$(FLAVOR).firm $(RELDIR)/
	@cp $(OUTDIR)/$(FLAVOR).firm.sha $(RELDIR)/
	@cp $(OUTDIR)/$(FLAVOR)_dev.firm $(RELDIR)/
	@cp $(OUTDIR)/$(FLAVOR)_dev.firm.sha $(RELDIR)/
	@cp $(ELF) $(RELDIR)/elf
	@cp $(CURDIR)/README.md $(RELDIR)
	@cp -R $(CURDIR)/resources/gm9 $(RELDIR)/gm9
	@cp -R $(CURDIR)/resources/sample $(RELDIR)/sample

	@-7za a $(RELDIR)/$(FLAVOR)-$(VERSION)-$(DBUILTS).zip ./$(RELDIR)/*

$(VRAM_TAR): $(SPLASH) $(OVERRIDE_FONT) $(VRAM_DATA) $(VRAM_SCRIPTS)
	@mkdir -p "$(@D)"
	@echo "Creating $@"
	@$(PY3) utils/add2tar.py $(VRAM_FLAGS) $(VRAM_TAR) $(shell find $^ -type f)

%.elf: .FORCE
	@echo "Building $@"
	@$(MAKE) --no-print-directory -C $(@D)

arm9/arm9.elf: $(VRAM_TAR)

$(OUTDIR)/AHBWRAM_LO.elf: $(ELF)
	@$(OBJCOPY) arm9/arm9.elf -j AHBWRAM_LO $@

$(OUTDIR)/AHBWRAM_HI.elf: $(ELF)
	@$(OBJCOPY) arm9/arm9.elf -j AHBWRAM_HI $@

BINS := $(OUTDIR)/AHBWRAM_LO.elf $(OUTDIR)/AHBWRAM_HI.elf

firm: $(ELF) $(BINS)
	@mkdir -p $(call dirname,"$(FIRM)") $(call dirname,"$(FIRMD)")
	@echo "[FLAVOR] $(FLAVOR)"
	@echo "[VERSION] $(VERSION)"
	@echo "[BUILD] $(DBUILTL)"
	@echo "[FIRM] $(FIRM)"
	@$(PY3) -m firmtool build $(FIRM) $(FTFLAGS) -g -D $(BINS) arm11/arm11.elf \
		-C NDMA NDMA XDMA
	@echo "[FIRM] $(FIRMD)"
	@$(PY3) -m firmtool build $(FIRMD) $(FTDFLAGS) -g -D $(BINS) arm11/arm11.elf \
		-C NDMA NDMA XDMA

vram0: $(VRAM_TAR) .FORCE # legacy target name

.FORCE:
