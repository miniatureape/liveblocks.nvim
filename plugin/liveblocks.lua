if vim.g.loaded_liveblocks then
  return
end
vim.g.loaded_liveblocks = true

local liveblocks = require('liveblocks')

local augroup = vim.api.nvim_create_augroup('Liveblocks', { clear = true })

vim.api.nvim_create_autocmd('FocusGained', {
  group = augroup,
  pattern = '*',
  callback = function()
    liveblocks.refresh_liveblocks()
  end,
})

vim.api.nvim_create_user_command('LiveblocksRefresh', function()
  liveblocks.refresh_liveblocks()
end, {})

vim.api.nvim_create_user_command('LiveblocksWriteBack', function()
  liveblocks.write_back()
end, {})

vim.keymap.set('n', '<leader>lbw', function()
  liveblocks.write_back()
end, { desc = 'Liveblocks: Write back to source file' })
