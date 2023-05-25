local NPC_AI = {}
NPC_AI.__index = NPC_AI
local HTTP = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local MPS = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local CollectionPoints = workspace.PackageCollection:GetChildren()
local DefaultSideQuestLikelihood = 5
local pPlatPrompted = {}

local globalPlayerLastChat = {}

type messageHistory = {[number] : {
	role: string,
	content: string
}}

local names = {
	"Freddy",
	"Billy Joel",
	"Bobby",
	"Dylan",
	"Gabe",
	"Danny",
	"Franklin",
	"Skyler",
	"Diana",
	"Poppy",
	"Philip",
	"Sal",
	"Walter",
	"Chad",
	"Manny"
}

local chatClrs = {
	Color3.new(0.623529, 1, 0.537255),
	Color3.new(1, 0.529412, 0.529412),
	Color3.new(0.462745, 0.298039, 0.298039),
	Color3.new(0.917647, 0.74902, 0.239216),
	Color3.new(0.168627, 0.0901961, 0.545098),
	Color3.new(1, 0.741176, 0.945098),
	Color3.new(1, 0.411765, 0.678431),
	Color3.new(1, 0.721569, 0.584314),
	Color3.new(0.403922, 0.309804, 0.231373),
	Color3.new(0.278431, 0.568627, 0.596078)
}

local locations = {
}

MPS.PromptGamePassPurchaseFinished:Connect(function(plr, gpID, purchased)
	if (purchased) and (gpID == 7039792) and (pPlatPrompted[plr]) then
		AnalyticsService:FireCustomEvent(plr, "NPC_PLATINUM", {status="SUCCESS"})
		game.ServerScriptService.BackendServices.GameAnalyticsServer.SendDesignEvent:Fire(plr, "NPC:BOUGHPLAT", nil)
		game.ServerScriptService.AnalyticsManager.SendMsgExtra:Fire('?? ' .. plr.Name .. ' bought platinum after NPC AI Prompt!')
	end
end)

for _, v in pairs(workspace.MapIcons:GetChildren()) do
	table.insert(locations, v.Name)
end

