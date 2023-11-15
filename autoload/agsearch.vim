" Script Name: agsearch.vim
" Description: search with ag (silver searcher) or grep.
"
" Copyright:   (C) 2018-2022
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:  <javierpuigdevall@gmail.com>
"
" Dependencies: jobs.vim, ag, grep, cat, awk.
"


"- functions -------------------------------------------------------------------
"
" Get the plugin reload command
function! agsearch#Reload()
    let l:pluginPath = substitute(s:plugin_path, "autoload", "plugin", "")
    let l:autoloadFile = s:plugin_path."/".s:plugin_name
    let l:pluginFile = l:pluginPath."/".s:plugin_name
    return "silent! unlet g:loaded_agsearch | so ".l:autoloadFile." | so ".l:pluginFile
endfunction


" Edit plugin files
" Cmd: Agedit
function! agsearch#Edit()
    let l:plugin = substitute(s:plugin_path, "autoload", "plugin", "")
    silent exec("tabnew ".s:plugin)
    silent exec("vnew   ".l:plugin."/".s:plugin_name)
endfunction


function! s:Initialize()
    let s:verbosityLevel = 0
    "let s:verbosityLevel = 1

    let s:jobsRunningDict = {}

    " Check jobs.vim plugin installed
    if empty(glob(s:plugin_path."/jobs.vim"))
        call s:Error("missing plugin jobs.vim (".s:plugin_path."/jobs.vim".")")
        call input("")
    endif

    if !exists("g:AgSearch_searchList")
        let g:AgSearch_searchList = []
    endif

    if !exists("g:AgSearch_searchInfoList")
        let g:AgSearch_searchInfoList = []
    endif

    if !exists("g:AgSearch_searchInfoCmdList")
        let g:AgSearch_searchInfoCmdList = []
    endif

    silent! unlet g:AgSearch_commandHelpList = []
    silent! unlet g:AgSearch_mappingsHelpList = []
    silent! unlet g:AgSearch_abbrevHelpList = []
endfunction


function! s:Error(mssg)
    echohl ErrorMsg | echom s:plugin.": ".a:mssg | echohl None
endfunction


function! s:Warn(mssg)
    echohl WarningMsg | echom a:mssg | echohl None
endfunction


function! s:EchoGreen(normalStr1, orangeStr, normalStr2)
    echon a:normalStr1
    echohl DiffAdd | echon a:orangeStr | echohl None
    echo a:normalStr2
endfunction

function! s:EchoOrange(normalStr1, orangeStr, normalStr2)
    echon a:normalStr1
    echohl WarningMsg | echon a:orangeStr | echohl None
    echo a:normalStr2
endfunction


" Debug function. Log message
function! s:Verbose(level,func,mssg)
    if s:verbosityLevel >= a:level
        echom "["s:plugin_name." : ".a:func." ] ".a:mssg
    endif
endfunction


" Debug function. Log message and wait user key
function! s:VerboseStop(level,func,mssg)
    if s:verbosityLevel >= a:level
        call input("[".s:plugin_name." : ".a:func." ] ".a:mssg." (press key)")
    endif
endfunction


func! agsearch#Verbose(level)
    if a:level == ""
        echo "[agsearch.vim] Verbosity: ".s:verbosityLevel
        return
    endif
    let s:verbosityLevel = a:level
    call s:Verbose(0, expand('<sfile>'), "Set verbose level: ".s:verbosityLevel)
endfun


function! s:WindowSplitMenu(default)
    let w:winSize = winheight(0)
    let text =  "split hor&izontal\n&split vertical\nnew &tab\ncurrent &window"
    let w:split = confirm("", l:text, a:default)
    redraw
endfunction


function! s:WindowSplit()
    if !exists('w:split')
        return
    endif

    let l:split = w:split
    let l:winSize = w:winSize

    if w:split == 1
        silent exec("sp! | enew")
    elseif w:split == 2
        silent exec("vnew")
    elseif w:split == 3
        silent exec("tabnew")
    elseif w:split == 4
        silent exec("enew")
    endif

    let w:split = l:split
    let w:winSize = l:winSize - 2
endfunction


function! s:WindowSplitEnd()
    if exists('w:split')
        if w:split == 1
            if exists('w:winSize')
                let lines = line('$')
                if l:lines <= w:winSize
                    echo "resize ".l:lines
                    exe "resize ".l:lines
                else
                    exe "resize ".w:winSize
                endif
            endif
            exe "normal! gg"
        endif
    endif
    silent! unlet w:winSize
    silent! unlet w:split
endfunction




"- AG search functions -----------------------------------------------------------

" Perform search of pattern on file/path
" Dump results to location list or file
" Arg1: pattern: text to search. Coma will be used to separate patterns for nested
"     ag searches.
" Arg2: file: input file/path where searching the pattern
" Arg3: options: 
" Return: output file where dumping the result, when empty use the location list
function! s:AgSearch(pattern, file, options)

    let file = a:file
    let fileDelete = ""
    let async = 1

    " When file's empty use current buffer as filename
    if l:file == ""
        let l:file = expand('%:t')
        echo "Empty path, use ".l:file
    endif

    " Check file exist
    "echomsg "Is file:".empty(glob(l:file))." dir:".isdirectory(l:file)

    if getbufvar(winbufnr(0), '&buftype') == 'quickfix'
        " Search on all files found on the QF window
        echo "Search input from quickfix window"
        let file = tempname()
        let fileDelete = l:file
        silent exec(":w! ".l:file)
    endif

    " Check file exist or directory exist
    let ext  = expand('%:t:e')
    if empty(glob(l:file)) || l:ext == "gz" || l:ext == "Z" || l:ext == "bz2" 
        "echomsg "empty file"
        if isdirectory(l:file)
            "echomsg "no dir"
            " Buffer not saved on file, dump content to a new tmp file
            let file = tempname()
            let fileDelete = l:file
            silent exec(":w! ".l:file)
            call s:Verbose(1, expand('<sfile>'), "Safe buffer on tmp file: ".l:file)
            "echomsg "dump buffer to file:"
        endif
    else
        " NOTE: single file, async search not needed
        "let noasync = 1
    endif

    if getbufvar(winbufnr(0), '&buftype') == 'quickfix'
        if !executable('cat')
            call s:Error("Executable 'cat' not found")
            return 1
        endif
        if !executable('grep')
            call s:Error("Executable 'grep' not found")
            return 1
        endif
        if !executable('awk')
            call s:Error("Executable 'awk' not found")
            return 1
        endif
        " Search on all files found on the QF window
        " Do not search on cotext lines of the QF window
        let tool0 = "cat ".l:file." |  grep \"|[123456789].*|\" | awk -F\"|\" '{print $1}' | xargs "
        let file = ""
        " NOTE: Async search not working when concatenating commands (using pipes)
        echo "Set search synchronous 0"
        let async = 0
    else
        let tool0 = ""
    endif

    if executable('ag')
        let tool0 .= "ag --vimgrep ".a:options
        let tool1  = "ag --nofilename "
    else
        if executable('grep')
            call s:Error("grep not found")
            return
        endif
        let tool0 .= "grep ".a:options
        let tool1  = "grep "
    endif

    " Iterate on comma separeted patterns
    " Concatenate a grep for every new pattern
    let n = 0
    let list = split(a:pattern, g:AgSearch_patternSeparator)
    for index in l:list 
        "echomsg "index".l:n.":"

        " Remove ' character at init or end
        if ( strpart(l:index,0,1) == "'" )
            let index = strpart(l:index,1)
        endif

        if ( strpart(l:index,strlen(l:index)-1,1) == "'" )
            let index = strpart(l:index,0,strlen(l:index)-1)
        endif

        if ( strpart(l:index,0,1) == "-" )
            let index = strpart(l:index,1)
            let opt = " -v "
        else
            let opt = ""
        endif

        if ( l:n == 0 ) | 
            let cmd = "".l:tool0.l:opt." \"".l:index."\" ".l:file
            let search = l:index
            " Vim search first search pattern
            let @/=l:index
        else
            let l:cmd .=" | ".l:tool1.l:opt." \"".l:index."\""
            " NOTE: Async search not working on commands with pipes
            echo "Set search synchronous 1"
            let async = 0
        endif
        let n += 1
    endfor

    " commented 2018-08-03 08:57 
    "if l:cmd =~ "*"
        " NOTE: Async search not working on commands with pipes/regexp
        " searches
        "echo "Set search synchronous 2"
        "let async = 0
    "endif

    " Change location's lists buffer title
    let pwd = getcwd()."/"
    let path = substitute(l:file, l:pwd, '', 'g')

    let l:cmdTmp = substitute(l:cmd, '"', '\\"', 'g')
    let l:callback = ["agsearch#SearchEnd", a:pattern, l:path, l:cmdTmp]
    "echom "callback: "l:callback

    echom "[agsearch.vim] Cmd: ".l:cmd
    let g:AgSearch_searchInfoCmdList += [ l:cmd ]

    call s:SystemCmd(l:cmd, l:callback, async)

    " Clean tmp file used for searching on buffers not saved
    if l:fileDelete != "" | call delete(l:fileDelete) | endif
    return 0
endfunction


