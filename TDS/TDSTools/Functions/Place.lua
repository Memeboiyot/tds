local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteFunction = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteFunction") else SpoofEvent
local RemoteEvent = if not GameSpoof then ReplicatedStorage:WaitForChild("RemoteEvent") else SpoofEvent
local TowerProps = {}

local PreviewHolder = ReplicatedStorage.PreviewHolder
local AssetsHologram = PreviewHolder.AssetsHologram
local AssetsError = PreviewHolder.AssetsError
local PreviewFolder = Workspace.PreviewFolder
local PreviewErrorFolder = Workspace.PreviewErrorFolder

-- Configuration
local MAX_PLACEMENT_ATTEMPTS = 10
local PLACEMENT_RETRY_DELAY = 0.5
local MAX_PLACEMENT_TIME = 45

function CheckPlace()
    return if not GameSpoof then (game.PlaceId == 5591597781) else if GameSpoof == "Ingame" then true else false
end

function IsValidPosition(position)
    -- Check if position is within reasonable bounds
    if math.abs(position.X) > 1000 or math.abs(position.Z) > 1000 then
        return false, "Position out of bounds"
    end
    
    -- Check if position is not underground
    if position.Y < -10 then
        return false, "Position too low"
    end
    
    -- Check for NaN values
    if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
        return false, "Invalid position values"
    end
    
    return true, "Valid position"
end

function StackPosition(Position, SkipCheck)
    local Position = if typeof(Position) == "Vector3" then Position else Vector3.new(0,0,0)
    local PositionY = Position.Y
    
    -- Add validation for minimum height
    if PositionY < 0 then
        Position = Vector3.new(Position.X, 0, Position.Z)
    end
    
    for i,v in ipairs(TowersContained) do
        if not v.Position or not v.Placed then
            continue
        end
        
        -- Check if positions overlap in XZ plane with better tolerance
        local horizontalDistance = (v.Position * Vector3.new(1,0,1) - Position * Vector3.new(1,0,1)).magnitude
        if horizontalDistance < 3 then -- Increased tolerance for better stacking
            local newY = v.Position.Y + 5
            -- Ensure we don't stack too high
            if newY < 50 then
                Position = Vector3.new(Position.X, newY, Position.Z)
            end
        end
    end
    
    return Vector3.new(0, Position.Y - PositionY, 0)
end

function ValidateTowerPlacement(towerInstance)
    if not towerInstance or not towerInstance.Parent then
        return false, "Tower instance is nil or has no parent"
    end
    
    -- Check if tower has essential components
    if not towerInstance:FindFirstChild("HumanoidRootPart") then
        return false, "Tower missing HumanoidRootPart"
    end
    
    -- Check if tower is still valid after a brief moment
    task.wait(0.1)
    if not towerInstance or not towerInstance.Parent then
        return false, "Tower became invalid after placement"
    end
    
    return true, "Tower placement validated"
end

function CanPlaceTower()
    local state = ReplicatedStorage:FindFirstChild("State")
    if not state then return true end
    
    local timer = state:FindFirstChild("Timer")
    if timer and timer:FindFirstChild("Time") then
        local currentTime = timer.Time.Value
        -- Add game-specific logic here if needed
    end
    
    return true
end

function DebugTower(Object, Color)
    repeat task.wait() until tonumber(Object.Name) and Object:FindFirstChild("HumanoidRootPart")
    local Color = Color or Color3.new(1, 0, 0)
    local HumanoidRootPart = Object:FindFirstChild("HumanoidRootPart")
    
    -- Remove existing GUI
    if HumanoidRootPart:FindFirstChild("BillboardGui") then
        HumanoidRootPart:FindFirstChild("BillboardGui"):Destroy()
    end
    
    local GuiInstance = Instance.new("BillboardGui")
    GuiInstance.Parent = HumanoidRootPart
    GuiInstance.Adornee = HumanoidRootPart
    GuiInstance.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
    GuiInstance.Size = UDim2.new(0, 250, 0, 50)
    GuiInstance.AlwaysOnTop = true
    
    local Text = Instance.new("TextLabel")
    Text.Parent = GuiInstance
    Text.BackgroundTransparency = 1
    Text.Text = Object.Name
    Text.Font = "Legacy"
    Text.Size = UDim2.new(1, 0, 0, 70)
    Text.TextSize = 22
    Text.TextScaled = false
    Text.TextColor3 = Color
    Text.TextStrokeColor3 = Color3.new(0, 0, 0)
    Text.TextStrokeTransparency = 0.5
    
    return GuiInstance
end

function CleanupFailedTower(towerTable, tempNum)
    if towerTable.TowerModel then
        towerTable.TowerModel:Destroy()
    end
    if towerTable.ErrorModel then
        towerTable.ErrorModel:Destroy()
    end
    if TowersContained[tempNum] then
        TowersContained[tempNum] = nil
    end
end

StratXLibrary.AllowPlace = false

