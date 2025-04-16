-- Rewrite: 2
while not game:IsLoaded() do wait() end

local PFS = game:GetService("PathfindingService")
local VIM = game:GetService("VirtualInputManager")

local testPath = PFS:CreatePath({
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = false,
    AgentJumpHeight = 10,
    AgentCanClimb = true,
    AgentMaxSlope = 45
})

local isInGame, currentCharacter, humanoid, waypoints, counter, gencompleted, s, f, stopbreakingplease, stamina, busy, reached, start_time, fail_attempt
local Spectators = {}
fail_attempt = 0

-- In-game check
task.spawn(function()
    while true do
        Spectators = {}
        for _, child in game.Workspace.Players.Spectating:GetChildren() do
            table.insert(Spectators, child.Name)
        end
        isInGame = not table.find(Spectators, game.Players.LocalPlayer.Name)
        wait(1)
    end
end)

-- RunHelper - v1.1 - Rewrite by chatgpt - More readable :sob:
task.spawn(function()
while true do
    if isInGame then
    local success, err = pcall(function()
        currentCharacter.Humanoid:SetAttribute("BaseSpeed", 14)
        local barText = game.Players.LocalPlayer.PlayerGui.TemporaryUI.PlayerInfo.Bars.Stamina.Amount.Text
        stamina = tonumber(string.split(barText, "/")[1])
        print("✨ Stamina read:", stamina)

        if stamina >= 10 then
            print("✔ Stamina sufficient (", stamina, ") — attempting to move...")
        else
            print("🚫 Conditions not met for movement. Stamina:", stamina, " | Busy:", tostring(busy))
            wait(0.1)
            return
        end
        if busy then
            print("busy")
            return
        end

        print("➡ Sending LeftShift key event to move.")
        VIM:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
    end)

    if not success then
        warn("🛑 Error occurred during loop:", err)
    end
    end
    wait(5)
end
end)

-- Main loop
while true do
    if isInGame then
        for _, surv in ipairs(game.Workspace.Players.Survivors:GetChildren()) do
            if surv:GetAttribute("Username") == game.Players.LocalPlayer.Name then
                currentCharacter = surv
            end
        end

        -- Death handler
        task.spawn(function()
            while true do
                if currentCharacter and currentCharacter:FindFirstChild("Humanoid") and currentCharacter.Humanoid.Health <= 0 then
                    isInGame = false
                    busy = false
                    break
                end
                wait(0.5)
            end
        end)

        for _, completedgen in ipairs(game.ReplicatedStorage.ObjectiveStorage:GetChildren()) do
            if not isInGame then break end

            local required = completedgen:GetAttribute("RequiredProgress")
            if completedgen.Value == required then
                -- Escape logic
                while #game.Workspace.Players.Killers:GetChildren() >= 1 do
                    s, f = pcall(function()
                        for _, killer in ipairs(game.Workspace.Players.Killers:GetChildren()) do
                            local dist = (killer.HumanoidRootPart.Position - currentCharacter.HumanoidRootPart.Position).Magnitude
                            if dist <= 100 then
                                testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, currentCharacter.HumanoidRootPart.Position + (-killer.HumanoidRootPart.CFrame.LookVector).Unit * 50)
                                waypoints = testPath:GetWaypoints()
                                humanoid = currentCharacter:WaitForChild("Humanoid")

                                for _, wp in ipairs(waypoints) do
                                    if stopbreakingplease then break end
                                    reached = false
                                    local conn
                                    conn = humanoid.MoveToFinished:Connect(function(s)
                                        reached = s
                                        conn:Disconnect()
                                    end)
                                    humanoid:MoveTo(wp.Position)
                                    local t = os.clock()
                                    repeat wait(0.01) until reached or (os.clock() - t >= 10)
                                end
                            end
                        end
                    end)
                    wait(0.1)
                end
            else
                -- Generator pathing and interaction
                local SurvivorGens = {}

                for _, gen in ipairs(game.Workspace.Map.Ingame:WaitForChild("Map"):GetChildren()) do
                    if gen.Name == "Generator" and gen.Progress.Value ~= 100 then
                        local goalPos = gen:WaitForChild("Positions").Right.Position
                        local distance = (currentCharacter.HumanoidRootPart.Position - goalPos).Magnitude
                        table.insert(SurvivorGens, {Generator = gen, Distance = distance})
                    end
                end

                table.sort(SurvivorGens, function(a, b) return a.Distance < b.Distance end)

                for _, genInfo in ipairs(SurvivorGens) do
                    local gen = genInfo.Generator
                    local goalPos = gen:WaitForChild("Positions").Right.Position

                    testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, goalPos)

                    if testPath.Status ~= Enum.PathStatus.Success then
                        warn("Path to generator failed:", testPath.Status)
                        continue
                    end

                    waypoints = testPath:GetWaypoints()
                    humanoid = currentCharacter:WaitForChild("Humanoid")

                    for idx, wp in ipairs(waypoints) do
                        if stopbreakingplease then
                            humanoid:MoveTo(currentCharacter.HumanoidRootPart.Position)
                            break
                        end

                        reached = false
                        local conn
                        conn = humanoid.MoveToFinished:Connect(function(s)
                            reached = s
                            conn:Disconnect()
                        end)

                        humanoid:MoveTo(wp.Position)
                        local start_time = os.clock()
                        repeat wait(0.05) until reached or (os.clock() - start_time >= 10)

                        if not reached then
                            warn(("Waypoint %d timed out. Trying next closest generator."):format(idx))
                            break
                        end
                    end

                    if not isInGame then break end

                    local distToGen = (currentCharacter.HumanoidRootPart.Position - goalPos).Magnitude
                    if distToGen > 10 then
                        warn("Too far from generator to interact. Skipping.")
                        continue
                    end

                    local thing = gen.Main:FindFirstChild("Prompt")
                    if not thing then continue end

                    thing.HoldDuration = 0
                    thing.RequiresLineOfSight = false
                    thing.MaxActivationDistance = 99999

                    busy = true
                    counter = 0
                    local startGenTime = tick()

                    while gen.Progress.Value ~= 100 do
                        thing:InputHoldBegin()
                        thing:InputHoldEnd()
                        gen.Remotes.RE:FireServer()
                        wait(2.5)
                        counter += 1
                        if counter >= 10 or not isInGame or (tick() - startGenTime > 30) then
                            warn("Generator timeout or fail. Exiting interaction loop.")
                            break
                        end
                    end

                    busy = false
                    if not isInGame then break end
                end
            end
        end
    end
    wait(0.1)
end
