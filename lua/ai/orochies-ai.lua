--[[
	太阳神三国杀武将扩展包·大蛇一族（AI部分）
	适用版本：V2 - 愚人版（版本号：20150401）清明补丁（版本号：20150405）
	武将总数：11
	武将一览：
		1、莉安娜（能量、必杀）＋（V字金锯、旋转的火花、重力风暴）
		2、八神庵（能量、必杀）＋（禁千二百十一式·八稚女、里百八式·八酒杯）
		3、嘉迪路（能量、必杀）＋（守卫、宽恕）
		4、薇思（能量、必杀）＋（连续反身打）
		5、麦卓（能量、必杀）＋（天国滑行）
		6、山崎龙二（能量、必杀）＋（断头台、射杀）
		7、克里斯（能量、必杀）＋（暗黑大蛇薙、拂大地之禁果）
		8、夏尔米（能量、必杀）＋（暗黑雷光拳、宿命·幻影·振子）
		9、七枷社（能量、必杀）＋（吼大地、荒大地、暗黑地狱极乐落）
		10、高尼茨（能量、必杀）＋（黑暗恸哭、真·八稚女·蛟）
		11、大蛇（能量、必杀）＋（混·まろかれ、大神·おおみわ）
	所需标记：
		1、@ocEnergyMark（“能量”标记，来自技能“能量”）
]]--
function SmartAI:useSkillCard(card, use)
	local name
	if card:isKindOf("LuaSkillCard") then
		name = "#" .. card:objectName()
	else
		name = card:getClassName()
	end
	if sgs.ai_skill_use_func[name] then
		sgs.ai_skill_use_func[name](card, use, self)
		if use.to then
			if not use.to:isEmpty() and sgs.dynamic_value.damage_card[name] then
				for _, target in sgs.qlist(use.to) do
					if self:damageIsEffective(target) then return end
				end
				use.card = nil
			end
		end
		return
	end
	if self["useCard"..name] then
		self["useCard"..name](self, card, use)
	end
end
sgs.ocx_skills = {}
sgs.ocx_use_func = {}
function changeSuitsToDirections(spades, hearts, clubs, diamonds)
	return hearts, diamonds, spades, clubs
end
function isValid(self, name, info)
	info = info or sgs.ocx_skills[name]
	local range = info["range"]
	local benefit = info["benefit"] or false
	if range == "distance = 1" then
		if benefit then
			for _,friend in ipairs(self.friends_noself) do
				if self.player:distanceTo(friend) == 1 then
					return true
				end
			end
		else
			for _,enemy in ipairs(self.enemies) do
				if self.player:distanceTo(enemy) == 1 then
					return true
				end
			end
		end
	elseif range == "inMyAttackRange" then
		if benefit then
			for _,friend in ipairs(self.friends_noself) do
				if self.player:inMyAttackRange(friend) then
					return true
				end
			end
		else
			for _,enemy in ipairs(self.enemies) do
				if self.player:inMyAttackRange(enemy) then
					return true
				end
			end
		end
	elseif range == "others" then
		if benefit then
			return #self.friends_noself > 0
		else
			return #self.enemies > 0
		end
	elseif range == "allplayers" then
		if benefit then
			return true
		else
			return #self.enemies > 0 
		end
	end
	return false
end
function getPriorTarget(self, range, benefit)
	if benefit then
		local friends = {}
		if range == "distance = 1" then
			for _,friend in ipairs(self.friends_noself) do
				if self.player:distanceTo(friend) == 1 then
					table.insert(friends, friend)
				end
			end
		elseif range == "inMyAttackRange" then
			for _,friend in ipairs(self.friends_noself) do
				if self.player:inMyAttackRange(friend) then
					table.insert(friends, friend)
				end
			end
		elseif range == "others" then
			friends = self.friends_noself
		elseif range == "allplayers" then
			friends = self.friends
		end
		if #friends > 0 then
			self:sort(friends, "defense")
			return friends[1]
		end
	else
		local flag = ( ( self.role == "renegade" ) and ( self.room:alivePlayerCount() > 2 ) )
		local enemies = {}
		if range == "distance = 1" then
			for _,enemy in ipairs(self.enemies) do
				if flag and enemy:isLord() then
				elseif self.player:distanceTo(enemy) == 1 then
					table.insert(enemies, enemy)
				end
			end
		elseif range == "inMyAttackRange" then
			for _,enemy in ipairs(self.enemies) do
				if flag and enemy:isLord() then
				elseif self.player:inMyAttackRange(enemy) then
					table.insert(enemies, enemy)
				end
			end
		elseif range == "others" then
			for _,enemy in ipairs(self.enemies) do
				if flag and enemy:isLord() then
				else
					table.insert(enemies, enemy)
				end
			end
		elseif range == "allplayers" then
			for _,enemy in ipairs(self.enemies) do
				if flag and enemy:isLord() then
				else
					table.insert(enemies, enemy)
				end
			end
		end
		if #enemies > 0 then
			self:sort(enemies, "threat")
			return enemies[1]
		end
	end