-- Initialize tower streaming
if CheckPlace() then
    task.spawn(function()
        if not ReplicatedStorage.Assets:FindFirstChild("Troops") then
            repeat
                task.wait()
            until ReplicatedStorage.Assets:FindFirstChild("Troops")
        end
        
        local TroopsFolder = ReplicatedStorage.Assets:FindFirstChild("Troops")
        for i,v in next, GetTowersInfo() do
            if v.Equipped and not (TroopsFolder:FindFirstChild(i) and TroopsFolder:FindFirstChild(i).Skins:FindFirstChild(v.Skin)) then
                repeat 
                    task.wait(1)
                    if not (TroopsFolder:FindFirstChild(i) and TroopsFolder:FindFirstChild(i).Skins:FindFirstChild(v.Skin)) then
                        RemoteEvent:FireServer("Streaming", "SelectTower", i, v.Skin)
                    end
                until TroopsFolder:FindFirstChild(i) and TroopsFolder:FindFirstChild(i).Skins:FindFirstChild(v.Skin)
            end
        end
        StratXLibrary.AllowPlace = true
    end)
end

function PreviewInitial()
    if not ReplicatedStorage.Assets:FindFirstChild("Troops") then
        repeat
            task.wait()
        until ReplicatedStorage.Assets:FindFirstChild("Troops")
    end
    
    for i,v in next, GetTowersInfo() do
        if v.Equipped then
            TowerProps[i] = v.Skin
            local Tower = ReplicatedStorage.Assets.Troops[i].Skins[v.Skin]:Clone()
            Tower.Parent = AssetsHologram
            Tower.Name = i
            
            for i2,v2 in next, Tower:GetDescendants() do
                if v2:IsA("BasePart") then
                    v2.Material = Enum.Material.ForceField
                    if v2.CanCollide then
                        v2.CanCollide = false
                    end
                end
            end
            
            local ErrorTower = Tower:Clone()
            for i2,v2 in next, ErrorTower:GetDescendants() do
                if v2:IsA("BasePart") then
                    v2.Color = Color3.new(1, 0, 0)
                end
            end
            ErrorTower.Parent = AssetsError
        end
    end
end

function AddFakeTower(Name, Type)
    if not TowerProps[Name] then
        PreviewInitial()
    end
    
    local Type = Type or "Normal"
    local Tower = if Type == "Normal" then AssetsHologram[Name] else AssetsError[Name]
    
    if Tower then
        Tower = Tower:Clone()
        Tower.Parent = PreviewHolder
        
        if Tower:FindFirstChild("AnimationController") then
            task.spawn(function()
                local Success
                repeat 
                    task.wait(.7)
                    Success = pcall(function()
                        Tower:FindFirstChild("AnimationController"):LoadAnimation(Tower.Animations.Idle["0"]):Play()
                    end)
                until Success
            end)
        end
        
        return Tower
    end
end