function! agsearch#SearchEnd(searchPattern, searchPath, searchCmd, resfile)
    silent exec "new ".a:resfile
    if s:verbosityLevel >= 4 | silent sav! temp | endif 

    let l:searchInfoDict = { 'resultsNum':0, 'searchPattern':a:searchPattern, 'searchPath':a:searchPath, 'searchCmd':a:searchCmd  }

    if line('$') == 1 && getline(1) == ''
        silent bd!
        call delete(a:resfile)
        echom "[agsearch.vim] Search ".a:searchPattern." on ".a:searchPath.". NO results found"
        redraw
        call s:Warn("[agsearch.vim] Search:'".a:searchPattern."' path:".a:searchPath.". No results found")
        let g:AgSearch_searchInfoList += [ l:searchInfoDict ]
        return 1
    endif

    let l:len = line('$')

    " Remove error messages
    silent! %s#^./##g
    " Remove complete paths
    silent! exec "%s#".getcwd()."/##g"
    " Remove paths beginning with ./
    silent! %s#^./##g
    if s:verbosityLevel >= 4 | silent sav! temp1 | endif 

    silent w!
    silent bd!

    if s:verbosityLevel >= 4 | tabnew temp | new temp1 | new temp2 | endif 

    let l:resultNumList = s:GetSearchResultsList(a:resfile)
    let l:resultLines = l:resultNumList[0]
    let l:contextBlocks = l:resultNumList[1]

    let l:headerLines = s:AddHeader(a:resfile, a:searchPattern, a:searchPath, l:resultLines)

    if g:AgSearch_autoSave == 1
        let l:filename = s:GetDefaultSaveFileName("auto")
        silent exec("silent w! ".l:filename)
        call s:RotateAutoSaveFiles()
    endif
    silent bd!

    let maxWinSize = winheight(0) / 2

    " Open search in location list 
    silent! call LocListSetOpen()
    silent exec("lgetfile ".a:resfile)
    silent lwindow
    wincmd j
    if &ft != "qf"
        call s:Error("Quickfix load error")
        return 1
    endif
    setlocal cursorline
    silent exe "silent normal! gg"
    let lines = line('$')

    call delete(a:resfile)

    if &buftype != 'quickfix'
        echom "[agsearch.vim] Search ".a:searchPattern." on ".a:searchPath.". NO results found"
        redraw
        call s:Warn("[agsearch.vim] Search:'".a:searchPattern."' path:".a:searchPath.". No results found.")
        let g:AgSearch_searchInfoList += [ l:searchInfoDict ]
        return 1
    endif

    " Check search results
    if l:lines == 0
        lwindow
        echom "[agsearch.vim] Search ".a:searchPattern." on ".a:searchPath.". NO results found"
        redraw
        call s:Warn("[agsearch.vim] Search:'".a:searchPattern."' path:".a:searchPath.". No results found.")
        let g:AgSearch_searchInfoList += [ l:searchInfoDict ]
        return 1
    endif

    let path = substitute(a:searchPath, '/', '-', 'g')
    let path = substitute(l:path, '-$', '', 'g')
    let path = substitute(l:path, '_-', '', 'g')
    "let path = substitute(l:path, ' ', '_', 'g')
    let path = substitute(l:path, ' ', '__', 'g')
    let path = substitute(l:path, '_$', '', 'g')

    "let l:buffname = "_agsearch_".a:searchPattern."_".l:path.".qf"
    let l:buffname  = g:AgSearch_savedSearchHeader
    let l:buffname .= "agsearch_".a:searchPattern."_".l:path."."
    let l:buffname .= g:AgSearch_savedSearchTail
    silent exec("0file")
    silent! exec("file ".l:buffname)

    " Fold lines, do not display the search context
    let w:AgSearch_resultLines = l:resultLines
    let w:AgSearch_contextBlocks = l:contextBlocks
    let l:lines = w:AgSearch_resultLines + w:AgSearch_contextBlocks + l:headerLines
    silent! normal ggzC
    call s:FoldContent()
    " Resize the quickfix window
    call s:ResizeQfWin(l:maxWinSize, l:lines)

    let l:searchInfoDict['resultsNum'] = l:resultLines
    let g:AgSearch_searchInfoList += [ l:searchInfoDict ]
    "echom "AgSearch_searchInfoList "g:AgSearch_searchInfoList

    echom "[agsearch.vim] Search ".a:searchPattern." on ".a:searchPath.".  Results found: ".l:resultLines
    redraw
    echo "[agsearch.vim] Search results found: ".l:resultLines
    return 0
endfunction


function! s:GetDefaultSaveFileName(mode)
    let l:filename  = g:AgSearch_savedSearchHeader
    let l:filename .= "vim-agsearch_"
    let l:filename .= strftime("%y%m%d-%H%M%S")
    if a:mode == "auto"
        let l:filename .= "_auto"
    endif
    let l:filename .= ".".g:AgSearch_savedSearchTail

    "echom "Autosave with name: ".l:filename
    return l:filename
endfunction


function! s:GetDefaultSaveFileName0(mode)
    if a:mode == "auto"
        let l:files = glob("*vim-agsearch_auto.*".g:AgSearch_savedSearchTail)
    else
        let l:files = glob("*vim-agsearch.*".g:AgSearch_savedSearchTail)
    endif

    let l:filesList = split(l:files)


    if len(l:filesList) > 0
        call sort(l:filesList, "agsearch#NumericSortDfltFilename")

        let l:lastFile = l:filesList[-1]
        let l:list = split(l:lastFile, '\.')
        let l:saveCounter = str2nr(l:list[1])
        if l:saveCounter == 0
            let l:saveCounter = 1
        else
            let l:saveCounter += 1
        endif
    else
        let l:saveCounter = 1
    endif

    let l:filename  = g:AgSearch_savedSearchHeader
    if a:mode == "auto"
        let l:filename .= "vim-agsearch_auto.".l:saveCounter."."
    else
        let l:filename .= "vim-agsearch.".l:saveCounter."."
    endif
    let l:filename .= g:AgSearch_savedSearchTail

    "echom "Autosave with name: ".l:filename
    return l:filename
endfunction


function! s:RotateAutoSaveFiles()
    let l:globpath  = g:AgSearch_savedSearchHeader
    let l:globpath .= "vim-agsearch*auto*."
    let l:globpath .= g:AgSearch_savedSearchTail

    let l:filesListStr = glob(l:globpath)
    let l:filesList = split(l:filesListStr)
    "echom "AutoSave files: "l:filesList

    if len(l:filesList) <= 0
        return
    endif
    if g:AgSearch_autoSaveNum  <= 0
        return
    endif
    if len(l:filesList) <= g:AgSearch_autoSaveNum 
        return
    endif

    let l:max = len(l:filesList) - g:AgSearch_autoSaveNum
    let l:n = 0

    call sort(l:filesList, "agsearch#NumericSortDfltFilename")

    for l:file in l:filesList
        if l:n > l:max | break | endif
        "echom "Rotate auto save, delete: ".l:file
        call delete(l:file)
        let l:n += 1
    endfor
endfunction


function! s:AddHeader(file,pattern,path,lines)
    setlocal modifiable
    exec "new ".a:file
    normal ggO
    let text = "[agsearch.vim] search pattern:'".a:pattern."' path:'".a:path."' (".a:lines." results)"
    put=l:text
    normal ggdd
    silent w
    setlocal nomodifiable
    return 1
endfunction


function! s:AlignQfData(file)
    exec "new ".a:file
    s#^./##g
    exec "s#^".getwd()."/##g"
    exec "s#\([0-9]:\) #\1".."#g"
    close
endfunction


"  
function! s:ResizeQfWin(max,lines)
    "let lines = len(getqflist())
    "echomsg "Lines max:".a:max." lines:".a:lines

    if a:lines <= a:max
        let resize = a:lines
    else
        let resize = a:max
    endif
    exe "resize ".l:resize
    return 0
endfunction


"- ASYNCHRONOUS JOB manager functions -----------------------------------------------------------
"
" Manage asynchronous system calls.
" Asign a name to identify the system call type.
" Allow only one system call per window.
" Keep track of the system calls launched.
" Arg1: system command.
" Arg2: callback function to process the system results.
" Arg3: if true run the system call on backgraund.
function! s:SystemCmd(command,callback,async)
    if !exists("g:VimJobsLoaded")
        call s:Error("Plugin jobs.vim not loaded.")
        return
    endif

    let jobName = "agsearch"

    if jobs#IsOnWindow(l:jobName) == 1
        call s:Error("Agsearch command already running in background on this window")
        return
    endif

    if g:AgSearch_runInBackground == 0 || a:async == 0
        "echo "Set search synchronous 10"
        let l:async = 0
    else
        let l:async = 1
    endif

    " DEBUG: Show command and wait user key
    if s:verbosityLevel == 1
        echo "cmd: ".a:command
        echo "(Press key to continue)"
        call input("")
    endif

    "call jobs#RunCmd(a:command,a:callback,l:async,l:jobName)
    redraw
    call jobs#RunCmd0(a:command,a:callback,l:async,l:jobName)
endfunction


