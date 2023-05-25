local ServerScripts = game:GetService("ServerScriptService")
local AnalyticsService = game:GetService("AnalyticsService")
local module = {}
local NPCFunctionality = require(ServerScripts.NPCFunctionality)
local Citizen_AI = require(ServerScripts.BackendServices.Citizen_Conversation_AI)
local Citizen_PreScripted = require(ServerScripts.BackendServices.Citizen_Conversation_PreScripted)

local Nodes = workspace.Citizen_Nodes:GetChildren()

type NPCCharData = {
	hairIndex: number,
	shirtIndex: number,
	pantsIndex: number,
	bodyColorIndex: number,
	accessoryIndex: number?
}

local function getFeasiblePoints(pos, ignoreList)
	local feasible = {}
	
	for _, node in pairs(Nodes) do
		if ((node.Position-pos).Magnitude < 500) and (not table.find(ignoreList, node)) then
			table.insert(feasible, node)
		end
	end
	
	return feasible
	
end

local function hasClearPath(pos, node)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {workspace.Citizens, workspace.PersistentSidewalk, workspace.PersistentRoad}
	
	local rayResult = workspace:Raycast(pos,  (node.Position-pos), rayParams)
	if not rayResult then
		return true
	else
		return false
	end
end

function module:CreateCitizenCharacter(forceGPT)

	
	local spawnPoint = Nodes[math.random(1, #Nodes)]
	
	local char = NPCFunctionality:New(workspace.Citizens, nil, spawnPoint, nil, nil, NPCFunctionality:create(), 0)
	
	local humanoid : Humanoid = char.Humanoid
	local talkPlrTarg = Instance.new("ObjectValue", char)
	talkPlrTarg.Name = "TalkPlr"
	
	
	local bws, bds, bhs
	
	local age = math.random(14, 30)
	
	local bSize = math.random(40,80)/100
	
	bws = char.Humanoid.BodyWidthScale
	bws.Value = ((age-14)/16)*.5 + bSize
	
	bds = char.Humanoid.BodyDepthScale
	bds.Value = ((age-14)/16)*.5 + bSize
	
	bhs = char.Humanoid.BodyHeightScale
	bhs.Value = ((age-14)/16)*.4 + .85
	
	for _, v in pairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CastShadow = true
		end
	end
	
	
	--if talking to new player, stop walking
	talkPlrTarg:GetPropertyChangedSignal("Value"):Connect(function(val)
		if talkPlrTarg.Value then
			char.WalkInterrupt.Value = not char.WalkInterrupt.Value
			local playerDirection = (talkPlrTarg.Value.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Unit
			task.wait(.5)
			humanoid:MoveTo(char.HumanoidRootPart.Position+playerDirection+Vector3.new((math.random()*5)-2.5,0,(math.random()*5)-2.5))
		end
	end)
	
	
	--setup interaction bounding box
	local boundingBox = script.Citizen_Prompt:Clone()
	boundingBox.Parent = char
	boundingBox.CitizenPrompt.CFrame = char.HumanoidRootPart.CFrame
	
	--attach the box to the humanoid root
	local weld = Instance.new("Weld", boundingBox)
	weld.Part0 = boundingBox.CitizenPrompt
	weld.Part1 = char.HumanoidRootPart
	
	local SpeechBubbleUI = script.Bubble:Clone()
	SpeechBubbleUI.Adornee = char
	SpeechBubbleUI.Parent = char
	--create convo AI instance
	local Citizen
	
	local isGPT = forceGPT or (math.random() > .5)
	if isGPT then
		Citizen = Citizen_AI.new(nil, age, nil, char)
	else
		Citizen = Citizen_PreScripted.new(nil, age, nil, char)
	end
	
	--set isGPT value in character for future identification
	char:SetAttribute("isGPT", isGPT)
	
	--walkInterrupt bind
	char.WalkInterrupt:GetPropertyChangedSignal("Value"):connect(function()
		humanoid:MoveTo(char.HumanoidRootPart.Position)
	end)
	
	
	local lastNode, currentNode
	--walk loop
	task.defer(function()
		while true do
			
			if talkPlrTarg.Value then
				repeat task.wait(math.random()*2) until
				(not talkPlrTarg.Value) or (not talkPlrTarg.Value.Character)
					or (not talkPlrTarg.Value.Character:FindFirstChild("HumanoidRootPart"))
					or ((talkPlrTarg.Value.Character:FindFirstChild("HumanoidRootPart").Position-char.HumanoidRootPart.Position).Magnitude > 20)
			end
			
			if (talkPlrTarg.Value) and (talkPlrTarg.Value.Character)
				and (talkPlrTarg.Value.Character:FindFirstChild("HumanoidRootPart"))
				and ((talkPlrTarg.Value.Character:FindFirstChild("HumanoidRootPart").Position-char.HumanoidRootPart.Position).Magnitude > 20) then
				
				talkPlrTarg.Value = nil
			
			end
			
			--TODO
			--in ignoreNodesList add:
			--nodes (with clear path) that are closer to the last node than to the current node
			local feasibleNodes = getFeasiblePoints(char.HumanoidRootPart.Position, {currentNode, lastNode})

			if #feasibleNodes > 0 then
				local nextNode = feasibleNodes[math.random(1, #feasibleNodes)]

				if not hasClearPath(char.HumanoidRootPart.Position, nextNode) then
					repeat
						nextNode = feasibleNodes[math.random(1, #feasibleNodes)]
						
						task.wait()
					until hasClearPath(char.HumanoidRootPart.Position, nextNode)
				end

				humanoid.WalkSpeed = math.random(10,20)
				humanoid:MoveTo(nextNode.Position)
				local reached = humanoid.MoveToFinished:Wait()
				local stoppedMoving = char.HumanoidRootPart.Velocity.Magnitude < 4
				
				
				while not reached do
					stoppedMoving = char.HumanoidRootPart.Velocity.Magnitude < 4
					if stoppedMoving then
						char.HumanoidRootPart.CFrame = nextNode.CFrame
						reached = true
					else
						humanoid:MoveTo(nextNode.Position)
						reached = humanoid.MoveToFinished:Wait()
					end
				end

				--track these to never backtrack the last node 
				lastNode = currentNode
				currentNode = nextNode

			else
				--no nodes in range
			end

			local keepGoing = math.random() > .5

			if not keepGoing then
				task.wait(math.random(3, 10))
			end

		end
	end)
end

local pSideQuestLocation = {}
local pSideQuestGPT = {}
local pSessionNPCConvos = {}

game.Players.PlayerAdded:Connect(function(plr)
	pSessionNPCConvos[plr] = {GPT = 0, PreScripted = 0}
end)

game.Players.PlayerRemoving:Connect(function(plr)
	AnalyticsService:FireCustomEvent(plr, "SESSION_CONVO_STATS", pSessionNPCConvos[plr])
end)

script.InitConvo.Event:Connect(function(plr, isGPT)
	if isGPT then
		pSessionNPCConvos[plr].GPT += 1
	else
		pSessionNPCConvos[plr].PreScripted += 1
	end
end)

game.ReplicatedStorage.ActionEvents["Collect package"].OnServerEvent:Connect(function(plr)
	local HRP = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if HRP then
		
		if (pSideQuestLocation[plr].BASE.Position-HRP.Position).Magnitude < 15 then
			--if within range to collect package
			plr.PackageCollection:Destroy()
			game.ReplicatedStorage.ActionEvents["Collect package"]:FireClient(plr)
			game.ReplicatedStorage.CS.SendNotif:FireClient(plr, "?? Aspiration Quest Complete!", "You have received 25 Aspiration points!")
			
			plr.AspirationPoints.Value += 25

			local InspiredMood = plr:FindFirstChild("Inspired")

			if InspiredMood then
				InspiredMood:Destroy()
			end

			task.defer(function()
				InspiredMood = Instance.new("NumberValue")
				InspiredMood.Name = "Inspired"
				InspiredMood.Value = tick() + 60
				InspiredMood.Parent = plr

				task.wait(60)

				if InspiredMood and InspiredMood.Parent then
					InspiredMood:Destroy()
				end

			end)
			
			AnalyticsService:FireCustomEvent(plr, "NPC_QUEST_FINISHED", {GPT=pSideQuestGPT[plr]})

			game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Energy.Value = math.min(100, game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Energy.Value+25)
			game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Hygiene.Value = math.min(100, game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Hygiene.Value+25)
			game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Hunger.Value = math.min(100, game.ReplicatedStorage.PNS:FindFirstChild(plr.Name).Hunger.Value+25)
		end
		
	end
end)

game.ReplicatedStorage.CS.PromptSideQuest.OnServerEvent:Connect(function(plr, accept)
	AnalyticsService:FireCustomEvent(plr, "NPC_INIT_QUEST", {accepted=accept, GPT=pSideQuestGPT[plr]})
	if accept then
		--confirm side quest
		local packageCollection = plr:FindFirstChild("PackageCollection")

		if not packageCollection then
			packageCollection = Instance.new("ObjectValue", plr)
			packageCollection.Name = "PackageCollection"
		end

		packageCollection.Value = pSideQuestLocation[plr]
	end
	
end)

script.PromptSideQuest.Event:Connect(function(plr, location, npcName, isGpt)
	pSideQuestGPT[plr] = isGpt or false
	pSideQuestLocation[plr] = location
	game.ReplicatedStorage.CS.PromptSideQuest:FireClient(plr, location, npcName)
end)

return module
