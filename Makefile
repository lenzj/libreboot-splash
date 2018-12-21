# User defined preferences in following file
include config.mk

LB_BAS = $(LB_MIR)/stable/$(LB_VER)
LB_SHA = SHA512SUMS
LB_SIG = SHA512SUMS.sig
LB_REC = 0x969A979505E8C5B2

LBR_NAM = libreboot_r$(LB_VER)_$(LBR_LOD)_$(LBR_COM)_$(LBR_SIZ)mb
LBR_TXZ = $(LBR_NAM).tar.xz
LBR_DWN = $(LB_BAS)/rom/$(LBR_LOD)/$(LBR_TXZ)
LBR_FIL = $(LBR_COM)_$(LBR_SIZ)mb_$(LBR_KEY)_$(LBR_DIS).rom

LBU_NAM = libreboot_r$(LB_VER)_util
LBU_TXZ = $(LBU_NAM).tar.xz
LBU_DWN = $(LB_BAS)/$(LBU_TXZ)

PKG = package
BLD = build
BLD_LBR = $(BLD)/$(LBR_NAM)
BLD_LBU = $(BLD)/$(LBU_NAM)
CBFSDIR = $(BLD_LBU)/cbfstool/$(LBU_CPU)
CBFSTOOL = $(CBFSDIR)/cbfstool
ICH9DIR = $(BLD_LBU)/ich9deblob/$(LBU_CPU)
ICH9GEN = $(ICH9DIR)/ich9gen
ICH9FIL = ich9fdgbe_$(LBR_SIZ)m.bin

IMG = images
BLD_LBC = $(BLD)/libreboot_custom
LBR_CUS = $(LBR_COM)_$(LBR_SIZ)mb_$(LBR_KEY)_$(LBR_DIS)_cust.rom
LBR_IMG = $(IMG_NAM).$(IMG_EXT)

all: $(BLD_LBC)/$(LBR_CUS)

$(BLD_LBC)/$(LBR_CUS): $(BLD_LBR)/$(LBR_FIL) $(IMG)/$(LBR_IMG) $(CBFSTOOL)
	@if [ "$(LBR_MAC)" = "00:00:00:00:00:00" ]; then \
		echo "Error:The LBR_MAC variable needs to be updated in config.mk"; \
		exit 1; \
	fi
	mkdir -p $(BLD_LBC)
	cp $(BLD_LBR)/$(LBR_FIL) $(BLD_LBC)/$(LBR_CUS)
	# Update rom to use appropriate mac address
	$(ICH9GEN) --macaddress $(LBR_MAC)
	mv $(ICH9FIL) $(BLD_LBC)
	rm ich9*.bin mkgbe*
	cd $(BLD_LBC); dd if=$(ICH9FIL) of=$(LBR_CUS) bs=12k count=1 conv=notrunc
	# Copy in desired splash image to build folder
	cp $(IMG)/$(LBR_IMG) $(BLD_LBC)/background.$(IMG_EXT)
	# Update grub.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) extract -n grub.cfg -f $(BLD_LBC)/grub_orig.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) remove -n grub.cfg
	sed -e 's:background.jpg:background.$(IMG_EXT):' $(BLD_LBC)/grub_orig.cfg > $(BLD_LBC)/grub_cust.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) add -n grub.cfg -f $(BLD_LBC)/grub_cust.cfg -t raw
	# Update grubtest.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) extract -n grubtest.cfg -f $(BLD_LBC)/grubtest_orig.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) remove -n grubtest.cfg
	sed -e 's:background.jpg:background.$(IMG_EXT):' $(BLD_LBC)/grubtest_orig.cfg > $(BLD_LBC)/grubtest_cust.cfg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) add -n grubtest.cfg -f $(BLD_LBC)/grubtest_cust.cfg -t raw
	# Update background (boot splash) file
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) remove -n background.jpg
	$(CBFSTOOL) $(BLD_LBC)/$(LBR_CUS) add -n background.$(IMG_EXT) -f $(BLD_LBC)/background.$(IMG_EXT) -t raw

$(BLD_LBR)/$(LBR_FIL): $(PKG)/$(LBR_TXZ)
	mkdir -p $(BLD)
	tar -C $(BLD) -xf $(PKG)/$(LBR_TXZ)
	touch $@

$(PKG)/$(LBR_TXZ): $(PKG)/$(LB_SHA)
	mkdir -p $(@D)
	wget -O $(PKG)/$(LBR_TXZ) $(LBR_DWN)
	cd $(PKG); cat $(LB_SHA) | grep $(LBR_NAM) | sed -e 's:./rom/grub/::' | sha512sum -c
	touch $@

$(CBFSTOOL): $(PKG)/$(LBU_TXZ)
	mkdir -p $(BLD)
	tar -C $(BLD) -xf $(PKG)/$(LBU_TXZ)
	touch $@

$(PKG)/$(LBU_TXZ): $(PKG)/$(LB_SHA)
	mkdir -p $(PKG)
	wget -O $(PKG)/$(LBU_TXZ) $(LBU_DWN)
	cd $(PKG); cat $(LB_SHA) | grep $(LBU_NAM) | sha512sum -c
	touch $@

$(PKG)/$(LB_SHA): config.mk
	mkdir -p $(PKG)
	wget -O $(PKG)/$(LB_SHA) $(LB_BAS)/$(LB_SHA)
	wget -O $(PKG)/$(LB_SIG) $(LB_BAS)/$(LB_SIG)
	gpg --recv-keys $(LB_REC)
	cd $(PKG); gpg --verify $(LB_SIG)
	touch $@

clean:
	rm -Rf $(BLD)

distclean:
	rm -Rf $(PKG) $(BLD)

.PHONY:
	all clean distclean
