--[[
	太阳神三国杀武将扩展包·大蛇一族
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
		10、高尼茨（能量、必杀）＋（黑暗哭泣、真·八稚女·蛟）
		11、大蛇（能量、必杀）＋（混·まろかれ、大神·おおみわ）
	所需标记：
		1、@ocEnergyMark（“能量”标记，来自技能“能量”）
]]--
module("extensions.orochies", package.seeall)
extension = sgs.Package("orochies", sgs.Package_GeneralPack)
json = require("json")
--技能暗将
AnJiang = sgs.General(extension, "ocAnJiang", "god", 5, true, true, true)
--翻译信息
sgs.LoadTranslationTable{
	["orochies"] = "大蛇一族",
}
--[[****************************************************************
	通用技能
]]--****************************************************************
sgs.ocKeys = {
	spade = "Forward",
	heart = "Up",
	club = "Back",
	diamond = "Down",
}
sgs.ocXSkillSelects = {}
sgs.ocXSkillDetails = {}
sgs.ocXSkillCards = {}
--[[
	技能：能量
	描述：你造成或受到1点伤害后，或于回合外失去一张手牌后，你摸一张牌，
		然后你可以将一张手牌置于你的武将牌上，称为“向”（至多十张）。
		出牌阶段开始时，你可以弃置四张“向”，令你本阶段内造成的伤害+1。
		出牌阶段限一次，你可以获得所有的“向”，然后将至多十张手牌作为“向”置于你的武将牌上。
]]--
function doEnergy(room, source, count)
	room:setPlayerFlag(source, "ocEnergyIgnore")
	room:drawCards(source, count, "ocEnergy")
	for i=1, count, 1 do
		if source:isKongcheng() then
			break
		end
		local pile = source:getPile("ocEnergyPile")
		if pile:length() >= 10 then
			break
		end
		local card = room:askForCard(source, ".", "@ocEnergy", sgs.QVariant(), sgs.Card_MethodNone, source, false, "ocEnergy")
		if card then
			source:addToPile("ocEnergyPile", card, true)
		else
			break
		end
	end
	room:setPlayerFlag(source, "-ocEnergyIgnore")
end
EnergyGatherCard = sgs.CreateSkillCard{
	name = "ocEnergyGatherCard",
	skill_name = "ocEnergy",
	target_fixed = true,
	will_throw = false,
	mute = true,
	on_use = function(self, room, source, targets)
		source:addToPile("ocEnergyPile", self, true)
	end,
}
EnergyCard = sgs.CreateSkillCard{
	name = "ocEnergyCard",
	skill_name = "ocEnergy",
	target_fixed = true,
	will_throw = true,
	mute = true,
	on_use = function(self, room, source, targets)
		local pile = source:getPile("ocEnergyPile")
		if not pile:isEmpty() then
			local move = sgs.CardsMoveStruct()
			move.from = source
			move.from_place = sgs.Player_PlaceSpecial
			move.to = source
			move.to_place = sgs.Player_PlaceHand
			move.card_ids = pile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_EXCHANGE_FROM_PILE, source:objectName())
			room:moveCardsAtomic(move, true)
		end
		room:setPlayerFlag(source, "ocEnergyGathering")
		room:askForUseCard(source, "@@ocEnergy", "@ocEnergy-gather")
		room:setPlayerFlag(source, "-ocEnergyGathering")
	end,
}
EnergyVS = sgs.CreateViewAsSkill{
	name = "ocEnergy",
	n = 10,
	view_filter = function(self, selected, to_select)
		if sgs.Self:hasFlag("ocEnergyGathering") then
			return not to_select:isEquipped()
		else
			return false
		end
	end,
	view_as = function(self, cards)
		if sgs.Self:hasFlag("ocEnergyGathering") then
			if #cards > 0 then
				local card = EnergyGatherCard:clone()
				for _,c in ipairs(cards) do
					card:addSubcard(c)
				end
				return card
			end
		else
			if #cards == 0 then
				return EnergyCard:clone()
			end
		end
	end,
	enabled_at_play = function(self, player)
		if player:hasFlag("ocEnergyGathering") then
			return false
		else
			if player:hasUsed("#ocEnergyCard") then
				return false
			elseif player:isKongcheng() then
				local pile = player:getPile("ocEnergyPile")
				return not pile:isEmpty()
			end
			return true
		end
	end,
	enabled_at_response = function(self, player, pattern)
		if player:hasFlag("ocEnergyGathering") then
			return pattern == "@@ocEnergy"
		else
			return false
		end
	end,
}
Energy = sgs.CreateTriggerSkill{
	name = "ocEnergy",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Damage, sgs.Damaged, sgs.CardsMoveOneTime, sgs.EventPhaseStart, sgs.EventPhaseEnd, sgs.DamageCaused},
	view_as_skill = EnergyVS,
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		if event == sgs.Damage then
			if player:hasFlag("ocEnergyIgnore") then
				return false
			end
			local damage = data:toDamage()
			local source = damage.from
			if source and source:objectName() == player:objectName() then
				doEnergy(room, source, damage.damage)
			end
		elseif event == sgs.Damaged then
			if player:hasFlag("ocEnergyIgnore") then
				return false
			end
			local damage = data:toDamage()
			local victim = damage.to
			if victim and victim:objectName() == player:objectName() then
				doEnergy(room, victim, damage.damage)
			end
		elseif event == sgs.CardsMoveOneTime then
			if player:hasFlag("ocEnergyIgnore") then
				return false
			end
			local move = data:toMoveOneTime()
			local source = move.from
			if source and source:objectName() == player:objectName() then
				if player:getPhase() == sgs.Player_NotActive then
					local count = 0
					for index, place in sgs.qlist(move.from_places) do
						if place == sgs.Player_PlaceHand then
							count = count + 1
						end
					end
					if count > 0 then
						doEnergy(room, player, count)
					end
				end
			end
		elseif event == sgs.EventPhaseStart then
			if player:getPhase() == sgs.Player_Play then
				if player:getMark("@ocEnergyMark") == 0 then
					local pile = player:getPile("ocEnergyPile")
					local num = pile:length()
					if num >= 4 then
						if player:askForSkillInvoke("ocEnergy", data) then
							if num == 4 then
								player:clearOnePrivatePile("ocEnergyPile")
							else
								local to_throw = sgs.IntList()
								for i=1, 4, 1 do
									room:fillAG(pile, player)
									local id = room:askForAG(player, pile, false, "ocEnergy")
									room:clearAG(player)
									if id > 0 then
										pile:removeOne(id)
										to_throw:append(id)
									end
								end
								local move = sgs.CardsMoveStruct()
								move.card_ids = to_throw
								move.to = nil
								move.to_place = sgs.Player_DiscardPile
								move.reason = sgs.CardMoveReason(
									sgs.CardMoveReason_S_REASON_REMOVE_FROM_PILE, 
									player:objectName()
								)
								room:moveCardsAtomic(move, true)
							end
							player:gainMark("@ocEnergyMark", 1)
						end
					end
				end
			end
		elseif event == sgs.EventPhaseEnd then
			if player:getPhase() == sgs.Player_Play then
				if player:getMark("@ocEnergyMark") > 0 then
					player:loseAllMarks("@ocEnergyMark")
				end
			end
		elseif event == sgs.DamageCaused then
			if player:hasFlag("ocEnergyIgnore") then
				return false
			end
			local damage = data:toDamage()
			local source = damage.from
			if source and source:objectName() == player:objectName() then
				if player:getMark("@ocEnergyMark") > 0 then
					local msg = sgs.LogMessage()
					msg.type = "#ocEnergyEffect"
					msg.from = player
					local count = damage.damage
					msg.arg = count
					count = count + 1
					msg.arg2 = count
					room:sendLog(msg) --发送提示信息
					damage.damage = count
					data:setValue(damage)
				end
			end
		end
		return false
	end,
}
--添加技能
AnJiang:addSkill(Energy)
--翻译信息
sgs.LoadTranslationTable{
	["ocEnergy"] = "能量",
	[":ocEnergy"] = "你造成或受到1点伤害后，或于回合外失去一张手牌后，你摸一张牌，然后你可以将一张手牌置于你的武将牌上，称为“向”（至多十张）。\
出牌阶段开始时，你可以弃置四张“向”，令你本阶段内造成的伤害+1。\
<font color=\"green\"><b>出牌阶段限一次</b></font>，你可以获得所有的“向”，然后将至多十张手牌作为“向”置于你的武将牌上。",
	["@ocEnergy"] = "您可以发动“能量”将一张手牌作为“向”置于武将牌上",
	["~ocEnergy"] = "选择一张手牌->点击“确定”",
	["@ocEnergy-gather"] = "您可以将至多十张手牌作为“向”置于武将牌上",
	["ocEnergyPile"] = "向",
	["@ocEnergyMark"] = "能量",
	["#ocEnergyEffect"] = "%from 处于能量状态，本次造成的伤害+1，从 %arg 点上升至 %arg2 点",
}
--[[
	技能：必杀
	描述：出牌阶段，你可以按一定顺序弃置一定数目的“向”，并选择对应的攻击模式，然后执行相应的效果。
]]--
function isMaxMode(player)
	if player:getMark("@ocEnergyMark") > 0 then
		return true
	elseif player:getHp() <= 1 then
		return true
	end
	return false