" Ag search command. 
" Use bash stile command to introduce the options/arguments.
" Arguments:
"   PATH                   : search paths.
"   PATTERN_1,PATTERN_N    : search pattern.
"
"   [-if=PATTERN1,PATTERN] : comma separated files to ignore
"   [-id=DIR1,DIR2]        : comma separated directories to ignore
"   [-r=_DIR_]             : replace first match of word _DIR_ on path
"
"   [--ignore-files=PATTERN1,PATTERN] : comma separated files to ignore
"   [--ignored-dirs=DIR1,DIR2]        : comma separated directories to ignore
"   [--replace-pattern=_DIR_]         : replace first match of word _DIR_ on path
" Return: none
" Commands: Ags, Agsd, Agsp, Agsf, Agsw, Agsb.
function! agsearch#Search(...)
    let l:path        = ""
    let l:pattern     = ""
    let l:options     = ""
    let l:dirs        = ""
    let l:files       = ""
    let l:before      = g:AgSearch_contextLinesBefore
    let l:after       = g:AgSearch_contextLinesAfter
    let l:filePattern = ""
    let l:dfltReplaceList = split(g:AgSearch_defaultReplacePatterns)
    let l:replaceList = []
    let l:cmd         = ""

    " Parse Function Arguments:
    " First parse the replace pattern argument (-rp or --replace-pattern)
    call s:Verbose(1, expand('<sfile>'), "Parse replace patterns function arguments")
    let n = 1
    for index in a:000
        call s:Verbose(1, expand('<sfile>'), "Arg".l:n.": ".l:index)
        if l:index[0] != "-" && l:index !~ "__FILE"
            let l:list = split(l:index, '=')
            if len(l:list) < 2
                continue
            endif

            let l:field = l:list[0][1:]
            let l:value = l:list[1]
            call s:Verbose(1, expand('<sfile>'), "ReplacePattern option: ".l:field." value:".l:value)
            "echom "ReplacePattern: option:".l:field." value:".l:value

            if l:field ==? "rp" || l:field ==# "-replace-pattern"
                call add(l:replaceList, l:value)
                call s:Verbose(1, expand('<sfile>'), " ReplaceList: ".join(l:replaceList))
            endif
        endif
        let n += 1
    endfor

    call s:Verbose(1, expand('<sfile>'), "")

    " Parse Function Arguments:
    " Parse the rest of the arguments:
    call s:Verbose(1, expand('<sfile>'), "Parse function arguments")
    let l:optionArgExpected = 0
    let l:n = 0
    for index in a:000
        let l:n += 1
        call s:Verbose(1, expand('<sfile>'), "Arg".l:n.": ".l:index)
        "if l:index[0] != "-" && l:index =~ "__FILE"
        if l:index[0] != "-"
            if l:optionArgExpected == 1
                let l:options .= l:index." "
                let l:optionArgExpected = 0
                call s:Verbose(1, expand('<sfile>'), " Arg: ".l:index." (is not an option, no - found)")
                continue
            endif

            let l:found = 0

            " Check if argument has a replace string:
            " If has a replace string then asume it is a path.
            for l:tag in l:replaceList
                if l:tag =~ ","
                    let l:list = split(l:tag, ",")
                    let l:tag = l:list[0]
                endif
                "echom "Check replace pattern tag:".l:tag." against ".l:index

                if l:index =~ l:tag
                    " The argument contains a pattern replace, so it must be a search path.
                    let l:path .= l:index." "
                    call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (contains replace pattern)")
                    let l:found = 1
                    break
                endif
            endfor
            if l:found == 1
                call s:Verbose(1, expand('<sfile>'), " Replace string found")
                continue
            endif

            " Check if argument has a default replace string:
            " If hast a replace string then asume it is a path.
            for l:replaceStr in split(g:AgSearch_defaultReplacePatterns)
                if l:index =~ l:replaceStr
                    " The argument contains a pattern replace so it must be a search path.
                    let l:path .= l:index." "
                    call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (contains replace pattern)")
                    let l:found = 1
                    break
                endif
            endfor
            if l:found == 1
                call s:Verbose(1, expand('<sfile>'), " Replace string found")
                continue
            endif

            " Check if path its __FILES__, then all files opened on vim should be searched.
            " File filters example: __FILES:keepPattern:--skipPattern__
            if l:index =~ "__FILES"
                let l:files = agsearch#GetBuffersAsString()
                call s:Verbose(1, expand('<sfile>'), " Search buffers: ".l:files)
                if l:files != ""
                    let l:pathTmp = ""
                    let l:filters = ""
                    let l:i = 1
                    "let l:i = 0
                    if l:index =~ ":"
                        let l:filters = substitute(l:index, "FILES:", "", "")
                        let l:filters = substitute(l:filters, "__", "", "g")
                        echo "Files loaded matching filters: ".substitute(l:filters, ":", ", ", "g")
                    else
                        echo "Files loaded:"
                    endif
                    for l:file in split(l:files)
                        call s:Verbose(1, expand('<sfile>'), "Check file: ".l:file)
                        "let l:i += 1
                        if l:filters != ""
                            " Filter files uising the provided keep/skip patterns.
                            let l:skipFile = 0
                            for l:filter in split(l:filters, ':')
                                if l:filter[0:1] == "--"
                                    " Filter patter to skip the file.
                                    let l:filterTmp = l:filter[2:]
                                    "echom "Check skip filter ".l:filter." file: ".l:file
                                    if l:file =~ l:filterTmp
                                        let l:skipFile = 1
                                        break
                                    endif
                                else
                                    " Filter patter to keep the file.
                                    "echom "Check keep filter ".l:filter." file: ".l:file
                                    if l:file !~ l:filter
                                        let l:skipFile = 1
                                        break
                                    endif
                                endif
                            endfor
                            if l:skipFile == 1
                                if g:AgSearch_showFilterSkipFiles == 1
                                    echohl Conceal
                                    echo " - File ".l:i.": ".l:file." (skip file, filtered by: '".l:filter."')."
                                    echohl None
                                    let l:i += 1
                                endif
                                continue
                            endif
                        endif
                        if filereadable(l:file)
                            echo " - File ".l:i.": ".l:file
                            let l:i += 1
                            let l:pathTmp .= l:file." "
                        else
                            if g:AgSearch_showNotFoundFiles == 1
                                echohl WarningMsg
                                echo " - File ".l:i.": ".l:file." (not found)."
                                let l:i += 1
                                echohl None
                            endif
                        endif
                    endfor
                    if len(l:pathTmp) == 0
                        call s:Warn("Search all open files: no files found.")
                    else
                        call confirm("Search this ".len(split(l:pathTmp))." files?")
                        let l:path .= l:pathTmp
                    endif
                endif
                continue
            endif

            " Check if argument contains wildcards
            let l:pathFilesList = globpath(l:index, '*')
            if len(l:pathFilesList) != 0
                let l:path .= l:index." "
                call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (paths contains wildcard)")
                continue
            endif

            if filereadable(l:index) != 0
                let l:path .= l:index." "
                call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (file found)")
            elseif glob(l:index) != ""
                let l:path .= l:index." "
                call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (wildcard file found)")
            elseif isdirectory(l:index) != 0
                let l:path .= l:index." "
                call s:Verbose(1, expand('<sfile>'), " Path: ".l:path." (dir found)")
            else
                if l:pattern != ""
                    let l:pattern .= "|"
                    let l:pattern .= l:index
                else
                    let l:pattern = l:index
                endif
                call s:Verbose(1, expand('<sfile>'), " Pattern: ".l:pattern)
            endif
        else
            let l:optionArgExpected = 0

            let l:list = split(l:index, '=')
            if len(l:list) < 2
                let l:options .= l:index." "
                let l:optionArgExpected = 1
                call s:Verbose(1, expand('<sfile>'), " Option: ".l:index)
                continue
            endif

            let l:field = l:list[0][1:]
            let l:value = l:list[1]
            call s:Verbose(1, expand('<sfile>'), " Field: ".l:field." Value:".l:value)

            if l:field ==? "if" || l:field ==? "-ignore-files"
                let l:files .= l:value
                call s:Verbose(1, expand('<sfile>'), " IgnoreFiles: ".l:files)
            elseif l:field ==# "id" || l:field ==# "-ignore-dirs"
                let l:dirs = l:value
                call s:Verbose(1, expand('<sfile>'), " IgnoreDirs: ".l:dirs)
            elseif l:field ==? "rp" || l:field ==# "-replace-pattern"
                " Already parsed before.
            else
                let l:options .= l:index." "
                let l:optionArgExpected = 1
                call s:Verbose(1, expand('<sfile>'), " Option: ".l:index)
            endif
        endif
        let n += 1
    endfor

    call s:Verbose(1, expand('<sfile>'), "")

    if l:pattern == ""
        call s:Warn("[agsearch.vim] Argument error. Search pattern not found.")
        return
    endif

    if l:path == ""
        call s:Error("[agsearch.vim] Argument error. Search path not found.")
        return
    endif

    if len(globpath(l:path, '*')) != 0
        call s:Error("[agsearch.vim] Argument error. Search path empty ".l:path)
        return
    endif

    " Apply Replace Patterns:
    if len(l:replaceList) == 0
        let l:replaceList = l:dfltReplaceList
    endif

    if len(l:replaceList) != 0

        for index in l:replaceList 
            call s:Verbose(2, expand('<sfile>'), "search replace pattern:".l:index)
            if l:index =~ ","
                let list      = split(l:index,",")
                let l:search  = get(l:list,0,"")
                let l:replace = get(l:list,1,"")
                "echom "Check replace pattern. Search tag:".l:search." against ".l:path.". Replace with:".l:replace
                call s:Verbose(2, expand('<sfile>'), "Check replace pattern. Search tag:".l:search." against ".l:path.". Replace with:".l:replace)
            else
                let l:search  = l:index
                let l:replace = ""
                "echom "Check replace pattern. Search tag:".l:search." against ".l:path
                call s:Verbose(2, expand('<sfile>'), "Check replace pattern. Search tag:".l:search." against ".l:path)
            endif

            if l:path =~ l:search
                call s:Verbose(1, expand('<sfile>'), "replace pattern:".l:search." with:".l:replace)

                if l:search == "" | break | endif

                if l:replace == ""
                    echo "Search path: ".l:path
                    let l:replace = input("Replace pattern ".l:search." with: ")
                    echo " "
                    if l:replace == "" | let l:replace = "*" | endif
                endif

                "echom "Replace pattern:".l:search." with:".l:replace
                call s:Verbose(2, expand('<sfile>'), "Replace pattern:".l:search." with:".l:replace)
                let l:path = substitute(l:path, l:search, l:replace, 'g')
                "echom "path: ".l:path
            endif
        endfor

        " Check paths exist:
        "echom "Check path: ".l:path
        let l:pathList = split(l:path)
        let l:path = ""
        for l:singlePath in l:pathList
            if glob(l:singlePath) != ""
                let l:path .= l:singlePath." "
                call s:Verbose(1, expand('<sfile>'), " Path: ".l:singlePath." (paths contains wildcard)")
            else
                call s:Warn("[agsearch.vim] Path not found ".l:singlePath)
            endif
        endfor
        "echom "Verified path: ".l:path
    endif

    if l:path == ""
        call s:Error("Argument error. Search path not found.")
        return
    endif

    if l:options !~ "-C" && l:options !~ "-A" && l:options !~ "-B"
        if g:AgSearch_contextLinesBefore != 0
            let l:options .= "-B ".g:AgSearch_contextLinesBefore." "
        endif
        if g:AgSearch_contextLinesAfter != 0
            let l:options .= " -A ".g:AgSearch_contextLinesAfter." "
        endif
    endif

    if l:files != ""
        let list = split(l:files,",")
        for index in l:list 
            let l:options .= "--ignore \"".l:index."\" "
        endfor
    endif

    if l:dirs != ""
        let list = split(l:dirs,",")
        for index in l:list 
            let l:options .= "--ignore-dir ".l:index." "
        endfor
    endif

    call s:Verbose(1, expand('<sfile>'), "pattern:".l:pattern."  path:".l:path."  options:".l:options)
    let g:AgSearch_searchList += [ [ l:pattern, l:path, l:options ] ]
    call s:AgSearch(l:pattern, l:path, l:options)
