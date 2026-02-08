if vim.g.loaded_liveblocks then
  return
end
vim.g.loaded_liveblocks = true

local liveblocks = require('liveblocks')

local augroup = vim.api.nvim_create_augroup('Liveblocks', { clear = true })

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = augroup,
  pattern = '*.md',
  callback = function()
    liveblocks.setup_folding()
  end,
})

vim.api.nvim_create_autocmd({'FocusGained', 'WinEnter', 'BufEnter'}, {
  group = augroup,
  pattern = '*.md',
  callback = function()
    liveblocks.refresh_liveblocks()
  end,
})

vim.api.nvim_create_autocmd({'BufWritePost', 'WinLeave', 'BufLeave'}, {
  group = augroup,
  pattern = '*.md',
  callback = function()
    liveblocks.write_all_blocks()
  end,
})

vim.api.nvim_create_user_command('LiveblocksCreate', function()
  liveblocks.create_liveblock()
end, {})

vim.api.nvim_create_user_command('LiveblocksRefresh', function()
  liveblocks.refresh_liveblocks()
end, {})

vim.api.nvim_create_user_command('LiveblocksWriteBack', function()
  liveblocks.write_back()
end, {})

vim.api.nvim_create_user_command('LiveblocksGoto', function()
  liveblocks.goto()
end, {})

vim.api.nvim_create_user_command('LiveblocksWrap', function(opts)
  liveblocks.wrap_selection(opts.line1, opts.line2)
end, { range = true })

vim.api.nvim_create_user_command('LiveblocksTelescope', function()
  require('telescope').extensions.liveblocks.liveblocks()
end, {})
