local module = require("./UnitAI.Builder.luau")

-- Create mock environment
local timeSpent = 0
local target = {
    GetDescendants = function()
        local parts = {}
        for i = 1, 1000 do
            table.insert(parts, { IsA = function(self, type) return type == "BasePart" end })
        end
        return parts
    end,
    GetAttribute = function(self, attr)
        if attr == "IsUnderConstruction" then return true end
        if attr == "Health" then return 100 end
        if attr == "Owner" then return "Player1" end
        if attr == "Progress" then return 99 end
        if attr == "BuildRequiredProgress" then return 100 end
        if attr == "MaxHealth" then return 100 end
        if attr == "Type" then return "Barracks" end
        return nil
    end,
    SetAttribute = function(self, attr, val) end,
    FindFirstChild = function(self, name) return nil end,
}

local builder = {
    GetAttribute = function(self, attr)
        if attr == "Range" then return 30 end
        if attr == "BuildPower" then return 5 end
        if attr == "Owner" then return "Player1" end
        return nil
    end
}

-- etc...