endfunction


" Relaunch previous search.
" Arg1: number of searches to show. If 0, show all.
" Cmd: AgS
function! agsearch#SearchAgain(...)
    if !exists("g:AgSearch_searchList")
        call s:Warn("[agsearch.vim] No search found.")
        return
    endif

    if len(g:AgSearch_searchList) <= 0
        call s:Warn("[agsearch.vim] No search found (0).")
        return
    endif

    if a:0 > 0
        let l:last = str2nr(a:1)
        if l:last == 0
            echo "[agsearch.vim] Compleat searches:"
        else
            echo "[agsearch.vim] Last ".l:last." searches:"
        endif
    else
        let l:last = g:AgSearch_showSearchInfoMax
        echo "[agsearch.vim] Last ".l:last." searches:"
    endif
    echo " "

    echo printf("%-4s %s", 'N)', 'Search command') 
    echo "-------------------------------------------------------------------------------"

    let l:list = deepcopy(g:AgSearch_searchList)
    call reverse(l:list)
    let n = 0

    let l:shortList = []
    for l:dict in l:list
        if l:last != 0 && l:n >= l:last
            break
        endif
        let l:shortList += [ l:dict ]
        let l:n += 1
    endfor

    call reverse(l:shortList)

    let n = 1
    for l:list in l:shortList
        if l:n % 2 == 0 | echohl SpecialKey | endif
        echo printf("%-4d %s", l:n, "Ags ".l:list[0]." ".l:list[1]." ".l:list[2]) 
        let n += 1
        echohl none
    endfor

    while 1
        echo " "
        let l:inputStr = input("Select search command to launch: ")
        let l:input = str2nr(l:inputStr)
        if l:input == 0 | return | endif
        echo " "
        if l:input < l:n
            let l:input -= 1
            break
        endif
        call s:Warn("Wrong list number ".l:input)
    endwhile

    let l:list = l:shortList[l:input]
    echo "Search again. :Ags "l:list[0]." ".l:list[1]." ".l:list[2]
    let g:AgSearch_searchList += [ [ l:list[0], l:list[1], l:list[2] ] ]
    call s:AgSearch(l:list[0], l:list[1], l:list[2])
endfunction


" Show last compleated searches info.
"   By default show a maximum number of lines defined on: g:AgSearch_showSearchInfoMax
" Args: 
"   e or extend: show extended information.
"   number: show last searches.
" Cmd: Agi
function! agsearch#Info(...)
    if !exists("g:AgSearch_searchInfoList")
        call s:Warn("[agsearch.vim] No search info found.")
        return
    endif

    if len(g:AgSearch_searchInfoList) <= 0
        call s:Warn("[agsearch.vim] No search info found (0).")
        return
    endif

    let l:mode = "normal"
    let l:last = g:AgSearch_showSearchInfoMax

    if a:0 > 0
        for l:arg in a:000
            if l:arg == "e" || l:arg == "extend" 
                let l:mode = "extend"
            else
                let l:last = str2nr(l:arg)
                if l:last == 0
                    echo "[agsearch.vim] Compleat search info:"
                "else
                    "echo "[agsearch.vim] Last ".l:last." searches info:"
                endif
            endif
        endfor
    endif

    if l:last != 0
        echo "[agsearch.vim] Last ".l:last." searches info:"
    endif
    echo " "

    echo printf(" %-4s %7s %-25s %s", 'N)', 'Results', 'SearchPattern', 'SearchPath') 

    if l:mode == "extend"
        echo printf(" %-4s %7s [%s]", '', '', 'Search-command') 
    endif
    echo "-------------------------------------------------------------------------------"

    let l:list = deepcopy(g:AgSearch_searchInfoList)
    call reverse(l:list)
    let n = 0

    let l:shortList = []
    for l:dict in l:list
        if l:last != 0 && l:n >= l:last
            break
        endif
        let l:shortList += [ l:dict ]
        let l:n += 1
    endfor

    call reverse(l:shortList)

    let n = 1
    for l:dict in l:shortList
        let l:results = get(l:dict, 'resultsNum', "")
        let l:pattern = get(l:dict, 'searchPattern', "")
        let l:path    = get(l:dict, 'searchPath', "")
        let l:cmd     = get(l:dict, 'searchCmd', "")

        if l:n % 2 == 0 | echohl SpecialKey | endif

        echo printf(" %-4s %-7d %-25s %s", l:n.")", l:results, l:pattern, l:path) 

        if l:mode == "extend" && l:cmd != ""
            echo printf(" %-4s %7s [%s]", '', '', l:cmd)
        endif

        echohl none
        let n += 1
    endfor
endfunction


" Show last search commands launched.
" Arg: number of searches to show. If 0, show all.
" Cmd: Agic
function! agsearch#CommandInfo(...)
    if !exists("g:AgSearch_searchInfoCmdList")
        call s:Warn("[agsearch.vim] No search commands' info found.")
        return
    endif

    if len(g:AgSearch_searchInfoCmdList) <= 0
        call s:Warn("[agsearch.vim] No search commands' info found (0).")
        return
    endif

    if a:0 > 0
        let l:last = str2nr(a:1)
        if l:last == 0
            echo "[agsearch.vim] Compleat search commands' info:"
        else
            echo "[agsearch.vim] Last ".l:last." search commands' info:"
        endif
    else
        let l:last = g:AgSearch_showSearchInfoMax
        echo "[agsearch.vim] Last ".l:last." search commands' info:"
    endif

    let l:list = deepcopy(g:AgSearch_searchInfoCmdList)
    call reverse(l:list)
    let n = 0

    let l:shortList = []
    for l:cmd in l:list
        if l:last != 0 && l:n >= l:last
            break
        endif
        let l:shortList += [ l:cmd ]
        let l:n += 1
    endfor

    call reverse(l:shortList)

    let n = 1
    for l:cmd in l:shortList
        if l:n % 2 == 0 | echohl SpecialKey | endif
        echo printf(" %4s %s", l:n.") ", l:cmd)
        echohl none
        let l:n += 1
    endfor
endfunction


" Save current search.
" Arg1: [filename], save file name, if empty get a default name.
" Cmd: Agsv
function! agsearch#Save(filename)
    if &ft != "qf"
        call s:Error("Not on a quickfix window")
        return
    endif

    if !exists("w:AgSearch_resultLines")
        call s:Warn("Not on a agsearch window")
        call confirm("Save aniway?")
    endif

    if a:filename != ""
        let l:filename = a:filename
    else
        let l:filename = s:GetDefaultSaveFileName("normal")
    endif

    " Save window
    let l:winnr = win_getid()
    " Save window position
    let l:winview = winsaveview()
    " Save window height:
    let l:winLen = winheight(0) " window lenght

    silent normal ggVG"my 
    silent tabnew
    silent put m
    silent normal ggdd
    silent! exec("%s#|#:#g")
    silent! exec("%s# col #:#g")
    silent! exec("%s/^:://g")
    silent exec("w ".l:filename)
    silent quit!

    echo "[agsearch.vim] Search saved as: ".l:filename

    " Restore window
    call win_gotoid(l:winnr)
    " Restore window position
    call winrestview(l:winview)
    " Restore window lenght
    exe "resize ".l:winLen
endfunction


" Sort list using number.
function! agsearch#NumericSortDfltFilename(firstStr, secondStr)
    "echom "Compare ".a:firstStr." and ".a:secondStr

    let l:list1 = split(a:firstStr, '\.')
    if len(l:list1) <= 0 | return 0 | endif
    let l:header1 = l:list1[0]

    let l:list2 = split(a:secondStr, '\.')
    if len(l:list2) <= 0 | return 0 | endif
    let l:header2 = l:list2[0]

    if l:header1 < l:header2
        "echom " Compare ".l:header1." and ".l:header2." = -1"
        return -1
    elseif l:header1 > l:header2
        "echom " Compare ".l:header1." and ".l:header2." = 1"
        return 1
    endif

    if len(l:list1) < 1 | return | endif
    let l:firstNum = str2nr(l:list1[1])
    if l:firstNum == 0 | return 0 | endif

    if len(l:list2) < 1 | return | endif
    let l:secondNum = str2nr(l:list2[1])
    if l:secondNum == 0 | return 0 | endif

    if l:firstNum < l:secondNum
        "echom "  Compare ".l:firstNum." and ".l:secondNum." = -1"
        return -1
    elseif l:firstNum > l:secondNum
        "echom "  Compare ".l:firstNum." and ".l:secondNum." = 1"
        return 1
    else 
        "echom "  Compare ".l:firstNum." and ".l:secondNum." = 0"
        return 0
    endif
