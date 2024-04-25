vim.schedule(function ()
  vim.cmd.edit(vim.fs.joinpath(os.getenv('XDG_CONFIG_HOME'), 'tests/Arctgx/DapStrategy/TrivialTest.php'))
  vim.api.nvim_win_set_cursor(0, {11, 9})
  require 'dap'.set_breakpoint()
  require 'neotest'.output_panel.open()
  require 'neotest'.summary.open()
end)