end
XSkillCard = sgs.CreateSkillCard{
	name = "ocXSkillCard",
	skill_name = "ocXSkill",
	target_fixed = false,
	will_throw = true,
	mute = true,
	filter = function(self, targets, to_select)
		if sgs.Self:hasFlag("ocXSkillSelect") then
			local skill = sgs.Self:property("ocXSkill"):toString()
			if skill ~= "" then
				local details = sgs.ocXSkillDetails[skill]
				if type(details) == "table" then
					local callback = details["filter"]
					if type(callback) == "function" then
						return callback(self, targets, to_select)
					end
				end
			end
			return false
		else
			return false
		end
	end,
	feasible = function(self, targets)
		if sgs.Self:hasFlag("ocXSkillSelect") then
			local skill = sgs.Self:property("ocXSkill"):toString()
			if skill ~= "" then
				local details = sgs.ocXSkillDetails[skill]
				if type(details) == "table" then
					local callback = details["feasible"]
					if type(callback) == "function" then
						return callback(self, targets)
					end
				end
			end
			return #targets > 0
		else
			return true
		end
	end,
	on_use = function(self, room, source, targets)
		local pile = source:getPile("ocEnergyPile")
		local command = {}
		local selected = sgs.IntList()
		while true do
			if pile:isEmpty() then
				break
			end
			room:fillAG(pile, source)
			local id = room:askForAG(source, pile, true, "ocXSkill")
			room:clearAG(source)
			if id == -1 then
				break
			end
			selected:append(id)
			pile:removeOne(id)
			local card = sgs.Sanguosha:getCard(id)
			local suit = card:getSuitString()
			local key = sgs.ocKeys[suit] or ""
			table.insert(command, key)
		end
		if not selected:isEmpty() then
			local move = sgs.CardsMoveStruct()
			move.card_ids = selected
			move.to = nil
			move.to_place = sgs.Player_DiscardPile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_REMOVE_FROM_PILE, source:objectName())
			room:moveCardsAtomic(move, true)
		end
		command = table.concat(command, "+")
		if command == "" then
			return 
		end
		local choices = "ocKeyA+ocKeyB+ocKeyC+ocKeyD"
		local key = room:askForChoice(source, "ocXSkill_KeySelect", choices, sgs.QVariant(command))
		local skills = {}
		for skill_name, judge_func in pairs(sgs.ocXSkillSelects) do
			if type(judge_func) == "function" then
				if judge_func(source, command, key) then
					table.insert(skills, skill_name)
				end
			end
		end
		if #skills == 0 then
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_FailCommand"
			msg.from = source
			room:sendLog(msg) --发送提示信息
			return 
		end
		skills = table.concat(skills, "+")
		local skill = room:askForChoice(source, "ocXSkill_SkillSelect", skills)
		room:setPlayerProperty(source, "ocXSkill", sgs.QVariant(skill))
		room:setPlayerFlag(source, "ocXSkillSelect")
		room:askForUseCard(source, "@@ocXSkill", "@"..skill)
		room:setPlayerFlag(source, "-ocXSkillSelect")
		room:setPlayerProperty(source, "ocXSkill", sgs.QVariant(""))
	end,
}
XSkill = sgs.CreateViewAsSkill{
	name = "ocXSkill",
	n = 0,
	view_as = function(self, cards)
		if sgs.Self:hasFlag("ocXSkillSelect") then
			local skill = sgs.Self:property("ocXSkill"):toString()
			if skill ~= "" then
				local card = sgs.ocXSkillCards[skill]
				if card then
					return card:clone()
				end
			end
		else
			return XSkillCard:clone()
		end
	end,
	enabled_at_play = function(self, player)
		local pile = player:getPile("ocEnergyPile")
		return not pile:isEmpty()
	end,
	enabled_at_response = function(self, player, pattern)
		return pattern == "@@ocXSkill"
	end,
}
--添加技能
AnJiang:addSkill(XSkill)
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill"] = "必杀",
	[":ocXSkill"] = "出牌阶段，你可以按一定顺序弃置一定数目的“向”，并选择对应的攻击模式，然后执行相应的效果。",
	["ocXSkill_KeySelect"] = "攻击模式",
	["ocXSkill_SkillSelect"] = "必杀选择",
	["ocKeyA"] = "轻拳",
	["ocKeyB"] = "轻脚",
	["ocKeyC"] = "重拳",
	["ocKeyD"] = "重脚",
	["~ocXSkill"] = "选择目标角色->点击“确定”",
	["#ocXSkill_FailCommand"] = "%from 的指令输入错误！未能成功发动必杀技",
}
--[[
	技能：八稚女（七重效果部分）
	效果：
		1、随机弃置目标一张牌
		2、随机获得目标一张牌
		3、目标失去1点体力
		4、目标受到1点伤害
		5、对目标造成1点伤害
		6、对目标造成1点火焰伤害
		7、对目标造成1点雷电伤害
		8、目标翻面
]]--
function doBaZhiNv(room, source, target, map)
	local range = #map
	local thread = room:getThread()
	local last_code = 0
	for i=1, 7, 1 do
		local index = math.random(1, range)
		local code = map[index]
		if code == 1 then
			local cards = target:getCards("he")
			local can_throw = {}
			for _,card in sgs.qlist(cards) do
				if source:canDiscard(target, card:getEffectiveId()) then
					table.insert(can_throw, card)
				end
			end
			if #can_throw > 0 then
				local index = math.random(1, #can_throw)
				local to_throw = can_throw[index]
				room:throwCard(to_throw, target, source)
				if last_code == code then
					thread:delay()
				end
			end
		elseif code == 2 then
			local cards = target:getCards("he")
			local count = cards:length()
			if count > 0 then
				local index = math.random(0, count-1)
				local to_obtain = cards:at(index)
				room:obtainCard(source, to_obtain, true)
				if last_code == code then
					thread:delay()
				end
			end
		elseif code == 3 then
			room:loseHp(target, 1)
			if last_code == code then
				thread:delay()
			end
		elseif code == 4 then
			local damage = sgs.DamageStruct()
			damage.from = nil
			damage.to = target
			damage.damage = 1
			room:damage(damage)
			thread:delay()
		elseif code == 5 then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 1
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
			thread:delay()
		elseif code == 6 then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Fire
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
			thread:delay()
		elseif code == 7 then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Thunder
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
			thread:delay()
		elseif code == 8 then
			target:turnOver()
			if last_code == code then
				thread:delay()
			end
		end
		if target:isDead() or source:isDead() then
			return false
		end
		last_code = code
	end
	return true
end
--[[****************************************************************
	编号：OROCHI - 001
	武将：莉安娜
	称号：嘉迪路之女
	势力：魏
	性别：女
	体力上限：3勾玉
]]--****************************************************************
LEONA = sgs.General(extension, "ocLEONA", "wei", 3, false)
--添加通用技能
LEONA:addSkill("ocEnergy")
LEONA:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocLEONA"] = "莉安娜",
	["&ocLEONA"] = "莉安娜",
	["#ocLEONA"] = "嘉迪路之女",
	["designer:ocLEONA"] = "DGAH",
	["cv:ocLEONA"] = "弓雅枝",
	["illustrator:ocLEONA"] = "网络资源",
	["~ocLEONA"] = "（惨叫声）",
}
--[[
	必杀：V字金锯
	出招：跳跃+下前下后+拳
	指令：红心+方块+黑桃+方块+草花 -> 轻拳/重拳
	描述：你可以选择一名其他角色，随机弃置其一半数目的手牌，并对其造成X/2点伤害（X为其体力上限，结果向上取整）。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_LEONA_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XA") then
		if command == "Up+Down+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XA"] = {
	name = "ocXSkill_LEONA_XA_Card",
	--skill_name = "ocXSkill_LEONA_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XA", 1) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(200)
		local handcards = target:handCards()
		local count = handcards:length()
		if count > 0 then
			local to_throw = sgs.IntList()
			local card_ids = handcards
			local num = math.ceil( count / 2 )
			for i=1, num, 1 do
				count = card_ids:length()
				local index = math.random(0, count-1)
				local id = card_ids:at(index)
				to_throw:append(id)
				card_ids:removeAt(index)
			end
			if num > 0 then
				local move = sgs.CardsMoveStruct()
				move.from = target
				move.from_place = sgs.Player_PlaceHand
				move.to = nil
				move.to_place = sgs.Player_DiscardPile
				move.card_ids = to_throw
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_DISMANTLE, source:objectName())
				room:moveCardsAtomic(move, true)
			end
		end
		if target:isAlive() and source:isAlive() then
			local maxhp = target:getMaxHp()
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = math.ceil( maxhp / 2 )
			thread:delay(1000)
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_LEONA_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XA") then
		if command == "Up+Down+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XA_MAX"] = {
	name = "ocXSkill_LEONA_XA_MAX_Card",
	--skill_name = "ocXSkill_LEONA_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XA", 2) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1500)
		local maxhp = target:getMaxHp()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = math.ceil( 2 * maxhp / 3 )
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() and source:isAlive() then
			local handcards = target:handCards()
			local count = handcards:length()
			if count > 0 then
				local to_throw = sgs.IntList()
				local card_ids = handcards
				local num = math.ceil( count / 2 )
				for i=1, num, 1 do
					count = card_ids:length()
					local index = math.random(0, count-1)
					local id = card_ids:at(index)
					to_throw:append(id)
					card_ids:removeAt(index)
				end
				if num > 0 then
					thread:delay(600)
					local move = sgs.CardsMoveStruct()
					move.from = target
					move.from_place = sgs.Player_PlaceHand
					move.to = nil
					move.to_place = sgs.Player_DiscardPile
					move.card_ids = to_throw
					move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_DISMANTLE, source:objectName())
					room:moveCardsAtomic(move, true)
				end
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XA_MAX"])
--技能效果
LEONA_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_LEONA_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
LEONA_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_LEONA_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(LEONA_XA_Audio)
LEONA:addSkill(LEONA_XA)
LEONA:addRelateSkill("ocXSkill_LEONA_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_LEONA_XA"] = "V字金锯",
	["$ocXSkill_LEONA_XA"] = "（V字金锯 的音效）",
	["@ocXSkill_LEONA_XA"] = "V字金锯：您可以选择一名其他角色，随机弃置其一半数目的手牌，并对其造成X/2点伤害（X为其体力上限，结果向上取整）",
	["ocXSkill_LEONA_XA_MAX"] = "V字金锯·MAX",
	["@ocXSkill_LEONA_XA_MAX"] = "V字金锯·MAX：您可以选择一名其他角色，对其造成2X/3点伤害，然后随机弃置其一半数目的手牌（X为其体力上限，结果向上取整）",
	["ocxskill_leona_xa_"] = "V字金锯",
	["ocxskill_leona_xa_max_"] = "V字金锯·MAX",
}
--[[
	必杀：旋转的火花
	出招：下后下前+脚
	指令：方块+草花+方块+黑桃 -> 轻脚/重脚
	描述：你可以选择一名其他角色，令其所有技能无效并将武将牌翻至背面朝上。该角色再次翻面时，你对其造成X/2点伤害（X为该角色的体力上限，结果向上取整），然后其所有技能恢复有效。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_LEONA_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XB"] = {
	name = "ocXSkill_LEONA_XB_Card",
	--skill_name = "ocXSkill_LEONA_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XB", 1) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1500)
		room:setPlayerMark(target, "ocXSkill_LEONA_XB_Skill_Invalid", 1)
		local alives = room:getAlivePlayers()
		for _,p in sgs.qlist(alives) do
			local cards = p:getCards("he")
			room:filterCards(p, cards, true)
		end
		room:doBroadcastNotify(40, json.encode({9}))
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_LEONA_XB_Skill_Effect"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_LEONA_XB"
		room:sendLog(msg) --发送提示信息
		if target:faceUp() then
			target:turnOver()
		end
		room:setPlayerMark(target, "ocXSkill_LEONA_XB_Effect", 1)
		room:setPlayerProperty(target, "ocXSkill_LEONA_XB_Source", sgs.QVariant(source:objectName()))
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XB"])
--MAX版
sgs.ocXSkillSelects["ocXSkill_LEONA_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XB_MAX"] = {
	name = "ocXSkill_LEONA_XB_MAX_Card",
	--skill_name = "ocXSkill_LEONA_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XB", 2) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1500)
		room:setPlayerMark(target, "ocXSkill_LEONA_XB_Skill_Invalid", 1)
		local alives = room:getAlivePlayers()
		for _,p in sgs.qlist(alives) do
			local cards = p:getCards("he")
			room:filterCards(p, cards, true)
		end
		room:doBroadcastNotify(40, json.encode({9}))
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_LEONA_XB_Skill_Effect"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_LEONA_XB_MAX"
		room:sendLog(msg) --发送提示信息
		if target:faceUp() then
			target:turnOver()
		end
		room:setPlayerMark(target, "ocXSkill_LEONA_XB_Effect", 1)
		room:setPlayerProperty(target, "ocXSkill_LEONA_XB_Source", sgs.QVariant(source:objectName()))
		room:setPlayerMark(target, "ocXSkill_LEONA_XB_MAX_Effect", 1)
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XB_MAX"])
--技能效果
LEONA_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_LEONA_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
LEONA_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_LEONA_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.TurnedOver},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		room:setPlayerMark(player, "ocXSkill_LEONA_XB_Effect", 0)
		local name = player:property("ocXSkill_LEONA_XB_Source"):toString() or ""
		room:setPlayerProperty(player, "ocXSkill_LEONA_XB_Source", sgs.QVariant(""))
		local source = nil
		local alives = room:getAlivePlayers()
		for _,p in sgs.qlist(alives) do
			if p:objectName() == name then
				source = p
				break
			end
		end
		local max_mode = false
		if player:getMark("ocXSkill_LEONA_XB_MAX_Effect") > 0 then
			room:setPlayerMark(player, "ocXSkill_LEONA_XB_MAX_Effect", 0)
			max_mode = true
		end
		if source then
			local maxhp = player:getMaxHp()
			local x = max_mode and math.ceil( 2 * maxhp / 3 ) or math.ceil( maxhp / 2 )
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = player
			damage.damage = x
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
		if player:getMark("ocXSkill_LEONA_XB_Skill_Invalid") > 0 then
			room:setPlayerMark(player, "ocXSkill_LEONA_XB_Skill_Invalid", 0)
			for _,p in sgs.qlist(alives) do
				local cards = p:getCards("he")
				room:filterCards(p, cards, false)
			end
			room:doBroadcastNotify(40, json.encode({9}))
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_LEONA_XB_Effect_Clear"
			msg.from = player
			msg.arg = max_mode and "ocXSkill_LEONA_XB_MAX" or "ocXSkill_LEONA_XB"
			room:sendLog(msg) --发送提示信息
		end
	end,
	can_trigger = function(self, target)
		if target and target:isAlive() then
			return target:getMark("ocXSkill_LEONA_XB_Effect") > 0
		end
	end,
}
LEONA_XB_Effect = sgs.CreateInvaliditySkill{
	name = "#ocXSkill_LEONA_XB_Effect",
	skill_valid = function(self, player, skill)
		if player:getMark("ocXSkill_LEONA_XB_Skill_Invalid") > 0 then
			return false
		end
		return true
	end
}
--添加技能
AnJiang:addSkill(LEONA_XB_Audio)
LEONA:addSkill(LEONA_XB)
LEONA:addSkill(LEONA_XB_Effect)
LEONA:addRelateSkill("ocXSkill_LEONA_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_LEONA_XB"] = "旋转的火花",
	["$ocXSkill_LEONA_XB"] = "さよなら…",
	["@ocXSkill_LEONA_XB"] = "旋转的火花：您可以选择一名其他角色，令其所有技能无效并将武将牌翻至背面朝上。该角色再次翻面时，你对其造成X/2点伤害（X为该角色的体力上限，结果向上取整），然后其所有技能恢复有效",
	["ocXSkill_LEONA_XB_MAX"] = "旋转的火花·MAX",
	["@ocXSkill_LEONA_XB_MAX"] = "旋转的火花·MAX：您可以选择一名其他角色，令其所有技能无效并将武将牌翻至背面朝上。该角色再次翻面时，你对其造成2X/3点伤害（X为该角色的体力上限，结果向上取整），然后其所有技能恢复有效",
	["#ocXSkill_LEONA_XB_Skill_Effect"] = "%from 发动了“%arg”，令 %to 的所有技能无效直至其再次翻面",
	["#ocXSkill_LEONA_XB_Effect_Clear"] = "%from 的武将牌翻面，受到“%arg”的影响消失，技能恢复有效",
	["ocxskill_leona_xb_"] = "旋转的火花",
	["ocxskill_leona_xb_max_"] = "旋转的火花·MAX",
}
--[[
	必杀：重力风暴
	出招：下前下前+拳
	指令：方块+黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，若其在你的攻击范围内，你随机弃置其三张牌，然后对其造成2点火焰伤害，否则你摸一张牌。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_LEONA_XC"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XC") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XC"] = {
	name = "ocXSkill_LEONA_XC_Card",
	--skill_name = "ocXSkill_LEONA_XC",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XC", 1) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		if source:inMyAttackRange(target) then
			for i=1, 3, 1 do
				local cards = target:getCards("he")
				if cards:isEmpty() then
					break
				end
				local index = math.random(0, cards:length() - 1)
				local card = cards:at(index)
				if source:canDiscard(target, card:getEffectiveId()) then
					room:throwCard(card, target, source)
					thread:delay(400)
				end
			end
			thread:delay(600)
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 2
			damage.nature = sgs.DamageStruct_Fire
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		else
			room:drawCards(source, 1, "ocXSkill_LEONA_XC")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XC"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XC"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_LEONA_XC_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_LEONA_XC") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_LEONA_XC_MAX"] = {
	name = "ocXSkill_LEONA_XC_MAX_Card",
	--skill_name = "ocXSkill_LEONA_XC_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_LEONA_XC", 2) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		if source:inMyAttackRange(target) then
			for i=1, 5, 1 do
				local cards = target:getCards("he")
				if cards:isEmpty() then
					break
				end
				local index = math.random(0, cards:length() - 1)
				local card = cards:at(index)
				if source:canDiscard(target, card:getEffectiveId()) then
					room:throwCard(card, target, source)
					thread:delay(300)
				end
			end
			thread:delay(600)
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 3
			damage.nature = sgs.DamageStruct_Fire
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		else
			room:drawCards(source, 1, "ocXSkill_LEONA_XC_MAX")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_LEONA_XC_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_LEONA_XC_MAX"])
