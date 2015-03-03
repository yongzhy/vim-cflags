python << EOF
import vim
import os
import sys
import re
import tempfile
import logging

logger = logging.getLogger(__name__)
hdlr = logging.FileHandler(os.path.join(tempfile.gettempdir(), 'vim-cflag.log'), mode='w')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.ERROR)
logger.info("Logger Initialized")

class CDefineFile():
    def __init__(self, filename = None):
        self.allOK = True
        self.flagFile = None
        self.fileModTime = -1
        self.defines = {}
        if filename is not None:
            self.update(filename)

    def clear(self):
        self.allOK = True 
        self.flagFile = None
        self.fileModTime = -1
        self.defines.clear()

    def update(self, filename):
    # update defines from define files
        if not os.path.isfile(filename):
            vim.command("echo \"Flag file not exists\"")
            self.allOK = False
        else:
            fileChanged = False
            if self.flagFile is None or self.flagFile != filename:
                self.flagFile = filename
                fileChanged = True 
            elif self.fileModTime != os.stat(filename).st_mtime:
                self.fileModTime = os.stat(filename).st_mtime
                fileChanged = True 

            if fileChanged == True:
                self.updateDefines()
                logger.info(self.defines)

    def updateDefines(self):
        self.defines.clear()
        with open(self.flagFile, 'r') as fh:
            for line in fh:
                ll = line.strip().split()
                if len(ll) == 3 and ll[0] == '#define':
                    self.defines[ll[1]] = ll[2]

    def getDefine(self, define):
        if define in self.defines.keys():
            return self.defines[define]
        
        return None

    def printDefine(self, define):
        if define in self.defines.keys():
            print "%s : %s" % (define, self.defines[define])

ORIG_STR = r'''
syn region cCppOutWrapper start="^\s*\(%:\|#\)\s*if\s\+__0KEY__\s*\($\|//\|/\*\|&\)" end=".\@=\|$" contains=cCppOutIf,cCppOutElse,@NoSpell fold
syn region cCppOutIf contained start="__0KEY__" matchgroup=cCppOutWrapper end="^\s*\(%:\|#\)\s*endif\>" contains=cCppOutIf2,cCppOutElse
syn region cCppOutIf2 contained matchgroup=cCppOutWrapper start="__0KEY__" end="^\s*\(%:\|#\)\s*\(else\>\|elif\s\+\(__0KEY__\s*\($\|//\|/\*\|&\)\)\@!\|endif\>\)"me=s-1 contains=cSpaceError,cCppOutSkip,@Spell fold
syn region cCppOutElse contained matchgroup=cCppOutWrapper start="^\s*\(%:\|#\)\s*\(else\|elif\)" end="^\s*\(%:\|#\)\s*endif\>"me=s-1 contains=TOP,cPreCondit
syn region cCppInWrapper start="^\s*\(%:\|#\)\s*if\s\+__1KEY__\s*\($\|//\|/\*\||\)" end=".\@=\|$" contains=cCppInIf,cCppInElse fold
syn region cCppInIf contained matchgroup=cCppInWrapper start="__01KEY__" end="^\s*\(%:\|#\)\s*endif\>" contains=TOP,cPreCondit
syn region cCppInElse contained start="^\s*\(%:\|#\)\s*\(else\>\|elif\s\+\(__1KEY__\s*\($\|//\|/\*\||\)\)\@!\)" end=".\@=\|$" containedin=cCppInIf contains=cCppInElse2 fold
syn region cCppInElse2 contained matchgroup=cCppInWrapper start="^\s*\(%:\|#\)\s*\(else\|elif\)\([^/]\|/[^/*]\)*" end="^\s*\(%:\|#\)\s*endif\>"me=s-1 contains=cSpaceError,cCppOutSkip,@Spell
syn region cCppOutSkip contained start="^\s*\(%:\|#\)\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(%:\|#\)\s*endif\>" contains=cSpaceError,cCppOutSkip
syn region cCppInSkip contained matchgroup=cCppInWrapper start="^\s*\(%:\|#\)\s*\(if\s\+\(__01KEY__\s*\($\|//\|/\*\||\|&\)\)\@!\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\(%:\|#\)\s*endif\>" containedin=cCppOutElse,cCppInIf,cCppInSkip contains=TOP,cPreProc
'''