return function(self, p1)
    local tableinfo = p1
    local Tower = tableinfo["TowerName"]
    local Position = tableinfo["Position"] or Vector3.new(0,0,0)
    local Rotation = tableinfo["Rotation"] or CFrame.new(0,0,0)
    local Wave,Min,Sec,InWave = tableinfo["Wave"] or 0, tableinfo["Minute"] or 0, tableinfo["Second"] or 0, tableinfo["InBetween"] or false
    
    if not CheckPlace() then
        return
    end
    
    SetActionInfo("Place","Total")
    TowersContained.Index += 1
    local TempNum = TowersContained.Index
    
    -- Calculate stacked position
    local stackedOffset = StackPosition(Position)
    local finalPosition = Position + stackedOffset
    
    TowersContained[TempNum] = {
        ["TowerName"] = Tower,
        ["Placed"] = false,
        ["TypeIndex"] = "Nil",
        ["Position"] = finalPosition,
        ["Rotation"] = Rotation,
        ["OldPosition"] = Position,
        ["PassedTimer"] = false,
    }

    local CurrentCount = StratXLibrary.CurrentCount
    local TowerTable = TowersContained[TempNum]
    
    repeat task.wait() until StratXLibrary.AllowPlace

    -- Validate position before creating preview
    local isValid, reason = IsValidPosition(finalPosition)
    if not isValid then
        ConsoleError("Cannot place tower: " .. reason)
        TowersContained[TempNum] = nil
        return
    end

    -- Create tower preview
    local TowerModel = AddFakeTower(TowerTable.TowerName)
    if not TowerModel then
        ConsoleError("Failed to create tower preview for: " .. Tower)
        TowersContained[TempNum] = nil
        return
    end
    
    TowerModel:PivotTo(CFrame.new(TowerTable.Position + Vector3.new(0,math.abs(TowerModel.PrimaryPart.HeightOffset.CFrame.Y),0)) * TowerTable.Rotation)
    TowerModel.Name = TempNum
    DebugTower(TowerModel,Color3.fromRGB(255, 130, 0))
    TowerTable.TowerModel = TowerModel
    
    if UtilitiesTab.flags.TowersPreview then
        TowerModel.Parent = PreviewFolder
    end

    -- Placement coroutine
    task.spawn(function()
        if not TimeWaveWait(Wave, Min, Sec, InWave, tableinfo["Debug"]) then
            CleanupFailedTower(TowerTable, TempNum)
            return
        end
        
        TowerTable.PassedTimer = true
        
        if not CanPlaceTower() then
            ConsoleError("Cannot place tower at this time - game state invalid")
            CleanupFailedTower(TowerTable, TempNum)
            return
        end

        local PlaceCheck, ErrorModel
        local placementSuccess = false
        
        -- Timeout for placement
        local placementTimeout = task.delay(MAX_PLACEMENT_TIME, function()
            if not placementSuccess and CurrentCount == StratXLibrary.RestartCount then
                ConsoleError("Tower Index: "..TempNum..", Type: \""..Tower.."\" Hasn't Been Placed In "..MAX_PLACEMENT_TIME.." Seconds.")
                ConsoleError("PlaceCheck Value: " .. tostring(PlaceCheck))
                CleanupFailedTower(TowerTable, TempNum)
            end
        end)

        -- Placement attempt loop
        local attempts = 0
        while attempts < MAX_PLACEMENT_ATTEMPTS do
            if CurrentCount ~= StratXLibrary.RestartCount then
                task.cancel(placementTimeout)
                CleanupFailedTower(TowerTable, TempNum)
                return
            end

            -- Attempt placement
            local success, result = pcall(function()
                return RemoteFunction:InvokeServer("Troops","Place",Tower,{
                    ["Position"] = TowerTable.Position,
                    ["Rotation"] = TowerTable.Rotation
                })
            end)

            if not success then
                ConsoleError("Error invoking placement: " .. tostring(result))
                attempts += 1
                task.wait(PLACEMENT_RETRY_DELAY)
                continue
            end

            PlaceCheck = result

            -- Handle placement result
            if typeof(PlaceCheck) == "Instance" then
                -- Successfully placed
                placementSuccess = true
                break
            elseif type(PlaceCheck) == "string" then
                if PlaceCheck == "You cannot place here!" and not ErrorModel then
                    -- Show error preview
                    ErrorModel = AddFakeTower(TowerTable.TowerName,"Error")
                    ErrorModel:PivotTo(CFrame.new(TowerTable.Position + Vector3.new(0,math.abs(TowerModel.PrimaryPart.HeightOffset.CFrame.Y),0)) * TowerTable.Rotation)
                    ErrorModel.Name = TempNum
                    DebugTower(ErrorModel,Color3.new(1, 0, 0))
                    TowerTable.ErrorModel = ErrorModel 
                    TowerModel.Parent = PreviewHolder
                    
                    if UtilitiesTab.flags.TowersPreview then
                        ErrorModel.Parent = PreviewErrorFolder
                    end
                end
                
                ConsoleWarn("Placement failed: " .. tostring(PlaceCheck))
            end

            attempts += 1
            task.wait(PLACEMENT_RETRY_DELAY)
        end

        -- Handle placement result
        if not placementSuccess then
            task.cancel(placementTimeout)
            ConsoleError("Failed to place tower after " .. MAX_PLACEMENT_ATTEMPTS .. " attempts: " .. Tower)
            CleanupFailedTower(TowerTable, TempNum)
            return
        end

        task.cancel(placementTimeout)

        -- Validate the placed tower
        local validationSuccess, validationMessage = ValidateTowerPlacement(PlaceCheck)
        if not validationSuccess then
            ConsoleError("Tower placement validation failed: " .. validationMessage)
            CleanupFailedTower(TowerTable, TempNum)
            return
        end

        -- Finalize successful placement
        PlaceCheck.Name = TempNum
        local TowerInfo = StratXLibrary.TowerInfo[Tower]
        TowerInfo[2] += 1
        PlaceCheck:SetAttribute("TypeIndex", Tower.." "..tostring(TowerInfo[2]))
        TowerInfo[1].Text = Tower.." : "..tostring(TowerInfo[2])
        
        TowerTable.Instance = PlaceCheck
        TowerTable.TypeIndex = PlaceCheck:GetAttribute("TypeIndex")
        TowerTable.Placed = true
        TowerTable.Target = "First"
        TowerTable.Upgrade = 0
        
        -- Clean up previews
        TowerModel.Parent = PreviewHolder
        TowerTable.DebugTag = DebugTower(TowerTable.Instance,Color3.new(0.35, 0.7, 0.3))
        
        if not UtilitiesTab.flags.TowersPreview then
            TowerTable.DebugTag.Enabled = false 
        end
        
        if ErrorModel then
            ErrorModel.Parent = PreviewHolder
        end
        
        if getgenv().Debug then
            task.spawn(DebugTower,TowerTable.Instance)
        end
        
        local TowerType = GetTypeIndex(tableinfo["TypeIndex"],TempNum)
        SetActionInfo("Place")
        
        local StackingCheck = (TowerTable.Position - TowerTable.OldPosition).magnitude > 1
        ConsoleInfo(`Placed {Tower} Index: {PlaceCheck.Name}, Type: \"{TowerType}\", (Wave {Wave}, Min: {Min}, Sec: {Sec}, InBetween: {InWave}) {if StackingCheck then ", Stacked Position" else ", Original Position"}`)
    end)
end