--技能效果
LEONA_XC_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_LEONA_XC",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
LEONA_XC = sgs.CreateTriggerSkill{
	name = "#ocXSkill_LEONA_XC",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(LEONA_XC_Audio)
LEONA:addSkill(LEONA_XC)
LEONA:addRelateSkill("ocXSkill_LEONA_XC")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_LEONA_XC"] = "重力风暴",
	["$ocXSkill_LEONA_XC"] = "（重力风暴 的音效）",
	["@ocXSkill_LEONA_XC"] = "重力风暴：您可以选择一名其他角色，若其在你的攻击范围内，你随机弃置其三张牌，然后对其造成2点火焰伤害，否则你摸一张牌",
	["ocXSkill_LEONA_XC_MAX"] = "重力风暴·MAX",
	["@ocXSkill_LEONA_XC_MAX"] = "重力风暴·MAX：您可以选择一名其他角色，若其在你的攻击范围内，你随机弃置其五张牌，然后对其造成3点火焰伤害，否则你摸一张牌",
	["ocxskill_leona_xc_"] = "重力风暴",
	["ocxskill_leona_xc_max_"] = "重力风暴·MAX",
}
--[[****************************************************************
	编号：OROCHI - 002
	武将：八神庵
	称号：终焉之炎
	势力：蜀
	性别：男
	体力上限：4勾玉
]]--****************************************************************
IORI = sgs.General(extension, "ocIORI", "shu", 4)
--添加通用技能
IORI:addSkill("ocEnergy")
IORI:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocIORI"] = "八神庵",
	["&ocIORI"] = "八神庵",
	["#ocIORI"] = "终焉之炎",
	["designer:ocIORI"] = "DGAH",
	["cv:ocIORI"] = "安井邦彦",
	["illustrator:ocIORI"] = "网络资源",
	["~ocIORI"] = "このままでは终わらんぞ～",
}
--[[
	必杀：禁千贰百拾壹式·八稚女
	出招：下前下后+拳
	指令：方块+黑桃+方块+草花 -> 轻拳/重拳
	描述：你可以选择一名其他角色，对其随机造成7次不利影响，然后对其造成2点火焰伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_IORI_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_IORI_XA") then
		if command == "Down+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_IORI_XA"] = {
	name = "ocXSkill_IORI_XA_Card",
	--skill_name = "ocXSkill_IORI_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_IORI_XA", 1) --播放配音
		local target = targets[1]
		local map = {
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, --随机弃置目标一张牌
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  --随机获得目标一张牌
			3, 3, --目标失去1点体力
			4, --目标受到1点伤害
			5, 5, --对目标造成1点伤害
			6, 6, 6, 6, --对目标造成1点火焰伤害
		}
		local thread = room:getThread()
		thread:delay(800)
		local alive = doBaZhiNv(room, source, target, map)
		if alive then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 2
			damage.nature = sgs.DamageStruct_Fire
			thread:delay(600)
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_IORI_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_IORI_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_IORI_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_IORI_XA") then
		if command == "Down+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_IORI_XA_MAX"] = {
	name = "ocXSkill_IORI_XA_MAX_Card",
	--skill_name = "ocXSkill_IORI_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_IORI_XA", 2) --播放配音
		local target = targets[1]
		local map = {
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, --随机弃置目标一张牌
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, --随机获得目标一张牌
			3, --目标失去1点体力
			4, 4, 4, --目标受到1点伤害
			5, 5, 5, 5, --对目标造成1点伤害
			6, 6, 6, 6, 6, 6, 6, --对目标造成1点火焰伤害
			7, --对目标造成1点雷电伤害
			8, --目标翻面
		}
		local thread = room:getThread()
		thread:delay(800)
		local alive = doBaZhiNv(room, source, target, map)
		if alive then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 2
			damage.nature = sgs.DamageStruct_Fire
			thread:delay(600)
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_IORI_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_IORI_XA_MAX"])
--技能效果
IORI_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_IORI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
IORI_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_IORI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(IORI_XA_Audio)
IORI:addSkill(IORI_XA)
IORI:addRelateSkill("ocXSkill_IORI_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_IORI_XA"] = "禁千贰百拾壹式·八稚女",
	["$ocXSkill_IORI_XA1"] = "游びは终わりだ! 泣け、叫べ、そして、死ねっ!",
	["$ocXSkill_IORI_XA2"] = "（疯狂的嚎叫声；MAX版）",
	["@ocXSkill_IORI_XA"] = "禁千贰百拾壹式·八稚女：您可以选择一名其他角色，对其随机造成7次不利影响，然后对其造成2点火焰伤害",
	["ocXSkill_IORI_XA_MAX"] = "禁千贰百拾壹式·八稚女·MAX",
	["@ocXSkill_IORI_XA_MAX"] = "禁千贰百拾壹式·八稚女·MAX：您可以选择一名其他角色，对其随机造成7次不利影响，然后对其造成2点火焰伤害",
	["ocxskill_iori_xa_"] = "禁千贰百拾壹式·八稚女",
	["ocxskill_iori_xa_max_"] = "禁千贰百拾壹式·八稚女·MAX",
}
--[[
	必杀：里百八式·八酒杯
	出招：下后下前+拳
	指令：方块+草花+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择你攻击范围内的一名角色，令其所有技能无效且不能使用或打出手牌直到其受到一次伤害后，然后其翻面并失去1点体力。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_IORI_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_IORI_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_IORI_XB"] = {
	name = "ocXSkill_IORI_XB_Card",
	--skill_name = "ocXSkill_IORI_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_IORI_XB", 1) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		room:setPlayerMark(target, "ocXSkill_IORI_XB_Skill_Invalid", 1)
		local alives = room:getAlivePlayers()
		for _,p in sgs.qlist(alives) do
			local cards = p:getCards("he")
			room:filterCards(p, cards, true)
		end
		room:doBroadcastNotify(40, json.encode({9}))
		room:setPlayerCardLimitation(target, "use,response", ".|.|.|hand", false)
		room:setPlayerMark(target, "ocXSkill_IORI_XB_Effect", 1)
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_IORI_XB_Skill_Effect"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_IORI_XB"
		room:sendLog(msg) --发送提示信息
		target:turnOver()
		thread:delay(500)
		room:loseHp(target, 1)
	end,
}
sgs.ocXSkillCards["ocXSkill_IORI_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_IORI_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_IORI_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_IORI_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_IORI_XB_MAX"] = {
	name = "ocXSkill_IORI_XB_MAX_Card",
	--skill_name = "ocXSkill_IORI_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_IORI_XB", 2) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		room:setPlayerMark(target, "ocXSkill_IORI_XB_Skill_Invalid", 1)
		local alives = room:getAlivePlayers()
		for _,p in sgs.qlist(alives) do
			local cards = p:getCards("he")
			room:filterCards(p, cards, true)
		end
		room:doBroadcastNotify(40, json.encode({9}))
		room:setPlayerCardLimitation(target, "use,response", ".|.|.|hand", false)
		room:setPlayerMark(target, "ocXSkill_IORI_XB_Effect", 1)
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_IORI_XB_Skill_Effect"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_IORI_XB_MAX"
		room:sendLog(msg) --发送提示信息
		target:turnOver()
		thread:delay(500)
		room:loseHp(target, 2)
	end,
}
sgs.ocXSkillCards["ocXSkill_IORI_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_IORI_XB_MAX"])
--技能效果
IORI_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_IORI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
IORI_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_IORI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.Damaged},
	on_trigger = function(self, event, player, data)
		local damage = data:toDamage()
		local victim = damage.to
		if victim and victim:objectName() == player:objectName() then
			local room = player:getRoom()
			room:setPlayerMark(player, "ocXSkill_IORI_XB_Skill_Invalid", 0)
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				local cards = p:getCards("he")
				room:filterCards(p, cards, false)
			end
			room:doBroadcastNotify(40, json.encode({9}))
			room:removePlayerCardLimitation(player, "use,response", ".|.|.|hand$0")
			room:setPlayerMark(player, "ocXSkill_IORI_XB_Effect", 0)
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_IORI_XB_Effect_Clear"
			msg.from = player
			msg.arg = "ocXSkill_IORI_XB"
			room:sendLog(msg) --发送提示信息
		end
		return false
	end,
	can_trigger = function(self, target)
		if target and target:isAlive() then
			return target:getMark("ocXSkill_IORI_XB_Effect") > 0
		end
		return false
	end,
}
IORI_XB_Effect = sgs.CreateInvaliditySkill{
	name = "#ocXSkill_IORI_XB_Effect",
	skill_valid = function(self, player, skill)
		if player:getMark("ocXSkill_IORI_XB_Skill_Invalid") > 0 then
			return false
		end
		return true
	end
}
--添加技能
AnJiang:addSkill(IORI_XB_Audio)
IORI:addSkill(IORI_XB)
IORI:addSkill(IORI_XB_Effect)
IORI:addRelateSkill("ocXSkill_IORI_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_IORI_XB"] = "里百八式·八酒杯",
	["$ocXSkill_IORI_XB1"] = "楽には死ねんぞ!",
	["$ocXSkill_IORI_XB2"] = "楽には死ねんぞ!（MAX版）",
	["@ocXSkill_IORI_XB"] = "里百八式·八酒杯：您可以选择你攻击范围内的一名角色，令其所有技能无效且不能使用或打出手牌直到其受到一次伤害后，然后其翻面并失去1点体力",
	["ocXSkill_IORI_XB_MAX"] = "里百八式·八酒杯·MAX",
	["@ocXSkill_IORI_XB_MAX"] = "里百八式·八酒杯·MAX：您可以选择一名其他角色，令其所有技能无效且不能使用或打出手牌直到其受到一次伤害后，然后其翻面并失去2点体力",
	["#ocXSkill_IORI_XB_Skill_Effect"] = "%from 发动了“%arg”，令 %to 的所有技能无效且不能使用或打出手牌",
	["#ocXSkill_IORI_XB_Effect_Clear"] = "%from 受到了伤害，受到“%arg”的效果消失，所有技能恢复有效并解除手牌使用和打出限制",
	["ocxskill_iori_xb_"] = "里百八式·八酒杯",
	["ocxskill_iori_xb_max_"] = "里百八式·八酒杯·MAX",
}
--[[****************************************************************
	编号：OROCHI - 003
	武将：嘉迪路
	称号：致命之牙
	势力：群
	性别：男
	体力上限：4勾玉
]]--****************************************************************
GAIDEL = sgs.General(extension, "ocGAIDEL", "qun", 4)
--添加通用技能
GAIDEL:addSkill("ocEnergy")
GAIDEL:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocGAIDEL"] = "嘉迪路",
	["&ocGAIDEL"] = "嘉迪路",
	["#ocGAIDEL"] = "致命之牙",
	["designer:ocGAIDEL"] = "DGAH",
	["cv:ocGAIDEL"] = "无",
	["illustrator:ocGAIDEL"] = "网络资源",
	["~ocGAIDEL"] = "嘉迪路 的阵亡台词",
}
--[[
	必杀：守卫
	出招：上后下前+脚
	指令：红心+草花+方块+黑桃 -> 轻脚/重脚
	描述：你可以选择一名其他角色，令其受到X点伤害（X为你攻击范围内受伤角色数且至少为1）。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_GAIDEL_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GAIDEL_XA") then
		if command == "Up+Back+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GAIDEL_XA"] = {
	name = "ocXSkill_GAIDEL_XA_Card",
	--skill_name = "ocXSkill_GAIDEL_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GAIDEL_XA") --播放配音
		local target = targets[1]
		local alives = room:getAlivePlayers()
		local count = 0
		for _,p in sgs.qlist(alives) do
			if source:inMyAttackRange(p) then
				if p:isWounded() then
					count = count + 1
				end
			end
		end
		if source:isWounded() then
			count = count + 1
		end
		count = math.max(1, count)
		local damage = sgs.DamageStruct()
		damage.from = nil
		damage.to = target
		damage.damage = count
		room:damage(damage)
	end,
}
sgs.ocXSkillCards["ocXSkill_GAIDEL_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GAIDEL_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_GAIDEL_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GAIDEL_XA") then
		if command == "Up+Back+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GAIDEL_XA_MAX"] = {
	name = "ocXSkill_GAIDEL_XA_MAX_Card",
	--skill_name = "ocXSkill_GAIDEL_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GAIDEL_XA") --播放配音
		local target = targets[1]
		room:setPlayerMark(target, "ocXSkill_GAIDEL_XA_MAX_Effect", 1)
		room:setPlayerProperty(target, "ocXSkill_GAIDEL_XA_MAX_Source", sgs.QVariant(source:objectName()))
		room:setPlayerCardLimitation(target, "use,response", "BasicCard|.|.|.", false)
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_GAIDEL_XA_MAX_Skill_Effect"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_GAIDEL_XA_MAX"
		room:sendLog(msg) --发送提示信息
		local alives = room:getAlivePlayers()
		local count = 0
		for _,p in sgs.qlist(alives) do
			if p:isWounded() then
				count = count + 1
			end
		end
		count = math.max(2, count)
		local damage = sgs.DamageStruct()
		damage.from = nil
		damage.to = target
		damage.damage = count
		room:damage(damage)
	end,
}
sgs.ocXSkillCards["ocXSkill_GAIDEL_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GAIDEL_XA_MAX"])
--技能效果
GAIDEL_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_GAIDEL_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
GAIDEL_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_GAIDEL_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_Start then
			local room = player:getRoom()
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				if p:getMark("ocXSkill_GAIDEL_XA_MAX_Effect") > 0 then
					local name = p:property("ocXSkill_GAIDEL_XA_MAX_Source"):toString() or ""
					if player:objectName() == name then
						room:setPlayerMark(p, "ocXSkill_GAIDEL_XA_MAX_Effect", 0)
						room:setPlayerProperty(p, "ocXSkill_GAIDEL_XA_MAX_Source", sgs.QVariant(""))
						room:removePlayerCardLimitation(p, "use,response", "BasicCard|.|.|.$0")
						local msg = sgs.LogMessage()
						msg.type = "#ocXSkill_GAIDEL_XA_MAX_Effect_Clear"
						msg.from = player
						msg.to:append(p)
						msg.arg = "ocXSkill_GAIDEL_XA_MAX"
						room:sendLog(msg) --发送提示信息
					end
				end
			end
		end
		return false
	end,
}
--添加技能
AnJiang:addSkill(GAIDEL_XA_Audio)
GAIDEL:addSkill(GAIDEL_XA)
GAIDEL:addRelateSkill("ocXSkill_GAIDEL_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_GAIDEL_XA"] = "守卫",
	["$ocXSkill_GAIDEL_XA"] = "技能 守卫 的台词",
	["@ocXSkill_GAIDEL_XA"] = "守卫：您可以选择一名其他角色，令其受到X点伤害（X为你攻击范围内受伤角色数且至少为1）",
	["ocXSkill_GAIDEL_XA_MAX"] = "守卫·MAX",
	["@ocXSkill_GAIDEL_XA_MAX"] = "守卫·MAX：您可以选择一名其他角色，该角色不能使用或打出基本牌直到你的下个回合开始，然后其受到X点伤害（X为受伤角色数且至少为2）",
	["#ocXSkill_GAIDEL_XA_MAX_Skill_Effect"] = "受“%arg”的影响，%to 不能使用或打出基本牌直到 %from 的下个回合开始",
	["#ocXSkill_GAIDEL_XA_MAX_Effect_Clear"] = "%from 的回合开始，%to 受“%arg”的影响消失，使用或打出基本牌不再受限",
	["ocxskill_gaidel_xa_"] = "守卫",
	["ocxskill_gaidel_xa_max_"] = "守卫·MAX",
}
--[[
	必杀：宽恕
	出招：上上上+拳
	指令：红心+红心+红心 -> 轻拳/重拳
	描述：你可以选择一名角色，令其回复所有体力并摸三张牌。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_GAIDEL_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GAIDEL_XB") then
		if command == "Up+Up+Up" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GAIDEL_XB"] = {
	name = "ocXSkill_GAIDEL_XB_Card",
	--skill_name = "ocXSkill_GAIDEL_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		return #targets == 0
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GAIDEL_XB") --播放配音
		local target = targets[1]
		local maxhp = target:getMaxHp()
		local hp = target:getHp()
		local delt = maxhp - hp
		if delt > 0 then
			local recover = sgs.RecoverStruct()
			recover.who = source
			recover.recover = delt
			room:recover(target, recover)
		end
		room:drawCards(target, 3, "ocXSkill_GAIDEL_XB")
	end,
}
sgs.ocXSkillCards["ocXSkill_GAIDEL_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GAIDEL_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_GAIDEL_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GAIDEL_XB") then
		if command == "Up+Up+Up" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GAIDEL_XB_MAX"] = {
	name = "ocXSkill_GAIDEL_XB_MAX_Card",
	--skill_name = "ocXSkill_GAIDEL_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		return #targets == 0
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GAIDEL_XB") --播放配音
		local target = targets[1]
		local judges = target:getJudgingAreaID()
		if not judges:isEmpty() then
			local move = sgs.CardsMoveStruct()
			move.card_ids = judges
			move.from = target
			move.from_place = sgs.Player_PlaceDelayedTrick
			move.to = nil
			move.to_place = sgs.Player_DiscardPile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, target:objectName())
			room:moveCardsAtomic(move, true)
		end
		if target:isChained() then
			room:setPlayerProperty(target, "chained", sgs.QVariant(false))
			room:broadcastProperty(target, "chained")
			room:getThread():trigger(sgs.ChainStateChanged, room, target)
		end
		if not target:faceUp() then
			target:turnOver()
		end
		local maxhp = target:getMaxHp() + 1
		room:setPlayerProperty(target, "maxhp", sgs.QVariant(maxhp))
		local hp = target:getHp()
		local delt = maxhp - hp
		if delt > 0 then
			local recover = sgs.RecoverStruct()
			recover.who = source
			recover.recover = delt
			room:recover(target, recover)
		end
		room:drawCards(target, 4, "ocXSkill_GAIDEL_XB_MAX")
	end,
}
sgs.ocXSkillCards["ocXSkill_GAIDEL_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GAIDEL_XB_MAX"])
--技能效果
GAIDEL_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_GAIDEL_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
GAIDEL_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_GAIDEL_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(GAIDEL_XB_Audio)
GAIDEL:addSkill(GAIDEL_XB)
GAIDEL:addRelateSkill("ocXSkill_GAIDEL_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_GAIDEL_XB"] = "宽恕",
	["$ocXSkill_GAIDEL_XB"] = "技能 宽恕 的台词",
	["@ocXSkill_GAIDEL_XB"] = "宽恕：您可以选择一名角色，令其回复所有体力并摸三张牌",
	["ocXSkill_GAIDEL_XB_MAX"] = "宽恕·MAX",
	["@ocXSkill_GAIDEL_XB_MAX"] = "宽恕·MAX：您可以选择一名角色，令其弃置判定区的所有牌，将武将牌恢复至游戏开始时的状态，然后增加1点体力上限、回复所有体力并摸四张牌",
	["ocxskill_gaidel_xb_"] = "宽恕",
	["ocxskill_gaidel_xb_max_"] = "宽恕·MAX",
}
--[[****************************************************************
	编号：OROCHI - 004
	武将：薇思
	称号：战争圣女
	势力：蜀
	性别：女
	体力上限：3勾玉
]]--****************************************************************
VICE = sgs.General(extension, "ocVICE", "shu", 3, false)
--添加通用技能
VICE:addSkill("ocEnergy")
VICE:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocVICE"] = "薇思",
	["&ocVICE"] = "薇思",
	["#ocVICE"] = "战争圣女",
	["designer:ocVICE"] = "DGAH",
	["cv:ocVICE"] = "弓雅枝",
	["illustrator:ocVICE"] = "网络资源",
	["~ocVICE"] = "薇思 的阵亡台词",
}
--[[
	必杀：连续反身打
	出招：近身+前下后前下后+重拳
	指令：黑桃+方块+草花+黑桃+方块+草花 -> 重拳
	描述：你可以选择一名距离为1的角色，并依次翻开牌堆顶的三张牌。每翻开一张：红色牌，其受到1点伤害；黑色牌，随机弃置其一张牌。然后你摸两张牌。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_VICE_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_VICE_XA") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_VICE_XA"] = {
	name = "ocXSkill_VICE_XA_Card",
	--skill_name = "ocXSkill_VICE_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return sgs.Self:distanceTo(to_select) == 1
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_VICE_XA") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		for i=1, 3, 1 do
			if target:isDead() or source:isDead() then
				break
			end
			local move = sgs.CardsMoveStruct()
			move.from = nil
			move.from_place = sgs.Player_DrawPile
			move.to = nil
			move.to_place = sgs.Player_PlaceTable
			move.card_ids = room:getNCards(1, true)
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
			room:moveCardsAtomic(move, true)
			thread:delay()
			local id = move.card_ids:first()
			local card = sgs.Sanguosha:getCard(id)
			if card:isRed() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 1
				room:damage(damage)
			elseif not target:isNude() then
				local cards = target:getCards("he")
				local count = cards:length()
				local index = math.random(0, count-1)
				local to_throw = cards:at(index)
				if source:canDiscard(target, to_throw:getEffectiveId()) then
					room:throwCard(to_throw, target, source)
				end
			end
			move.from_place = sgs.Player_PlaceTable
			move.to_place = sgs.Player_DiscardPile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
			room:moveCardsAtomic(move, true)
		end
		if source:isAlive() then
			room:drawCards(source, 2, "oxSkill_VICE_XA")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_VICE_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_VICE_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_VICE_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_VICE_XA") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_VICE_XA_MAX"] = {
	name = "ocXSkill_VICE_XA_MAX_Card",
	--skill_name = "ocXSkill_VICE_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return sgs.Self:distanceTo(to_select) == 1
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_VICE_XA") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		for i=1, 5, 1 do
			if target:isDead() or source:isDead() then
				break
			end
			local move = sgs.CardsMoveStruct()
			move.from = nil
			move.from_place = sgs.Player_DrawPile
			move.to = nil
			move.to_place = sgs.Player_PlaceTable
			move.card_ids = room:getNCards(1, true)
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
			room:moveCardsAtomic(move, true)
			thread:delay()
			local id = move.card_ids:first()
			local card = sgs.Sanguosha:getCard(id)
			if card:isRed() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 1
				room:damage(damage)
			elseif not target:isNude() then
				local cards = target:getCards("he")
				local count = cards:length()
				local index = math.random(0, count-1)
				local to_throw = cards:at(index)
				if source:canDiscard(target, to_throw:getEffectiveId()) then
					room:throwCard(to_throw, target, source)
				end
			end
			move.from_place = sgs.Player_PlaceTable
			move.to_place = sgs.Player_DiscardPile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
			room:moveCardsAtomic(move, true)
		end
		if source:isAlive() then
			room:drawCards(source, 3, "oxSkill_VICE_XA_MAX")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_VICE_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_VICE_XA_MAX"])
--技能效果
VICE_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_VICE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
VICE_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_VICE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(VICE_XA_Audio)
VICE:addSkill(VICE_XA)
VICE:addRelateSkill("ocXSkill_VICE_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_VICE_XA"] = "连续反身打",
	["$ocXSkill_VICE_XA"] = "痛いよ",
	["@ocXSkill_VICE_XA"] = "连续反身打：您可以选择一名距离为1的角色，并依次翻开牌堆顶的三张牌。每翻开一张：红色牌，其受到1点伤害；黑色牌，随机弃置其一张牌。然后你摸两张牌",
	["ocXSkill_VICE_XA_MAX"] = "连续反身打·MAX",
	["@ocXSkill_VICE_XA_MAX"] = "连续反身打·MAX：您可以选择一名距离为1的角色，并依次翻开牌堆顶的五张牌。每翻开一张：红色牌，其受到1点伤害；黑色牌，随机弃置其一张牌。然后你摸三张牌",
	["ocxskill_vice_xa_"] = "连续反身打",
	["ocxskill_vice_xa_max_"] = "连续反身打·MAX",
}
--[[****************************************************************
	编号：OROCHI - 005
	武将：麦卓
	称号：鬼敏女豹
	势力：魏
	性别：女
	体力上限：3勾玉
]]--****************************************************************
MATURE = sgs.General(extension, "ocMATURE", "wei", 3, false)
--添加通用技能
MATURE:addSkill("ocEnergy")
MATURE:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocMATURE"] = "麦卓",
	["&ocMATURE"] = "麦卓",
	["#ocMATURE"] = "鬼敏女豹",
	["designer:ocMATURE"] = "DGAH",
	["cv:ocMATURE"] = "辻裕子",
	["illustrator:ocMATURE"] = "网络资源",
	["~ocMATURE"] = "（惨叫声）",
}
--[[
	必杀：天国滑行
	出招：下后下前+拳
	指令：方块+草花+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，令其与座次与你最远的角色交换座位，然后其受到X点伤害并弃置所有装备（X为其交换座位时经过的座位数且至少为2）。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_MATURE_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_MATURE_XA") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_MATURE_XA"] = {
	name = "ocXSkill_MATURE_XA_Card",
	--skill_name = "ocXSkill_MATURE_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_MATURE_XA") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1000)
		local myseat = source:getSeat()
		local maxDelt, maxTarget = -1, nil
		local alives = room:getAlivePlayers()
		local sum = alives:length()
		for _,p in sgs.qlist(alives) do
			local seat = p:getSeat()
			local right = math.abs(myseat - seat)
			local left = sum - right
			local delt = math.min(right, left)
			if delt > maxDelt then
				maxDelt = delt
				maxTarget = p
			end
		end
		local count = 2
		if maxTarget and maxTarget:objectName() ~= target:objectName() then
			local seatA = target:getSeat()
			local seatB = maxTarget:getSeat()
			count = math.max( 2, math.abs(seatA - seatB) )
			room:swapSeat(target, maxTarget)
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_MATURE_XA_Swap_Seat"
			msg.from = target
			msg.to:append(maxTarget)
			room:sendLog(msg) --发送提示信息
		end
		local damage = sgs.DamageStruct()
		damage.from = nil
		damage.to = target
		damage.damage = count
		room:damage(damage)
		if target:isAlive() then
			target:throwAllEquips()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_MATURE_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_MATURE_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_MATURE_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_MATURE_XA") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_MATURE_XA_MAX"] = {
	name = "ocXSkill_MATURE_XA_MAX_Card",
	--skill_name = "ocXSkill_MATURE_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_MATURE_XA") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1000)
		local myseat = source:getSeat()
		local maxDelt, maxTarget = -1, nil
		local alives = room:getAlivePlayers()
		local sum = alives:length()
		for _,p in sgs.qlist(alives) do
			local seat = p:getSeat()
			local right = math.abs(myseat - seat)
			local left = sum - right
			local delt = math.max(right, left)
			if delt > maxDelt then
				maxDelt = delt
				maxTarget = p
			end
		end
		local count = 3
		if maxTarget and maxTarget:objectName() ~= target:objectName() then
			local seatA = target:getSeat()
			local seatB = maxTarget:getSeat()
			count = math.max( 3, math.abs(seatA - seatB) )
			room:swapSeat(target, maxTarget)
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_MATURE_XA_Swap_Seat"
			msg.from = target
			msg.to:append(maxTarget)
			room:sendLog(msg) --发送提示信息
		end
		local damage = sgs.DamageStruct()
		damage.from = nil
		damage.to = target
		damage.damage = count
		room:damage(damage)
		if target:isAlive() then
			target:throwAllHandCardsAndEquips()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_MATURE_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_MATURE_XA_MAX"])
