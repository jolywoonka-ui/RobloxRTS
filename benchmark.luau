local function benchmark()
    -- Create a mock model with 100 parts
    local function createMockUnit(name)
        local c = {Name = name, parts = {}}
        for i=1, 100 do
            table.insert(c.parts, {
                className = "BasePart",
                IsA = function(self, className) return self.className == className end,
                Transparency = 0,
                Material = "Plastic",
                Color = "White",
                CanCollide = true,
                Anchored = false,
                CanQuery = true
            })
        end
        function c:GetDescendants()
            return self.parts
        end
        function c:FindFirstChildOfClass()
            return nil
        end
        function c:Clone()
            return createMockUnit(self.Name)
        end
        function c:Destroy()
        end
        return c
    end

    local selected = {}
    for i=1, 1000 do
        table.insert(selected, createMockUnit("TestUnit"))
    end

    local start = os.clock()
    for _, unit in ipairs(selected) do
        local ghost = unit:Clone()
        ghost.Name = "Ghost_" .. unit.Name
        for _, part in ipairs(ghost:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 0.7
                part.Material = "Neon"
                part.Color = "Blue"
                part.CanCollide = false
                part.Anchored = true
                part.CanQuery = false
            elseif part:IsA("Decal") or part:IsA("Texture") then
                part.Transparency = 0.7
            end
        end
        local hum = ghost:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
    end
    print("Baseline:", os.clock() - start)

    local start2 = os.clock()
    local ghostTemplates = {}
    for _, unit in ipairs(selected) do
        local template = ghostTemplates[unit.Name]
        if not template then
            template = unit:Clone()
            template.Name = "Ghost_" .. unit.Name
            for _, part in ipairs(template:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = 0.7
                    part.Material = "Neon"
                    part.Color = "Blue"
                    part.CanCollide = false
                    part.Anchored = true
                    part.CanQuery = false
                elseif part:IsA("Decal") or part:IsA("Texture") then
                    part.Transparency = 0.7
                end
            end
            local hum = template:FindFirstChildOfClass("Humanoid")
            if hum then hum:Destroy() end
            ghostTemplates[unit.Name] = template
        end

        local ghost = template:Clone()
        local hum = ghost:FindFirstChildOfClass("Humanoid")
        if hum then hum:Destroy() end
    end
    for _, t in pairs(ghostTemplates) do
        t:Destroy()
    end
    print("Optimized:", os.clock() - start2)
end

benchmark()
