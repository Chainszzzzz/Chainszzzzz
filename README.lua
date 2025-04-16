-- Rewrite: 2
while not game:IsLoaded() do
    wait()
end

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
    print("     <- All")
    for i, child in game.Workspace.Players.Spectating:GetChildren() do
        print("[In-game Check] - A loop just being ran")
        print("      -> ".. child.Name)
        table.insert(Spectators, child.Name)
    end
    if table.find(Spectators, game.Players.LocalPlayer.Name) then
        isInGame = false
        print("    - Not in game")
        wait(1)
    else
        print("    + Is in game")
        isInGame = true
        wait(1)
    end
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

        if stamina >= 70 then
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

-- Hopping Handler
task.spawn(function()
wait(20*60)
local ts = game:GetService("TeleportService")
ts:Teleport(game.placeId)
end)

-- Main loop
while true do
if isInGame then
    for _, surv in ipairs(game.Workspace.Players.Survivors:GetChildren()) do
        if surv:GetAttribute("Username") == game.Players.LocalPlayer.Name then
            currentCharacter = surv
            print("    -> currentCharacter set to", surv.Name)
        end
    end

    -- Death handler
    task.spawn(function()
        while true do
            if currentCharacter and currentCharacter:FindFirstChild("Humanoid") then
                if currentCharacter.Humanoid.Health <= 0 then
                    print("💀 You died.")
                    isInGame = false
                    busy = false
                    break
                end
            end
        wait(0.5)
        end
    end)

    for _, completedgen in ipairs(game.ReplicatedStorage.ObjectiveStorage:GetChildren()) do
        if not isInGame then
            warn("???")
            break
        end
        local required = completedgen:GetAttribute("RequiredProgress")
        if completedgen.Value == required then
            print("✔ Completed all gens, proceed to RUN!")

            while #game.Workspace.Players:WaitForChild("Killers"):GetChildren() >= 1 do
                if #game.Workspace.Players.Killers:GetChildren() == 0 then
                        isInGame = false
                        break
                    end
                s, f = pcall(function()
                    for _, killer in ipairs(game.Workspace.Players.Killers:GetChildren()) do
                        local dist = (killer.HumanoidRootPart.Position - currentCharacter.HumanoidRootPart.Position).Magnitude
                        if dist <= 100 then
                            print("🦸‍♂️ Killer nearby! Running...")

                            testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, currentCharacter.HumanoidRootPart.Position + (-killer.HumanoidRootPart.CFrame.LookVector).Unit * 50)
                            waypoints = testPath:GetWaypoints()
                            humanoid = currentCharacter:WaitForChild("Humanoid")

                            print("📍 Got", #waypoints, "waypoints. Moving...")

                            local conn
                            for idx, wp in ipairs(waypoints) do
                                if stopbreakingplease then
                                    humanoid:MoveTo(currentCharacter.HumanoidRootPart.Position)
                                    break
                                end

                                reached = false
                                start_time = os.clock()
                                conn = humanoid.MoveToFinished:Connect(function(s)
                                    reached = s
                                    print("    Reached waypoint", idx)
                                    conn:Disconnect()
                                end)

                                humanoid:MoveTo(wp.Position)
                                repeat wait(0.01) until reached or (os.clock() - start_time) >= 10
                                if not reached then
                                    testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, goalPos)
                                    waypoints = testPath:GetWaypoints()
                                    warn(("📍 Waypoint %d timed out after 10 secs — gen another path"):format(idx))
                                    fail_attempt = fail_attempt + 1
                                    warn(fail_attempt)
                                    if counter >= 5 then
                                        warn("Fail, break")
                                        fail_attempt = 0
                                        break
                                    end
                                end
                            end
                        end
                    end
                end)
                wait(0.1)
            end
            print(s)
            print(f)

        else
            -- Try to repair a generator
            for _, gen in ipairs(game.Workspace.Map.Ingame:WaitForChild("Map"):GetChildren()) do
                if gen.Name == "Generator" and gen.Progress.Value ~= 100 then
                    print("🔧 Generator found:", gen.Name, "progress =", gen.Progress.Value)
                    local goalPos = gen:WaitForChild("Positions").Right.Position
                    print("🔧 Computing path to", goalPos)
                    testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, goalPos)
                    print("      Path status =", testPath.Status)

                    if testPath.Status == Enum.PathStatus.Success then
                        waypoints = testPath:GetWaypoints()
                        humanoid = currentCharacter:WaitForChild("Humanoid")

                        print("🛣 Moving along", #waypoints, "waypoints...")
                        for idx, wp in ipairs(waypoints) do
                            if stopbreakingplease then
                                humanoid:MoveTo(currentCharacter.HumanoidRootPart.Position)
                                break
                            end
                            humanoid:MoveTo(wp.Position)
                            reached = false
                            start_time = os.clock()
                            conn = humanoid.MoveToFinished:Connect(function(s)
                                reached = s
                                print("    Reached waypoint", idx)
                                conn:Disconnect()
                            end)
                            humanoid:MoveTo(wp.Position)
                            repeat wait(0.01) until reached or (os.clock() - start_time) >= 10
                            if not reached then
                                warn(("📍 Waypoint %d timed out after 10 secs — gen another path"):format(idx))
                                fail_attempt = fail_attempt + 1
                                warn(fail_attempt)
                                if fail_attempt >= 5 then
                                    warn("fail")
                                    fail_attempt = 0
                                    break
                                end
                                testPath:ComputeAsync(currentCharacter.HumanoidRootPart.Position, goalPos)
                                waypoints = testPath:GetWaypoints()
                            end
                        end

                        print("✔ Interacting with generator prompt")
                        if not isInGame then
                            warn("???")
                            break
                        end
                        local thing = gen.Main.Prompt
                        if thing then
                            print("Yes!")
                        else
                            print("This gen somehow got no prompt, switched")
                            break
                        end
                        thing.HoldDuration = 0
                        thing.RequiresLineOfSight = false
                        thing.MaxActivationDistance = 99999

                        game.Workspace.Camera.CFrame = CFrame.new(201.610779, 64.460968, 1307.98096, 0.99840349, -0.0556023642, 0.00994364079, -1.31681965e-09, 0.176041901, 0.984382629, -0.0564845055, -0.982811034, 0.17576085)
                        wait(0.1)
                        thing:InputHoldBegin()
                        thing:InputHoldEnd()
                        busy = true
                        counter = 0
                        while gen.Progress.Value ~= 100 do
                            thing:InputHoldBegin()
                            thing:InputHoldEnd()
                            gen.Remotes.RE:FireServer()
                            wait(2.5)
                            if counter >= 10 or not isInGame then
                                warn("??")
                                break
                            end
                        end
                        print("✔ Generator fixed!")
                        busy = false
                        if not isInGame then
                            break
                        end
                    else
                        warn("🛑 Path failed with status", testPath.Status)
                    end
                end
            end
        end
    end
end
wait(0.1)
end