--技能效果
MATURE_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_MATURE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
MATURE_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_MATURE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(MATURE_XA_Audio)
MATURE:addSkill(MATURE_XA)
MATURE:addRelateSkill("ocXSkill_MATURE_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_MATURE_XA"] = "天国滑行",
	["$ocXSkill_MATURE_XA"] = "（狂野的笑声）",
	["@ocXSkill_MATURE_XA"] = "天国滑行：您可以选择一名其他角色，令其与座次与你最远的角色交换座位，然后其受到X点伤害并弃置所有装备（X为其交换座位时经过的座位数且至少为2）",
	["ocXSkill_MATURE_XA_MAX"] = "天国滑行·MAX",
	["@ocXSkill_MATURE_XA_MAX"] = "天国滑行·MAX：您可以选择一名其他角色，令其与座次与你最远的角色交换座位，然后其受到X点伤害并弃置所有手牌和装备（X为其交换座位时经过的座位数且至少为3）",
	["#ocXSkill_MATURE_XA_Swap_Seat"] = "%from 与 %to 交换了座位",
	["ocxskill_mature_xa_"] = "天国滑行",
	["ocxskill_mature_xa_max_"] = "天国滑行·MAX",
}
--[[****************************************************************
	编号：OROCHI - 006
	武将：山崎龙二
	称号：死亡狂乱
	势力：群
	性别：男
	体力上限：4勾玉
]]--****************************************************************
YAMAZAKI = sgs.General(extension, "ocYAMAZAKI", "qun", 4)
--添加通用技能
YAMAZAKI:addSkill("ocEnergy")
YAMAZAKI:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocYAMAZAKI"] = "山崎龙二",
	["&ocYAMAZAKI"] = "山崎龙二",
	["#ocYAMAZAKI"] = "死亡狂乱",
	["designer:ocYAMAZAKI"] = "DGAH",
	["cv:ocYAMAZAKI"] = "石井康嗣",
	["illustrator:ocYAMAZAKI"] = "网络资源",
	["~ocYAMAZAKI"] = "（惨叫声）",
}
--[[
	必杀：断头台
	出招：下前下前+拳
	指令：方块+黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，获得其区域中的一张牌并视为对其连续使用了四张【杀】，然后对其造成1点伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_YAMAZAKI_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YAMAZAKI_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XA"] = {
	name = "ocXSkill_YAMAZAKI_XA_Card",
	--skill_name = "ocXSkill_YAMAZAKI_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YAMAZAKI_XA", 1) --播放配音
		local target = targets[1]
		if not target:isAllNude() then
			local id = room:askForCardChosen(source, target, "hej", "ocXSkill_YAMAZAKI_XA") 
			if id > 0 then
				room:obtainCard(source, id, true)
			end
		end
		local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
		slash:setSkillName("ocXSkill")
		local thread = room:getThread()
		for i=1, 4, 1 do
			if target:isDead() or source:isDead() then
				return 
			elseif source:canSlash(target, slash, false) then
				local use = sgs.CardUseStruct()
				use.from = source
				use.to:append(target)
				use.card = slash
				room:setPlayerFlag(source, "ocEnergyIgnore")
				room:useCard(use, false)
				room:setPlayerFlag(source, "-ocEnergyIgnore")
				thread:delay(500)
			else
				break
			end
		end
		if target:isAlive() and source:isAlive() then
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 1
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YAMAZAKI_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_YAMAZAKI_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YAMAZAKI_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XA_MAX"] = {
	name = "ocXSkill_YAMAZAKI_XA_MAX_Card",
	--skill_name = "ocXSkill_YAMAZAKI_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YAMAZAKI_XA", 2) --播放配音
		local target = targets[1]
		if not target:isAllNude() then
			local id = room:askForCardChosen(source, target, "hej", "ocXSkill_YAMAZAKI_XA_MAX") 
			if id > 0 then
				room:obtainCard(source, id, true)
			end
		end
		local slash = sgs.Sanguosha:cloneCard("slash", sgs.Card_NoSuit, 0)
		slash:setSkillName("ocXSkill")
		local thread = room:getThread()
		for i=1, 4, 1 do
			if target:isDead() or source:isDead() then
				return 
			elseif source:canSlash(target, slash, false) then
				local use = sgs.CardUseStruct()
				use.from = source
				use.to:append(target)
				use.card = slash
				room:setPlayerFlag(source, "ocEnergyIgnore")
				room:useCard(use, false)
				room:setPlayerFlag(source, "-ocEnergyIgnore")
				thread:delay(500)
			else
				break
			end
		end
		if target:isAlive() and source:isAlive() then
			for i=1, 7, 1 do
				local cards = target:getCards("he")
				local count = cards:length()
				if count == 0 then
					break
				end
				local index = math.random(0, count-1)
				local card = cards:at(index)
				if source:canDiscard(target, card:getEffectiveId()) then
					room:throwCard(card, target, source)
				end
			end
		end
		if target:isAlive() and source:isAlive() then
			thread:delay()
			local damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target
			damage.damage = 2
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YAMAZAKI_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XA_MAX"])
--技能效果
YAMAZAKI_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_YAMAZAKI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
YAMAZAKI_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_YAMAZAKI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(YAMAZAKI_XA_Audio)
YAMAZAKI:addSkill(YAMAZAKI_XA)
YAMAZAKI:addRelateSkill("ocXSkill_YAMAZAKI_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_YAMAZAKI_XA"] = "断头台",
	["$ocXSkill_YAMAZAKI_XA1"] = "（断头台 的音效）",
	["$ocXSkill_YAMAZAKI_XA2"] = "（断头台·MAX 的音效）",
	["@ocXSkill_YAMAZAKI_XA"] = "断头台：您可以选择一名其他角色，获得其区域中的一张牌并视为对其连续使用了四张【杀】，然后对其造成1点伤害。",
	["ocXSkill_YAMAZAKI_XA_MAX"] = "断头台·MAX",
	["@ocXSkill_YAMAZAKI_XA_MAX"] = "断头台·MAX：您可以选择一名其他角色，获得其区域中的一张牌并视为对其连续使用了四张【杀】，然后随机弃置其七张牌，对其造成2点伤害。",
	["ocxskill_yamazaki_xa_"] = "断头台",
	["ocxskill_yamazaki_xa_max_"] = "断头台·MAX",
}
--[[
	必杀：射杀
	出招：近身+前下后前下后+拳
	指令：黑桃+方块+草花+黑桃+方块+草花 -> 轻拳/重拳
	描述：你可以选择一名距离为1的角色，对其造成1点伤害并弃置其两张牌，然后其受到1点伤害并翻面。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_YAMAZAKI_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YAMAZAKI_XB") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XB"] = {
	name = "ocXSkill_YAMAZAKI_XB_Card",
	--skill_name = "ocXSkill_YAMAZAKI_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return sgs.Self:distanceTo(to_select) == 1
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YAMAZAKI_XB", 1) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 1
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		thread:delay(1000)
		if target:isAlive() and source:isAlive() then
			for i=1, 2, 1 do
				if target:isNude() then
					break
				end
				local id = room:askForCardChosen(source, target, "he", "ocXSkill_YAMAZAKI_XB")
				if id > 0 then
					room:throwCard(id, target, source)
				end
			end
		end
		if target:isAlive() and source:isAlive() then
			thread:delay(500)
			damage.from = nil
			room:damage(damage)
			if target:isAlive() then
				thread:delay(500)
				target:turnOver()
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YAMAZAKI_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_YAMAZAKI_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YAMAZAKI_XB") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XB_MAX"] = {
	name = "ocXSkill_YAMAZAKI_XB_MAX_Card",
	--skill_name = "ocXSkill_YAMAZAKI_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return sgs.Self:distanceTo(to_select) == 1
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YAMAZAKI_XB", 2) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 1
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		thread:delay(1000)
		if target:isAlive() and source:isAlive() then
			local map = {
				1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
				2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
				3, 
				4, 4, 
				5, 
				6, 
				7, 
			}
			local alive = doBaZhiNv(room, source, target, map)
			if alive then
				thread:delay(500)
				damage.from = nil
				damage.damage = 2
				room:damage(damage)
				if target:isAlive() then
					thread:delay(500)
					target:turnOver()
				end
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YAMAZAKI_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YAMAZAKI_XB_MAX"])
--技能效果
YAMAZAKI_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_YAMAZAKI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
YAMAZAKI_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_YAMAZAKI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(YAMAZAKI_XB_Audio)
YAMAZAKI:addSkill(YAMAZAKI_XB)
YAMAZAKI:addRelateSkill("ocXSkill_YAMAZAKI_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_YAMAZAKI_XB"] = "射杀",
	["$ocXSkill_YAMAZAKI_XB1"] = "（射杀 的音效）",
	["$ocXSkill_YAMAZAKI_XB2"] = "（射杀·MAX 的音效）",
	["@ocXSkill_YAMAZAKI_XB"] = "射杀：您可以选择一名距离为1的角色，对其造成1点伤害并弃置其两张牌，然后其受到1点伤害并翻面",
	["ocXSkill_YAMAZAKI_XB_MAX"] = "射杀·MAX",
	["@ocXSkill_YAMAZAKI_XB_MAX"] = "射杀·MAX：您可以选择一名距离为1的角色，对其造成1点伤害并对其造成7次不利影响，然后其受到2点伤害并翻面",
	["ocxskill_yamazaki_xb_"] = "射杀",
	["ocxskill_yamazaki_xb_max_"] = "射杀·MAX",
}
--[[****************************************************************
	编号：OROCHI - 007
	武将：克里斯
	称号：炎之觉醒
	势力：蜀
	性别：男
	体力上限：3勾玉
]]--****************************************************************
CHRIS = sgs.General(extension, "ocCHRIS", "shu", 3)
--添加通用技能
CHRIS:addSkill("ocEnergy")
CHRIS:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocCHRIS"] = "克里斯",
	["&ocCHRIS"] = "克里斯",
	["#ocCHRIS"] = "炎之觉醒",
	["designer:ocCHRIS"] = "DGAH",
	["cv:ocCHRIS"] = "绪方りお",
	["illustrator:ocCHRIS"] = "网络资源",
	["~ocCHRIS"] = "ひ、ひかりが……",
}
--[[
	必杀：暗黑大蛇薙
	出招：下后下前+拳
	指令：方块+草花+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名你攻击范围内的角色，对其造成3点火焰伤害，对其下家（若不是你）造成1点火焰伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_CHRIS_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_CHRIS_XA") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_CHRIS_XA"] = {
	name = "ocXSkill_CHRIS_XA_Card",
	--skill_name = "ocXSkill_CHRIS_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_CHRIS_XA", 1) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		local target2 = target:getNextAlive()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 3
		damage.nature = sgs.DamageStruct_Fire
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target2:objectName() ~= source:objectName() then
			damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target2
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Fire
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_CHRIS_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_CHRIS_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_CHRIS_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_CHRIS_XA") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_CHRIS_XA_MAX"] = {
	name = "ocXSkill_CHRIS_XA_MAX_Card",
	--skill_name = "ocXSkill_CHRIS_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_CHRIS_XA", 2) --播放配音
		local thread = room:getThread()
		thread:delay(500)
		local target = targets[1]
		local target2 = target:getNextAlive()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 3
		damage.nature = sgs.DamageStruct_Fire
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() then
			damage.from = nil
			damage.damage = 1
			room:damage(damage)
		end
		if target2:objectName() ~= source:objectName() then
			damage = sgs.DamageStruct()
			damage.from = source
			damage.to = target2
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Fire
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
			if target2:isAlive() then
				room:loseHp(target2, 1)
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_CHRIS_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_CHRIS_XA_MAX"])
--技能效果
CHRIS_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_CHRIS_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
CHRIS_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_CHRIS_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(CHRIS_XA_Audio)
CHRIS:addSkill(CHRIS_XA)
CHRIS:addRelateSkill("ocXSkill_CHRIS_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_CHRIS_XA"] = "暗黑大蛇薙",
	["$ocXSkill_CHRIS_XA1"] = "はい、死んでください！",
	["$ocXSkill_CHRIS_XA2"] = "はい、死んでください！（MAX版）",
	["@ocXSkill_CHRIS_XA"] = "暗黑大蛇薙：您可以选择一名你攻击范围内的角色，对其造成3点火焰伤害，对其下家（若不是你）造成1点火焰伤害",
	["ocXSkill_CHRIS_XA_MAX"] = "暗黑大蛇薙·MAX",
	["@ocXSkill_CHRIS_XA_MAX"] = "暗黑大蛇薙·MAX：您可以选择一名你攻击范围内的角色，对其造成3点火焰伤害并令其受到1点火焰伤害，对其下家（若不是你）造成1点火焰伤害并令其失去1点体力",
	["ocxskill_chris_xa_"] = "暗黑大蛇薙",
	["ocxskill_chris_xa_max_"] = "暗黑大蛇薙·MAX",
}
--[[
	必杀：拂大地之禁果
	出招：下前下前+拳
	指令：方块+黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，对其造成2点火焰伤害，然后令其与下家交换位置并翻面。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_CHRIS_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_CHRIS_XB") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_CHRIS_XB"] = {
	name = "ocXSkill_CHRIS_XB_Card",
	--skill_name = "ocXSkill_CHRIS_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_CHRIS_XB", 1) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(500)
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 2
		damage.nature = sgs.DamageStruct_Fire
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() then
			local next_player = target:getNextAlive()
			room:swapSeat(target, next_player)
			target:turnOver()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_CHRIS_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_CHRIS_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_CHRIS_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_CHRIS_XB") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_CHRIS_XB_MAX"] = {
	name = "ocXSkill_CHRIS_XB_MAX_Card",
	--skill_name = "ocXSkill_CHRIS_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_CHRIS_XB", 2) --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(500)
		room:swapSeat(source, target)
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 1
		damage.nature = sgs.DamageStruct_Fire
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isDead() or source:isDead() then
			return 
		end
		thread:delay(500)
		room:swapSeat(target, source)
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isDead() or source:isDead() then
			return 
		end
		thread:delay(500)
		room:swapSeat(target, source)
		damage.damage = 2
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() then
			target:throwAllHandCards()
			target:turnOver()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_CHRIS_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_CHRIS_XB_MAX"])