class Conditions():
    def __init__(self):
        self._0s = [] # in use condition expression that is False
        self._1s = [] # in use condition expression that is True

    def apply(self):
    # Apply the conditions on current buffer
        # reverse sort so flags beginnig with another shorter flag name can be parsed correctly
        self._0s = sorted(self._0s, reverse = True)
        self._1s = sorted(self._1s, reverse = True)
        str0key = '\(' + '\|'.join(self._0s) + '\)'
        str1key = '\(' + '\|'.join(self._1s) + '\)'
        str01key = '\(' + '\|'.join(self._0s + self._1s) + '\)'

        cmdl = []
        for line in ORIG_STR.split('\n'):
            line = line.strip()
            if line.find('__0KEY__') != -1:
                cmdl.append(line.replace('__0KEY__', str0key))
            elif line.find('__1KEY__') != -1:
                cmdl.append(line.replace('__1KEY__', str1key))
            elif line.find('__01KEY__') != -1:
                cmdl.append(line.replace('__01KEY__', str01key))

        for cmd in cmdl:
            cmd = cmd.replace('!', '\!')
            logger.info("CMD: %s" % cmd)
            vim.command(cmd)

    def _eval(self, dfile, cond):
    # Evaluate condition expression, result to be True or False
        left = cond.replace('&&', ' and ').replace('||', ' or ').replace('!', ' not ').replace('(', ' ( ').replace(')', ' ) ')
        expr = []
        for x in left.split():
            if x in dfile.defines:
                expr.append(dfile.defines[x])
            else:
                expr.append(x)
        try:
            logger.info("EXPR: %s" % " ".join(expr))
            eret = eval(' '.join(expr))
        except:
            return None
        else:
            return eret

    def add(self, dfile, cond):
        if cond not in self._0s and cond not in self._1s:
            logger.info("ADD: %s" % cond)
            ret = self._eval(dfile, cond)
            if ret == True:
                self._1s.append(cond)
            elif ret == False:
                self._0s.append(cond)

COND_MACRO = re.compile(r'^\s*#\s*(if|elif)\s+(?P<flag>.+)\s*')
def pyDoSynUpdate():
    global gDefineFile
    try:
        filename = vim.eval("g:c_define_file")
    except:
        logger.warning("g:c_define_file not defined")
        return 

    gDefineFile.update(filename)
    cond = Conditions()
    b = vim.current.buffer
    for i in range(len(b)):
        line = b[i].strip()
        pos = line.find(r'//')
        if pos != -1:
            line = line[:pos]
        pos = line.find(r'/*')
        if pos != -1:
            line = line[:pos]
        ret = COND_MACRO.match(line)
        if ret:
            flagstr = ret.group('flag')
            cond.add(gDefineFile, flagstr)

    cond.apply()

def pyPrintDefine(define):
    global gDefineFile
    try:
        filename = vim.eval("g:c_define_file")
    except:
        logger.warning("g:c_define_file not defined")
        return 

    gDefineFile.update(filename)
    word = vim.eval("expand(\"<cword>\")")
    gDefineFile.printDefine(word)


# instance for C define file, global variable
gDefineFile = CDefineFile()
EOF

function! cflags#SynUpdate()
python << EOF
pyDoSynUpdate()
EOF
endfunction

function! cflags#PrintDefine()
python << EOF
word = vim.eval("expand(\"<cword>\")")
pyPrintDefine(word)
EOF
endfunction

" define VIM command to execute the syn region udpate
command! DoSynUpdate :call cflags#SynUpdate()