endfunction


" Search files containing saved searches on current working directory.
"   By default search all files matching: g:AgSearch_savedAgSearchGlobpath
"   By default show first line of content of the file when the line contains
"   "agsearch", otherwise asume its not an agsearch file and show filename.
"   By default show a maximum number of lines defined on: g:AgSearch_showSearchInfoMax
" Args: 
"   a:  show all auto saved searches
"   A:  show all searches matching glopath: g:AgSearch_savedSearchesGlobpath
"   f:  show filename instead of first line of content.
"   u:  show only user files, hide auto-saved files.
"   number: show last searches.
function! s:GetSavedFileSearchMenu(argsList)
    echo "Loading saved searches list..."

    let l:lastn = g:AgSearch_showSearchInfoMax
    let l:mode = "firstline"
    let l:globpath = g:AgSearch_savedAgSearchGlobpath
    let l:filter = " (".l:globpath.")"
    let l:text = ""

    for l:arg in a:argsList
        if l:arg ==# "a"
            let l:mode = "autofiles"
            let l:text = " auto"
        elseif l:arg ==# "A"
            let l:globpath = g:AgSearch_savedSearchesGlobpath
            let l:filter = " (".l:globpath.")"
            let l:text = " any"
        elseif l:arg ==# "f"
            let l:mode = "filename"
        elseif l:arg ==# "u"
            let l:mode = "userfiles"
            let l:text = " user"
        else
            let l:lastn = str2nr(l:arg)
        endif
    endfor

    let l:filesListStr = glob(l:globpath)
    let l:fullFilesList = split(l:filesListStr)
    redraw

    if len(l:fullFilesList) <= 0
        call s:Warn("[agsearch.vim] No saved searches found.")
        return ""
    endif

    " Save window
    let l:winnr = win_getid()
    " Save window position
    let l:winview = winsaveview()


    " Set aside last N files.
    if l:lastn == 0 || len(l:fullFilesList) < l:lastn && l:mode == ""
        let l:filesList = l:fullFilesList
    else
        call reverse(l:fullFilesList)
        let l:filesList = []
        let l:n = 1
        for l:file in l:fullFilesList
            "echom "Check ".l:file
            if l:mode == "userfiles" && l:file =~ "vim-agsearch" && l:file =~ "_auto\."
                "echom "Discard auto file ".l:file
                continue
            endif
            if l:mode == "autofiles" && l:file =~ "agsearch" && l:file !~ "_auto\."
                "echom "Discard user file ".l:file
                continue
            endif
            if l:lastn > 0 && l:n > l:lastn
                break
            endif
            let l:filesList += [ l:file ]
        endfor
    endif
    call sort(l:filesList, "agsearch#NumericSortDfltFilename")

    " Get the first content line of each file.
    let l:infoList = []
    let l:n = 1
    for l:file in l:filesList
        if l:lastn > 0 && l:n > l:lastn
            break
        endif
        silent exec("tabedit ".l:file)
        normal gg"myy
        let l:info = @m
        let l:infoList += [ l:info ]
        silent quit!
    endfor

    if len(l:infoList) <= 0
        call s:Warn("[agsearch.vim] No saved searches found.")
        return ""
    endif


    "echo "[agsearch.vim] Saved searches: "
    echo "[agsearch.vim] Saved".l:filter.l:text." searches found: "
    let l:fileType = ""
    let l:n = 1
    if l:mode == "filename"
        for l:file in l:filesList
            if l:file =~ "vim-agsearch_auto"
                let l:fileType = "[AS]"
            endif
            if l:n % 2 == 0 | echohl SpecialKey | endif
            echo printf(" %2d) search-file:'%s'  %s", l:n, l:file, l:fileType)
            echohl none
            let n += 1
        endfor
    else
        for l:info in l:infoList
            if l:lastn > 0 && l:n > l:lastn
                break
            endif

            let l:pos = l:n -1
            "echom "Compare: ".l:filesList[l:pos]." with ".g:AgSearch_savedSearchHeader."vim-agsearch*".g:AgSearch_savedSearchTail

            if l:filesList[l:pos] =~ "vim-agsearch"
                if l:filesList[l:pos] =~ "auto"
                    let l:fileType = "[AutoSave]"
                    echohl Conceal
                else
                    let l:fileType = "[UserSave]"
                endif
            else
                "echohl StatusLine
                echohl DiffText
            endif

            if l:info =~ "agsearch"
                let l:info = substitute(l:info, "::", "", "")
                let l:info = substitute(l:info, "||", "", "")
                let l:info = substitute(l:info, "agsearch.vim", "", "")
                let l:info = substitute(l:info, "\[\]", "", "")
                " Trim spaces
                let l:info = substitute(l:info,'^\s\+','','g')
                let l:info = substitute(l:info,'\s\+$','','g')
                let l:info = substitute(l:info, "", "", "")
                let l:info = substitute(l:info, "\n", "", "")

                echo printf(" %2d) %s  search-file:'%s'  %s", l:n, l:info, l:filesList[l:pos], l:fileType)
            else
                echo printf(" %2d) search-file:'%s'  %s", l:n, l:filesList[l:pos], l:fileType)
            endif
            echohl none
            let n += 1
        endfor
    endif

    " Restore window
    call win_gotoid(l:winnr)
    " Restore window position
    call winrestview(l:winview)

    while 1
        let l:inputStr = input("Select search number: ")
        if l:inputStr == "" | return "" | endif
        let l:input = str2nr(l:inputStr)
        if l:input == 0 | return "" | endif
        echo " "
        if l:input < l:n
            let l:input -= 1
            let l:inputFile = l:filesList[l:input]
            break
        endif
        call s:Warn("Wrong input number")
    endwhile

    return l:inputFile
endfunction


" Load saved search.
" By default search all files matching: g:AgSearch_savedAgSearchGlobpath
" By default show first line of content of the file when the line contains
" "agsearch", otherwise asume its not an agsearch file and show filename.
" Args: 
"   a:  show all auto saved searches
"   A:  show all searches matching glopath: g:AgSearch_savedSearchesGlobpath
"   f:  show filename instead of first line of content.
"   u:  show only user files, hide auto-saved files.
"   number: show last searches.
" Cmd: Agl
function! agsearch#Load(...)
    let l:file =  s:GetSavedFileSearchMenu(a:000)
    "echom "File:".l:file
    if l:file == "" | return | endif
    redraw

    " Save window height:
    let l:winLen = winheight(0) " window lenght

    " Load file to quickfix
    silent exec "lgetfile ".l:file
    silent lwindow
    wincmd j
    if &ft != "qf"
        call s:Error("Quickfix load error")
        return
    endif
    setlocal cursorline
    silent exe "silent normal! gg"

    " Resize the quickfix window:
    " Workout the window resize data:
    let buffLen = line('$') " buffer lenght
    let maxlen = l:winLen/2

    if l:buffLen < l:maxlen
        exe "resize ".l:buffLen
    endif
    let w:AgSearch_resultLines = 0
endfunction


" Delete saved search.
" By default search all files matching: g:AgSearch_savedAgSearchGlobpath
" By default show first line of content of the file when the line contains
" "agsearch", otherwise asume its not an agsearch file and show filename.
" Args: 
"   a:  show all auto saved searches
"   A:  show all searches matching glopath: g:AgSearch_savedSearchesGlobpath
"   f:  show filename instead of first line of content.
"   u:  show only user files, hide auto-saved files.
"   number: show last searches.
" Cmd: Agd
function! agsearch#Delete(...)
    while 1
        let l:file =  s:GetSavedFileSearchMenu(a:000)
        if l:file == ""
            return
        endif
        redraw
        echo "[agsearch.vim] Selected file: ".l:file
        if confirm("Attention, do you want to delete file?", "&yes\n&no", 2) != 2
            call delete(l:file)
        endif
    endwhile
endfunction


" Open a saved search file.
" By default search all files matching: g:AgSearch_savedAgSearchGlobpath
" By default show first line of content of the file when the line contains
" "agsearch", otherwise asume its not an agsearch file and show filename.
" Args: 
"   a:  show all auto saved searches
"   A:  show all searches matching glopath: g:AgSearch_savedSearchesGlobpath
"   f:  show filename instead of first line of content.
"   u:  show only user files, hide auto-saved files.
"   number: show last searches.
" Cmd: Ago
"function! agsearch#Open(mode, globpath, lastn)
function! agsearch#Open(...)
    let l:file = s:GetSavedFileSearchMenu(a:000)
    if l:file == "" | return | endif
    redraw
    silent exec("tabedit ".l:file)
endfunction


