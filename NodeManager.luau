-- NodeManager (ModuleScript, ServerStorage)
local HttpService = game:GetService("HttpService")

local NodeManager = {}
NodeManager.__index = NodeManager

function NodeManager.new(mapModel)
	local self = setmetatable({}, NodeManager)
	self.MapModel = mapModel
	self.FarmNodes = {}  -- node -> occupied (boolean or userId)
	return self
end

-- Recursively find all nodes of a given name
function NodeManager:findAllNodes(nodeName)
	local nodes = {}
	local function search(container)
		for _, child in pairs(container:GetChildren()) do
			if child:IsA("BasePart") and child.Name == nodeName then
				-- Assign a unique ID if not present
				if not child:GetAttribute("NodeID") then
					child:SetAttribute("NodeID", HttpService:GenerateGUID(false))
				end
				table.insert(nodes, child)
			elseif child:IsA("Folder") or child:IsA("Model") then
				search(child)
			end
		end
	end
	search(self.MapModel)
	return nodes
end

-- Initialize nodes at round start
function NodeManager:scanNodes()
	self.FarmNodes = {}
	local allNodes = self:findAllNodes("Node_Farm")
	print("NodeManager: found", #allNodes, "farm nodes")
	for _, node in ipairs(allNodes) do
		node.CanCollide = false  -- чтобы не мешали рейкасту
		self.FarmNodes[node] = false
		node:SetAttribute("Occupied", nil)
	end
end

-- Try to occupy a node for a player
-- Returns the node if successful, nil otherwise
function NodeManager:occupyNode(nodeName, playerName, position)
	local bestNode = nil
	local bestDist = 4
	for node, occupied in pairs(self.FarmNodes) do
		if node and node.Parent and not occupied and node.Name == nodeName then
			local dist = (node.Position - position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestNode = node
			end
		end
	end
	if bestNode then
		self.FarmNodes[bestNode] = playerName
		bestNode:SetAttribute("Occupied", true)
		bestNode:SetAttribute("OccupiedBy", playerName)
		return bestNode
	end
	return nil
end

-- Free a node by its ID (preferred) or name (fallback)
function NodeManager:freeNode(nodeID, nodeName, nodePos)
	if nodeID then
		for node, occupied in pairs(self.FarmNodes) do
			if node and node.Parent and node:GetAttribute("NodeID") == nodeID then
				self.FarmNodes[node] = false
				node:SetAttribute("Occupied", nil)
				node:SetAttribute("OccupiedBy", nil)
				print("NodeManager: freed node by ID", nodeID)
				return true
			end
		end
	end
	-- Fallback to name + position
	if nodeName and nodePos then
		for node, occupied in pairs(self.FarmNodes) do
			if node and node.Parent and node.Name == nodeName and (node.Position - nodePos).Magnitude < 0.1 then
				self.FarmNodes[node] = false
				node:SetAttribute("Occupied", nil)
				node:SetAttribute("OccupiedBy", nil)
				print("NodeManager: freed node by name+pos", nodeName)
				return true
			end
		end
	end
	print("NodeManager: failed to free node", nodeID or nodeName)
	return false
end

function NodeManager:isNodeOccupied(node)
	return self.FarmNodes[node] ~= false
end

return NodeManager