local function RandomName()
	return names[math.random(1, #names)]
end

local function RandomAge()
	return math.random(13, 30)
end

local function getCompletion(txt, plr, char)
	
	local startT = tick()
	
	local charHRP = char:FindFirstChild("HumanoidRootPart")
	local c = script.TypingStatus:Clone()
	c.Adornee = charHRP
	c.Parent = plr.PlayerGui
	
	local responseEvent = Instance.new("BindableEvent")
	
	--create a function that sends a request and fires the responseEvent when received
	task.defer(function()
		responseEvent:Fire(HTTP:RequestAsync({
			Url = "http://api.roville.com:8085/chat",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HTTP:JSONEncode({
				input_text = txt
			})
		}))
	end)
	
	--if the response isn't received within 15 seconds, fire the responseEvent with an empty response
	task.defer(function()
		task.wait(15)
		responseEvent:Fire()
	end)
	
	local response = responseEvent.Event:Wait()
	responseEvent:Destroy()
	c:Destroy()
	
	--check if the response is empty, and track the failed response
	if not response then
		AnalyticsService:FireCustomEvent(plr, "NPC_CONVO", {status="FAILED"})
		return "..."
	end
	
	AnalyticsService:FireCustomEvent(plr, "NPC_CONVO", {status="SUCCESS", GPT=true, isPlatinum=(game.ServerScriptService.CheckGamepass:Invoke(plr, 7039792) or false), promptMessage=txt, response=HTTP:JSONDecode(response.Body).response:sub(1, 35), latency=tick()-startT})
	
	--if we have a response, return it
	return HTTP:JSONDecode(response.Body).response
end

local function getRandomIntroduction()
	return "Hi!"
end

local function getRandomConvoInterruption()
	return "I have to go now, bye!"
end

function NPC_AI.new(Name : string?, Age : number?, PreviousConversationData : string?, Character : Model)
	local self = setmetatable({}, NPC_AI)
	
	self.char = Character
	self.Name = Name or RandomName()
	self.Age = Age or RandomAge()
	self.chatClr = chatClrs[math.random(1,#chatClrs)]
	self.CurrentPlrInConvo = nil
	
	-- initialize any properties or variables here
	self.convoIntroduced = false
	
	--if this npc has previous convo data, save here
	self.currentPrompt = {}
	self.lastConvoWithPlr = {}
	self.plrSideQuestLikelihood = {}
	self.plrPromptedQuest = {}
	self.currentConvoStart = 0
	self.lastPlrInConvo = nil
	self.currentConversationDepth = 0
	
	self.char.TalkPlr:GetPropertyChangedSignal("Value"):connect(function()
		if not self.char.TalkPlr.Value then
			if self.CurrentPlrInConvo then
				AnalyticsService:FireCustomEvent(self.lastPlrInConvo, "NPC_CONVO_STATS", {GPT=false, depth=self.currentConversationDepth, length=tick()-self.currentConvoStart})
				self.CurrentPlrInConvo:Disconnect()
			end
		end
	end)
	
	game.ReplicatedStorage.ActionEvents.Talk.OnServerEvent:Connect(function(plr, obj)
		if obj:IsDescendantOf(self.char) then
			
			if (((not self.lastConvoWithPlr[plr]) or (self.lastConvoWithPlr[plr] < tick()-600))

				and

				((not globalPlayerLastChat[plr]) or (globalPlayerLastChat[plr] < tick()-300)))
				
				or

				script.Parent.CitizenController.UnlimitedConversation.Value
				
				or
				
				game.ServerScriptService.CheckGamepass:Invoke(plr, 7039792)
				
			then
				
				self.lastPlrInConvo = plr
				self.lastConvoWithPlr[plr] = tick()
				self.currentConvoStart = tick()
				globalPlayerLastChat[plr] = tick()
				script.Parent.Citizen_Character.InitConvo:Fire(plr, false)
				
				for _, v in pairs(workspace.Citizens:GetChildren()) do
					local TalkPlrVal = v:FindFirstChild("TalkPlr")
					if TalkPlrVal and (not (v==Character)) and (TalkPlrVal.Value==plr) then
						TalkPlrVal.Value = nil
					end
				end

				if self.CurrentPlrInConvo then
					self.CurrentPlrInConvo:Disconnect()
				end

				self.currentConversationDepth = 0
				self.char.TalkPlr.Value = plr
				self.CurrentPlrInConvo = plr.Chatted:Connect(function(msg)
					self:Respond(msg, plr)
				end)

				self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] or {}

				if #self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] < 1 then
					self:Introduce(plr)
				else
					self:MeetAgain(plr)
				end
			else
				
				if (self.lastConvoWithPlr[plr]) and (self.lastConvoWithPlr[plr] > tick()-600) then
					game.ReplicatedStorage.CS.NPCUpsell:FireClient(plr, "? You can only talk with the same NPC every 10 minutes!")
					pPlatPrompted[plr] = true
					game.ReplicatedStorage.CS.SendNotif:FireClient(plr, "? Can't talk with this NPC yet!", "? You can only talk with the same NPC every 10 minutes!")
				else
					game.ReplicatedStorage.CS.NPCUpsell:FireClient(plr, "? You can only start new conversations with NPCs every 5 minutes!")
					pPlatPrompted[plr] = true
					game.ReplicatedStorage.CS.SendNotif:FireClient(plr, "? Can't talk with this NPC yet!", "? You can only start new conversations with NPCs every 5 minutes!")
				end
				
			end
			
		end
	end)
	
	return self
end

function NPC_AI:showMsg(msg : string)
	--remove any old chat bubbles
	local oldBubble = self.char.Bubble.BubbleChatList:FindFirstChild("Bubley")
	if oldBubble then
		oldBubble:Destroy()
	end
	
	
	--create a new chat bubble for the NPC and display the retreived message
	local newBubble = script.Bubley:Clone()
	msg = msg:gsub('"', ""):gsub("\n", "")
	newBubble.Frame.Text.Text = msg
	newBubble.Parent = self.char.Bubble.BubbleChatList
	
	game.ReplicatedStorage.CS.ServerMSG:FireAllClients({
		Text = '[NPC: ' .. self.Name .. ']: ' .. msg;
		Color=self.chatClr;
		Font = Enum.Font.GothamSemibold;
	})
	
	--remove the chat bubble after a delay depending on the length of message
	task.delay(1 + (msg:len()/10), function()
		if newBubble and newBubble.Parent then
			newBubble:Destroy()
		end
	end)
end

function NPC_AI:Introduce(plr)
	self.convoIntroduced = false
	local answer = getRandomIntroduction()

	if answer then
		self:showMsg(answer)
		game.ReplicatedStorage.CS.ConvoNotif:FireClient(plr)
		self.convoIntroduced = true
	end
end

function NPC_AI:MeetAgain(plr)
	local answer = getRandomIntroduction()

	if answer then
		self.plrPromptedQuest[plr] = nil
		self:showMsg(answer)
	end
end

function NPC_AI:Respond(txt, plr)
	if self.convoIntroduced then
		
		local giveSideQuest = false
		local packageLocation, maxTokens

		if not self.plrSideQuestLikelihood[plr] then
			self.plrSideQuestLikelihood[plr] = DefaultSideQuestLikelihood --default percentage of likelihood to give sidequest
		else
			self.plrSideQuestLikelihood[plr] = math.min(65, self.plrSideQuestLikelihood[plr]*2) 
		end

		giveSideQuest = ((math.random()*100) < self.plrSideQuestLikelihood[plr]) and (not plr:FindFirstChild("PackageCollection"))
			and (not self.plrPromptedQuest[plr]) and script.Parent.CitizenController.SideQuestsEnabled.Value

		local answer
		if giveSideQuest then
			--give side quest
			maxTokens = 150
			packageLocation = CollectionPoints[math.random(1, #CollectionPoints)]
			answer = getCompletion("GET_QUEST", plr, self.char):format(packageLocation.Name)
			--reset side quest likelihood
			self.plrPromptedQuest[plr] = true
			self.plrSideQuestLikelihood[plr] = nil
		else
			answer = getCompletion(txt, plr, self.char)
		end

		if answer then
			self:showMsg(answer)
			
			if giveSideQuest then
				game.ServerScriptService.BackendServices.Citizen_Character.PromptSideQuest:Fire(plr, packageLocation, self.Name)
			end
			
			self.lastConvoWithPlr[plr] = tick()
			globalPlayerLastChat[plr] = tick()
			self.currentConversationDepth+=1
			if not script.Parent.CitizenController.UnlimitedConversation.Value then
				if ((self.currentConversationDepth > 3) and (not game.ServerScriptService.CheckGamepass:Invoke(plr, 7039792))) or (self.currentConversationDepth > 15) then
					self.CurrentPlrInConvo:Disconnect()

					task.wait(1)
					local answer = getRandomConvoInterruption()

					if answer then
						self:showMsg(answer)
					end

					task.wait(1)
					self.char.TalkPlr.Value = nil

				end
			end
		end
	end
end

return NPC_AI
