local root = vim.fn.tempname()
vim.fn.mkdir(vim.fs.joinpath(root, "work"), "p")
vim.fn.mkdir(vim.fs.joinpath(root, "other"), "p")
vim.fn.writefile({ "# Work" }, vim.fs.joinpath(root, "work", "main"))

local init_path = vim.fs.joinpath(root, "init.lua")
vim.fn.writefile({
  string.format("vim.opt.runtimepath:prepend(%q)", vim.fn.getcwd()),
  'require("lib")',
  'vim.cmd("filetype on")',
  "lib.module.get_enabled_modules = function()",
  '  require("modules/core/syslang")',
  "  return {}",
  "end",
  "lib.module.get_module_plugins = function() return {} end",
  "lib.lazy.install = function() end",
  "lib.lazy.setup = function() end",
  'require("config")',
}, init_path)

local verify_path = vim.fs.joinpath(root, "verify.lua")
vim.fn.writefile({
  'local expected = vim.fs.joinpath(vim.uv.cwd(), "work/main")',
  "local arguments = vim.fn.argv()",
  'local work_opened = vim.api.nvim_buf_get_name(0) == expected and arguments[1] == "work/main"',
  'local other_unchanged = arguments[2] == "other"',
  'local syslang_detected = vim.bo.filetype == "syslang"',
  "if not work_opened or not other_unchanged or not syslang_detected then",
  '  vim.api.nvim_err_writeln("opened " .. vim.api.nvim_buf_get_name(0) .. " with arguments " .. vim.inspect(arguments) .. " and filetype " .. vim.bo.filetype)',
  '  vim.cmd("cquit 1")',
  "end",
  'vim.cmd("qall!")',
}, verify_path)

local result = vim
  .system({
    vim.v.progpath,
    "-n",
    "-i",
    "NONE",
    "--headless",
    "--noplugin",
    "-u",
    init_path,
    "-c",
    "luafile " .. vim.fn.fnameescape(verify_path),
    "work",
    "other",
  }, { cwd = root, text = true })
  :wait()

vim.fn.delete(root, "rf")

assert(result.code == 0, result.stderr)

print("ok: literal work opens work/main with the Syslang filetype")
