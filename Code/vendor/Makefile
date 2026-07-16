.PHONY: help
help:
	@echo "Specific targets:"
	@echo "  $(TARGETS)"
	@echo "  See each <target>.vendor.hjson for details of remote repos etc."
	@echo "General targets:"
	@echo "  all           All targets"
	@echo "  clean         Delete temporary files"
	@echo "  full_clean    Restore to pristine state"

.PHONY: all
all:
	make  $(TARGETS)

# ================================================================
VENDOR_PY = ./vendor.py

# ----------------
TARGETS += Drum_Fife
LOCKS   += Drum_Fife.lock.hjson
.PHONY: Drum_Fife
Drum_Fife:
	$(VENDOR_PY)  Drum_Fife.vendor.hjson

# ----------------
TARGETS += bsc-contrib_Misc
LOCKS   += bsc-contrib_Misc.lock.hjson
.PHONY: bsc-contrib_Misc
bsc-contrib_Misc:
	$(VENDOR_PY)  bsc-contrib_Misc.vendor.hjson

# ----------------
TARGETS += RVFI_DII_Types
LOCKS   += RVFI_DII_Types.lock.hjson
.PHONY: RVFI_DII_Types
RVFI_DII_Types:
	$(VENDOR_PY)  RVFI_DII_Types.vendor.hjson

# ================================================================

.PHONY: clean
clean:
	rm -r -f  *~

.PHONY: full_clean
full_clean: clean
	rm -r -f  $(TARGETS)  $(LOCKS)
