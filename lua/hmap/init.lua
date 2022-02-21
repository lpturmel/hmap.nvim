local popup = require"plenary.popup"

local M = {}

-- Globals
local _hmap_bufwin = nil
local _hmap_win_id = nil

-- Locals
local function list(m)
    local map_list = {}
    local maps = vim.api.nvim_get_keymap(m)

    for i, map in ipairs(maps) do
        map_list[i] = {
            rhs = map.rhs,
            lhs = map.lhs
        }
    end

    return map_list
end

local function close_window()
    vim.api.nvim_win_close(_hmap_win_id, true)

    _hmap_win_id = nil
    _hmap_bufwin = nil
end

local function create_window()
    local width =  60
    local height = 10
    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

    -- Creates a temporary buffer
    local bufwin = vim.api.nvim_create_buf(false, true)

    -- Create the popup
    local win_id, win = popup.create(bufwin, {
        title = "Hmap",
        highlight = "HmapWindow",
        line = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        minwidth = width,
        minheight = height,
        borderchars = borderchars
    })

    return {
        bufwin = bufwin,
        win = win,
        win_id = win_id,
    }
end

-- API
M.toggle_window = function()
    if _hmap_win_id ~= nil and vim.api.nvim_win_is_valid(_hmap_win_id) then
        close_window()
        return
    end

    local content = list("n")
    local win_info = create_window()

    _hmap_win_id = win_info.win_id
    _hmap_bufwin = win_info.bufwin

    -- Content needs to be strings currently list of tables
    for idx = 1, #content do
        content[idx] = string.format("%s --- %s", content[idx].lhs, content[idx].rhs)
    end

    vim.api.nvim_buf_set_name(_hmap_bufwin, "hmap-menu")
    vim.api.nvim_buf_set_lines(_hmap_bufwin, 0, #content, false, content)
    vim.api.nvim_buf_set_option(Harpoon_bufh, "filetype", "hmap")
    vim.api.nvim_buf_set_option(Harpoon_bufh, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(Harpoon_bufh, "bufhidden", "delete")

    vim.api.nvim_buf_set_keymap(
        Harpoon_bufh,
        "n",
        "q",
        "<Cmd>lua require('hmap').toggle_window()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        Harpoon_bufh,
        "n",
        "<ESC>",
        "<Cmd>lua require('hmap').toggle_window()<CR>",
        { silent = true }
    )
     vim.cmd(
        string.format(
            "autocmd BufModifiedSet <buffer=%s> set nomodified",
            _hmap_bufwin
        )
    )
    vim.cmd("autocmd BufLeave <buffer> ++nested ++once silent lua require('hmap').toggle_window()")
end

return M