end
--[[
	技能：能量
	描述：你造成或受到1点伤害后，或于回合外失去一张手牌后，你摸一张牌，
		然后你可以将一张手牌置于你的武将牌上，称为“向”（至多十张）。
		出牌阶段开始时，你可以弃置四张“向”，令你本阶段内造成的伤害+1。
		出牌阶段限一次，你可以获得所有的“向”，然后将至多十张手牌作为“向”置于你的武将牌上。
]]--
--room:askForCard(source, ".", "@ocEnergy", sgs.QVariant(), sgs.Card_MethodNone, source, false, "ocEnergy")
sgs.ai_skill_cardask["@ocEnergy"] = function(self, data, pattern, target, target2, arg, arg2)
	local handcards = self.player:getHandcards()
	local count = handcards:length()
	if count == 0 then
		return "."
	elseif count == 1 and self:needKongcheng(self.player) then
		return handcards:first():getEffectiveId()
	end
	handcards = sgs.QList2Table(handcards)
	if self.player:getPhase() == sgs.Player_Play then
		self:sortByUseValue(handcards, true)
		if self:getOverflow() > 0 then
			local keepJink, keepPeach, keepNull = false, false, false
			for _,card in ipairs(handcards) do
				local dummy_use = {
					isDummy = true,
				}
				if card:isKindOf("TrickCard") then
					self:useTrickCard(card, dummy_use)
				elseif card:isKindOf("EquipCard") then
					self:useEquipCard(card, dummy_use)
				elseif card:isKindOf("BasicCard") then
					self:useBasicCard(card, dummy_use)
				end
				if dummy_use.card then
					continue
				end
				if card:isKindOf("Jink") and not keepJink then
					keepJink = card:getEffectiveId()
				elseif card:isKindOf("Peach") and not keepPeach then
					keepPeach = card:getEffectiveId()
				elseif card:isKindOf("Nullification") and not keepNull then
					keepNull = card:getEffectiveId()
				else
					return card:getEffectiveId()
				end
			end
			return keepNull or keepJink or keepPeach or "."
		end
		return "."
	end
	if count > 2 and self:willSkipPlayPhase() then
		self:sortByUseValue(handcards)
		return handcards[1]:getEffectiveId()
	end
	local flag = false
	if self:getOverflow() > 0 then
		self:sortByUseValue(handcards)
		flag = true
	else
		self:sortByKeepValue(handcards, true)
	end
	for _,trick in ipairs(handcards) do
		if trick:isNDTrick() and not trick:isKindOf("Nullification") then
			return trick:getEffectiveId()
		end
	end
	for _,equip in ipairs(handcards) do
		if equip:isKindOf("EquipCard") then
			return equip:getEffectiveId()
		end
	end
	for _,trick in ipairs(handcards) do
		if trick:isKindOf("TrickCard") and not trick:isKindOf("Nullification") then
			return trick:getEffectiveId()
		end
	end
	if flag then
		return handcards[1]:getEffectiveId()
	end
	return "."
end
--room:askForUseCard(source, "@@ocEnergy", "@ocEnergy-gather")
sgs.ai_skill_use["@@ocEnergy"] = function(self, prompt, method)
	local handcards = self.player:getHandcards()
	handcards = sgs.QList2Table(handcards)
	self:sortByUseValue(handcards, true)
	local count = #handcards
	local spades, hearts, clubs, diamonds = {}, {}, {}, {}
	for _,card in ipairs(handcards) do
		local suit = card:getSuit()
		if suit == sgs.Card_Spade then
			table.insert(spades, card)
		elseif suit == sgs.Card_Heart then
			table.insert(hearts, card)
		elseif suit == sgs.Card_Club then
			table.insert(clubs, card)
		elseif suit == sgs.Card_Diamond then
			table.insert(diamonds, card)
		end
	end
	local ups, downs, forwards, backs = changeSuitsToDirections(spades, hearts, clubs, diamonds)
	local n_up, n_down, n_forward, n_back = #ups, #downs, #forwards, #backs
	local ocx_names = {}
	local max_mode = false
	if self.player:getHp() <= 1 then
		max_mode = true
	elseif self.player:getMark("@ocEnergyMark") > 0 then
		max_mode = true
	end
	for name, info in pairs(sgs.ocx_skills) do
		if type(info) == "table" then
			local flag = info["max_mode"] or false
			local total = info["total"] 
			if count > total and ( flag == max_mode ) then
				local skill = info["skill"]
				if self.player:hasSkill(skill) then
					local upNum = info["Up"] or 0
					local downNum = info["Down"] or 0
					local forwardNum = info["Forward"] or 0
					local backNum = info["Back"] or 0
					if n_up >= upNum and n_down >= downNum and n_forward >= forwardNum and n_back >= backNum then
						if isValid(self, name, info) then
							table.insert(ocx_names, name)
							n_up = n_up - upNum
							n_down = n_down - downNum
							n_forward = n_forward - forwardNum
							n_back = n_back - backNum
							count = count - total
						end
					end
				end
			end
		end
	end
	local to_put = {}
	if #ocx_names > 0 then
		for _, name in ipairs(ocx_names) do
			local info = sgs.ocx_skills[name]
			local total = info["total"] or 0
			if #to_put + total <= 10 then
				local upNum = info["Up"] or 0
				local downNum = info["Down"] or 0
				local forwardNum = info["Forward"] or 0
				local backNum = info["Back"] or 0
				local num = 0
				while num < upNum do
					local id = ups[1]:getEffectiveId()
					table.insert(to_put, id)
					table.remove(ups, 1)
					num = num + 1
				end
				num = 0
				while num < downNum do
					local id = downs[1]:getEffectiveId()
					table.insert(to_put, id)
					table.remove(downs, 1)
					num = num + 1
				end
				num = 0
				while num < forwardNum do
					local id = forwards[1]:getEffectiveId()
					table.insert(to_put, id)
					table.remove(forwards, 1)
					num = num + 1
				end
				num = 0
				while num < backNum do
					local id = backs[1]:getEffectiveId()
					table.insert(to_put, id)
					table.remove(backs, 1)
					num = num + 1
				end
			end
		end
	end
	local fill_num = #to_put --用于发动技能的、已选的手牌数
	local wait_num = 10 - fill_num --还可以放置的卡牌数
	local extra_num = self:getOverflow() --溢出的手牌数
	local space = extra_num - fill_num --放置完已选手牌数后，依然溢出的手牌数
	if space > 0 and wait_num > 0 then
		local hasWeakFriends = false
		for _,friend in ipairs(self.friends) do
			if self:isWeak(friend) then
				hasWeakFriends = true
				break
			end
		end
		local num = math.min(space, wait_num)
		local rest = {}
		for _,up in ipairs(ups) do
			table.insert(rest, up)
		end
		for _,down in ipairs(downs) do
			table.insert(rest, down)
		end
		for _,forward in ipairs(forwards) do
			table.insert(rest, forward)
		end
		for _,back in ipairs(backs) do
			table.insert(rest, back)
		end
		self:sortByUseValue(rest, true)
		local keepSlash = nil
		for _,card in ipairs(rest) do
			if hasWeakFriends and card:isKindOf("Peach") then
				continue
			end
			local dummy_use = {
				isDummy = true,
			}
			if card:isKindOf("BasicCard") then
				self:useBasicCard(card, dummy_use)
			elseif card:isKindOf("EquipCard") then
				self:useEquipCard(card, dummy_use)
			elseif card:isKindOf("TrickCard") then
				self:useTrickCard(card, dummy_use)
			end
			if dummy_use.card and card:isKindOf("Slash") then
				if keepSlash then
					if not self:hasCrossbowEffect() then
						dummy_use.card = nil
					end
				else
					keepSlash = card
				end
			end
			if not dummy_use.card then
				table.insert(to_put, card:getEffectiveId())
				num = num - 1
				if num <= 0 then
					break
				end
			end
		end
	end
	if #to_put > 0 then
		local card_str = "#ocEnergyGatherCard:"..table.concat(to_put, "+")..":->."
		return card_str
	end
	return "."
