
APP=t3send
PVPATH=../../
SRC=main.cpp ../../T3Message.cpp ../../Socket.cpp \
	../../stringlist.cpp ../../HttpComponent.cpp ../../comm.cpp 

#DISTRO=Makefile	readme.txt

INCL=-I$(subst :, -I,$(PVPATH))
#LIBS=-lstdc++ -lxml -lpthread
LIBS=-lstdc++

CC=g++
#CFLAGS=-D_REENTRANT -g -Wall -ansi
CFLAGS=-g -Wall -ansi

# dependancy file
DEP_FILE=$(APP).dep

OBJDIR=obj
TMPOBJ=${SRC:%.cpp=%.o}
OBJ=$(addprefix obj/,$(notdir $(TMPOBJ)))
RELEASE=release/

########## Begin Targets

$(APP): $(OBJDIR) $(OBJ) $(RELEASE)
	$(CC) -o $(RELEASE)$(APP) $(OBJ) $(LIBS) 

depend:
	@echo "" > $(DEP_FILE)
	@for d in $(SRC) ; do \
		gcc -MM $(INCL) $(CFLAGS) $$d |\
				perl -pe "print '$(OBJDIR)/' if /:/ " >> $(DEP_FILE); \
		echo '		$$(CC) $$(CFLAGS) -o $$(OBJDIR)/$$(basename $$(notdir $$<)).o -c $$< $$(INCL)' >> $(DEP_FILE); \
		echo "" >> $(DEP_FILE); \
	done
	@echo "" >> $(DEP_FILE)

$(OBJDIR)::
	@[ -d $(OBJDIR) ] || mkdir $(OBJDIR) > /dev/null

$(RELEASE)::
	@[ -d $(RELEASE) ] || mkdir $(RELEASE) > /dev/null

#zip:
#	rm gaim_talker.zip
#	zip -j9 gaim_talker $(SRC) $(DISTRO)

clean:
	rm $(OBJ) $(RELEASE)$(APP)

include $(DEP_FILE)
