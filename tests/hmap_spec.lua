describe("hmap", function()
    it("can be required", function()
        require'hmap'
    end)

    it("can open the window", function()
        local hmap = require("hmap")
        hmap.toggle_window()
    end)
end)