end
--player:askForSkillInvoke("ocEnergy", data)
sgs.ai_skill_invoke["ocEnergy"] = function(self, data)
	self.ocx_energy_invoke = {}
	if self.player:getHp() <= 1 then
		return false
	end
	local pile = self.player:getPile("ocEnergyPile")
	local p_spade, p_heart, p_club, p_diamond = 0, 0, 0, 0
	for _,id in sgs.qlist(pile) do
		local card = sgs.Sanguosha:getCard(id)
		local suit = card:getSuit()
		if suit == sgs.Card_Spade then
			p_spade = p_spade + 1
		elseif suit == sgs.Card_Heart then
			p_heart = p_heart + 1
		elseif suit == sgs.Card_Club then
			p_club = p_club + 1
		elseif suit == sgs.Card_Diamond then
			p_diamond = p_diamond + 1
		end
	end
	local p_up, p_down, p_forward, p_back = changeSuitsToDirections(p_spade, p_heart, p_club, p_diamond)
	local handcards = self.player:getHandcards()
	local h_spade, h_heart, h_club, h_diamond = 0, 0, 0, 0
	for _,card in sgs.qlist(handcards) do
		local suit = card:getSuit()
		if suit == sgs.Card_Spade then
			h_spade = h_spade + 1
		elseif suit == sgs.Card_Heart then
			h_heart = h_heart + 1
		elseif suit == sgs.Card_Club then
			h_club = h_club + 1
		elseif suit == sgs.Card_Diamond then
			h_diamond = h_diamond + 1
		end
	end
	local h_up, h_down, h_forward, h_back = changeSuitsToDirections(h_spade, h_heart, h_club, h_diamond)
	local count = pile:length() + handcards:length()
	local function getExtraNum(need, hand, pile)
		local delt = pile - need --牌堆比需求多出的数目
		if delt >= 0 then --牌堆自身就能满足需求
			return delt
		end
		delt = - delt --牌堆与需求的差额
		local all = hand + pile --资源总数
		local extra = all - need --资源总余额
		if extra < 0 then --综合所有资源都不能满足需求
			return -1
		end
		local x = pile - extra --牌堆至少应保留的数目
		if x >= 0 then
			return extra
		end
		return -1
	end
	for name, info in pairs(sgs.ocx_skills) do
		if type(info) == "table" and info["max_mode"] then
			if count >= info["total"] then
				local upNum = info["Up"] or 0
				local downNum = info["Down"] or 0
				local forwardNum = info["Forward"] or 0
				local backNum = info["Back"] or 0
				local extra = 0
				local extra_up = getExtraNum(upNum, h_up, p_up)
				if extra_up < 0 then
					continue
				else
					extra = extra + extra_up
				end
				local extra_down = getExtraNum(downNum, h_down, p_down)
				if extra_down < 0 then
					continue
				else
					extra = extra + extra_down
				end
				local extra_forward = getExtraNum(forwardNum, h_forward, p_forward)
				if extra_forward < 0 then
					continue
				else
					extra = extra + extra_forward
				end
				local extra_back = getExtraNum(backNum, h_back, p_back)
				if extra_back < 0 then
					continue
				else
					extra = extra + extra_back
				end
				if extra >= 4 then
					self.ocx_energy_invoke = {
						["Up"] = extra_up,
						["Down"] = extra_down,
						["Forward"] = extra_forward,
						["Back"] = extra_back,
					}
					return true
				end
			end
		end
	end
	return false
end
--room:askForAG(player, pile, false, "ocEnergy")
sgs.ai_skill_askforag["ocEnergy"] = function(self, card_ids)
	local msg = self.ocx_energy_invoke
	if type(msg) == "table" then
		local spades, hearts, clubs, diamonds = {}, {}, {}, {}
		for _,id in ipairs(card_ids) do
			local card = sgs.Sanguosha:getCard(id)
			local suit = card:getSuit()
			if suit == sgs.Card_Spade then
				table.insert(spades, card)
			elseif suit == sgs.Card_Heart then
				table.insert(hearts, card)
			elseif suit == sgs.Card_Club then
				table.insert(clubs, card)
			elseif suit == sgs.Card_Diamond then
				table.insert(diamonds, card)
			end
		end
		local ups, downs, forwards, backs = changeSuitsToDirections(spades, hearts, clubs, diamonds)
		local e_up = msg["Up"] or 0
		if e_up > 0 and #ups > 0 then
			self:sortByUseValue(ups, true)
			self.ocx_energy_invoke["Up"] = e_up - 1
			return ups[1]:getEffectiveId()
		end
		local e_down = msg["Down"] or 0
		if e_down > 0 and #downs > 0 then
			self:sortByUseValue(downs, true)
			self.ocx_energy_invoke["Down"] = e_down - 1
			return downs[1]:getEffectiveId()
		end
		local e_forward = msg["Forward"] or 0
		if e_forward > 0 and #forwards > 0 then
			self:sortByUseValue(forwards, true)
			self.ocx_energy_invoke["Forward"] = e_forward - 1
			return forwards[1]:getEffectiveId()
		end
		local e_back = msg["Back"] or 0
		if e_back > 0 and #backs > 0 then
			self:sortByUseValue(backs, true)
			self.ocx_energy_invoke["Back"] = e_back - 1
			return backs[1]:getEffectiveId()
		end
	end
