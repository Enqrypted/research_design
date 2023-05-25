local NPC_AI = {}
NPC_AI.__index = NPC_AI
local HTTP = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local API_KEY = "API"
local DefaultSideQuestLikelihood = 5
local CollectionPoints = workspace.PackageCollection:GetChildren()
local MPS = game:GetService("MarketplaceService")
local AnalyticsService = game:GetService("AnalyticsService")
local pPlatPrompted = {}

local globalPlayerLastChat = {}

type messageHistory = {[number] : {
	role: string,
	content: string
}}

local cantTalkResponse = {
	"Sorry can't talk right now, bye",
	"I'm late for work! Gotta get going!",
	"I need to go to school, cya!",
	"I'm not in the mood for talking right now!",
	"Gotta go fast!",
	"I'm running late for work at RoVille's bakery! Let's chat another time, I promise!",
	"My neighbor's in trouble, I need to help them now. We'll catch up later",
	"Family emergency, no time, talk later!",
	"Urgent town meeting, can't miss it. Let's talk soon!",
	"Just noticed a leak in my house, gotta fix it! Chat later?",
	"My pet's run off, need to find them! Talk to you soon!",
	"Oh no, I left the stove on at home! Can't talk, sorry!",
	"Heading to RoVille Market, it's closing soon. Speak later!",
	"I have a dentist appointment, can't be late."
}

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