--技能效果
CHRIS_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_CHRIS_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
CHRIS_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_CHRIS_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(CHRIS_XB_Audio)
CHRIS:addSkill(CHRIS_XB)
CHRIS:addRelateSkill("ocXSkill_CHRIS_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_CHRIS_XB"] = "拂大地之禁果",
	["$ocXSkill_CHRIS_XB1"] = "さあ焼き尽くそうね！",
	["$ocXSkill_CHRIS_XB2"] = "さあ焼き尽くそうね！（MAX版）",
	["@ocXSkill_CHRIS_XB"] = "拂大地之禁果：您可以选择一名其他角色，对其造成2点火焰伤害，然后令其与下家交换位置并翻面",
	["ocXSkill_CHRIS_XB_MAX"] = "拂大地之禁果·MAX",
	["@ocXSkill_CHRIS_XB_MAX"] = "拂大地之禁果·MAX：您可以选择一名其他角色，对其依次造成1点、1点、2点火焰伤害同时与你交换座位，然后其弃置所有手牌并翻面",
	["ocxskill_chris_xb_"] = "拂大地之禁果",
	["ocxskill_chris_xb_max_"] = "拂大地之禁果·MAX",
}
--[[****************************************************************
	编号：OROCHI - 008
	武将：夏尔米
	称号：荒稻雷光
	势力：蜀
	性别：女
	体力上限：4勾玉
]]--****************************************************************
SHERMIE = sgs.General(extension, "ocSHERMIE", "shu", 4, false)
--添加通用技能
SHERMIE:addSkill("ocEnergy")
SHERMIE:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocSHERMIE"] = "夏尔米",
	["&ocSHERMIE"] = "夏尔米",
	["#ocSHERMIE"] = "荒稻雷光",
	["designer:ocSHERMIE"] = "DGAH",
	["cv:ocSHERMIE"] = "西川叶月",
	["illustrator:ocSHERMIE"] = "网络资源",
	["~ocSHERMIE"] = "（惨叫声）",
}
--[[
	必杀：暗黑雷光拳
	出招：下前下前+拳
	指令：方块+黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择你攻击范围内的一名角色，对其造成2点雷电伤害，再对其造成1点雷电伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_SHERMIE_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_SHERMIE_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_SHERMIE_XA"] = {
	name = "ocXSkill_SHERMIE_XA_Card",
	--skill_name = "ocXSkill_SHERMIE_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_SHERMIE_XA") --播放配音
		room:getThread():delay(1250)
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 2
		damage.nature = sgs.DamageStruct_Thunder
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() and source:isAlive() then
			damage = sgs.DamageStruct()
			damage.from = nil
			damage.to = target
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Thunder
			room:damage(damage)
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_SHERMIE_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_SHERMIE_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_SHERMIE_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_SHERMIE_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_SHERMIE_XA_MAX"] = {
	name = "ocXSkill_SHERMIE_XA_MAX_Card",
	--skill_name = "ocXSkill_SHERMIE_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_SHERMIE_XA") --播放配音
		room:getThread():delay(1250)
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 3
		damage.nature = sgs.DamageStruct_Thunder
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		if target:isAlive() and source:isAlive() then
			damage = sgs.DamageStruct()
			damage.from = nil
			damage.to = target
			damage.damage = 1
			damage.nature = sgs.DamageStruct_Thunder
			room:damage(damage)
			if target:isAlive() then
				room:loseHp(target, 1)
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_SHERMIE_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_SHERMIE_XA_MAX"])
--技能效果
SHERMIE_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_SHERMIE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
SHERMIE_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_SHERMIE_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(SHERMIE_XA_Audio)
SHERMIE:addSkill(SHERMIE_XA)
SHERMIE:addRelateSkill("ocXSkill_SHERMIE_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_SHERMIE_XA"] = "暗黑雷光拳",
	["$ocXSkill_SHERMIE_XA"] = "あんこくらいこうけん！",
	["@ocXSkill_SHERMIE_XA"] = "暗黑雷光拳：您可以选择你攻击范围内的一名角色，对其造成2点雷电伤害，然后其受到1点雷电伤害",
	["ocXSkill_SHERMIE_XA_MAX"] = "暗黑雷光拳·MAX",
	["@ocXSkill_SHERMIE_XA_MAX"] = "暗黑雷光拳·MAX：您可以选择你攻击范围内的一名角色，对其造成3点雷电伤害，然后其受到1点雷电伤害并失去1点体力",
	["ocxskill_shermie_xa_"] = "暗黑雷光拳",
	["ocxskill_shermie_xa_max_"] = "暗黑雷光拳·MAX",
}
--[[
	必杀：宿命·幻影·振子
	出招：下前下前+脚
	指令：方块+黑桃+方块+黑桃 -> 轻脚/重脚
	描述：你可以选择一名其他角色，其与你交换位置并翻面，然后你对其造成2点雷电伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_SHERMIE_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_SHERMIE_XB") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_SHERMIE_XB"] = {
	name = "ocXSkill_SHERMIE_XB_Card",
	--skill_name = "ocXSkill_SHERMIE_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_SHERMIE_XB") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1000)
		room:swapSeat(source, target)
		thread:delay(1000)
		target:turnOver()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 2
		damage.nature = sgs.DamageStruct_Thunder
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
	end,
}
sgs.ocXSkillCards["ocXSkill_SHERMIE_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_SHERMIE_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_SHERMIE_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_SHERMIE_XB") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyB" or key == "ocKeyD" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_SHERMIE_XB_MAX"] = {
	name = "ocXSkill_SHERMIE_XB_MAX_Card",
	--skill_name = "ocXSkill_SHERMIE_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_SHERMIE_XB") --播放配音
		local target = targets[1]
		local thread = room:getThread()
		thread:delay(1000)
		room:swapSeat(source, target)
		thread:delay(1000)
		target:turnOver()
		room:setPlayerMark(target, "Armor_Nullified", 1)
		room:setPlayerMark(target, "ocXSkill_SHERMIE_XB_MAX_Effect", 1)
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_SHERMIE_XB_MAX_Armor_Nullified"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_SHERMIE_XB_MAX"
		room:sendLog(msg) --发送提示信息
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 3
		damage.nature = sgs.DamageStruct_Thunder
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
	end,
}
sgs.ocXSkillCards["ocXSkill_SHERMIE_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_SHERMIE_XB_MAX"])
--技能效果
SHERMIE_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_SHERMIE_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
SHERMIE_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_SHERMIE_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseEnd},
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_Play then
			local room = player:getRoom()
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				if p:getMark("ocXSkill_SHERMIE_XB_MAX_Effect") > 0 then
					room:setPlayerMark(p, "ocXSkill_SHERMIE_XB_MAX_Effect", 0)
					room:setPlayerMark(p, "Armor_Nullified", 0)
					local msg = sgs.LogMessage()
					msg.type = "#ocXSkill_SHERMIE_XB_MAX_Clear"
					msg.from = p
					msg.arg = "ocXSkill_SHERMIE_XB_MAX",
					room:sendLog(msg) --发送提示信息
				end
			end
		end
		return false
	end,
}
--添加技能
AnJiang:addSkill(SHERMIE_XB_Audio)
SHERMIE:addSkill(SHERMIE_XB)
SHERMIE:addRelateSkill("ocXSkill_SHERMIE_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_SHERMIE_XB"] = "宿命·幻影·振子",
	["$ocXSkill_SHERMIE_XB"] = "いいわね、いくわよ！",
	["@ocXSkill_SHERMIE_XB"] = "宿命·幻影·振子：您可以选择一名其他角色，其与你交换位置并翻面，然后你对其造成2点雷电伤害",
	["ocXSkill_SHERMIE_XB_MAX"] = "宿命·幻影·振子·MAX",
	["@ocXSkill_SHERMIE_XB_MAX"] = "宿命·幻影·振子·MAX：您可以选择一名其他角色，其与你交换位置并翻面，然后其防具无效直到本阶段结束且你对其造成3点雷电伤害",
	["#ocXSkill_SHERMIE_XB_MAX_Armor_Nullified"] = "%from 发动了“%arg”，令 %to 的防具无效直到本阶段结束",
	["#ocXSkill_SHERMIE_XB_MAX_Clear"] = "当前阶段结束，“%arg”的影响消失，%from 的防具恢复有效",
	["ocxskill_shermie_xb_"] = "宿命·幻影·振子",
	["ocxskill_shermie_xb_max_"] = "宿命·幻影·振子·MAX",
}
--[[****************************************************************
	编号：OROCHI - 009
	武将：七枷社
	称号：干枯大地
	势力：蜀
	性别：男
	体力上限：4勾玉
]]--****************************************************************
YASHIRO = sgs.General(extension, "ocYASHIRO", "shu", 4)
--添加通用技能
YASHIRO:addSkill("ocEnergy")
YASHIRO:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocYASHIRO"] = "七枷社",
	["&ocYASHIRO"] = "七枷社",
	["#ocYASHIRO"] = "干枯大地",
	["designer:ocYASHIRO"] = "DGAH",
	["cv:ocYASHIRO"] = "栗根圆",
	["illustrator:ocYASHIRO"] = "网络资源",
	["~ocYASHIRO"] = "なに……?!",
}
--[[
	必杀：吼大地
	出招：下前下前+拳
	指令：方块+黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名攻击范围内的角色，翻开牌堆顶的一张牌，然后对其造成X/3点伤害（X为翻开牌的点数，结果向上取整）。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XA"] = {
	name = "ocXSkill_YASHIRO_XA_Card",
	--skill_name = "ocXSkill_YASHIRO_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XA") --播放配音
		local target = targets[1]
		local ids = room:getNCards(1, true)
		local move = sgs.CardsMoveStruct()
		move.from = nil
		move.from_place = sgs.Player_DrawPile
		move.to = nil
		move.to_place = sgs.Player_PlaceTable
		move.card_ids = ids
		move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
		room:moveCardsAtomic(move, true)
		local thread = room:getThread()
		thread:delay(1000)
		local id = ids:first()
		local card = sgs.Sanguosha:getCard(id)
		local point = card:getNumber()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = math.ceil( point / 3 )
		move.from_place = sgs.Player_PlaceTable
		move.to_place = sgs.Player_DiscardPile
		move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
		room:moveCardsAtomic(move, true)
		thread:delay(1600)
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XA") then
		if command == "Down+Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XA_MAX"] = {
	name = "ocXSkill_YASHIRO_XA_MAX_Card",
	--skill_name = "ocXSkill_YASHIRO_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:inMyAttackRange(to_select) then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XA") --播放配音
		local target = targets[1]
		local ids = room:getNCards(1, true)
		local move = sgs.CardsMoveStruct()
		move.from = nil
		move.from_place = sgs.Player_DrawPile
		move.to = nil
		move.to_place = sgs.Player_PlaceTable
		move.card_ids = ids
		move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
		room:moveCardsAtomic(move, true)
		local thread = room:getThread()
		thread:delay(1000)
		room:setPlayerMark(target, "Armor_Nullified", 1)
		room:setPlayerMark(target, "ocXSkill_YASHIRO_XA_MAX_Effect", 1)
		local msg = sgs.LogMessage()
		msg.type = "#ocXSkill_YASHIRO_XA_MAX_Armor_Nullified"
		msg.from = source
		msg.to:append(target)
		msg.arg = "ocXSkill_YASHIRO_XA_MAX"
		room:sendLog(msg) --发送提示信息
		local id = ids:first()
		local card = sgs.Sanguosha:getCard(id)
		local point = card:getNumber()
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = math.ceil( point / 2 )
		move.from_place = sgs.Player_PlaceTable
		move.to_place = sgs.Player_DiscardPile
		move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
		room:moveCardsAtomic(move, true)
		thread:delay(1600)
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XA_MAX"])
--技能效果
YASHIRO_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_YASHIRO_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
YASHIRO_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_YASHIRO_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseEnd},
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_Play then
			local room = player:getRoom()
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				if p:getMark("ocXSkill_YASHIRO_XA_MAX_Effect") > 0 then
					room:setPlayerMark(p, "ocXSkill_YASHIRO_XA_MAX_Effect", 0)
					room:setPlayerMark(p, "Armor_Nullified", 0)
					local msg = sgs.LogMessage()
					msg.type = "#ocXSkill_YASHIRO_XA_MAX_Clear"
					msg.from = p
					msg.arg = "ocXSkill_YASHIRO_XA_MAX"
					room:sendLog(msg) --发送提示信息
				end
			end
		end
		return false
	end,
}
--添加技能
AnJiang:addSkill(YASHIRO_XA_Audio)
YASHIRO:addSkill(YASHIRO_XA)
YASHIRO:addRelateSkill("ocXSkill_YASHIRO_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_YASHIRO_XA"] = "吼大地",
	["$ocXSkill_YASHIRO_XA"] = "おおおおお、いっちまいな！",
	["@ocXSkill_YASHIRO_XA"] = "吼大地：你可以选择一名攻击范围内的角色，翻开牌堆顶的一张牌，然后对其造成X/3点伤害（X为翻开牌的点数，结果向上取整）",
	["ocXSkill_YASHIRO_XA_MAX"] = "吼大地·MAX",
	["@ocXSkill_YASHIRO_XA_MAX"] = "吼大地·MAX：你可以选择一名攻击范围内的角色，令该角色的防具无效直到本阶段结束，然后你翻开牌堆顶的一张牌，对其造成X/2点伤害（X为翻开牌的点数，结果向上取整）",
	["#ocXSkill_YASHIRO_XA_MAX_Armor_Nullified"] = "%from 发动了“%arg”，令 %to 的防具无效直到本阶段结束",
	["#ocXSkill_YASHIRO_XA_MAX_Clear"] = "当前阶段结束，“%arg”的影响消失，%from 的防具恢复有效",
	["ocxskill_yashiro_xa_"] = "吼大地",
	["ocxskill_yashiro_xa_max_"] = "吼大地·MAX",
}
--[[
	必杀：荒大地
	出招：近身+后下前后下前+拳
	指令：草花+方块+黑桃+草花+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名距离为1的角色，随机获得其一张牌，然后你的上家、下家和你分别对其造成1点伤害并将其武将牌翻面。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XB") then
		if command == "Back+Down+Forward+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XB"] = {
	name = "ocXSkill_YASHIRO_XB_Card",
	--skill_name = "ocXSkill_YASHIRO_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XB") --播放配音
		local target = targets[1]
		if not target:isNude() then
			local cards = target:getCards("he")
			local count = cards:length()
			local index = math.random(0, count-1)
			local card = cards:at(index)
			room:obtainCard(source, card, true)
		end
		local damage = sgs.DamageStruct()
		damage.to = target
		damage.damage = 1
		local thread = room:getThread()
		if target:isAlive() and source:isAlive() then
			local num = room:alivePlayerCount()
			local last_player = source:getNextAlive(num-1)
			damage.from = last_player
			thread:delay()
			room:setPlayerFlag(last_player, "AI_DoNotUpdateIntention")
			room:damage(damage)
		end
		if target:isAlive() and source:isAlive() then
			local next_player = source:getNextAlive()
			damage.from = next_player
			thread:delay()
			room:setPlayerFlag(next_player, "AI_DoNotUpdateIntention")
			room:damage(damage)
		end
		if target:isAlive() and source:isAlive() then
			damage.from = source
			thread:delay()
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
		if target:isAlive() then
			target:turnOver()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XB") then
		if command == "Back+Down+Forward+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XB_MAX"] = {
	name = "ocXSkill_YASHIRO_XB_MAX_Card",
	--skill_name = "ocXSkill_YASHIRO_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XB") --播放配音
		local target = targets[1]
		if not target:isNude() then
			local cards = target:getCards("he")
			local count = cards:length()
			local index = math.random(0, count-1)
			local card = cards:at(index)
			room:obtainCard(source, card, true)
		end
		local num = room:alivePlayerCount()
		local last_player = source:getNextAlive(num-1)
		if target:isAlive() and source:isAlive() and not target:isNude() then
			local id = room:askForCardChosen(last_player, target, "he", "ocXSkill_YASHIRO_XB_MAX")
			if id > 0 and last_player:canDiscard(target, id) then
				room:throwCard(id, target, last_player)
			end
		end
		local next_player = source:getNextAlive()
		if target:isAlive() and source:isAlive() and not target:isNude() then
			local id = room:askForCardChosen(next_player, target, "he", "ocXSkill_YASHIRO_XB_MAX")
			if id > 0 and next_player:canDiscard(target, id) then
				room:throwCard(id, target, next_player)
			end
		end
		local damage = sgs.DamageStruct()
		damage.to = target
		damage.damage = 1
		local thread = room:getThread()
		if target:isAlive() and source:isAlive() then
			damage.from = last_player
			thread:delay()
			room:setPlayerFlag(last_player, "AI_DoNotUpdateIntention")
			room:damage(damage)
		end
		if target:isAlive() and source:isAlive() then
			damage.from = next_player
			thread:delay()
			room:setPlayerFlag(next_player, "AI_DoNotUpdateIntention")
			room:damage(damage)
		end
		if target:isAlive() and source:isAlive() then
			damage.from = source
			damage.damage = 2
			thread:delay()
			room:setPlayerFlag(source, "ocEnergyIgnore")
			room:damage(damage)
			room:setPlayerFlag(source, "-ocEnergyIgnore")
		end
		if target:isAlive() then
			target:turnOver()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XB_MAX"])
