
# configuration file
BASENAME=t3client
BPR_MAKEFILE=$(BASENAME).bpr
BPR_TMPFILE=$(BASENAME).tmp
WIN_MAKEFILE=$(BASENAME).mak
TARGET=$(BASENAME).exe
WIN_CONFIG=

RELEASE=release
OBJ_DIR=win_obj
BUILD_FILE=build.bat
WIN_RSH=runbo
WIN_MAKE=make

RUNBO_DIR=r:\$(USER)\runbo
RUNBO_CON=$(RUNBO_DIR)\runbo.connect
RUNBO_SUC=$(RUNBO_DIR)\runbo.success

MOVE=/bin/mv
REMOVE=/bin/rm
COPY=/bin/cp

DRIVE=$(shell trdr | sed -ne 's/\:.*/:/p')
DIR=$(shell trdr | sed -e 's/$(DRIVE)\///')
WINFILE=$(shell echo  $(DRIVE)/$(DIR)/$(BUILD_FILE) | sed -e 's/\//\\\\\\\\/g')
WINDIR=\$(shell echo  $(DIR) | sed -e 's/\//\\/g')

WINE=/usr/X11R6/bin/wine --managed --winver win98

runbo: $(BUILD_FILE) $(RELEASE) $(OBJ_DIR)
	@echo $(WINFILE)
	@$(WIN_RSH) $(WINFILE) | sed -e 's/\\/\//g' 
	@if [ -n "$(BPR_TMPFILE)" ]; then \
		$(REMOVE) $(BPR_TMPFILE); \
		$(REMOVE) $(WIN_MAKEFILE); \
	fi
	@$(REMOVE) $(BUILD_FILE)

unix: $(RELEASE) $(OBJ_DIR)
	@if [ -n "$(BPR_TMPFILE)" ]; then \
	    perl -pe 's/\\\\.*?;//g' $(BPR_MAKEFILE) > $(BPR_TMPFILE); \
	    $(WINE) -- bpr2mak $(BPR_TMPFILE); \
		echo; \
	fi
	$(WINE) -- $(WIN_MAKE) -f $(WIN_MAKEFILE) | sed -e 's/\\/\//g'
	@if [ -n "$(BPR_TMPFILE)" ]; then \
		$(REMOVE) $(BPR_TMPFILE); \
		$(REMOVE) $(WIN_MAKEFILE); \
	fi

win: 
	copy $(BPR_MAKEFILE) $(BPR_TMPFILE)
	bpr2mak $(BPR_TMPFILE)
	@echo . 
	$(WIN_MAKE) -f $(WIN_MAKEFILE)
	del $(BPR_TMPFILE)
	del $(WIN_MAKEFILE)

$(BUILD_FILE)::
	@echo `date`
	@echo 'Creating $(BUILD_FILE) for $(WIN_MAKEFILE) -> $(TARGET)'
	@echo '@echo off' > $(BUILD_FILE) 
	@ if [ -n "$(RUNBO_CON)" ]; then \
		echo 'echo %0 > $(RUNBO_CON)' >> $(BUILD_FILE); \
	fi
	@echo '$(DRIVE)' >> $(BUILD_FILE)
	@echo 'cd $(WINDIR)' >> $(BUILD_FILE)
	@echo 'rem Target = $(TARGET)' >> $(BUILD_FILE)
	@ if [ -n "$(BPR_TMPFILE)" ]; then \
	    perl -pe 's/\\\\.*?;//g' $(BPR_MAKEFILE) > $(BPR_TMPFILE); \
	    echo 'bpr2mak -o $(WIN_MAKEFILE) $(BPR_TMPFILE)' >> $(BUILD_FILE); \
	    echo '@echo on' >> $(BUILD_FILE); \
	    echo '@echo Makefile Conversion Complete.' >> $(BUILD_FILE); \
	    echo '@echo off' >> $(BUILD_FILE); \
   	fi
	@echo '$(WIN_MAKE) -f $(WIN_MAKEFILE) $(WIN_CONFIG)' >> $(BUILD_FILE)
	@ if [ -n "$(RUNBO_SUC)" ]; then \
		echo 'echo %0 > $(RUNBO_SUC)' >> $(BUILD_FILE); \
	fi
	/usr/bin/unix2dos -o $(BUILD_FILE)
	
$(RELEASE)::
	@[ -d $(RELEASE) ] || mkdir $(RELEASE) > /dev/null

$(OBJ_DIR)::
	@[ -d $(OBJ_DIR) ] || mkdir $(OBJ_DIR) > /dev/null

clean:
	$(REMOVE) $(OBJ_DIR)/*.obj *.lib *.bpi *.~* *.pch *.res \
		$(RELEASE)/*.tds *.tds *.#* \
		$(RELEASE)/$(TARGET)

# this is to trick make into using unix
%.o: %.cpp $(BUILD_FILE) 
	$(BCC_RSH) $(WHO) $(COMMAND) $(OBJ_DIR)\\$*.obj 
	$(REMOVE) $(BUILD_FILE)

%.obj: %.cpp 
	$(WIN_MAKE) -f $(BCC_MAKEFILE) $(OBJ_DIR)\\$@
