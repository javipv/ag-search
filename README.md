# ag-search
Search with ag/grep in background, save/load searches on quickfix

## Description

ag-search allows you to launch ag (silver searcher) or grep commands in background and display the results on quickfix window.

Launch :Agh for abridged help and examples.

ag-search is a plugin to:
- Launch a search in background (Ags path pattern [options]).
- Concatenate searches (:Ags pattern1,pattern2,pattern3 path [options]).
- Concatenate searches. Remove not matching pattern2 (:Ags pattern1,-pattern2 path [options]).
- Launch again a previous search (:AgS)
- Save/load/open/delete saved search results (:Agsv, :Agl, :Agd, :AgD, :Ago).
- Automatically save last N searches performed.
- Retrieve search information of the last searches performed (:Agi, :Agic).
- Create custom mappings and abbreviations to launch user searches more easily.
- Force search with context (:Agc, :Agc 4, :Agc 2 4).
- Fold/unfold the context on the quickfix window (:Agf)

This plugin uses jobs.vim to launch the search in backgraund.
- Use command :Jobsl to show information about your searches running in backgraund.
- Use command :Jobsk to kill any searche running in backgraund.

Default mappings:
- \<leader>af : search word under cursor (or visual selection) in current buffer.
- \<leader>ad : search word under cursor (or visual selection) in current buffer file's directory.
- \<leader>ap : search word under cursor (or visual selection) in current buffer file's parent directory.
- \<leader>aw : search word under cursor (or visual selection) in working directory.

Default abbreviations:
- _agf : search in current buffer.
- _agd : search in current buffer's directory.
- _agp : search in current buffer's previous directory.
- _agw : search in working directory.

The doc page is still pending meanwhile you can check :Agh for an abridged command help and examples:

Any feedback will be welcome.

Ags command options:
- ID=path1,path2         : ignore (comma separed) directories.
- IF=pattern1,pattern2 : ignore (comma separed) patterns.
- RP=pattern               : ask user to replace on the provided path any words on g:AgSearch_defaultReplacePatterns (Defaults: _DIR_, _DIR1_, _DIR2..., _FILE_).


## ADVANCED:
Customizations you can add to your .vimrc file.

```vimscript
" Fold/unfold the context on quickfix window:
nnoremap <Leader>f     :Agf<CR>
```

Create mapping to search on a folder projects, ask user to replace _DIR_ with the directory name or use wildcard * to search all directories:
```vimscript
nnoremap <Leader>as :Ags /home/jp/projects/_DIR_/source/ <C-R>="-s ".expand('<cword>')<CR>
```

Create command :Agss, map <leader>as and abbreviation _ags to search on directory sources, inside directory projets, and ask user to replace _DIR_ with a directory name (project name) or wildcard (like: *) to search all directories (projects):
```vimscript
" Remove previous user commands:
call agsearch#AddUserCmdMapAbbrev( { 'reset':1 } )

" Add new user commands:
call agsearch#AddUserCmdMapAbbrev( { 'default':"s", 'path':'/home/jp/projects/_DIR_/source/', 'help':"Search source dir on projects" } )
call agsearch#AddUserCmdMapAbbrev( { 'default':"c", 'path':'./home/jp/config/myconfig/', 'help':"Search config dir" } )
```

## Install details
Minimum version: Vim 7.0+

Recomended version: Vim 8.0+
