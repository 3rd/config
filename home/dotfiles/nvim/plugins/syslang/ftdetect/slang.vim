if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

function s:detect()
  " abort for floating windows
  let config = nvim_win_get_config(0)
  let rel = get(config, "relative")
  if (rel != "")
    return
  endif

  " abort for empty buffer
  if expand('%:p') == ""
    return
  endif

  " abort if ft is already set to something other than "syslang"
  if (&ft != "" && &ft != "syslang")
    return
  endif

  " abort if the extension is not empty and different from "syslang"
  if (expand('%:e') != "" && expand('%:e') != "syslang")
    return
  endif

  autocmd FileType syslang :lua require("syslang").setup()
  setlocal filetype=syslang
endfunction


autocmd BufRead,BufNewFile * call s:detect()