--技能效果
YASHIRO_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_YASHIRO_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
YASHIRO_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_YASHIRO_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(YASHIRO_XB_Audio)
YASHIRO:addSkill(YASHIRO_XB)
YASHIRO:addRelateSkill("ocXSkill_YASHIRO_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_YASHIRO_XB"] = "荒大地",
	["$ocXSkill_YASHIRO_XB"] = "おとなしくしてろよ、すぐにおわるからよ！",
	["@ocXSkill_YASHIRO_XB"] = "荒大地：您可以选择一名距离为1的角色，随机获得其一张牌，然后你的上家、下家和你分别对其造成1点伤害并将其武将牌翻面。",
	["ocXSkill_YASHIRO_XB_MAX"] = "荒大地·MAX",
	["@ocXSkill_YASHIRO_XB_MAX"] = "荒大地·MAX：您可以选择一名距离为1的角色，随机获得其一张牌，然后你的上家、下家分别弃置其一张牌并分别对其造成1点伤害，最后其受到你造成的2点伤害并翻面。",
	["ocxskill_yashiro_xb_"] = "荒大地",
	["ocxskill_yashiro_xb_max_"] = "荒大地·MAX",
}
--[[
	必杀：暗黑地狱极乐落
	出招：近身+前下后前下后+拳
	指令：黑桃+方块+草花+黑桃+方块+草花 -> 轻拳/重拳
	描述：你可以选择一名距离为1的角色，对其造成1点伤害。然后你翻开牌堆顶的五张牌，其中每翻开一张红心牌，其受到1点伤害，否则其随机弃置一张牌。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XC"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XC") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XC"] = {
	name = "ocXSkill_YASHIRO_XC_Card",
	--skill_name = "ocXSkill_YASHIRO_XC",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XC", 1) --播放配音
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 1
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		local thread = room:getThread()
		for i=1, 5, 1 do
			if target:isAlive() and source:isAlive() then
				local move = sgs.CardsMoveStruct()
				move.card_ids = room:getNCards(1, true)
				move.from = nil
				move.from_place = sgs.Player_DrawPile
				move.to = nil
				move.to_place = sgs.Player_PlaceTable
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
				room:moveCardsAtomic(move, true)
				thread:delay()
				local id = move.card_ids:first()
				local card = sgs.Sanguosha:getCard(id)
				if card:getSuit() == sgs.Card_Heart then
					local hurt = sgs.DamageStruct()
					hurt.from = nil
					hurt.to = target
					hurt.damage = 1
					room:damage(hurt)
				elseif not target:isNude() then
					local cards = target:getCards("he")
					local count = cards:length()
					local index = math.random(0, count-1)
					local to_throw = cards:at(index)
					if target:canDiscard(target, to_throw:getEffectiveId()) then
						room:throwCard(to_throw, target, target)
					end
				end
				move.from_place = sgs.Player_PlaceTable
				move.to_place = sgs.Player_DiscardPile
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
				room:moveCardsAtomic(move, true)
			else
				break
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XC"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XC"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_YASHIRO_XC_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_YASHIRO_XC") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_YASHIRO_XC_MAX"] = {
	name = "ocXSkill_YASHIRO_XC_MAX_Card",
	--skill_name = "ocXSkill_YASHIRO_XC_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_YASHIRO_XC", 1) --播放配音
		local target = targets[1]
		local damage = sgs.DamageStruct()
		damage.from = source
		damage.to = target
		damage.damage = 1
		room:setPlayerFlag(source, "ocEnergyIgnore")
		room:damage(damage)
		room:setPlayerFlag(source, "-ocEnergyIgnore")
		local thread = room:getThread()
		for i=1, 7, 1 do
			if target:isAlive() and source:isAlive() then
				local move = sgs.CardsMoveStruct()
				move.card_ids = room:getNCards(1, true)
				move.from = nil
				move.from_place = sgs.Player_DrawPile
				move.to = nil
				move.to_place = sgs.Player_PlaceTable
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_TURNOVER, source:objectName())
				room:moveCardsAtomic(move, true)
				thread:delay()
				local id = move.card_ids:first()
				local card = sgs.Sanguosha:getCard(id)
				if card:isRed() then
					local hurt = sgs.DamageStruct()
					hurt.from = nil
					hurt.to = target
					hurt.damage = 1
					room:damage(hurt)
				elseif not target:isNude() then
					local cards = target:getCards("he")
					local count = cards:length()
					local index = math.random(0, count-1)
					local to_throw = cards:at(index)
					if target:canDiscard(target, to_throw:getEffectiveId()) then
						room:throwCard(to_throw, target, target)
					end
				end
				move.from_place = sgs.Player_PlaceTable
				move.to_place = sgs.Player_DiscardPile
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_NATURAL_ENTER, source:objectName())
				room:moveCardsAtomic(move, true)
			else
				break
			end
		end
		if target:isAlive() and source:isAlive() then
			room:broadcastSkillInvoke("ocXSkill_YASHIRO_XC", 2) --播放配音
			thread:delay()
			local duel = sgs.Sanguosha:cloneCard("duel", sgs.Card_NoSuit, 0)
			duel:setSkillName("ocXSkill_YASHIRO_XC_MAX")
			if source:isProhibited(target, duel) then
				duel:deleteLater()
			else
				local use = sgs.CardUseStruct()
				use.from = source
				use.to:append(target)
				use.card = duel
				room:setPlayerFlag(source, "ocEnergyIgnore")
				room:useCard(use, false)
				room:setPlayerFlag(source, "-ocEnergyIgnore")
			end
			if target:isAlive() then
				target:turnOver()
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_YASHIRO_XC_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_YASHIRO_XC_MAX"])
--技能效果
YASHIRO_XC_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_YASHIRO_XC",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
YASHIRO_XC = sgs.CreateTriggerSkill{
	name = "#ocXSkill_YASHIRO_XC",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(YASHIRO_XC_Audio)
YASHIRO:addSkill(YASHIRO_XC)
YASHIRO:addRelateSkill("ocXSkill_YASHIRO_XC")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_YASHIRO_XC"] = "暗黑地狱极乐落",
	["$ocXSkill_YASHIRO_XC1"] = "調子こいてんじゃねーぞこら！",
	["$ocXSkill_YASHIRO_XC2"] = "その命もらったあ！",
	["@ocXSkill_YASHIRO_XC"] = "暗黑地狱极乐落：您可以选择一名距离为1的角色，对其造成1点伤害。然后你翻开牌堆顶的五张牌，其中每翻开一张红心牌，其受到1点伤害，否则其随机弃置一张牌。",
	["ocXSkill_YASHIRO_XC_MAX"] = "暗黑地狱极乐落·MAX",
	["@ocXSkill_YASHIRO_XC_MAX"] = "暗黑地狱极乐落·MAX：您可以选择一名距离为1的角色，对其造成1点伤害。然后你翻开牌堆顶的七张牌，其中每翻开一张红色牌，其受到1点伤害，否则其随机弃置一张牌。最后你视为对其使用了一张【决斗】并令其翻面。",
	["ocxskill_yashiro_xc_"] = "暗黑地狱极乐落",
	["ocxskill_yashiro_xc_max_"] = "暗黑地狱极乐落·MAX",
}
--[[****************************************************************
	编号：OROCHI - 010
	武将：高尼茨
	称号：息吹暴风
	势力：魏
	性别：男
	体力上限：4勾玉
]]--****************************************************************
GOENITZ = sgs.General(extension, "ocGOENITZ", "wei", 4)
--添加通用技能
GOENITZ:addSkill("ocEnergy")
GOENITZ:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocGOENITZ"] = "高尼茨",
	["&ocGOENITZ"] = "高尼茨",
	["#ocGOENITZ"] = "息吹暴风",
	["designer:ocGOENITZ"] = "DGAH",
	["cv:ocGOENITZ"] = "岛吉则",
	["illustrator:ocGOENITZ"] = "网络资源",
	["~ocGOENITZ"] = "（惨叫声）",
}
--[[
	必杀：黑暗哭泣
	出招：近身+前下后前下后+重拳
	指令：黑桃+方块+草花+黑桃+方块+草花 -> 重拳
	描述：你可以指定一名与你距离为1的角色，其他角色依次随机获得其一张牌（至少5张），然后该角色失去2点体力。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_GOENITZ_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GOENITZ_XA") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GOENITZ_XA"] = {
	name = "ocXSkill_GOENITZ_XA_Card",
	--skill_name = "ocXSkill_GOENITZ_XA",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GOENITZ_XA") --播放配音
		local target = targets[1]
		local num = 0
		local player = source
		local round = false
		local break_flag = false
		while true do
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				if p:objectName() ~= target:objectName() then
					if target:isDead() or target:isNude() then
						break_flag = true
						break
					elseif round and num >= 5 then
						break_flag = true
						break
					elseif p:isDead() then
						continue
					end
					local cards = target:getCards("he")
					local count = cards:length()
					local index = math.random(0, count-1)
					local card = cards:at(index)
					room:obtainCard(p, card, true)
					num = num + 1
				end
			end
			if break_flag then
				break
			end
			round = true
		end
		if target:isAlive() then
			room:loseHp(target, 2)
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_GOENITZ_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GOENITZ_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_GOENITZ_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GOENITZ_XA") then
		if command == "Forward+Down+Back+Forward+Down+Back" then
			if key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GOENITZ_XA_MAX"] = {
	name = "ocXSkill_GOENITZ_XA_MAX_Card",
	--skill_name = "ocXSkill_GOENITZ_XA_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:distanceTo(to_select) == 1 then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GOENITZ_XA") --播放配音
		local target = targets[1]
		local num = 0
		local player = source
		local round = false
		local break_flag = false
		while true do
			local alives = room:getAlivePlayers()
			for _,p in sgs.qlist(alives) do
				if p:objectName() ~= target:objectName() then
					if target:isDead() or target:isNude() then
						break_flag = true
						break
					elseif round and num >= 8 then
						break_flag = true
						break
					elseif p:isDead() then
						continue
					end
					local cards = target:getCards("he")
					local count = cards:length()
					local index = math.random(0, count-1)
					local card = cards:at(index)
					room:obtainCard(p, card, true)
					num = num + 1
				end
			end
			if break_flag then
				break
			end
			round = true
		end
		if target:isAlive() then
			room:loseHp(target, 3)
		end
		if target:isAlive() then
			target:turnOver()
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_GOENITZ_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GOENITZ_XA_MAX"])
--技能效果
GOENITZ_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_GOENITZ_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
GOENITZ_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_GOENITZ_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(GOENITZ_XA_Audio)
GOENITZ:addSkill(GOENITZ_XA)
GOENITZ:addRelateSkill("ocXSkill_GOENITZ_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_GOENITZ_XA"] = "黑暗哭泣",
	["$ocXSkill_GOENITZ_XA"] = "お别れです!",
	["@ocXSkill_GOENITZ_XA"] = "黑暗哭泣：您可以指定一名与你距离为1的角色，其他角色依次随机获得其一张牌（至少5张），然后该角色失去2点体力",
	["ocXSkill_GOENITZ_XA_MAX"] = "黑暗哭泣·MAX",
	["@ocXSkill_GOENITZ_XA_MAX"] = "黑暗哭泣·MAX：您可以指定一名与你距离为1的角色，其他角色依次随机获得其一张牌（至少8张），然后该角色失去3点体力并将武将牌翻面",
	["ocxskill_goenitz_xa_"] = "黑暗哭泣",
	["ocxskill_goenitz_xa_max_"] = "黑暗哭泣·MAX",
}
--[[
	必杀：真·八稚女·蛟
	出招：下后下前+拳
	指令：方块+草花+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，对其随机造成7次不利影响，然后令其受到2点伤害。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_GOENITZ_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GOENITZ_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GOENITZ_XB"] = {
	name = "ocXSkill_GOENITZ_XB_Card",
	--skill_name = "ocXSkill_GOENITZ_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GOENITZ_XB") --播放配音
		local target = targets[1]
		local map = {
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, --随机弃置目标一张牌
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  --随机获得目标一张牌
			3, 3, 3, 3, 3, 3, --目标失去1点体力
			4, --目标受到1点伤害
			5, 5, 5, --对目标造成1点伤害
			6, 6, --对目标造成1点火焰伤害
			7, 7, --对目标造成1点雷电伤害
			8, --目标翻面
		}
		local alive = doBaZhiNv(room, source, target, map)
		if alive then
			local damage = sgs.DamageStruct()
			damage.from = nil
			damage.to = target
			damage.damage = 2
			room:damage(damage)
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_GOENITZ_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GOENITZ_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_GOENITZ_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_GOENITZ_XB") then
		if command == "Down+Back+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_GOENITZ_XB_MAX"] = {
	name = "ocXSkill_GOENITZ_XB_MAX_Card",
	--skill_name = "ocXSkill_GOENITZ_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			if sgs.Self:objectName() ~= to_select:objectName() then
				return true
			end
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_GOENITZ_XB") --播放配音
		local target = targets[1]
		local map = {
			1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, --随机弃置目标一张牌
			2, 2, 2, 2, 2, 2, 2, 2, 2, 2, --随机获得目标一张牌
			3, 3, 3, 3, 3, 3, --目标失去1点体力
			4, 4, 4, --目标受到1点伤害
			5, 5, 5, 5, --对目标造成1点伤害
			6, 6, --对目标造成1点火焰伤害
			7, 7, --对目标造成1点雷电伤害
			8, --目标翻面
		}
		local alive = doBaZhiNv(room, source, target, map)
		if alive then
			room:loseMaxHp(target, 3)
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_GOENITZ_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_GOENITZ_XB_MAX"])
--技能效果
GOENITZ_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_GOENITZ_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
GOENITZ_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_GOENITZ_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(GOENITZ_XB_Audio)
GOENITZ:addSkill(GOENITZ_XB)
GOENITZ:addRelateSkill("ocXSkill_GOENITZ_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_GOENITZ_XB"] = "真·八稚女·蛟",
	["$ocXSkill_GOENITZ_XB"] = "神罚です!!",
	["@ocXSkill_GOENITZ_XB"] = "真·八稚女·蛟：您可以选择一名其他角色，对其随机造成7次不利影响，然后对其造成2点伤害。",
	["ocXSkill_GOENITZ_XB_MAX"] = "真·八稚女·实相克",
	["@ocXSkill_GOENITZ_XB_MAX"] = "真·八稚女·实相克：您可以选择一名其他角色，对其随机造成7次不利影响，然后令其失去3点体力上限。",
	["ocxskill_goenitz_xb_"] = "真·八稚女·蛟",
	["ocxskill_goenitz_xb_max_"] = "真·八稚女·实相克",
}
--[[****************************************************************
	编号：OROCHI - 011
	武将：大蛇
	称号：地球意志
	势力：神
	性别：男
	体力上限：4勾玉
]]--****************************************************************
OROCHI = sgs.General(extension, "ocOROCHI", "god", 4, true, true)
--添加通用技能
OROCHI:addSkill("ocEnergy")
OROCHI:addSkill("ocXSkill")
--翻译信息
sgs.LoadTranslationTable{
	["ocOROCHI"] = "大蛇",
	["&ocOROCHI"] = "大蛇",
	["#ocOROCHI"] = "地球意志",
	["designer:ocOROCHI"] = "DGAH",
	["cv:ocOROCHI"] = "绪方りお",
	["illustrator:ocOROCHI"] = "网络资源",
	["~ocOROCHI"] = "大蛇 的阵亡台词",
}
--[[
	必杀：混·まろかれ
	出招：下后+拳
	指令：方块+草花 -> 轻拳/重拳
	描述：你可以令所有其他角色依次先受到2点火焰伤害、再受到1点火焰伤害，然后翻面。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_OROCHI_XA"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_OROCHI_XA") then
		if command == "Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_OROCHI_XA"] = {
	name = "ocXSkill_OROCHI_XA_Card",
	--skill_name = "ocXSkill_OROCHI_XA",
	target_fixed = true,
	will_throw = false,
	mute = true,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_OROCHI_XA") --播放配音
		room:getThread():delay(500)
		local others = room:getOtherPlayers(source)
		room:sortByActionOrder(others)
		for _,target in sgs.qlist(others) do
			if target:isAlive() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 2
				damage.nature = sgs.DamageStruct_Fire
				room:damage(damage)
			end
			if target:isAlive() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 1
				damage.nature = sgs.DamageStruct_Fire
				room:damage(damage)
			end
			if target:isAlive() then
				target:turnOver()
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_OROCHI_XA"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_OROCHI_XA"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_OROCHI_XA_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_OROCHI_XA") then
		if command == "Down+Back" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_OROCHI_XA_MAX"] = {
	name = "ocXSkill_OROCHI_XA_MAX_Card",
	--skill_name = "ocXSkill_OROCHI_XA_MAX",
	target_fixed = true,
	will_throw = false,
	mute = true,
	on_use = function(self, room, source, targets)
		room:broadcastSkillInvoke("ocXSkill_OROCHI_XA") --播放配音
		room:getThread():delay(500)
		local others = room:getOtherPlayers(source)
		room:sortByActionOrder(others)
		for _,target in sgs.qlist(others) do
			if target:isAlive() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 3
				damage.nature = sgs.DamageStruct_Fire
				room:damage(damage)
			end
			if target:isAlive() then
				local damage = sgs.DamageStruct()
				damage.from = nil
				damage.to = target
				damage.damage = 1
				damage.nature = sgs.DamageStruct_Fire
				room:damage(damage)
			end
			if target:isAlive() then
				room:loseHp(target, 1)
				target:throwAllEquips()
			end
			if target:isAlive() then
				target:turnOver()
			end
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_OROCHI_XA_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_OROCHI_XA_MAX"])
--技能效果
OROCHI_XA_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_OROCHI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
OROCHI_XA = sgs.CreateTriggerSkill{
	name = "#ocXSkill_OROCHI_XA",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
--添加技能
AnJiang:addSkill(OROCHI_XA_Audio)
OROCHI:addSkill(OROCHI_XA)
OROCHI:addRelateSkill("ocXSkill_OROCHI_XA")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_OROCHI_XA"] = "混·まろかれ",
	["$ocXSkill_OROCHI_XA"] = "さあ、無に帰ろう... ",
	["@ocXSkill_OROCHI_XA"] = "混·まろかれ：您可以令所有其他角色依次先受到2点火焰伤害，再受到1点火焰伤害，然后翻面。",
	["ocXSkill_OROCHI_XA_MAX"] = "混·まろかれ·MAX",
	["@ocXSkill_OROCHI_XA_MAX"] = "混·まろかれ·MAX：您可以令所有其他角色依次受到3点火焰伤害，再受到1点火焰伤害，然后失去1点体力、弃置所有装备并翻面。",
	["ocxskill_orochi_xa_"] = "混·まろかれ",
	["ocxskill_orochi_xa_max_"] = "混·まろかれ·MAX",
}
--[[
	必杀：大神·おおみわ
	出招：前下前+拳
	指令：黑桃+方块+黑桃 -> 轻拳/重拳
	描述：你可以选择一名其他角色，若其在你的攻击范围内，你观看其所有手牌并弃置其中任意数目的红心牌，然后对其造成X点伤害（X为你弃置红心牌的数量）；若其不在你的攻击范围内，本回合内其视为在你的攻击范围内。
]]--
--正常版本
sgs.ocXSkillSelects["ocXSkill_OROCHI_XB"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_OROCHI_XB") then
		if command == "Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return not isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_OROCHI_XB"] = {
	name = "ocXSkill_OROCHI_XB_Card",
	--skill_name = "ocXSkill_OROCHI_XB",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		local target = targets[1]
		local thread = room:getThread()
		if source:inMyAttackRange(target) then
			if target:isKongcheng() then
				return 
			end
			local card_ids = target:handCards()
			local heart_ids = sgs.IntList()
			local disabled_ids = sgs.IntList()
			local to_throw = sgs.IntList()
			for _,id in sgs.qlist(card_ids) do
				local heart = sgs.Sanguosha:getCard(id)
				if heart:getSuit() == sgs.Card_Heart then
					heart_ids:append(id)
				else
					disabled_ids:append(id)
				end
			end
			local show_flag = true
			while true do
				if heart_ids:isEmpty() then
					break
				end
				room:fillAG(card_ids, source, disabled_ids)
				local id = room:askForAG(source, heart_ids, true, "ocXSkill_OROCHI_XB")
				room:clearAG(source)
				if id == -1 then
					break
				end
				card_ids:removeOne(id)
				heart_ids:removeOne(id)
				to_throw:append(id)
				show_flag = false
			end
			room:broadcastSkillInvoke("ocXSkill_OROCHI_XB", 1) --播放配音
			if show_flag then
				room:showAllCards(target, source)
			else
				local x = to_throw:length()
				local move = sgs.CardsMoveStruct()
				move.to = nil
				move.to_place = sgs.Player_DiscardPile
				move.card_ids = to_throw
				move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_DISMANTLE, source:objectName())
				room:moveCardsAtomic(move, true)
				local damage = sgs.DamageStruct()
				damage.from = source
				damage.to = target
				damage.damage = x
				room:setPlayerFlag(source, "ocEnergyIgnore")
				room:damage(damage)
				room:setPlayerFlag(source, "-ocEnergyIgnore")
			end
		else
			room:setPlayerMark(source, "ocXSkill_OROCHI_XB_Effect", 1)
			room:setPlayerMark(target, "ocXSkill_OROCHI_XB_Target", 1)
			room:insertAttackRangePair(source, target)
			local msg = sgs.LogMessage()
			msg.type = "#ocXSkill_OROCHI_XB_Dist"
			msg.from = player
			msg.to:append(target)
			room:sendLog(msg) --发送提示信息
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_OROCHI_XB"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_OROCHI_XB"])
--MAX版本
sgs.ocXSkillSelects["ocXSkill_OROCHI_XB_MAX"] = function(player, command, key)
	if player:hasSkill("#ocXSkill_OROCHI_XB") then
		if command == "Forward+Down+Forward" then
			if key == "ocKeyA" or key == "ocKeyC" then
				return isMaxMode(player)
			end
		end
	end
