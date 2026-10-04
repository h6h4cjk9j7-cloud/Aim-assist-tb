-- Smooth Aim Lock + Auto Fire / Fixed Crosshair FOV Circle
-- LocalScript → StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local CIRCLE_SIZE = 52.5
local MAX_DISTANCE = 150
local SMOOTHNESS = 8
local FIRE_RATE = 0.08

local CIRCLE_Y_OFFSET = 8

--------------------------------------------------
-- GUI
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "AimLockGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local circle = Instance.new("Frame")
circle.Name = "FOVCircle"
circle.Size = UDim2.fromOffset(CIRCLE_SIZE, CIRCLE_SIZE)
circle.AnchorPoint = Vector2.new(0.5, 0.5)

circle.Position = UDim2.fromOffset(
	camera.ViewportSize.X / 2,
	camera.ViewportSize.Y / 2 + CIRCLE_Y_OFFSET
)

circle.BackgroundTransparency = 1
circle.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Parent = circle

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = circle

--------------------------------------------------
-- KEEP CIRCLE IN THE SAME POSITION
--------------------------------------------------

camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
	circle.Position = UDim2.fromOffset(
		camera.ViewportSize.X / 2,
		camera.ViewportSize.Y / 2 + CIRCLE_Y_OFFSET
	)
end)

--------------------------------------------------
-- VALID TOOL CHECK
--------------------------------------------------

local function getValidTool()

	local character = player.Character

	if not character then
		return nil
	end

	local tool = character:FindFirstChildOfClass("Tool")

	if not tool then
		return nil
	end

	if tool:GetAttribute("AimLockTool") == false then
		return nil
	end

	if tool:GetAttribute("AimLockTool") == true then
		return tool
	end

	local toolName = string.lower(tool.Name)

	local excludedNames = {
		"knife",
		"sword",
		"blade",
		"dagger",
		"katana",
		"melee",
		"weapon",
		"bow",
		"crossbow"
	}

	for _, name in ipairs(excludedNames) do
		if string.find(toolName, name, 1, true) then
			return nil
		end
	end

	return tool
end

--------------------------------------------------
-- VISIBILITY CHECK
--------------------------------------------------

local function isVisible(character, part)

	local origin = camera.CFrame.Position
	local direction = part.Position - origin

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {
		player.Character
	}

	local result = workspace:Raycast(
		origin,
		direction,
		rayParams
	)

	if not result then
		return true
	end

	return result.Instance:IsDescendantOf(character)
end

--------------------------------------------------
-- FIND TARGET
--------------------------------------------------

local function getTarget()

	if not getValidTool() then
		return nil
	end

	local closestTarget = nil
	local closestDistance = math.huge

	local screenCenter = Vector2.new(
		camera.ViewportSize.X / 2,
		camera.ViewportSize.Y / 2
	)

	for _, otherPlayer in ipairs(Players:GetPlayers()) do

		if otherPlayer ~= player and otherPlayer.Character then

			local character = otherPlayer.Character
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local targetPart = character:FindFirstChild("HumanoidRootPart")
				or character:FindFirstChild("UpperTorso")
				or character:FindFirstChild("Torso")

			if humanoid and humanoid.Health > 0 and targetPart then

				local worldDistance =
					(targetPart.Position - camera.CFrame.Position).Magnitude

				if worldDistance <= MAX_DISTANCE then

					local screenPosition, onScreen =
						camera:WorldToViewportPoint(targetPart.Position)

					if onScreen and screenPosition.Z > 0 then

						local partPosition = Vector2.new(
							screenPosition.X,
							screenPosition.Y
						)

						local distanceFromCenter =
							(partPosition - screenCenter).Magnitude

						if distanceFromCenter <= CIRCLE_SIZE / 2 then

							if isVisible(character, targetPart) then

								if distanceFromCenter < closestDistance then
									closestDistance = distanceFromCenter
									closestTarget = targetPart
								end

							end
						end
					end
				end
			end
		end
	end

	return closestTarget
end

--------------------------------------------------
-- AIM + AUTO FIRE
--------------------------------------------------

local nextShot = 0

RunService.RenderStepped:Connect(function(deltaTime)

	local tool = getValidTool()

	if not tool then
		return
	end

	local target = getTarget()

	if target then

		--------------------------------------------------
		-- SMOOTHER AIM
		--------------------------------------------------

		local cameraPosition = camera.CFrame.Position

		local targetCFrame = CFrame.lookAt(
			cameraPosition,
			target.Position
		)

		local alpha = 1 - math.exp(
			-SMOOTHNESS * deltaTime
		)

		camera.CFrame = camera.CFrame:Lerp(
			targetCFrame,
			alpha
		)

		--------------------------------------------------
		-- RAPID FIRE
		--------------------------------------------------

		if os.clock() >= nextShot then

			tool:Activate()

			nextShot = os.clock() + FIRE_RATE

		end

	else

		nextShot = 0

	end
end)