end
--EnergyCard:Play
local energy_skill = {
	name = "ocEnergy",
	getTurnUseCard = function(self, inclusive)
		if self.player:hasUsed("#ocEnergyCard") then
			return nil
		elseif self.player:isKongcheng() then
			local pile = self.player:getPile("ocEnergyPile")
			if pile:isEmpty() then
				return nil
			end
		end
		return sgs.Card_Parse("#ocEnergyCard:.:")
	end,
}
table.insert(sgs.ai_skills, energy_skill)
sgs.ai_skill_use_func["#ocEnergyCard"] = function(card, use, self)
	use.card = card
end
--相关信息
sgs.ai_use_priority["ocEnergyCard"] = 7.8
sgs.ai_use_value["ocEnergyCard"] = 3
--[[
	技能：必杀
	描述：出牌阶段，你可以按一定顺序弃置一定数目的“向”，然后执行相应的效果。
]]--
--room:askForAG(source, pile, true, "ocXSkill")
sgs.ai_skill_askforag["ocXSkill"] = function(self, card_ids)
	local ocx_name = sgs.ocx_skill_name
	if type(ocx_name) == "string" then
		local info = sgs.ocx_skills[ocx_name]
		local command = info["command"]:split("+")
		local selected = self.ocx_selected or {}
		local index = #selected + 1
		local result, direction = nil, nil
		if index <= #command then
			direction = command[index]
			local spades, hearts, clubs, diamonds = {}, {}, {}, {}
			for _,id in ipairs(card_ids) do
				local card = sgs.Sanguosha:getCard(id)
				local suit = card:getSuit()
				if suit == sgs.Card_Spade then
					table.insert(spades, card)
				elseif suit == sgs.Card_Heart then
					table.insert(hearts, card)
				elseif suit == sgs.Card_Club then
					table.insert(clubs, card)
				elseif suit == sgs.Card_Diamond then
					table.insert(diamonds, card)
				end
			end
			local ups, downs, forwards, backs = changeSuitsToDirections(spades, hearts, clubs, diamonds)
			if direction == "Up" and #ups > 0 then
				self:sortByUseValue(ups, true)
				result = ups[1]:getEffectiveId()
			elseif direction == "Down" and #downs > 0 then
				self:sortByUseValue(downs, true)
				result = downs[1]:getEffectiveId()
			elseif direction == "Forward" and #forwards > 0 then
				self:sortByUseValue(forwards, true)
				result = forwards[1]:getEffectiveId()
			elseif direction == "Back" and #backs > 0 then
				self:sortByUseValue(backs, true)
				result = backs[1]:getEffectiveId()
			end
		end
		if result then
			table.insert(selected, direction)
		else
			selected = {}
		end
		self.ocx_selected = selected
		return result or -1
	end
	return -1
