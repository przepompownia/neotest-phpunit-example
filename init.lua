local thisInitFile = debug.getinfo(1).source:match('@?(.*)')
local configDir = vim.fs.dirname(thisInitFile)

vim.env['XDG_CONFIG_HOME'] = configDir
vim.env['XDG_DATA_HOME'] = configDir .. '/.xdg/data'
vim.env['XDG_STATE_HOME'] = configDir .. '/.xdg/state'
vim.env['XDG_CACHE_HOME'] = configDir .. '/.xdg/cache'
local stdPathConfig = vim.fn.stdpath('config')

vim.opt.runtimepath:prepend(stdPathConfig)
vim.opt.packpath:prepend(stdPathConfig)
local pluginsPath = vim.uv.fs_realpath('plugins') .. '/'

local onExit = vim.schedule_wrap(function (obj)
  vim.notify(obj.stdout)
  vim.notify(obj.stderr, vim.log.levels.WARN)
end)

for name, repo in pairs {
  ['plenary.nvim'] = {url = 'https://github.com/nvim-lua/plenary.nvim'},
  ['neotest'] = {url = 'https://github.com/nvim-neotest/neotest'},
  ['nvim-dap'] = {url = 'https://github.com/mfussenegger/nvim-dap'},
  ['nvim-treesitter'] = {url = 'https://github.com/nvim-treesitter/nvim-treesitter'},
  ['neotest-phpunit'] = {url = 'https://github.com/przepompownia/neotest-phpunit', branch = 'dap-strategy'},
} do
  local installPath = pluginsPath .. name
  if vim.fn.isdirectory(installPath) == 0 then
    local command = {
      'git',
      'clone',
      '--',
      repo.url,
      installPath,
    }
    if repo.branch then
      table.insert(command, 3, '--branch')
      table.insert(command, 4, repo.branch)
    end
    vim.system(command, {}, onExit)
  end
  vim.opt.runtimepath:append(installPath)
end

local function init()
  vim.cmd.colorscheme 'habamax'
  vim.go.termguicolors = true
  local dap = require 'dap'
  dap.defaults.fallback.switchbuf = 'useopen'
  dap.set_log_level('TRACE')
  dap.adapters.php = {
    type = 'executable',
    command = vim.uv.cwd() .. '/bin/dap-adapter-utils',
    args = {'run', 'vscode-php-debug', 'phpDebug'}
  }

  dap.configurations.php = {
    {
      log = true,
      type = 'php',
      request = 'launch',
      name = 'Listen for XDebug',
      port = 9003,
      stopOnEntry = false,
      xdebugSettings = {
        max_children = 512,
        max_data = 1024,
        max_depth = 4,
      },
      breakpoints = {
        exception = {
          Notice = false,
          Warning = false,
          Error = false,
          Exception = false,
          ['*'] = false,
        },
      },
    }
  }

  require('nvim-treesitter.configs').setup {
    ensure_installed = {'php'},
    highlight = {
      enable = true,
    },
  }
  local phpXdebugCmd = {
    'php',
    '-dzend_extension=xdebug.so',
    'vendor/bin/phpunit',
  }
  local phpXdebugEnv = {XDEBUG_CONFIG = 'idekey=neotest'}
  local neotest = require('neotest')
  neotest.setup({
    adapters = {
      require('neotest-phpunit') {
        env = phpXdebugEnv,
        dap = dap.configurations.php[1],
        phpunit_cmd = function ()
          return 'vendor/bin/phpunit'
        end,
      },
    }
  })
  vim.api.nvim_create_user_command('PhpUnitWithXdebug', function (opts)
    local phpunit = vim.tbl_values(phpXdebugCmd)
    table.insert(phpunit, opts.fargs[1] or vim.api.nvim_buf_get_name(0))
    vim.system(phpunit, {env = phpXdebugEnv}, onExit)
  end, {nargs = '?', complete = 'file'})

  vim.keymap.set('n', '<Esc>', vim.cmd.fclose)
  vim.keymap.set({'n'}, ',dr', dap.continue, {})
  vim.keymap.set({'n'}, ',ds', dap.step_over, {})
  vim.keymap.set({'n'}, ',dc', dap.close, {})
  vim.keymap.set({'n'}, ',no', neotest.summary.toggle, {})
  vim.keymap.set({'n'}, ',nr', neotest.run.run, {})
  vim.keymap.set({'n'}, ',nd', function () neotest.run.run({
    strategy = 'dap',
    -- env = phpXdebugEnv,
  }) end, {})

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'php',
    callback = function ()
      function ShowListeningIndicator()
        local indicator = '%#DiagnosticError#⛧ %#StatusLine# [Listening...]'
        return dap.session() and indicator or '%#DiagnosticInfo#☠%#StatusLine# [No debug session]'
      end
      vim.opt_local.statusline = '%{%v:lua.ShowListeningIndicator()%} %f'
    end
  })

  vim.schedule(function ()
    vim.cmd.edit 'tests/Arctgx/DapStrategy/TrivialTest.php'
    vim.api.nvim_win_set_cursor(0, {11, 9})
    dap.set_breakpoint()
    neotest.output_panel.open()
    neotest.summary.open()
  end)
end

vim.api.nvim_create_autocmd('UIEnter', {
  callback = init,
})
