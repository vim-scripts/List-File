" Creates and maintains text files of nested lists.
" File must end in '.list'.
" Use >> and << to adjust depth of item.
" Includes nested folding for lists. Use standard vim fold shortcuts (e.g.: zo, zc).
" Commands and shortcuts:
" CREATING
" ,n - create new item
" <enter> - (insert or normal) create new item
" ,s - create sub item
" <tab> - (insert or normal) create sub-item
" ,u - create super item
" MARKING
" ,p - mark item with '=' (in progress)
" ,x - mark item with 'x' (completed)
" ,o - mark item with 'o'
" ,? - mark item with '?'
" ,- - mark item with '-' (default, incomplete)
" ,N - set priority as N, where N is 1-5
" ET CETERA
" ,t - add/update timestamp on item
" ,r - (visual line) sort highlighted items
" ,r - (normal) sort entire file
" :Lcreate <name> - create new list file in current buffer with <name> (".list" is added automagically)
" :Lsearch mark <mark> - find all items with <mark> (e.g.: =, 1, -, etc.) using location list
"          tag <tag> - find all items with <tag> using location list
" :Ltag <tag> [tag ...] - (normal or visual line) add tag(s) to line(s) (has tab complete)
" :Ltagr <tag> [tag ...] - (normal or visual line) remove tag(s) from line(s) (has tab complete)
" :Lmark <mark> - (normal or visual line) mark item(s) with <mark>

"""
""" CONFIGURABLE OPTIONS
"""

" should items have timestamps by default?
if (!exists("g:listFile_timestamp"))
	let g:listFile_timestamp = 0
endif
" how far should each level indent?
if (!exists("g:listFile_indent"))
	let g:listFile_indent = 4
endif
" sort order for item marks
if (!exists("g:listFile_ranks"))
	let g:listFile_ranks = ['=','1','2','3','4','5','o','-','?','x']
endif

"""
""" END CONFIGURABLE OPTIONS
"""

com! -nargs=1 Lcreate :call ListCreate("<args>")

let s:ranks = {}
autocmd BufNewFile,BufRead *.list call ListFile()