end
sgs.ocXSkillDetails["ocXSkill_OROCHI_XB_MAX"] = {
	name = "ocXSkill_OROCHI_XB_MAX_Card",
	--skill_name = "ocXSkill_OROCHI_XB_MAX",
	target_fixed = false,
	will_throw = false,
	mute = true,
	filter = function(self, targets, to_select)
		if #targets == 0 then
			return to_select:objectName() ~= sgs.Self:objectName()
		end
		return false
	end,
	on_use = function(self, room, source, targets)
		local target = targets[1]
		local heart_ids = sgs.IntList()
		if not target:isKongcheng() then
			room:showAllCards(target)
			local handcards = target:getHandcards()
			for _,card in sgs.qlist(handcards) do
				if card:getSuit() == sgs.Card_Heart then
					local id = card:getEffectiveId()
					heart_ids:append(id)
				end
			end
		end
		local count = heart_ids:length()
		if count > 0 then
			room:broadcastSkillInvoke("ocXSkill_OROCHI_XB", 1) --播放配音
			room:getThread():delay(1000)
			room:broadcastSkillInvoke("ocXSkill_OROCHI_XB", 2) --播放配音
			local move = sgs.CardsMoveStruct()
			move.card_ids = heart_ids
			move.to = nil
			move.to_place = sgs.Player_DiscardPile
			move.reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_DISMANTLE, source:objectName())
			room:moveCardsAtomic(move, true)
			room:killPlayer(target)
		else
			room:loseHp(target, 1)
		end
	end,
}
sgs.ocXSkillCards["ocXSkill_OROCHI_XB_MAX"] = sgs.CreateSkillCard(sgs.ocXSkillDetails["ocXSkill_OROCHI_XB_MAX"])
--技能效果
OROCHI_XB_Audio = sgs.CreateTriggerSkill{
	name = "ocXSkill_OROCHI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {},
	on_trigger = function(self, event, player, data)
	end,
}
OROCHI_XB = sgs.CreateTriggerSkill{
	name = "#ocXSkill_OROCHI_XB",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.EventPhaseStart},
	on_trigger = function(self, event, player, data)
		if player:getPhase() == sgs.Player_NotActive then
			if player:getMark("ocXSkill_OROCHI_XB_Effect") > 0 then
				local room = player:getRoom()
				room:setPlayerMark(player, "ocXSkill_OROCHI_XB_Effect", 0)
				local alives = room:getAlivePlayers()
				for _,p in sgs.qlist(alives) do
					if p:getMark("ocXSkill_OROCHI_XB_Target") > 0 then
						room:setPlayerMark(p, "ocXSkill_OROCHI_XB_Target", 0)
						room:removeAttackRangePair(player, p)
						local msg = sgs.LogMessage()
						msg.type = "#ocXSkill_OROCHI_XB_Dist_Clear"
						msg.from = player
						msg.to:append(p)
						room:sendLog(msg) --发送提示信息
					end
				end
			end
		end
		return false
	end,
}
--添加技能
AnJiang:addSkill(OROCHI_XB_Audio)
OROCHI:addSkill(OROCHI_XB)
OROCHI:addRelateSkill("ocXSkill_OROCHI_XB")
--翻译信息
sgs.LoadTranslationTable{
	["ocXSkill_OROCHI_XB"] = "大神·おおみわ",
	["$ocXSkill_OROCHI_XB1"] = "はかないもの... ",
	["$ocXSkill_OROCHI_XB2"] = "（音效；MAX版）",
	["@ocXSkill_OROCHI_XB"] = "大神·おおみわ：您可以选择一名其他角色，观看其所有手牌并弃置其中任意数目的红心牌，然后对其造成X点伤害（X为你弃置红心牌的数量）",
	["ocXSkill_OROCHI_XB_MAX"] = "大神·おおみわ·MAX",
	["@ocXSkill_OROCHI_XB_MAX"] = "大神·おおみわ·MAX：您可以选择一名其他角色，展示其所有手牌。若其中有红心牌，你弃置之并令该角色立即死亡，否则其受到1点伤害",
	["#ocXSkill_OROCHI_XB_Dist"] = "%from 发动了“大神·おおみわ”，%to 本回合内视为在 %from 的攻击范围内",
	["#ocXSkill_OROCHI_XB_Dist_Clear"] = "%from 的回合结束，解除了与 %to 的攻击范围约束",
	["ocxskill_orochi_xb_"] = "大神·おおみわ",
	["ocxskill_orochi_xb_max_"] = "大神·おおみわ·MAX",
}