" Delete all saved searches.
" By default search all files matching: g:AgSearch_savedAgSearchGlobpath
" By default show first line of content of the file when the line contains
" "agsearch", otherwise asume its not an agsearch file and show filename.
" Args: 
"   a:  show all auto saved searches
"   u:  show only user files, hide auto-saved files.
" Cmd: AgD
function! agsearch#DeleteAll(...)
    let l:globpath = g:AgSearch_savedAgSearchGlobpath
    let l:mode = ""
    let l:filter = " (".g:AgSearch_savedAgSearchGlobpath.")"
    let l:text = ""

    for l:arg in a:000
        if l:arg ==# "a"
            let l:mode = "autofiles"
            let l:text = " auto"
        elseif l:arg ==# "A"
            let l:globpath = g:AgSearch_savedSearchesGlobpath
            let l:filter = " (".g:AgSearch_savedSearchesGlobpath.")"
            let l:text = " any"
        elseif l:arg ==# "u"
            let l:mode = "userfiles"
            let l:text = " user"
        endif
    endfor

    let l:filesListStr = glob(l:globpath)
    let l:filesList = split(l:filesListStr)
    if len(l:filesList) <= 0
        call s:Warn("[agsearch.vim] No saved searches found.")
        return ""
    endif

    let l:shortFilesList = []
    for l:file in l:filesList
        if l:mode == "userfiles" && l:file =~ "vim-agsearch" && l:file =~ "_auto\."
            continue
        endif
        if l:mode == "autofiles" && l:file =~ "agsearch" && l:file !~ "_auto\."
            continue
        endif
        let l:shortFilesList += [ l:file ]
    endfor

    echo "[agsearch.vim] Saved".l:filter.l:text." searches found: ".len(l:shortFilesList)
    echo "Files: ".join(l:shortFilesList)

    if confirm("Attention, do you want to delete all saved searches?", "&yes\n&no", 2) != 2
        for l:file in l:shortFilesList
            "echom "Delete: ".l:file
            call delete(l:file)
        endfor
    endif
endfunction


" Get/set context lines.
" Cmd: Agc
function! agsearch#ContextLines(...)
    if a:0 >= 2
        let g:AgSearch_contextLinesBefore = a:1
        let g:AgSearch_contextLinesAfter  = a:2
        let l:tmp = " set to"
    elseif a:0 > 0
        let g:AgSearch_contextLinesBefore = a:1
        let g:AgSearch_contextLinesAfter  = a:1
        let l:tmp = " set to"
    else
        let l:tmp = ""
    endif

    if g:AgSearch_contextLinesAfter == g:AgSearch_contextLinesBefore
        let l:text = ": ".g:AgSearch_contextLinesBefore
    else
        let l:text = " context before: ".g:AgSearch_contextLinesBefore." context after: ".g:AgSearch_contextLinesAfter
    endif

    echo "[agsearch.vim] Search context lines".l:tmp.l:text
endfunction


function! s:FoldContent()
    wincmd k
    let winheight = winheight(0)
    wincmd j
    let winheight += winheight(0)

    " Fold the search context
    " Remove fold underline
    hi Folded term=NONE cterm=NONE gui=NONE ctermbg=NONE

    let foldExpr=" col "
    setlocal foldexpr=(getline(v:lnum)=~l:foldExpr)?0:(getline(v:lnum-1)=~l:foldExpr)\|\|(getline(v:lnum+1)=~l:foldExpr)?1:2
    setlocal foldmethod=expr 
    " Remove fold padding charactesr -----
    setlocal fillchars="vert:|,fold: "
    setlocal foldtext="..."
    setlocal foldlevel=0 
    setlocal foldcolumn=0
    "
    let maxWinSize = l:winheight /2
    let lines = line('$')

    if exists("w:AgSearch_resultLines")
        if w:AgSearch_resultLines != 0
            let lines = w:AgSearch_resultLines
        endif
    endif
    if exists("w:AgSearch_contextBlocks")
        let lines += w:AgSearch_contextBlocks
    endif
endfunction


" Fold all context line.
" https://coderwall.com/p/usd_cw/a-pretty-vim-foldtext-function 
" Cmd: Agf
function! agsearch#ContextFoldToogle()
    if &ft != 'qf'
        return
    endif

    if !has("folding")
        return
    endif

    if !exists("w:AgSearch_resultLines")
        return
    endif

    wincmd k
    let winheight = winheight(0)
    wincmd j
    let winheight += winheight(0)

    if &foldlevel != 0
        " Fold the search context
        " Remove fold underline
        "hi Folded term=NONE cterm=NONE gui=NONE ctermbg=DarkGrey 
        hi Folded term=NONE cterm=NONE gui=NONE ctermbg=NONE

        let foldExpr=" col "
        setlocal foldexpr=(getline(v:lnum)=~l:foldExpr)?0:(getline(v:lnum-1)=~l:foldExpr)\|\|(getline(v:lnum+1)=~l:foldExpr)?1:2
        setlocal foldmethod=expr 
        " Remove fold padding charactesr -----
        setlocal fillchars="vert:|,fold: "
        setlocal foldtext="..."
        setlocal foldlevel=0 
        setlocal foldcolumn=0

        let maxWinSize = l:winheight /2
        let lines = line('$')

        if exists("w:AgSearch_resultLines")
            if w:AgSearch_resultLines != 0
                let lines = w:AgSearch_resultLines
            endif
        endif
        if exists("w:AgSearch_contextBlocks")
            let lines += w:AgSearch_contextBlocks
        endif

        echo "[agsearch.vim] fold context lines."
    else
        " Unfold the search context
        setlocal foldtext="            "
        setlocal foldlevel=99 

        let maxWinSize = l:winheight *9/10
        let lines = line('$')
        echo "[agsearch.vim] unfold context lines."
    endif

    " Save window position
    let l:winview = winsaveview()
    " Resize the quickfix window
    call s:ResizeQfWin(l:maxWinSize, l:lines)
    " Restore window position
    call winrestview(l:winview)
endfunction


" Parse the results file and count
" Return: list with number of results found and context blocks found.
function! s:GetSearchResultsList(file)
    redir! > readfile.out

    " Parse the config file
    let l:file = readfile(a:file)

    let l:resultLines = 0
    let l:contextBlocks = 0
    let l:resultFound = 1

    for l:line in l:file
        if l:line[0] == type(0) && l:line[0:1] != "--"
            " Not context line
            let l:resultLines += 1
            let l:resultFound = 1
        elseif l:resultFound == 1
            " Context block
            let l:contextBlocks += 1
            let l:resultFound = 0
        endif
    endfor

    redir END
    return [ l:resultLines, l:contextBlocks ]
endfunction


" Get all opened buffers as string.
function! agsearch#GetBuffersAsString()
    let all = range(0, bufnr('$'))
    let res = ""
    for b in all
        if buflisted(b)
            let omittFlag = 0
            for omittName in split(g:AgSearch_omittBufferNamesList, ' ')
                if bufname(b) =~ l:omittName
                    let omittFlag = 1
                    break
                endif
            endfor
            if l:omittFlag == 0
                if l:res != ""
                    let l:res .= " "
                endif
                let l:res .= bufname(b)
            endif
        endif
    endfor
    return res
endfunction


" Toogle search from backgraound/foreground.
" Commands: Agbg
function! agsearch#ToogleBackgraundSearch()
    if g:AgSearch_runInBackground == 1
        let g:AgSearch_runInBackground = 0
        echo s:plugin_name.": run commands in foreground"
    else
        let g:AgSearch_runInBackground = 1
        echo s:plugin_name.": run commands in background"
    endif
endfunction



"- Generate commands/maps/abbreviations -------------------------------------------------------------------