" 'install' list features
fun! ListFile()
	setfiletype listfile

	" we want our own folding stuff
	setl foldmethod=expr
	setl foldexpr=ListFoldLevel(v:lnum)
	setl foldtext=ListFoldLine()
	
	" set the configured tabbing options
	exe 'setlocal shiftwidth='.g:listFile_indent
	exe 'setlocal tabstop='.g:listFile_indent

	" make indentation look like list view
	setl listchars=tab:\|\ 
	setl list

	" don't show matching brackets
	setl noshowmatch
	" automatic indentation
	setl cindent
	" don't wrap long lines (cleans up display)
	setl nowrap
	setl tw=0

	" map all the magic shortcuts
	if (g:listFile_timestamp == 1)
		" add [n]ew item below current
		nmap <buffer> ,n o-  [<ESC>:call ListTimestamp()<CR><ESC>^la
		" add new sub item below current
		nmap <buffer> ,s o-  [<ESC>:call ListTimestamp()<CR><ESC>>>^la
		" add new super item below current
		nmap <buffer> ,u o-  [<ESC>:call ListTimestamp()<CR><ESC><<^la
	else
		" add [n]ew item below current
		nmap <buffer> ,n o- 
		" add new sub item below current
		nmap <buffer> ,s o- <ESC>>>^la
		" add new super item below current
		nmap <buffer> ,u o- <ESC><<^la
	endif
	imap <buffer> <tab> <ESC>,s
	nmap <buffer> <tab> ,s
	imap <buffer> <cr> <ESC>,n
	nmap <buffer> <cr> ,n
	" mark item as [x]
	nmap <buffer> ,x :Lmark x<CR>
	vmap <buffer> ,x :Lmark x<CR>
	" mark item as [-]
	nmap <buffer> ,- :Lmark -<CR>
	vmap <buffer> ,- :Lmark -<CR>
	" mark item as = (in [p]rogress)
	nmap <buffer> ,p :Lmark =<CR>
	vmap <buffer> ,p :Lmark =<CR>
	" mark item as [o]
	nmap <buffer> ,o :Lmark o<CR>
	vmap <buffer> ,o :Lmark o<CR>
	" mark item as [?]
	nmap <buffer> ,? :Lmark ?<CR>
	vmap <buffer> ,? :Lmark ?<CR>
	" mark item with a priority
	nmap <buffer> ,1 :Lmark 1<CR>
	nmap <buffer> ,2 :Lmark 2<CR>
	nmap <buffer> ,3 :Lmark 3<CR>
	nmap <buffer> ,4 :Lmark 4<CR>
	nmap <buffer> ,5 :Lmark 5<CR>
	" add/update [t]imestamp
	nmap <buffer> ,t mz$a [<ESC>:call ListTimestamp()<CR><ESC>`z
	vmap <buffer> ,r :call ListSortV()<CR>
	nmap <buffer> ,r :call ListSortAll()<CR>

	com! -nargs=+ -buffer Lsearch :call ListSearch("<args>")
	com! -nargs=+ -buffer -range -complete=customlist,ListTagComplete Ltag :call ListTagV(<count>,"<args>")
	com! -nargs=+ -buffer -range -complete=customlist,ListTagComplete Ltagr :call ListTagRV(<count>,"<args>")
	com! -nargs=1 -buffer -range Lmark :call ListSetMark(<count>,"<args>")

	let b:tags = {}
	call ListTagCompileIndex()
endfunction

fun! ListSearch(args)
	let args = split(a:args,' ')
	let type = remove(l:args,0)
	echo l:args
	let string = join(l:args,' ')
	if (l:type == 'mark')
		call ListMark(l:string)
	elseif (l:type == 'tag')
		call ListTagSearch(l:string)
	endif
endfunction

fun! ListCreate(name)
	exe 'e '.a:name.'.list'
	let @z = '- '
	normal "zP
endfunction

" fix properly formatted timestamp
fun! ListTimestamp()
	let addStamp = 0
	if getline('.') =~ '\['
		let addStamp = 1
	endif
	normal ^t[d$
	if l:addStamp
		call ListTimestampString()
		normal "zp
	endif
endfunction

" return actual timestamp string
fun! ListTimestampString()
	let @z = ' ['.strftime('%y-%m-%d %H:%M').']'
endfunction


"""
""" FOLDING
"""

" return fold line format
fun! ListFoldLine()
	let s:count = 1
	let s:spaces = '|'
	while s:count < &shiftwidth
		let s:spaces = s:spaces.' '
		let s:count = s:count + 1
	endwhile
	let numLines = v:foldend - v:foldstart
	let foldLine = substitute(getline(v:foldstart)." (".l:numLines.")","\t",s:spaces,'g')
	if (winwidth(0) > strlen(foldLine))
		let foldLine = l:foldLine.repeat(' ',winwidth(0) - strlen(foldLine))
	endif
	return l:foldLine
endfunction

" foldexpr function
fun! ListFoldLevel(linenum)
	let s:prefix = ''
	let s:myline = getline(a:linenum)
	let s:nextline = getline(a:linenum+1)
	let s:mynumtabs = ListGetDepth(s:myline)
	let s:nextnumtabs = ListGetDepth(s:nextline)
	if s:nextnumtabs > s:mynumtabs " if this item has sub-items
		let s:level = s:nextnumtabs
	else " next item is either same or higher level
		let s:level = s:mynumtabs
		if s:nextnumtabs < s:mynumtabs " if next item has higher level, close this fold
			let s:prefix = '<'
			let s:level = s:nextnumtabs+1
		end
	endif
	if a:linenum > 1
		s:pline = getline(a:linenum-1)
		s:pnumtabs = ListGetDepth(s:pline)
		if s:level < s:pnumtabs
		" if this is higher level than prev, start a new fold
			let s:prefix = '>'
		endif
	endif
	return s:prefix.s:level
endfunction


"""
""" SORTING
"""

" sort highlighted lines
fun! ListSortV() range
	call ListSort(a:firstline,a:lastline)
endfunction

" sort whole file
fun! ListSortAll()
	call ListSort(1,line('$'))
endfunction

" sort range of lines
fun! ListSort(start,end)
	let s:sortLines = getline(a:start,a:end)
	let s:sortDict = {0:[]}

	let s:curDepth = ListGetDepth(s:sortLines[0])
	let s:stack = [0]
	let s:index = 0

	while (ListDictFormat())
	endwhile
	let sorted = ListCompileSorted(0)
	call setline(a:start,l:sorted)
endfunction

" construct sorted list string from sortDict
fun! ListCompileSorted(index)
	call ListConvertRanks()
	let list = get(s:sortDict,a:index,[])
	if (!empty(l:list))
		let sorted = sort(s:sortDict[a:index],"ListSortFunction")
		let allSorted = []
		for item in l:sorted
			call add(l:allSorted,item[1])
			let sublist = ListCompileSorted(item[0])
			if (sublist != [])
				call extend(l:allSorted,l:sublist)
			endif 
		endfor
		return l:allSorted
	else
		return []
	endif
endfunction

" put entire list in dictionary format for sorting
" this cannot be recursive, as any list file with lines > maxfuncdepth could be sorted
fun! ListDictFormat()
	if (len(s:sortLines) == 0)
		return 0
	endif
	let line = remove(s:sortLines,0)
	let s:prevDepth = s:curDepth
	let s:curDepth = ListGetDepth(l:line)
	if (s:curDepth > s:prevDepth) " we're starting a sub-list
		" add prev index to stack because it's now a parent
		call add(s:stack,s:index)
		" create empty list in dictionary
		let s:sortDict[s:index] = []
	elseif (s:curDepth < s:prevDepth) " we're ending sub-list(s)
		" pop the stack as many times as necessary
		let diff = s:prevDepth - s:curDepth
		while (l:diff > 0)
			call remove(s:stack,len(s:stack)-1)
			let diff = l:diff - 1
		endwhile
	endif
	call add(s:sortDict[s:stack[len(s:stack) - 1]],[s:index + 1,l:line])
	let s:index = s:index + 1
	return 1
endfunction

" sorting function
fun! ListSortFunction(one,two)
	let onerank = ListGetItemRank(a:one[1])
	let tworank = ListGetItemRank(a:two[1])
	return l:onerank == l:tworank ? 0 : l:onerank < l:tworank ? -1 : 1
endfunction

"converts ranks to usable dictionary
fun! ListConvertRanks()
	let i = 0
	for rank in g:listFile_ranks
		let s:ranks[rank] = l:i
		let i = l:i + 1
	endfor
endfunction

" get rank for the given line based on user-defined mark ranks
fun! ListGetItemRank(line)
	let matches = matchlist(a:line,'^\s*\(\S\+\)')
	let mark = l:matches[1]
	let default = 1000 + char2nr(l:mark)
	return get(s:ranks,l:mark,l:default)
endfunction

" get the depth of the given line
fun! ListGetDepth(line)
	return match(a:line,"[^\t]",0)
endfunction


"""
""" MARKING
"""

" mark current line
fun! ListSetMark(end,mark)
	if (a:end > 0)
		exe "'<,'>s/^\\(\\s*\\)./\\1".a:mark."/"
		nohl
	else
		let @z = strpart(a:mark,0,1)
		normal mz^dl"zP
		call ListTimestamp()
		normal `z
	endif
endfunction

" find items with mark
fun! ListMark(mark)
	exe 'lvimgrep /^\s*'.a:mark.'/ %'
	lopen
endfunction


"""
""" TAGGING
"""

" tag a line
fun! ListTag(line,tags)
	let line = getline(a:line)
	let tags = ' :'.join(split(a:tags,' '),': :').':'
	let pos = match(l:line,'\[')
	if (l:pos == -1)
		let line = l:line.l:tags
	else
		let line = strpart(l:line,0,l:pos-1).l:tags.strpart(l:line,l:pos-1)
	endif
	call setline(a:line,l:line)
	for tagString in split(a:tags,' ')
		let b:tags[tagString] = 'x'
	endfor
endfunction

" remove tag from line
fun! ListTagR(line,tags)
	let line = getline(a:line)
	let tags = split(a:tags,' ')
	for tagString in l:tags
		let line = substitute(l:line,'\s\=:'.tagString.':','','')
	endfor
	call setline(a:line,l:line)
endfunction

" tag lines in visual mode
fun! ListTagV(end,tags) range
	let start = line('.')
	let end = a:end > 0 ? a:end : line('.')
	while (l:start <= l:end)
		call ListTag(l:start,a:tags)
		let start = l:start + 1
	endwhile
endfunction

" remove tags in visual mode
fun! ListTagRV(end,tags) range
	let start = line('.')
	let end = a:end > 0 ? a:end : line('.')
	while (l:start <= l:end)
		call ListTagR(l:start,a:tags)
		let start = l:start + 1
	endwhile
endfunction

" search for tag
fun! ListTagSearch(string)
	exe 'lvimgrep /:'.a:string.':/ %'
	lopen
endfunction

" compile tag index
fun! ListTagCompileIndex()
	for line in getbufline('%',0,'$')
		let matches = matchlist(line,':\([^\s:]\+\):')
		if len(l:matches) > 0
			call remove(l:matches,0)
			for tagString in l:matches
				if tagString != ''
					let b:tags[tagString] = 'x'
				endif
			endfor
		endif
	endfor
endfunction

" autocomplete function for tags
fun! ListTagComplete(argLead,cmdLine,cursorPos)
	let matches = []
	for tagString in keys(b:tags)
		if match(tagString,'^'.a:argLead) >= 0
			call add(l:matches,tagString)
		endif
	endfor
	return l:matches
endfunction
