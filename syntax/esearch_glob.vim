if exists('b:current_syntax')
  finish
endif
syn match esearchFilename   '^[^ ].*$'
syn match esearchBasename   '[^/]\+$' contained containedin=esearchFilename
syn match esearchHeader     '\%1l.*'
syn match esearchStatistics '\d\+' contained containedin=esearchHeader

let b:current_syntax = 'esearch_glob'
