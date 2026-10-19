
-- Driver Block + Consistent Continuous Wobble
-- LocalScript in StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Movement settings
local MOVE_SPEED = 16
local TURN_RESPONSIVENESS = 50
local MAX_TORQUE = 1000000

-- Driver block
local BLOCK_SIZE = Vector3.new(2, 0.4, 2)

-- Consistent wobble settings
local MAX_SWING_ANGLE = math.rad(45)
local DRIVE_FREQUENCY = 12
local WOBBLE_RESPONSE = 12
local WOBBLE_DAMPING = 5

local character
local humanoid
local rootPart
local driverBlock
local footAttachment
local blockAttachment
local rootAttachment
local ballSocket
local alignOrientation
local updateConnection
local savedAutoRotate

local function cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if ballSocket then
		ballSocket:Destroy()
		ballSocket = nil
	end

	if alignOrientation then
		alignOrientation:Destroy()
		alignOrientation = nil
	end

	if footAttachment then
		footAttachment:Destroy()
		footAttachment = nil
	end

	if blockAttachment then
		blockAttachment:Destroy()
		blockAttachment = nil
	end

	if rootAttachment then
		rootAttachment:Destroy()
		rootAttachment = nil
	end

	if driverBlock then
		driverBlock:Destroy()
		driverBlock = nil
	end

	if humanoid and humanoid.Parent and savedAutoRotate ~= nil then
		humanoid.AutoRotate = savedAutoRotate
	end

	character = nil
	humanoid = nil
	rootPart = nil
end

local function setupCharacter(newCharacter)
	cleanup()

	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	local leftFoot = character:FindFirstChild("LeftFoot")
	local rightFoot = character:FindFirstChild("RightFoot")

	local footPosition

	if leftFoot and rightFoot then
		footPosition = (leftFoot.Position + rightFoot.Position) / 2
	else
		footPosition = rootPart.Position - Vector3.new(0, 3, 0)
	end

	savedAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	-- Driver block
	driverBlock = Instance.new("Part")
	driverBlock.Name = "WobbleDriverBlock"
	driverBlock.Size = BLOCK_SIZE
	driverBlock.Material = Enum.Material.Neon
	driverBlock.Color = Color3.fromRGB(0, 170, 255)
	driverBlock.Anchored = true
	driverBlock.CanCollide = false
	driverBlock.CanTouch = false
	driverBlock.CanQuery = false
	driverBlock.CFrame = CFrame.new(footPosition)
	driverBlock.Parent = workspace

	-- Driver attachment
	blockAttachment = Instance.new("Attachment")
	blockAttachment.Name = "DriverAttachment"
	blockAttachment.Parent = driverBlock

	-- Character foot pivot
	footAttachment = Instance.new("Attachment")
	footAttachment.Name = "FootPivotAttachment"
	footAttachment.Position =
		rootPart.CFrame:PointToObjectSpace(footPosition)
	footAttachment.Parent = rootPart

	-- Connect character to driver block
	ballSocket = Instance.new("BallSocketConstraint")
	ballSocket.Name = "DriverBallSocket"
	ballSocket.Attachment0 = blockAttachment
	ballSocket.Attachment1 = footAttachment
	ballSocket.LimitsEnabled = false
	ballSocket.TwistLimitsEnabled = false
	ballSocket.Parent = driverBlock

	-- Orientation controller
	rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "WobbleOrientationAttachment"
	rootAttachment.Parent = rootPart

	alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "WobbleAlignOrientation"
	alignOrientation.Mode =
		Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = rootAttachment
	alignOrientation.Responsiveness = TURN_RESPONSIVENESS
	alignOrientation.MaxTorque = MAX_TORQUE
	alignOrientation.RigidityEnabled = false
	alignOrientation.Parent = rootPart

	-- Wobble state
	local elapsed = 0
	local angle = 0
	local angularVelocity = 0
	local previousHeading = rootPart.CFrame.LookVector

	-- Ground detection
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {
		character,
		driverBlock,
	}

	updateConnection = RunService.PreSimulation:Connect(function(dt)
		if not character or not character.Parent
			or not humanoid or humanoid.Health <= 0
			or not driverBlock or not driverBlock.Parent then
			return
		end

		dt = math.min(dt, 1 / 30)
		elapsed += dt

		-- Move the driver block with player input
		local moveDirection = humanoid.MoveDirection

		local horizontalMovement = Vector3.new(
			moveDirection.X,
			0,
			moveDirection.Z
		)

		if horizontalMovement.Magnitude > 1 then
			horizontalMovement = horizontalMovement.Unit
		end

		local nextPosition = driverBlock.Position
			+ horizontalMovement * MOVE_SPEED * dt

		-- Keep the driver block near the ground
		local rayResult = workspace:Raycast(
			nextPosition + Vector3.new(0, 3, 0),
			Vector3.new(0, -10, 0),
			rayParams
		)

		if rayResult then
			nextPosition = Vector3.new(
				nextPosition.X,
				rayResult.Position.Y + BLOCK_SIZE.Y / 2,
				nextPosition.Z
			)
		end

		driverBlock.CFrame = CFrame.new(nextPosition)

		-- Preserve the last movement direction
		if horizontalMovement.Magnitude > 0.05 then
			previousHeading = horizontalMovement.Unit
		end

		-- Smooth, consistent continuous wobble
		local targetAngle =
			MAX_SWING_ANGLE
			* math.sin(DRIVE_FREQUENCY * elapsed)

		local acceleration =
			(targetAngle - angle) * WOBBLE_RESPONSE
			- WOBBLE_DAMPING * angularVelocity

		angularVelocity += acceleration * dt
		angle += angularVelocity * dt

		angle = math.clamp(
			angle,
			-MAX_SWING_ANGLE,
			MAX_SWING_ANGLE
		)

		-- Combine movement heading with wobble rotation
		local flatHeading = Vector3.new(
			previousHeading.X,
			0,
			previousHeading.Z
		)

		if flatHeading.Magnitude < 0.001 then
			flatHeading = Vector3.new(0, 0, -1)
		end

		local headingCFrame = CFrame.lookAt(
			Vector3.zero,
			flatHeading.Unit
		)

		alignOrientation.CFrame =
			headingCFrame.Rotation
			* CFrame.Angles(0, 0, angle)
	end)
end

player.CharacterAdded:Connect(setupCharacter)

player.CharacterRemoving:Connect(function()
	cleanup()
end)

if player.Character then
	setupCharacter(player.Character)
end