end
--room:askForChoice(source, "ocXSkill_KeySelect", choices, sgs.QVariant(command))
sgs.ai_skill_choice["ocXSkill_KeySelect"] = function(self, choices, data)
	local command = data:toString()
	local ocx_name = sgs.ocx_skill_name
	local valid_flag = false
	if type(ocx_name) == "string" then
		local info = sgs.ocx_skills[ocx_name]
		if type(info) == "table" then
			local cmd = info["command"]
			if type(cmd) == "string" and cmd == command then
				valid_flag = true
			end
		end
	end
	if not valid_flag then
		local ocx_names = {}
		for name, info in pairs(sgs.ocx_skills) do
			if type(info) == "table" then
				local skill = info["skill"]
				if skill and self.player:hasSkill(skill) then
					local cmd = info["command"]
					if cmd and cmd == command then
						table.insert(ocx_names, name)
					end
				end
			end
		end
		if #ocx_names > 0 then
			local valid, invalid = {}, {}
			for _, name in ipairs(ocx_names) do
				if isValid(self, name) then
					table.insert(valid, name)
				else
					table.insert(invalid, name)
				end
			end
			if #valid > 0 then
				local index = math.random(1, #valid)
				ocx_name = valid[index]
			elseif #invalid > 0 then
				local index = math.random(1, #invalid)
				ocx_name = invalid[index]
			end
		end
	end
	local keys = choices:split("+")
	if type(ocx_name) == "string" then
		local info = sgs.ocx_skills[ocx_name]
		for _,key in ipairs(keys) do
			if info[key] then
				return key
			end
		end
	end
	return keys[math.random(1, #keys)]
end
--room:askForChoice(source, "ocXSkill_SkillSelect", skills)
sgs.ai_skill_choice["ocXSkill_SkillSelect"] = function(self, choices, data)
	local choice = sgs.ocx_skill_name
	if choice and string.find(choices, choice) then
		return choice
	end
	local names = choices:split("+")
	local valid = {}
	for _,name in ipairs(names) do
		if isValid(self, name) then
			table.insert(valid, name)
		end
	end
	if #valid > 0 then
		return valid[math.random(1, #valid)]
	end
	return names[math.random(1, #names)]
end
--room:askForUseCard(source, "@@ocXSkill", "@"..skill)
sgs.ai_skill_use["@@ocXSkill"] = function(self, prompt, method)
	local ocx_skill = string.sub(prompt, 2)
	local callback = sgs.ocx_use_func[ocx_skill]
	if type(callback) == "function" then
		return callback(self) or "."
	end
	return "."
end
--XSkillCard:Play
local x_skill = {
	name = "ocXSkill",
	getTurnUseCard = function(self, inclusive)
		local pile = self.player:getPile("ocEnergyPile")
		if pile:isEmpty() then
			return nil
		end
		return sgs.Card_Parse("#ocXSkillCard:.:")
	end,
}
table.insert(sgs.ai_skills, x_skill)
sgs.ai_skill_use_func["#ocXSkillCard"] = function(card, use, self)
	sgs.ocx_skill_name = nil
	if #self.enemies == 0 then
		return 
	end
	local pile = self.player:getPile("ocEnergyPile")
	local count = pile:length()
	local spades, hearts, clubs, diamonds = {}, {}, {}, {}
	for _,id in sgs.qlist(pile) do
		local dir = sgs.Sanguosha:getCard(id)
		local suit = dir:getSuit()
		if suit == sgs.Card_Spade then
			table.insert(spades, dir)
		elseif suit == sgs.Card_Heart then
			table.insert(hearts, dir)
		elseif suit == sgs.Card_Club then
			table.insert(clubs, dir)
		elseif suit == sgs.Card_Diamond then
			table.insert(diamonds, dir)
		end
	end
	local ups, downs, forwards, backs = changeSuitsToDirections(spades, hearts, clubs, diamonds)
	local n_up, n_down, n_forward, n_back = #ups, #downs, #forwards, #backs
	local isMaxMode = false
	if self.player:getMark("@ocEnergyMark") > 0 then
		isMaxMode = true
	elseif self.player:getHp() <= 1 then
		isMaxMode = true
	end
	local ocx_names = {}
	for name, info in pairs(sgs.ocx_skills) do
		if type(info) == "table" then
			local max_mode = info["max_mode"] or false
			if count >= info["total"] and ( isMaxMode == max_mode ) then
				local skill = info["skill"]
				if self.player:hasSkill(skill) then
					local upNum = info["Up"] or 0
					local downNum = info["Down"] or 0
					local forwardNum = info["Forward"] or 0
					local backNum = info["Back"] or 0
					if n_up >= upNum and n_down >= downNum and n_forward >= forwardNum and n_back >= backNum then
						if isValid(self, name, info) then
							table.insert(ocx_names, name)
						end
					end
				end
			end
		end
	end
	if #ocx_names == 0 then
		return 
	end
	local ocx_name = ocx_names[math.random(1, #ocx_names)]
	use.card = card
	if not use.isDummy then
		sgs.ocx_skill_name = ocx_name
	end
end
--相关信息
sgs.ai_use_priority["ocXSkillCard"] = 7
sgs.ai_use_value["ocXSkillCard"] = 8
--[[****************************************************************
	编号：OROCHI - 001
	武将：莉安娜
	称号：嘉迪路之女
	势力：魏
	性别：女
	体力上限：3勾玉
]]--****************************************************************
--V字金锯
sgs.ocx_skills["ocXSkill_LEONA_XA"] = {
	name = "ocXSkill_LEONA_XA",
	skill = "#ocXSkill_LEONA_XA",
	command = "Up+Down+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 5,
	Up = 1,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_LEONA_XA"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_LEONA_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XA_Card"] = 200
--V字金锯·MAX
sgs.ocx_skills["ocXSkill_LEONA_XA_MAX"] = {
	name = "ocXSkill_LEONA_XA_MAX",
	skill = "#ocXSkill_LEONA_XA",
	command = "Up+Down+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 5,
	Up = 1,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_LEONA_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_LEONA_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XA_MAX_Card"] = 200
--旋转的火花
sgs.ocx_skills["ocXSkill_LEONA_XB"] = {
	name = "ocXSkill_LEONA_XB",
	skill = "#ocXSkill_LEONA_XB",
	command = "Down+Back+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_LEONA_XB"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_LEONA_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XB_Card"] = 200
--旋转的火花·MAX
sgs.ocx_skills["ocXSkill_LEONA_XB_MAX"] = {
	name = "ocXSkill_LEONA_XB_MAX",
	skill = "#ocXSkill_LEONA_XB",
	command = "Down+Back+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_LEONA_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_LEONA_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XB_MAX_Card"] = 200
--重力风暴
sgs.ocx_skills["ocXSkill_LEONA_XC"] = {
	name = "ocXSkill_LEONA_XC",
	skill = "#ocXSkill_LEONA_XC",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_LEONA_XC"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_LEONA_XC_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XC_Card"] = 200
--重力风暴·MAX
sgs.ocx_skills["ocXSkill_LEONA_XC_MAX"] = {
	name = "ocXSkill_LEONA_XC_MAX",
	skill = "#ocXSkill_LEONA_XC",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_LEONA_XC_MAX"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_LEONA_XC_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_LEONA_XC_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 002
	武将：八神庵
	称号：终焉之炎
	势力：蜀
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--禁千贰百拾壹式·八稚女
sgs.ocx_skills["ocXSkill_IORI_XA"] = {
	name = "ocXSkill_IORI_XA",
	skill = "#ocXSkill_IORI_XA",
	command = "Down+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_IORI_XA"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_IORI_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_IORI_XA_Card"] = 200
--禁千贰百拾壹式·八稚女·MAX
sgs.ocx_skills["ocXSkill_IORI_XA_MAX"] = {
	name = "ocXSkill_IORI_XA_MAX",
	skill = "#ocXSkill_IORI_XA",
	command = "Down+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_IORI_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_IORI_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_IORI_XA_MAX_Card"] = 200
--里百八式·八酒杯
sgs.ocx_skills["ocXSkill_IORI_XB"] = {
	name = "ocXSkill_IORI_XB",
	skill = "#ocXSkill_IORI_XB",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_IORI_XB"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_IORI_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_IORI_XB_Card"] = 200
--里百八式·八酒杯·MAX
sgs.ocx_skills["ocXSkill_IORI_XB_MAX"] = {
	name = "ocXSkill_IORI_XB_MAX",
	skill = "#ocXSkill_IORI_XB",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_IORI_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_IORI_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_IORI_XB_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 003
	武将：嘉迪路
	称号：致命之牙
	势力：群
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--守卫
sgs.ocx_skills["ocXSkill_GAIDEL_XA"] = {
	name = "ocXSkill_GAIDEL_XA",
	skill = "#ocXSkill_GAIDEL_XA",
	command = "Up+Back+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Up = 1,
	Down = 1,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_GAIDEL_XA"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_GAIDEL_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GAIDEL_XA_Card"] = 200
--守卫·MAX
sgs.ocx_skills["ocXSkill_GAIDEL_XA_MAX"] = {
	name = "ocXSkill_GAIDEL_XA_MAX",
	skill = "#ocXSkill_GAIDEL_XA",
	command = "Up+Back+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Up = 1,
	Down = 1,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_GAIDEL_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_GAIDEL_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GAIDEL_XA_MAX_Card"] = 200
--宽恕
sgs.ocx_skills["ocXSkill_GAIDEL_XB"] = {
	name = "ocXSkill_GAIDEL_XB",
	skill = "#ocXSkill_GAIDEL_XB",
	command = "Up+Up+Up",
	ocKeyA = true,
	ocKeyC = true,
	total = 3,
	Up = 3,
	max_mode = false,
	benefit = true,
	range = "allplayers",
}
sgs.ocx_use_func["ocXSkill_GAIDEL_XB"] = function(self)
	local target = getPriorTarget(self, "allplayers", true)
	if target then
		return "#ocXSkill_GAIDEL_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GAIDEL_XB_Card"] = -100
--宽恕·MAX
sgs.ocx_skills["ocXSkill_GAIDEL_XB_MAX"] = {
	name = "ocXSkill_GAIDEL_XB_MAX",
	skill = "#ocXSkill_GAIDEL_XB",
	command = "Up+Up+Up",
	ocKeyA = true,
	ocKeyC = true,
	total = 3,
	Up = 3,
	max_mode = true,
	benefit = true,
	range = "allplayers",
}
sgs.ocx_use_func["ocXSkill_GAIDEL_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "allplayers", true)
	if target then
		return "#ocXSkill_GAIDEL_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GAIDEL_XB_MAX_Card"] = -100
--[[****************************************************************
	编号：OROCHI - 004
	武将：薇思
	称号：战争圣女
	势力：蜀
	性别：女
	体力上限：3勾玉
]]--****************************************************************
--连续反身打
sgs.ocx_skills["ocXSkill_VICE_XA"] = {
	name = "ocXSkill_VICE_XA",
	skill = "#ocXSkill_VICE_XA",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = false,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_VICE_XA"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_VICE_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_VICE_XA_Card"] = 200
--连续反身打·MAX
sgs.ocx_skills["ocXSkill_VICE_XA_MAX"] = {
	name = "ocXSkill_VICE_XA_MAX",
	skill = "#ocXSkill_VICE_XA",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = true,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_VICE_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_VICE_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_VICE_XA_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 005
	武将：麦卓
	称号：鬼敏女豹
	势力：魏
	性别：女
	体力上限：3勾玉
]]--****************************************************************
--天国滑行
sgs.ocx_skills["ocXSkill_MATURE_XA"] = {
	name = "ocXSkill_MATURE_XA",
	skill = "#ocXSkill_MATURE_XA",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_MATURE_XA"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_MATURE_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_MATURE_XA_Card"] = 200
--天国滑行·MAX
sgs.ocx_skills["ocXSkill_MATURE_XA_MAX"] = {
	name = "ocXSkill_MATURE_XA_MAX",
	skill = "#ocXSkill_MATURE_XA",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_MATURE_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_MATURE_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_MATURE_XA_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 006
	武将：山崎龙二
	称号：死亡狂乱
	势力：群
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--断头台
sgs.ocx_skills["ocXSkill_YAMAZAKI_XA"] = {
	name = "ocXSkill_YAMAZAKI_XA",
	skill = "#ocXSkill_YAMAZAKI_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_YAMAZAKI_XA"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_YAMAZAKI_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YAMAZAKI_XA_Card"] = 200
--断头台·MAX
sgs.ocx_skills["ocXSkill_YAMAZAKI_XA_MAX"] = {
	name = "ocXSkill_YAMAZAKI_XA_MAX",
	skill = "#ocXSkill_YAMAZAKI_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_YAMAZAKI_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_YAMAZAKI_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YAMAZAKI_XA_MAX_Card"] = 200
--射杀
sgs.ocx_skills["ocXSkill_YAMAZAKI_XB"] = {
	name = "ocXSkill_YAMAZAKI_XB",
	skill = "#ocXSkill_YAMAZAKI_XB",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = false,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YAMAZAKI_XB"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YAMAZAKI_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YAMAZAKI_XB_Card"] = 200
--射杀·MAX
sgs.ocx_skills["ocXSkill_YAMAZAKI_XB_MAX"] = {
	name = "ocXSkill_YAMAZAKI_XB_MAX",
	skill = "#ocXSkill_YAMAZAKI_XB",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = true,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YAMAZAKI_XB"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YAMAZAKI_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YAMAZAKI_XB_MAX_Card"] = 200
--room:askForCardChosen(source, target, "hej", "ocXSkill_YAMAZAKI_XA") 
--room:askForCardChosen(source, target, "hej", "ocXSkill_YAMAZAKI_XA_MAX") 
--room:askForCardChosen(source, target, "he", "ocXSkill_YAMAZAKI_XB")
--[[****************************************************************
	编号：OROCHI - 007
	武将：克里斯
	称号：炎之觉醒
	势力：蜀
	性别：男
	体力上限：3勾玉
]]--****************************************************************
--暗黑大蛇薙
sgs.ocx_skills["ocXSkill_CHRIS_XA"] = {
	name = "ocXSkill_CHRIS_XA",
	skill = "#ocXSkill_CHRIS_XA",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_CHRIS_XA"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_CHRIS_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_CHRIS_XA_Card"] = 200
--暗黑大蛇薙·MAX
sgs.ocx_skills["ocXSkill_CHRIS_XA_MAX"] = {
	name = "ocXSkill_CHRIS_XA_MAX",
	skill = "#ocXSkill_CHRIS_XA",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_CHRIS_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_CHRIS_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_CHRIS_XA_MAX_Card"] = 200
--拂大地之禁果
sgs.ocx_skills["ocXSkill_CHRIS_XB"] = {
	name = "ocXSkill_CHRIS_XB",
	skill = "#ocXSkill_CHRIS_XB",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_CHRIS_XB"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_CHRIS_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_CHRIS_XB_Card"] = 200
--拂大地之禁果·MAX
sgs.ocx_skills["ocXSkill_CHRIS_XB_MAX"] = {
	name = "ocXSkill_CHRIS_XB_MAX",
	skill = "#ocXSkill_CHRIS_XB",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_CHRIS_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_CHRIS_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_CHRIS_XB_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 008
	武将：夏尔米
	称号：荒稻雷光
	势力：蜀
	性别：女
	体力上限：4勾玉
]]--****************************************************************
--暗黑雷光拳
sgs.ocx_skills["ocXSkill_SHERMIE_XA"] = {
	name = "ocXSkill_SHERMIE_XA",
	skill = "#ocXSkill_SHERMIE_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_SHERMIE_XA"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_SHERMIE_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_SHERMIE_XA_Card"] = 200
--暗黑雷光拳·MAX
sgs.ocx_skills["ocXSkill_SHERMIE_XA_MAX"] = {
	name = "ocXSkill_SHERMIE_XA_MAX",
	skill = "#ocXSkill_SHERMIE_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_SHERMIE_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_SHERMIE_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_SHERMIE_XA_MAX_Card"] = 200
--宿命·幻影·振子
sgs.ocx_skills["ocXSkill_SHERMIE_XB"] = {
	name = "ocXSkill_SHERMIE_XB",
	skill = "#ocXSkill_SHERMIE_XB",
	command = "Down+Forward+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_SHERMIE_XB"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_SHERMIE_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_SHERMIE_XB_Card"] = 200
--宿命·幻影·振子·MAX
sgs.ocx_skills["ocXSkill_SHERMIE_XB_MAX"] = {
	name = "ocXSkill_SHERMIE_XB_MAX",
	skill = "#ocXSkill_SHERMIE_XB",
	command = "Down+Forward+Down+Forward",
	ocKeyB = true,
	ocKeyD = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_SHERMIE_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_SHERMIE_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_SHERMIE_XB_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 009
	武将：七枷社
	称号：干枯大地
	势力：蜀
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--吼大地
sgs.ocx_skills["ocXSkill_YASHIRO_XA"] = {
	name = "ocXSkill_YASHIRO_XA",
	skill = "#ocXSkill_YASHIRO_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = false,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XA"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_YASHIRO_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XA_Card"] = 200
--吼大地·MAX
sgs.ocx_skills["ocXSkill_YASHIRO_XA_MAX"] = {
	name = "ocXSkill_YASHIRO_XA_MAX",
	skill = "#ocXSkill_YASHIRO_XA",
	command = "Down+Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 2,
	max_mode = true,
	range = "inMyAttackRange",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "inMyAttackRange")
	if target then
		return "#ocXSkill_YASHIRO_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XA_MAX_Card"] = 200
--荒大地
sgs.ocx_skills["ocXSkill_YASHIRO_XB"] = {
	name = "ocXSkill_YASHIRO_XB",
	skill = "#ocXSkill_YASHIRO_XB",
	command = "Back+Down+Forward+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = false,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XB"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YASHIRO_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XB_Card"] = 200
--荒大地·MAX
sgs.ocx_skills["ocXSkill_YASHIRO_XB_MAX"] = {
	name = "ocXSkill_YASHIRO_XB_MAX",
	skill = "#ocXSkill_YASHIRO_XB",
	command = "Back+Down+Forward+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = true,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YASHIRO_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XB_MAX_Card"] = 200
local system_updateIntention = sgs.updateIntention
function sgs.updateIntention(from, to, intention, card)
	if from and from:hasFlag("AI_DoNotUpdateIntention") then
		from:setFlags("-AI_DoNotUpdateIntention")
		return 
	end
	system_updateIntention(from, to, intention, card)
end
--暗黑地狱极乐落
sgs.ocx_skills["ocXSkill_YASHIRO_XC"] = {
	name = "ocXSkill_YASHIRO_XC",
	skill = "#ocXSkill_YASHIRO_XC",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = false,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XC"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YASHIRO_XC_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XC_Card"] = 200
--暗黑地狱极乐落·MAX
sgs.ocx_skills["ocXSkill_YASHIRO_XC_MAX"] = {
	name = "ocXSkill_YASHIRO_XC_MAX",
	skill = "#ocXSkill_YASHIRO_XC",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = true,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_YASHIRO_XC_MAX"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_YASHIRO_XC_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_YASHIRO_XC_MAX_Card"] = 200
--room:askForCardChosen(last_player, target, "he", "ocXSkill_YASHIRO_XB_MAX")
--room:askForCardChosen(next_player, target, "he", "ocXSkill_YASHIRO_XB_MAX")
--[[****************************************************************
	编号：OROCHI - 010
	武将：高尼茨
	称号：息吹暴风
	势力：魏
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--黑暗哭泣
sgs.ocx_skills["ocXSkill_GOENITZ_XA"] = {
	name = "ocXSkill_GOENITZ_XA",
	skill = "#ocXSkill_GOENITZ_XA",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = false,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_GOENITZ_XA"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_GOENITZ_XA_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GOENITZ_XA_Card"] = 200
--黑暗哭泣·MAX
sgs.ocx_skills["ocXSkill_GOENITZ_XA_MAX"] = {
	name = "ocXSkill_GOENITZ_XA_MAX",
	skill = "#ocXSkill_GOENITZ_XA",
	command = "Forward+Down+Back+Forward+Down+Back",
	ocKeyC = true,
	total = 6,
	Down = 2,
	Forward = 2,
	Back = 2,
	max_mode = true,
	range = "distance = 1",
}
sgs.ocx_use_func["ocXSkill_GOENITZ_XA_MAX"] = function(self)
	local target = getPriorTarget(self, "distance = 1")
	if target then
		return "#ocXSkill_GOENITZ_XA_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GOENITZ_XA_MAX_Card"] = 200
--真·八稚女·蛟
sgs.ocx_skills["ocXSkill_GOENITZ_XB"] = {
	name = "ocXSkill_GOENITZ_XB",
	skill = "#ocXSkill_GOENITZ_XB",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_GOENITZ_XB"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_GOENITZ_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GOENITZ_XB_Card"] = 200
--真·八稚女·实相克
sgs.ocx_skills["ocXSkill_GOENITZ_XB_MAX"] = {
	name = "ocXSkill_GOENITZ_XB_MAX",
	skill = "#ocXSkill_GOENITZ_XB",
	command = "Down+Back+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 4,
	Down = 2,
	Forward = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_GOENITZ_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_GOENITZ_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_GOENITZ_XB_MAX_Card"] = 200
--[[****************************************************************
	编号：OROCHI - 011
	武将：大蛇
	称号：地球意志
	势力：神
	性别：男
	体力上限：4勾玉
]]--****************************************************************
--混·まろかれ
sgs.ocx_skills["ocXSkill_OROCHI_XA"] = {
	name = "ocXSkill_OROCHI_XA",
	skill = "#ocXSkill_OROCHI_XA",
	command = "Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 2,
	Down = 1,
	Back = 1,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_OROCHI_XA"] = function(self)
	local safe = true
	if self.role == "renegade" and self.room:alivePlayerCount() > 2 then
		safe = false
	elseif self.role == "loyalist" then
		safe = false
	end
	local damage = 3
	local JinXuanDi = self.room:findPlayerBySkillName("wuling")
	if JinXuanDi and JinXuanDi:getMark("@wind") > 0 then
		damage = damage + 2
	end
	if not safe then
		local lord = getLord(self.player)
		if lord then
			if self:damageIsEffective(lord, sgs.DamageStruct_Fire, nil) then
				local next_player = lord:getNextAlive()
				if next_player and next_player:objectName() == self.player:objectName() then
					safe = true
				elseif lord:getHp() + self:getAllPeachNum(lord) > damage then
					safe = true
				end
			else
				safe = true
			end
		end
	end
	if safe then
		return "#ocXSkill_OROCHI_XA_Card:.:->."
	end
	return "."
end
--混·まろかれ·MAX
sgs.ocx_skills["ocXSkill_OROCHI_XA_MAX"] = {
	name = "ocXSkill_OROCHI_XA_MAX",
	skill = "#ocXSkill_OROCHI_XA",
	command = "Down+Back",
	ocKeyA = true,
	ocKeyC = true,
	total = 2,
	Down = 1,
	Back = 1,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_OROCHI_XA_MAX"] = function(self)
	local safe = true
	if self.role == "renegade" and self.room:alivePlayerCount() > 2 then
		safe = false
	elseif self.role == "loyalist" then
		safe = false
	end
	local damage = 5
	local JinXuanDi = self.room:findPlayerBySkillName("wuling")
	if JinXuanDi and JinXuanDi:getMark("@wind") > 0 then
		damage = damage + 2
	end
	if not safe then
		local lord = getLord(self.player)
		if lord then
			if self:damageIsEffective(lord, sgs.DamageStruct_Fire, nil) then
				local next_player = lord:getNextAlive()
				if next_player and next_player:objectName() == self.player:objectName() then
					safe = true
				elseif lord:getHp() + self:getAllPeachNum(lord) > damage then
					safe = true
				end
			else
				safe = true
			end
		end
	end
	if safe then
		return "#ocXSkill_OROCHI_XA_MAX_Card:.:->."
	end
	return "."
end
--大神·おおみわ
sgs.ocx_skills["ocXSkill_OROCHI_XB"] = {
	name = "ocXSkill_OROCHI_XB",
	skill = "#ocXSkill_OROCHI_XB",
	command = "Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 3,
	Down = 1,
	Forward = 2,
	max_mode = false,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_OROCHI_XB"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_OROCHI_XB_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_OROCHI_XB_Card"] = 200
--大神·おおみわ·MAX
sgs.ocx_skills["ocXSkill_OROCHI_XB_MAX"] = {
	name = "ocXSkill_OROCHI_XB_MAX",
	skill = "#ocXSkill_OROCHI_XB",
	command = "Forward+Down+Forward",
	ocKeyA = true,
	ocKeyC = true,
	total = 3,
	Down = 1,
	Forward = 2,
	max_mode = true,
	range = "others",
}
sgs.ocx_use_func["ocXSkill_OROCHI_XB_MAX"] = function(self)
	local target = getPriorTarget(self, "others")
	if target then
		return "#ocXSkill_OROCHI_XB_MAX_Card:.:->"..target:objectName()
	end
	return "."
end
sgs.ai_card_intention["ocXSkill_OROCHI_XB_MAX_Card"] = 200