" Add new command.
" Add new normal and visual mappings.
" Add new abbreviation.
" Arg1: command, 
" Arg2: nmap, 
" Arg3: vmap, 
" Arg4: abbrev, 
" Arg5: options, 
" Arg6: path, 
" Arg7: help, 
function! s:GenerateCommandMappingOrAbbrev(command, nmap, vmap, abbrev, options, path, help)
    "call s:Verbose(1, expand('<sfile>'), "Add: command:".a:command." nmap:".a:nmap." vmap:".a:vmap." abbrev:".a:abbrev." options:".a:options." path:".a:path. "help:".a:help)
    "echom "Add: command:".a:command." nmap:".a:nmap." vmap:".a:vmap." abbrev:".a:abbrev." options:".a:options." path:".a:path. "help:".a:help

    let l:cmdList  = []

    if a:path == ""
        call s:Error("Mandatory options path empty or not found")
        return
    endif

    if !exists("g:AgSearch_commandHelpList")
        let g:AgSearch_commandHelpList = []
    endif
    if !exists("g:AgSearch_mappingsHelpList")
        let g:AgSearch_mappingsHelpList = []
    endif
    if !exists("g:AgSearch_abbrevHelpList")
        let g:AgSearch_abbrevHelpList = []
    endif

    if a:options == ""
        let l:options = "''"
        let l:options = "none"
    else
        let l:options = a:options
    endif

    " Search Replace Pattern On Path:
    let l:replacePatternFound = 0

    " User set replace pattern options
    " Check if path contains a user replace pattern.
    if a:options =~ "-rp=" || a:options =~ "--replace-pattern="
        for l:index in split(a:options)
            let l:list = split(l:index, '=')
            if len(l:list) < 2
                let l:options .= l:index." "
                let l:optionArgExpected = 1
                call s:Verbose(1, expand('<sfile>'), " Replace pattern Option: ".l:index)
                continue
            endif

            let l:field = l:list[0][1:]
            let l:value = l:list[1]

            if (l:field ==? "rp" || l:field ==# "-replace-pattern") && a:path =~ l:value
                "echom "Replace pattern found: ".a:path. " ".l:replacePattern
                let l:replacePatternFound = 1
                break
            endif
        endfor
    endif

    " Check if path contains a default replace pattern.
    if l:replacePatternFound == 0
        for l:replacePattern in split(g:AgSearch_defaultReplacePatterns)
            if a:path =~ l:replacePattern
                "echom "Replace pattern found: ".a:path. " ".l:replacePattern
                let l:replacePatternFound = 1
            endif
        endfor
    endif

    if a:path =~ "__FILES.*__"
        " Path is command, like __FILES__, __FILES:pattern__, " __FILES:--pattern:pattern1__...
        let l:path = a:path
        let l:expandPath = 0
    else
        if glob(a:path) != "" || l:replacePatternFound == 1
            " Treat as real path.
            let l:path = a:path
            let l:expandPath = 0
        else
            " Treat as command expansion. 
            " Command to get path, like: getcwd() or expand(%).
            let l:path = "<C-R>=".a:path."<CR>"
            let l:expandPath = 1
        endif
    endif


    " Generate Command:
    if a:command != ""
        if l:expandPath == 1
            "let l:cmdStr = "command! -nargs=* ".a:command." call agsearch#Search(".a:path.", ".l:options.", <f-args>)"
            let pathError = 1
        else
            let l:cmdStr = "command! -nargs=* ".a:command." call agsearch#Search(\"".l:path."\", ".l:options.", <f-args>)"
            let pathError = 0
        endif

        if pathError == 0
            "echom l:cmdStr
            let l:cmdList += [ l:cmdStr ]

            if has("gui_running") 
                "call agSearch#CreateMenus('cn' , '' , ":".a:command." ", "Search: ".l:path." search options: ".l:options, ":".a:command)
                silent! call agSearch#CreateMenus('cn' , '' , ":".a:command." ", "Search: ".l:path.", search options: ".l:options, ":".a:command)
            endif

            if a:help != ""
                let g:AgSearch_commandHelpList += [ "   ".a:command." : ".a:help ]
            endif
        endif
    endif

    " Generate Mappings:
    if a:nmap != ""
        if a:options =~ "-rp=" || a:options =~ "-replace-patterns="
            let l:cmdStr = "nnoremap ".a:nmap." :Ags ".l:path." <C-R>=expand('<cword>')<CR>"." ".a:options
        else
            let l:cmdStr = "nnoremap ".a:nmap." :Ags <C-R>=expand('<cword>')<CR>"." ".a:options." ".l:path
        endif
        "echom l:cmdStr
        let l:cmdList += [ l:cmdStr ]
    endif

    if a:vmap != ""
        let l:cmdStr = "vnoremap ".a:vmap." :<BS><BS><BS><BS><BS>Ags ".l:path." <C-R>=agsearch#getVisualSel()<CR> ".a:options
        "echom l:cmdStr
        let l:cmdList += [ l:cmdStr ]
    endif

    " Generate Abbreviations:
    if a:abbrev != ""
        let l:cmdStr = "cnoreabbrev ".a:abbrev." Ags ".l:path." ".a:options
        "echom l:cmdStr
        let l:cmdList += [ l:cmdStr ]

        if a:help != ""
            let g:AgSearch_abbrevHelpList += [ "   ".a:abbrev." : ".a:help ]
        endif
    endif


    for l:cmd in l:cmdList
        "echom l:cmd
        call s:Verbose(1, expand('<sfile>'), "Add: ".l:cmd)
        silent exec(l:cmd)
    endfor
endfunction


function! agsearch#GenerateDefaultCmdMapAbbrev(command, nmap, vmap, abbrev, options, path, help)
    call s:Verbose(1, expand('<sfile>'), "Add: command:".a:command." nmap".a:nmap." vmap:".a:vmap." abbrev:".a:abbrev." options:".a:options." path:".a:path. "help:".a:help)

    let l:command = ""
    let l:nmap = ""
    let l:vmap = ""
    let l:abbrev = ""

    if a:path == ""
        call s:Error("Mandatory options path empty or not found")
        return
    endif

    if a:command != ""
        let l:command = g:AgSearch_defaultCommand.a:command
    endif

    if a:nmap != ""
        let l:nmap = g:AgSearch_defaultMapping.a:nmap
    endif

    if a:vmap != ""
        let l:vmap = g:AgSearch_defaultMapping.a:vmap
    endif

    if a:abbrev != ""
        let l:abbrev = g:AgSearch_defaultAbbrev.a:abbrev
    endif

    call s:GenerateCommandMappingOrAbbrev(l:command, l:nmap, l:vmap, l:abbrev, a:options, a:path, a:help)
endfunction


" Generate the user mappings saved on list: g:AgSearch_userCommandsList
function! agsearch#GenerateUserCmdMapAbbrev()
    if !exists("g:AgSearch_userCommandsList")
        return
    endif

    for l:dict in g:AgSearch_userCommandsList
        let l:default     = get(l:dict, 'default', "")
        if l:default != ""
            let l:command = g:AgSearch_defaultCommand.l:default
            let l:nmap    = g:AgSearch_defaultMapping.l:default
            let l:vmap    = g:AgSearch_defaultMapping.l:default
            let l:abbrev  = g:AgSearch_defaultAbbrev.l:default
        else
            let l:command = get(l:dict, 'cmd', "")
            let l:nmap    = get(l:dict, 'nmap', "")
            let l:vmap    = get(l:dict, 'vmap', "")
            let l:abbrev  = get(l:dict, 'abbrev', "")
        endif

        let l:options = get(l:dict, 'opt', "")
        let l:path    = get(l:dict, 'path', "")
        let l:help    = get(l:dict, 'help', "")

        if l:path == ""
            call s:Error("Mandatory fiedl 'path' empty or not found")
            return
        endif

        call s:GenerateCommandMappingOrAbbrev(l:command, l:nmap, l:vmap, l:abbrev, l:options, l:path, l:help)
    endfor
endfunction


" Reset or Generate the user commands/mappings/abbreviations.
" Add new user command, mapping and/or abbreviations
" Arg1: dictionar to: 
" - Reset the user commands. Ex: {"reset":1}
" - Generate the user commands. Ex: {"generate",1}
" - Add new command. Ex: { 'default':'P', 'path':'/home/jp/projects', 'help':'Search projects dir' }
function! agsearch#AddUserCmdMapAbbrev(dict)
    if a:dict == {}
        return
    endif

    if get(a:dict, 'reset', "") == 1
        silent! unlet g:AgSearch_userCommandsList = []
        return
    endif

    if get(a:dict, 'generate', "") == 1
        call agsearch#GenerateUserCmdMapAbbrev()
        return
    endif

    if !exists("g:AgSearch_userCommandsList")
        let g:AgSearch_userCommandsList = []
    endif
    let g:AgSearch_userCommandsList += [ a:dict ]
endfunction


"- utils -------------------------------------------------------------------

function! agsearch#getVisualSel()
    let [line_start, column_start] = getpos("'<")[1:2]
    let [line_end, column_end] = getpos("'>")[1:2]
    let lines = getline(line_start, line_end)
    if len(lines) == 0
        return ''
    endif
    let lines[-1] = lines[-1][: column_end - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][column_start - 1:]
    return escape(join(lines, "\n"),' \')
endfunction


"- menus -------------------------------------------------------------------

" Show abbridged command help:
" Commands: Agh
function! agsearch#Help()
    let l:job = "background"

    if g:AgSearch_runInBackground == 1
        let l:job = "foreground"
    endif

    let l:text  = ""
    let l:text .= "[".s:plugin_name."] help (v".g:Agsearch_version."):\n"
    let l:text .= "  \n"
    let l:text .= "Abridged command help:\n"
    let l:text .= "  \n"
    let l:text .= "Commands:\n"
    let l:text .= "\n"
    let l:text .= "   Ags [OPTIONS] PATH PATTERN : show the sign levels available and its color configuration.\n"
    let l:text .= "      Arguments:\n"
    let l:text .= "      PATH                   : search paths.\n"
    let l:text .= "        Use path __FILES__ to search all files opened in current vim session.\n"
    let l:text .= "        Use path __FILES:keepPattern:--skipPattern__ to filter the files to search.\n"
    let l:text .= "      PATTERN_1,PATTERN_N    : search pattern.\n"
    let l:text .= "  \n" 
    let l:text .= "      Options:\n"
    let l:text .= "      [-if=PATTERN1,PATTERN] : comma separated files to ignore.\n"
    let l:text .= "      [-id=DIR1,DIR2]        : comma separated directories to ignore.\n"
    let l:text .= "      [-rp=__DIR__,*]        : replace first match of word '__DIR__' with '*' on path.\n"
    let l:text .= "   \n"
    let l:text .= "      Long options:\n"
    let l:text .= "      [--ignore-files=PATTERN1,PATTERN] : comma separated files to ignore.\n"
    let l:text .= "      [--ignored-dirs=DIR1,DIR2]        : comma separated directories to ignore.\n"
    let l:text .= "      [--replace-pattern=_DIR_]         : replace first match of word _DIR_ on path.\n"
    let l:text .= "   \n"
    let l:text .= "   AgS         : launch again a previous search.\n"
    let l:text .= "   Agc [LINES_BEFORE] [LINES_AFTER]: set/get search context line number configuration.\n"
    let l:text .= "   Agf         : on quickfix window showing search results, fold/unfold context.\n"
    let l:text .= "   Agi  [OPT1] : Show last compleat N searches info.\n"
    let l:text .= "    OPT1=e     : show extended information.\n"
    let l:text .= "    OPT1=num   : show last 'num' info. Use 0 to show all info.\n"
    let l:text .= "   Agic [N]    : Show last N search commands launched.\n"
    let l:text .= "   Agsv [NAME] : Save a search. If no name provided, asign default name.\n"
    let l:text .= "   Agd  [OPT2] : Delete a search file with default name.\n"
    let l:text .= "   AgD  [OPT2] : Delete all search files with default name.\n"
    let l:text .= "   Ago  [OPT2] : Open a search file with default name.\n"
    let l:text .= "    OPT2=a: show only auto saved files.\n"
    let l:text .= "    OPT2=A: show all saved file searches matching path: ".g:AgSearch_savedSearchesGlobpath.".\n"
    let l:text .= "    OPT2=f: show filename instead of content of first line.\n"
    let l:text .= "    OPT2=u: show only user files, hide the auto-saved files.\n"
    let l:text .= "    OPT2=num: show last 'num' searches. Use 0 to show all searches found.\n"
    let l:text .= "   Agbg        : toogle search to ".l:job.".\n"
    let l:text .= "   Agh         : show this help.\n"
    let l:text .= "   \n"
    if len(g:AgSearch_commandHelpList) != 0
        for l:helpStr in g:AgSearch_commandHelpList
            let l:text .= l:helpStr.".\n"
        endfor
        let l:text .= "   \n"
    endif
    let l:text .= "   \n"
    if len(g:AgSearch_abbrevHelpList) != 0
        let l:text .= "Abbrebiations:\n"
        for l:helpStr in g:AgSearch_abbrevHelpList
            let l:text .= l:helpStr.".\n"
        endfor
        let l:text .= "   \n"
    endif
    let l:text .= "Examples:\n"
    let l:text .= "   \n"
    let l:text .= "   Search word run on directory projects:\n"
    let l:text .= "    :Ags run /home/jp/projects/\n"
    let l:text .= "    :Ags /home/jp/projects/ run\n"
    let l:text .= "   \n"
    let l:text .= "   Search word run on file:\n"
    let l:text .= "    :Ags run /home/jp/projects/myproject/file.cpp\n"
    let l:text .= "    :Ags /home/jp/projects/myproject/file.cpp run\n"
    let l:text .= "   \n"
    let l:text .= "   Search word run on directory projects with 4 lines of context:\n"
    let l:text .= "    :Ags run /home/jp/projects/ -C 4\n"
    let l:text .= "    :Ags /home/jp/projects/ run -C 4\n"
    let l:text .= "    :Ags /home/jp/projects/ -C 4 run\n"
    let l:text .= "   \n"
    let l:text .= "   Concatenate seaches:\n"
    let l:text .= "    :Ags run,config /home/jp/projects/\n"
    let l:text .= "    (Equivalent to ag run /home/jp/projects | ag config)\n"
    let l:text .= "   \n"
    let l:text .= "   Concatenate searches, remove all lines containing 'config':\n"
    let l:text .= "    :Ags run,-config /home/jp/projects/\n"
    let l:text .= "    (Equivalent to ag run /home/jp/projects | ag -v config)\n"
    let l:text .= "   \n"
    let l:text .= "   Concatenate several search:\n" 
    let l:text .= "    Will concatente three ag or grep commands.\n"
    let l:text .= "    :Ags run,thread,source /home/jp/projects/\n"
    let l:text .= "    (Equivalent to: 'ag --vimgrep run /home/jp/projects/ | ag thread | ag source')\n"
    let l:text .= "   \n"
    let l:text .= "   Multiple pattern search:\n"
    let l:text .= "    :Ags \"mutex|lock|monitor\" /home/jp/projects/\n"
    let l:text .= "   \n"
    let l:text .= "   Search word run on directory projects ignore any .cfg, .o or .xml files:\n"
    let l:text .= "    :Ags run /home/jp/projects/ -IF=*.cfg,*.o,*.xml\n"
    let l:text .= "   \n"
    let l:text .= "   Search word run on directory projects ignore any directory 'config':\n"
    let l:text .= "    :Ags run /home/jp/projects/ -ID=config\n"
    let l:text .= "   \n"
    let l:text .= "   Search pattern run.*thread on directory source inside all projects:\n"
    let l:text .= "    :Ags run.*thread /home/jp/projects/_DIR_/source/\n"
    let l:text .= "   \n"
    let l:text .= "   Search pattern run.*thread on directory source inside all projects:\n"
    let l:text .= "    :Ags run.*thread /home/jp/projects/_DIR_/source/\n"
    let l:text .= "   \n"
    let l:text .= "   Search pattern run.*thread, ask user to replace __DIR__, __DIR2__ and __FILE__ patterns :\n"
    let l:text .= "    :Ags run.*thread /home/__DIR__/projects/__DIR2__/source/_FILE_\n"
    let l:text .= "   \n"
    let l:text .= "   Search pattern run.*thread on every cpp file on all source directories inside current projects:\n"
    let l:text .= "    :Ags run.*thread /home/jp/projects/DIR/source/FILE -RP=DIR -RP=FILE,*.cpp\n"
    let l:text .= "   \n"
    let l:text .= "   Show search context lines configuration:\n"
    let l:text .= "    :Agc\n"
    let l:text .= "   \n"
    let l:text .= "   Change context lines config, 1 lines before, 4 after:\n"
    let l:text .= "    :Agc 1 4\n"
    let l:text .= "   \n"
    let l:text .= "   Change context lines config, 4 lines before, 4 after:\n"
    let l:text .= "    :Agc 4\n"
    let l:text .= "   \n"
    let l:text .= "   Show information of last 20 searches finished:\n"
    let l:text .= "    :Agi 20\n"
    let l:text .= "   \n"
    let l:text .= "   Show extended information of last 20 searches finished:\n"
    let l:text .= "    :Agi e 20\n"
    let l:text .= "   \n"
    let l:text .= "   Show information of all searches finished:\n"
    let l:text .= "    :Agi 0\n"
    let l:text .= "   \n"
    let l:text .= "   Show ag command for the last 20 searches finished:\n"
    let l:text .= "    :Agic 20\n"
    let l:text .= "   \n"
    let l:text .= "   Show ag command for all searches finished:\n"
    let l:text .= "    :Agic 0\n"
    let l:text .= "   \n"
    let l:text .= "   Save current search with default name (".g:AgSearch_savedSearchHeader."vim-agsearch_YYMMDD-HHMMSS.".g:AgSearch_savedSearchTail.":\n"
    let l:text .= "    :Agsv mysearch.qf\n"
    let l:text .= "   \n"
    let l:text .= "   Save current search with name mysearch.qf:\n"
    let l:text .= "    :Agsv mysearch.qf\n"
    let l:text .= "   \n"
    let l:text .= "   Search text 'run' on all files opened on vim:\n"
    let l:text .= "    :Ags run __FILES__\n"
    let l:text .= "   \n"
    let l:text .= "   Search text 'run' on all files opened on vim, skip xml files:\n"
    let l:text .= "    :Ags run __FILES:--xml__\n"
    let l:text .= "   \n"
    let l:text .= "   Search text 'run' on all files opened on vim, search only cpp and diff files:\n"
    let l:text .= "    :Ags run __FILES:cpp:diff__\n"
    let l:text .= "   \n"
    let l:text .= "   Search text 'run' on all files opened on vim, search only not config and cpp files:\n"
    let l:text .= "    :Ags run __FILES:cpp:--config__\n"
    let l:text .= "   \n"

    redraw
    call s:WindowSplitMenu(4)
    call s:WindowSplit()
    silent put = l:text
    silent! exec '0file | file svnTools_plugin_help'
    normal ggdd
    call s:WindowSplitEnd()
endfunction


" Create menu items for the specified modes.
function! agsearch#CreateMenus(modes, submenu, target, desc, cmd)
    " Build up a map command like
    let plug = a:target
    let plug_start = 'noremap <silent> ' . ' :call AgSearch("'
    let plug_end = '", "' . a:target . '")<cr>'

    " Build up a menu command like
    let menuRoot = get(['', 'AgSearch', '&AgSearch', "&Plugin.&AgSearch".a:submenu], 3, '')
    let menu_command = 'menu ' . l:menuRoot . '.' . escape(a:desc, ' ')

    if strlen(a:cmd)
        let menu_command .= '<Tab>' . a:cmd
    endif

    let menu_command .= ' ' . (strlen(a:cmd) ? plug : a:target)
    "let menu_command .= ' ' . (strlen(a:cmd) ? a:target)

    call s:Verbose(1, expand('<sfile>'), l:menu_command)

    " Execute the commands built above for each requested mode.
    for mode in (a:modes == '') ? [''] : split(a:modes, '\zs')
        if strlen(a:cmd)
            execute mode . plug_start . mode . plug_end
            call s:Verbose(1, expand('<sfile>'), "execute ". mode . plug_start . mode . plug_end)
        endif
        " Check if the user wants the menu to be displayed.
        if g:AgSearch_mode != 0
            execute mode . menu_command
        endif
    endfor
endfunction


"- Release tools ------------------------------------------------------------
"

" Create a vimball release with the plugin files.
" Commands: Agvba
function! agsearch#NewVimballRelease()
    let text  = ""
    let text .= "plugin/agsearch.vim\n"
    let text .= "autoload/agsearch.vim\n"
    let text .= "plugin/jobs.vim\n"
    let text .= "autoload/jobs.vim\n"

    silent tabedit
    silent put = l:text
    silent! exec '0file | file vimball_files'
    silent normal ggdd

    let l:plugin_name = substitute(s:plugin_name, ".vim", "", "g")
    let l:releaseName = l:plugin_name."_".g:Agsearch_version.".vmb"

    let l:workingDir = getcwd()
    silent cd ~/.vim
    silent exec "1,$MkVimball! ".l:releaseName." ./"
    silent exec "vertical new ".l:releaseName
    silent exec "cd ".l:workingDir
endfunction


"- initializations ------------------------------------------------------------

let  s:plugin = expand('<sfile>')
let  s:plugin_path = expand('<sfile>:p:h')
let  s:plugin_name = expand('<sfile>:t')

call s:Initialize()

