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
" NOTES:
"
" Version:      0.0.3
" Changes:
"  - Fix: change file/dir replace tag to __FILES__, __DIR__...
"  - Fix: file search all buffers with tags __FILES__.
" 0.0.3 	Fry, 28 Jan 2022.     JPuigdevall
"  - New: use path __FILES__ to search in all files open on current vim session.
"     Use __FILES:pattern__ to search only files matching pattern.
"     Use __FILES:--pattern__ to search only files not matching pattern.
"  - New: AgF command, _agF abbreviation, <leader>aF map. to search all files
"    open on current vim session.
"  - Remove: Agb command (_agb abbreviation, <leader>ab mapping) removed.
" 0.0.2 	Mon, 10 Jan 2022.     JPuigdevall
"  - Fix: auto save files rotation.
" 0.0.1 	Thu, 23 Dec 2021.     JPuigdevall
"  - First version.


if exists('g:loaded_agsearch')
    finish
endif

let g:loaded_agsearch = 1
let s:save_cpo = &cpo
set cpo&vim

let s:leader = exists('g:mapleader') ? g:mapleader : ''

let g:Agsearch_version = "0.0.3"


"- configuration --------------------------------------------------------------

let g:AgSearch_runInBackground        = get(g:, 'AgSearch_runInBackground', 1)
let g:AgSearch_patternSeparator       = get(g:, 'AgSearch_patternSeparator', ",")
let g:AgSearch_contextLinesAfter      = get(g:, 'AgSearch_contextLinesAfter',  0)
let g:AgSearch_contextLinesBefore     = get(g:, 'AgSearch_contextLinesBefore', 0)
let g:AgSearch_omittBufferNamesList   = get(g:, 'AgSearch_omittBufferNamesList', "NERD No\ name [unite __Tagbar__")
let g:AgSearch_showSearchInfoMax      = get(g:, 'AgSearch_showSearchInfoMax', 15)
let g:AgSearch_useDefaultCommands     = get(g:, 'AgSearch_useDefaultCommands', "yes")
let g:AgSearch_defaultCommand         = get(g:, 'AgSearch_defaultCommand', "Ags")
let g:AgSearch_defaultMapping         = get(g:, 'AgSearch_defaultMapping', "<leader>a")
let g:AgSearch_defaultAbbrev          = get(g:, 'AgSearch_defaultAbbrev', "_ag")
let g:AgSearch_defaultReplacePatterns = get(g:, 'AgSearch_defaultReplacePatterns', "__DIR__ __DIR1__ __DIR2__ __DIR3__ __DIR4__ __FILE__")
let g:AgSearch_userCommandsList       = get(g:, 'AgSearch_userCommandsList',[])
let g:AgSearch_savedSearchHeader      = get(g:, 'AgSearch_savedSearchHeader', "_")
let g:AgSearch_savedSearchTail        = get(g:, 'AgSearch_savedSearchTail', "qf")
let g:AgSearch_savedAgSearchGlobpath  = get(g:, 'AgSearch_savedAgSearchGlobpath', "./*vim-agsearch*qf")
let g:AgSearch_savedSearchesGlobpath  = get(g:, 'AgSearch_savedSearchesGlobpath', "./*qf")
let g:AgSearch_autoSave               = get(g:, 'AgSearch_autoSave', 1)
let g:AgSearch_autoSaveNum            = get(g:, 'AgSearch_autoSaveNum', 10)
let g:AgSearch_showFilterSkipFiles    = get(g:, 'AgSearch_showFilterSkipFiles', 1)
let g:AgSearch_showNotFoundFiles      = get(g:, 'AgSearch_showNotFoundFiles', 1)


let g:AgSearch_mode = get(g:, 'AgSearch_mode', 3)


"- commands -------------------------------------------------------------------

" Search with silver searcher:
" Arguments:
"   PATH                   : search paths.
"   PATTERN_1,PATTERN_N    : search pattern.
"
"   [-if=PATTERN1,PATTERN] : comma separated files to ignore
"   [-id=DIR1,DIR2]        : comma separated directories to ignore
"   [-rp=_DIR_,*]          : replace first match of word _DIR_ with * on path.
"
"   [--ignore-files=PATTERN1,PATTERN] : comma separated files to ignore
"   [--ignore-dirs=DIR1,DIR2]         : comma separated directories to ignore
"   [--replace-pattern=_DIR_]         : replace first match of word _DIR_ on path
command! -nargs=* -complete=file Ags                   call agsearch#Search(<f-args>)

command! -nargs=*                AgS                   call agsearch#SearchAgain(<f-args>)

" On quickfix/linkedlist window with search contents and context toogle folding.
command! -nargs=0                Agf                   call agsearch#ContextFoldToogle()

" Get/set context lines.
command! -nargs=*                Agc                   call agsearch#ContextLines(<f-args>)

" Get last commands saved information:
command! -nargs=*                Agi                   call agsearch#Info(<f-args>)
command! -nargs=*                Agic                  call agsearch#CommandInfo(<f-args>)

" Manage saved searches
command! -nargs=?                Agsv                  call agsearch#Save(<q-args>)
command! -nargs=*                Agl                   call agsearch#Load(<f-args>)
command! -nargs=*                Agd                   call agsearch#Delete(<f-args>)
command! -nargs=*                AgD                   call agsearch#DeleteAll(<f-args>)
command! -nargs=*                Ago                   call agsearch#Open(<f-args>)

" Display plugin help:
command! -nargs=0                Agh                   call agsearch#Help()

