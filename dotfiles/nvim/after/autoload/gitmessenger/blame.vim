if exists('s:CreateBlame')
  finish
endif

runtime autoload/gitmessenger/blame.vim
let s:CreateBlame = funcref('gitmessenger#blame#new')

function! s:spawn_git(SpawnGit, args, callback) dict abort
  let args = a:args
  if args ==# ['--no-pager', 'diff', 'HEAD', self.blame_file]
    let args = ['--no-pager', 'diff', 'HEAD', '--', self.state.diff_file_to]
    let previous_file = self.state.diff_file_from
    if previous_file !=# '' && previous_file !=# self.state.diff_file_to
      call add(args, previous_file)
    endif
  endif

  return call(a:SpawnGit, [args, a:callback], self)
endfunction

function! gitmessenger#blame#new(file, line, opts) abort
  let blame = s:CreateBlame(a:file, a:line, a:opts)
  if blame is v:null
    return blame
  endif

  let blame.spawn_git = function('s:spawn_git', [blame.spawn_git])
  return blame
endfunction
