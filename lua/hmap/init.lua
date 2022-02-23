local popup = require"plenary.popup"

local M = {}
-- State
local _hmap_input_bufwin = nil
local _hmap_input_win_id = nil
local _hmap_results_bufwin = nil
local _hmap_results_win_id = nil
local _hmap_results = nil
local _hmap_maps = nil

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

local function close_window(win_id)
    if win_id and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
    end
end

local function create_window(opts)
    local borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }

    -- Creates a temporary buffer
    local bufwin = vim.api.nvim_create_buf(false, true)


    -- Create the input popup
    local win_id, _ = popup.create(bufwin, {
        title = opts.title,
        highlight = opts.highlight,
        line = math.floor(((vim.o.lines - opts.height) / 2) - 1) - opts.line_offset,
        col = math.floor((vim.o.columns - opts.width) / 2) - opts.col_offset,
        minwidth = opts.width,
        minheight = opts.height,
        borderchars = borderchars
    })


    return {
        bufwin = bufwin,
        win_id = win_id,
    }
end

local function set_window_options(winbuf, content, menu_name)
    vim.api.nvim_buf_set_name(winbuf, menu_name)
    vim.api.nvim_buf_set_lines(winbuf, 0, #content, false, content)
    vim.api.nvim_buf_set_option(winbuf, "filetype", "hmap")
    vim.api.nvim_buf_set_option(winbuf, 'swapfile', false)
    vim.api.nvim_buf_set_option(winbuf, "buftype", "nofile")
    -- Clear on hide
    vim.api.nvim_buf_set_option(winbuf, 'bufhidden', 'wipe')
end

local function is_window_open()
    return (_hmap_input_win_id ~= nil and vim.api.nvim_win_is_valid(_hmap_input_win_id)) and (_hmap_results ~= nil and vim.api.nvim_win_is_valid(_hmap_results_win_id))
end

local function update_results(value)
    if value == nil or value == "" then
        _hmap_results = _hmap_maps
        return
    end

    vim.api.nvim_buf_set_option(_hmap_results_bufwin, "modifiable", true)

    local filtered_results = {}
    local lvalue = string.lower(value)
    -- Filter _hmap_results by value
    for _, map_str in ipairs(_hmap_maps) do
        local lmap_str = string.lower(map_str)
        if string.find(lmap_str, lvalue) then
            table.insert(filtered_results, map_str)
        end
    end

    _hmap_results = filtered_results

    vim.api.nvim_buf_set_lines(_hmap_results_bufwin, 0, -1, true, filtered_results)
    vim.api.nvim_buf_set_option(_hmap_results_bufwin, "modifiable", false)
end

-- API
M.toggle_window = function()
    local is_open = is_window_open()

    if is_open then
        close_window(_hmap_input_win_id)
        close_window(_hmap_results_win_id)

        _hmap_input_win_id = nil
        _hmap_input_bufwin = nil
        _hmap_results_win_id = nil
        _hmap_results_bufwin = nil
        return
    end

    local content = list("n")

    -- Results window
    local results_win_info = create_window({
        title = "Results",
        width = 60,
        height = 10,
        line_offset = 0,
        col_offset = 0,
        highlight = "HmapResultsWindow"
    })

    -- Input window
    local input_win_info = create_window({
        title = "Input",
        width = 60,
        height = 1,
        line_offset = -8,
        col_offset = 0,
        highlight = "HmapInputWindow"
    })

    _hmap_input_win_id = input_win_info.win_id
    _hmap_input_bufwin = input_win_info.bufwin
    _hmap_results_win_id = results_win_info.win_id
    _hmap_results_bufwin = results_win_info.bufwin

    -- Content needs to be strings currently list of tables
    for idx = 1, #content do
        content[idx] = string.format("%s --- %s", content[idx].lhs, content[idx].rhs)
    end

    _hmap_results = content
    _hmap_maps = content

    set_window_options(_hmap_input_bufwin, {}, "hmap-input-menu")
    set_window_options(_hmap_results_bufwin, _hmap_results, "hmap-results-menu")

    vim.api.nvim_buf_set_option(_hmap_results_bufwin, "modifiable", false)

    -- Set toggle bindings to input window as it will be the only interactible window
    vim.api.nvim_buf_set_keymap(
        _hmap_input_bufwin,
        "n",
        "q",
        "<Cmd>lua require('hmap').toggle_window()<CR>",
        { silent = true }
    )
    vim.api.nvim_buf_set_keymap(
        _hmap_input_bufwin,
        "n",
        "<ESC>",
        "<Cmd>lua require('hmap').toggle_window()<CR>",
        { silent = true }
    )
    -- Start in insert mode
    vim.cmd [[startinsert]]
    vim.cmd("autocmd BufLeave <buffer> ++nested ++once silent lua require('hmap').toggle_window()")

    -- Bind on change events
    vim.cmd(
            string.format(
                "autocmd TextChanged,TextChangedI <buffer=%s> lua require('hmap').on_input_change()",
                _hmap_input_bufwin
            )
        )
end

M.on_input_change = function()
    local buffval = vim.api.nvim_buf_get_lines(_hmap_input_bufwin, 0, -1, false)
    local value = table.concat(buffval, "\n")

    update_results(value)
end
return M
