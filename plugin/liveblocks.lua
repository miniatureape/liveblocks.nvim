if vim.g.loaded_liveblocks then
  return
end
vim.g.loaded_liveblocks = true

local liveblocks = require('liveblocks')

local augroup = vim.api.nvim_create_augroup('Liveblocks', { clear = true })

vim.api.nvim_create_autocmd({'FocusGained', 'WinEnter', 'BufEnter'}, {
  group = augroup,
  pattern = '*.md',
  callback = function()
    print("refreshing liveblocks")
    liveblocks.refresh_liveblocks()
  end,
})

vim.api.nvim_create_autocmd('BufWritePost', {
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

vim.keymap.set('n', '<leader>lbw', function()
  liveblocks.write_back()
end, { desc = 'Liveblocks: Write back to source file' })