local moods = {

	"vibin",
	"chillin",
	"normal",
	"happy",
	"energized",
	"tired",
	"sad",
	"angry"

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

local function GetMood()
	return moods[math.random(1, #moods)]
end

local function GetLocation(pos)
	local currentLocation = "The city"
	local closestDistance = 400
	
	for _, v in pairs(workspace.MapIcons:GetChildren()) do
		if (v.Value-pos).Magnitude < closestDistance then
			closestDistance = (v.Value-pos).Magnitude
			currentLocation = v.Name
		end
	end
	
	for _, v in pairs(workspace.Properties:GetChildren()) do
		if (v.PSpawn.Position-pos).Magnitude < closestDistance then
			closestDistance = (v.PSpawn.Position-pos).Magnitude
			currentLocation = v.Location.Value
		end
	end
	print(currentLocation)
	return currentLocation
	
end

local function getCompletion(prompt : messageHistory, plr, charHRP, creativity, maxTokens)
	
	local startT = tick()
	local c = script.TypingStatus:Clone()
	c.Adornee = charHRP
	c.Parent = plr.PlayerGui
	
	local responseEvent = Instance.new("BindableEvent")
	
	task.defer(function()
		responseEvent:Fire(HTTP:RequestAsync({
			Url = "https://api.openai.com/v1/chat/completions",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. API_KEY
			},
			Body = HTTP:JSONEncode({
				model = "gpt-3.5-turbo",
				messages = prompt,
				temperature = creativity or .85,
				max_tokens = maxTokens or 35
			})
		}))
	end)
	
	task.defer(function()
		task.wait(15)
		responseEvent:Fire()
	end)
	
	local response = responseEvent.Event:Wait()
	responseEvent:Destroy()
	c:Destroy()
	
	if not response then
		AnalyticsService:FireCustomEvent(plr, "NPC_CONVO", {status="FAILED"})
		return "..."
	end
	
	if not HTTP:JSONDecode(response.Body).choices then
		print(HTTP:JSONDecode(response.Body))
	end
	
	AnalyticsService:FireCustomEvent(plr, "NPC_CONVO", {status="SUCCESS", GPT=true, isPlatinum=(game.ServerScriptService.CheckGamepass:Invoke(plr, 7039792) or false), promptMessage=prompt[#prompt].content:sub(0, 15), response=HTTP:JSONDecode(response.Body).choices[1].message.content:sub(1, 35), latency=tick()-startT})
	
	return HTTP:JSONDecode(response.Body).choices[1].message.content
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
	self.initialPrompt = "You are in-game NPC named " .. self.Name .. ", citizen in RoVille. Age " .. self.Age .. ". RoVille is city in Robloxia with neighborhoods: Bloxwood park, RoVille Hills, RoVille beach, city center. RoVille places: Bloxy Delights Bakery, The bank, Bloxy Burger, clothing store, car dealership, Bloxy Diner, dock, grocery, hangar, roville hospital, Frozen chills (ice-cream), main park, nightclub, office, pet store, roville school, roville space agency and theater. There is social media called InstaVille. You can build a business or buy a home from the marketplace or build your own house. Respond in casual small-talk answers as a fellow citizen. Limit responses to one sentence. Don't respond to political or controversial topics. Do not understand real-world topics or personalities, only fiction. Don't be formal and have casual talking style. Current mood is " .. GetMood() .. ". You will never invite others to come with you and will always make up excuses if you're invited to do something. Use emojis sometime. Keep user engaged and conversation going as much as possible"
	
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
				AnalyticsService:FireCustomEvent(self.lastPlrInConvo, "NPC_CONVO_STATS", {GPT=true, depth=self.currentConversationDepth, length=tick()-self.currentConvoStart})
				print({GPT=true, depth=self.currentConversationDepth, length=tick()-self.currentConvoStart})
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
				script.Parent.Citizen_Character.InitConvo:Fire(plr, true)
				
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

function NPC_AI:CleanHistory(plr)
	local history = self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)]
	local newHistory = {}
	
	for i, msg in pairs(history) do
		if not ((i > 1) and (i < #history-2)) then
			table.insert(newHistory, msg)
		end
	end
	
	self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = newHistory
	print(newHistory)
	
end

function NPC_AI:showMsg(msg : string)
	local oldBubble = self.char.Bubble.BubbleChatList:FindFirstChild("Bubley")
	if oldBubble then
		oldBubble:Destroy()
	end

	local newBubble = script.Bubley:Clone()
	msg = msg:gsub('"', ""):gsub("\n", "")
	newBubble.Frame.Text.Text = msg
	newBubble.Parent = self.char.Bubble.BubbleChatList
	
	game.ReplicatedStorage.CS.ServerMSG:FireAllClients({
		Text = '[NPC: ' .. self.Name .. ']: ' .. msg;
		Color=self.chatClr;
		Font = Enum.Font.GothamSemibold;
	})
	
	task.delay(1 + (msg:len()/10), function()
		if newBubble and newBubble.Parent then
			newBubble:Destroy()
		end
	end)
end

function NPC_AI:Introduce(plr)
	self.convoIntroduced = false
	local tempPrompt = self.initialPrompt .. " Current location: " .. GetLocation(self.char.HumanoidRootPart.Position) .. ". Say something random relating to yourself or your surroundings and ask whats up. max 25 words."
	local tempHistory : messageHistory = table.clone(self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)])
	table.insert(tempHistory, {role = "system", content = tempPrompt})
	local answer = getCompletion(tempHistory, plr, self.char.HumanoidRootPart, 1)

	if answer then
		if answer == "..." then
			--give default bye response
			self:showMsg(cantTalkResponse[math.random(1, #cantTalkResponse)])
			task.wait(2)
			
			--reset cooldown so if this NPC can't talk, you can go to another NPC and try talking
			globalPlayerLastChat[plr] = nil
			
			self.char.TalkPlr.Value = nil
		else
			self:showMsg(answer)
			game.ReplicatedStorage.CS.ConvoNotif:FireClient(plr)

			table.insert(tempHistory, {role="assistant", content=answer})
			self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = tempHistory
			self.convoIntroduced = true
		end
	end
end

function NPC_AI:MeetAgain(plr)
	local tempPrompt = "You meet again. Response: "
	local tempHistory : messageHistory = table.clone(self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)])
	table.insert(tempHistory, {role = "system", content = tempPrompt})
	local answer = getCompletion(tempHistory, plr, self.char.HumanoidRootPart, 1)

	if answer then
		self:showMsg(answer)
		
		self.plrPromptedQuest[plr] = nil
		table.insert(tempHistory, {role="assistant", content=answer})
		self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = tempHistory
		self:CleanHistory(plr)
	end
end

function NPC_AI:Respond(txt, plr)
	if self.convoIntroduced then
		
		local filteredPlayerInput = TextService:FilterStringAsync(txt:sub(0, 100), plr.UserId, Enum.TextFilterContext.PrivateChat):GetChatForUserAsync(plr.UserId)
		
		local giveSideQuest = false
		local packageLocation, maxTokens
		
		if not self.plrSideQuestLikelihood[plr] then
			self.plrSideQuestLikelihood[plr] = DefaultSideQuestLikelihood --default percentage of likelihood to give sidequest
		else
			self.plrSideQuestLikelihood[plr] = math.min(65, self.plrSideQuestLikelihood[plr]*2) 
		end
		
		giveSideQuest = ((math.random()*100) < self.plrSideQuestLikelihood[plr]) and (not plr:FindFirstChild("PackageCollection"))
			and (not self.plrPromptedQuest[plr]) and script.Parent.CitizenController.SideQuestsEnabled.Value
		
		local tempPrompt
		if giveSideQuest then
			--give side quest
			maxTokens = 150
			packageLocation = CollectionPoints[math.random(1, #CollectionPoints)]
			tempPrompt = 'Respond to: (' .. filteredPlayerInput .. ') and also ask player for a favor: make up an excuse that you need them to collect a package for you from ' .. packageLocation.Name .. '. Response: '
			--reset side quest likelihood
			self.plrPromptedQuest[plr] = true
			self.plrSideQuestLikelihood[plr] = nil
		else
			tempPrompt = 'Respond to: (' .. filteredPlayerInput .. ') Response: '
		end
		
		
		local tempHistory : messageHistory = table.clone(self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)])
		table.insert(tempHistory, {role = "user", content = tempPrompt})
		local answer = getCompletion(tempHistory, plr, self.char.HumanoidRootPart, 1, maxTokens)

		if answer then
			self:showMsg(answer)
			
			if giveSideQuest then
				game.ServerScriptService.BackendServices.Citizen_Character.PromptSideQuest:Fire(plr, packageLocation, self.Name, true)
			end

			table.insert(tempHistory, {role="assistant", content=answer})
			self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = tempHistory
			self:CleanHistory(plr)
			self.lastConvoWithPlr[plr] = tick()
			globalPlayerLastChat[plr] = tick()
			self.currentConversationDepth+=1
			if not script.Parent.CitizenController.UnlimitedConversation.Value then
				if ((self.currentConversationDepth > 3) and (not game.ServerScriptService.CheckGamepass:Invoke(plr, 7039792))) or (self.currentConversationDepth > 15) then
					self.CurrentPlrInConvo:Disconnect()

					task.wait(1)
					local tempPrompt = 'Politely end the conversation and make an excuse if needed, say bye. Response: '
					local tempHistory : messageHistory = table.clone(self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)])
					table.insert(tempHistory, {role = "system", content = tempPrompt})
					local answer = getCompletion(tempHistory, plr, self.char.HumanoidRootPart)

					if answer then
						self:showMsg(answer)
						table.insert(tempHistory, {role="assistant", content=answer})
						self.currentPrompt[tostring(self.char.TalkPlr.Value.UserId)] = tempHistory
						self:CleanHistory(plr)
					end

					task.wait(1)
					self.char.TalkPlr.Value = nil

				end
			end
		end
	end
end

return NPC_AI
