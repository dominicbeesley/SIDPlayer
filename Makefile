
define uniq =
  $(eval seen :=)
  $(foreach _,$1,$(if $(filter $_,${seen}),,$(eval seen += $_)))
  ${seen}
endef

PC := %

SIDRELOC=sidreloc-1.0-dom/sidrelocBRK
RIPSID=ripsid/ripsidBRK

SUBDIRSWIMAKE:=$(shell for a in $$(find -mindepth 1 -type d); do if [ -e $$a/Makefile ]; then echo $$a; fi; done;)
SSDS:=$(addsuffix .ssd, $(notdir $(shell for a in $$(find playlists -mindepth 1 -type d); do if [ -n $(find $$a -type f -iname "*.sid" -printf '.' | wc -c) ]; then echo $$a; fi; done;)))
BRKS:=$(addprefix playlists-conv/, $(addsuffix .brk, $(basename $(patsubst playlists/%,%,$(shell find playlists -type f -iname "*.sid")))))
BBCSID:=$(addprefix playlists-conv/, $(addsuffix .bbcsid, $(basename $(patsubst playlists/%,%,$(shell find playlists -type f -iname "*.sid")))))
BBCDIRS:=$(call uniq, $(dir $(BBCSID)))
BBCSIDINF:=$(addprefix playlists-conv/, $(addsuffix .bbcsid.inf, $(basename $(patsubst playlists/%,%,$(shell find playlists -type f -iname "*.sid")))))
BBCMEN:=$(addprefix playlists-conv/, $(addsuffix .men, $(basename $(patsubst playlists/%,%,$(shell find playlists -type f -iname "*.sid")))))


all::	interdirs subdirs $(BBCSID) $(BBCSIDINF) $(SSDS) 


interdirs: playlists-conv | $(BBCDIRS)

$(BBCDIRS) playlists-conv:
	mkdir -p $@

.SECONDEXPANSION:
$(BRKS): %.brk: playlists/$$(patsubst playlists-conv/$$(PC),$$(PC), %.sid)
	$(SIDRELOC)  -f --z 20-5F --page 1A --sid-dest-address FC20 "$<" $(basename $@).rel >$(basename $@).brk 2>$(basename $@).err; \
	x="$$?"; \
	if [ $$x -ne 0 ] && [ $$x -ne 64 ] ; then echo "$$x" >$(basename $@).bad; fi

$(BBCSID): %.bbcsid: %.brk
	if [ -e $(basename $<).bad ]; then \
		echo "." >$@; \
		echo "DOM=1" >$@.vars; \
	else \
		$(RIPSID) $(basename $@).rel $@ $< 2>"$@.vars" ;\
	fi \

$(BBCSIDINF): %.bbcsid.inf: %.bbcsid	
	$(eval FN := $(notdir $(basename $<)))
	$(eval BBSX := $(shell X=$(FN);Y=$${X//[^a-zA-Z0-9]/};echo $${Y^^}))

	./mkfilename.sh $@ $(BBSX)



subdirs: $(SUBDIRSWIMAKE)

$(SUBDIRSWIMAKE):
	make all -C $@

%.ssd:	playlists-conv/%/*.bbcsid.inf sidplayer/sidpelk.bbc sidplayer/sidpl.bbc
	echo "make ssd"
	dfs form -80 $@.tmp
	$(eval TMP := $(shell mktemp))
	echo -e "MO.7\r\n*SIDPLAY\r\n" >$(TMP)
	dfs add -f "!BOOT" $@.tmp "$(TMP)"

	$(eval BBCSIDINFNOTBAD := $(foreach var,$(wildcard playlists-conv/$(basename $@)/*.bbcsid.inf),$(if $(wildcard $(basename $(basename $(var))).bad),,$(var))))


	#count good inf files
	printf "\\x$$(printf "%x" $(words $(BBCSIDINFNOTBAD)))" > $(TMP)
	cat $(foreach v,$(sort $(BBCSIDINFNOTBAD)),$(basename $v).men) >> $(TMP)

	dfs add $@.tmp $(BBCSIDINFNOTBAD)

	dfs add -l 0x6000 -e 0x6000 -f "sidplay" $@.tmp "sidplayer/sidpl.bbc"
	dfs add -l 0x4800 -e 0x4800 -f "sidpelk" $@.tmp "sidplayer/sidpelk.bbc"
	dfs add -l 0x7C00 -e 0x0000 -f "M.MENU" $@.tmp "$(TMP)"
	dfs add -f "F.HEX" $@.tmp "sidplayer/hexdigs.bin"

	dfs opt4 -3 $@.tmp
	dfs title $@.tmp $(basename $@)

	-rm $(TMP)
	-rm $@
	mv $@.tmp $@





clean:
	rm -r -f inter
	rm -r -f playlists-conv
	$(foreach a,$(SUBDIRSWIMAKE), $(MAKE) -C $(a) clean;)
	rm -f *.ssd

.PHONY:	all clean $(SUBDIRSWIMAKE)