" Change plugin verbosity:
command! -nargs=?                Agv                   call agsearch#Verbose(<q-args>)

" Toogle search to background or foreground:
command! -nargs=0                Agbg                  call agsearch#ToogleBackgraundSearch()

" Set auto save mode:
"command! -nargs=?                Agsva                 call agsearch#ToogleAutoSave(<q-args>)

" Release functions:
command! -nargs=0                Agvba                 call agsearch#NewVimballRelease()

" Edit plugin files:
command! -nargs=0                Agedit                call agsearch#Edit()


if g:AgSearch_useDefaultCommands != ""
    "call agsearch#GenerateDefaultCmdMapAbbrev("b", "b", "b", "b", "", "agsearch#GetBuffersAsString()", "Search on all all open buffers")
    call agsearch#GenerateDefaultCmdMapAbbrev("F", "F", "F", "F", "", "__FILES__", "Search on all all open buffers")
    call agsearch#GenerateDefaultCmdMapAbbrev("f", "f", "f", "f", "", "expand(\"%\")", "Search on current file")
    call agsearch#GenerateDefaultCmdMapAbbrev("d", "d", "d", "d", "", "expand(\"%:p:h\")", "Search on current directory")
    call agsearch#GenerateDefaultCmdMapAbbrev("p", "p", "p", "p", "", "expand(\"%:p:h\").\"/../\"", "Search previous directory")
    call agsearch#GenerateDefaultCmdMapAbbrev("w", "w", "w", "w", "", "getcwd().\"/\"", "Search working directory")
endif

"" User Commands Configuration Examle:

"call agsearch#AddUserCmdMapAbbrev( { 'reset':1 } )
"
"" Using default headers for command: 'Ag', map: '<leader>a' and abbreviation: '_a'
"call agsearch#AddUserCmdMapAbbrev( { 'default':"c", 'path':'./config/myconfig/', 'help':"Search config dir" } )
"call agsearch#AddUserCmdMapAbbrev( { 'default':"pj", 'path':'/home/jp/projects/_DIR_', 'help':"Search project dir" } )
"call agsearch#AddUserCmdMapAbbrev( { 'default':"Pj", 'path':'/home/jp/projects/_DIR_', 'opt':'-c 4', 'help':"Search project dir with context" } )
"call agsearch#AddUserCmdMapAbbrev( { 'default':"s", 'path':'/home/jp/projects/_DIR_/src/', 'help':"Search source dir on all projects" } )
"call agsearch#AddUserCmdMapAbbrev( { 'default':"n", 'path':'/home/jp/projects/_DIR_/src/network/configs/_DIR1_/*.xml', 'help':"Search network configs dir on all projects" } )
"
"" Using compleat custom commands, map, and abbreviations:
"call agsearch#AddUserComdMapAbbrev( { 'cmd':"AgSearch_config", 'nmap':"<Leader>sc", 'vmap':"<Leader>sc", 'abbrev' : "_scfg", 'path':'./config/myconfig/', 'help':"Search config dir" } )


call agsearch#GenerateUserCmdMapAbbrev()


"- Mappings -------------------------------------------------------------------

"nnoremap <Leader>f     :Agf<CR>
"nnoremap <Esc>f        :Agf<CR>


"- Abbreviations -------------------------------------------------------------------

" DEBUG: functions: reload plugin
cnoreabbrev _agrl    <C-R>=agsearch#Reload()<CR>


"- menus -------------------------------------------------------------------

if has("gui_running") 
    call agsearch#CreateMenus('cn' , ''              , ':Ags'                  , 'Search (args: [OPTIONS] PATH PATTERN)'              , ':Ags')
    call agsearch#CreateMenus('cn' , ''              , ':AgS'                  , 'Launch again a previous search'                     , ':AgS')
    call agsearch#CreateMenus('cn' , ''              , ':Agf'                  , 'Fold/unfold quickfix window search context'         , ':Agf')
    call agsearch#CreateMenus('cn' , '.&config'      , ':Agc [BEFORE] [AFTER]' , 'Change search context lines'                        , ':Agc')
    call agsearch#CreateMenus('cn' , '.&config'      , ':Agbg'                 , 'Toogle search in foreground/background'             , ':Agbg')
    call agsearch#CreateMenus('cn' , '.&info'        , ':Agi [OPT] [N]'        , 'Show last N completed search information'           , ':Agi')
    call agsearch#CreateMenus('cn' , '.&info'        , ':Agic [N]'             , 'Show last N search commands'                        , ':Agic')
    call agsearch#CreateMenus('cn' , '.&saveAndLoad' , ':Agsv [name]'          , 'Save search to file'                                , ':Agsv')
    call agsearch#CreateMenus('cn' , '.&saveAndLoad' , ':Agl [OPT] [N]'        , 'Load search from file with default name'            , ':Agsv')
    call agsearch#CreateMenus('cn' , '.&saveAndLoad' , ':Agd [OPT] [N]'        , 'Delete a search file with default name'             , ':Agd')
    call agsearch#CreateMenus('cn' , '.&saveAndLoad' , ':AgD [OPT]'            , 'Delete all searches with default name'              , ':AgD')
    call agsearch#CreateMenus('cn' , '.&saveAndLoad' , ':Ago [OPT] [N]'        , 'Open a search file with default name'               , ':Ago')
    call agsearch#CreateMenus('cn' , ''              , ':Agh'                  , 'Show abridged plugin help'                          , ':Agh')
endif

let &cpo = s:save_cpo
unlet s:save_cpo
