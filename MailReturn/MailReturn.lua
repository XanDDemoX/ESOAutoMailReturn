
local _task = nil 

local _pending = {}
local _tasks = {}

local _delay = 1500
local _prefix = "[AutoMailReturn]: "

local _subjects = {"/r","/b","/ret","/rts","rts","return","bounce","/return","/bounce"}

local _settings = {autoDeleteEmpty = true, delay = _delay}

local _currentMail = { sendTo="", subject="" }

local _blocked = false
local _blockedrun = false

local function trim(str)
	if str == nil or str == "" then return str end 
	return (str:gsub("^%s*(.-)%s*$", "%1"))
end 

function stringStartWith(str,strstart)
   return string.sub(str,1,string.len(strstart))==strstart
end

local function IsPending(id)
	local item =_pending[zo_getSafeId64Key(id)] 
	return item ~= nil,item
end

local function IsValidSubject(subject)
	subject = string.lower(trim(subject))
	for i,v in ipairs(_subjects) do
		if stringStartWith(subject,v) == true then
			return true
		end
	end
	return false
end

local function IsReturnRequired(id, returned,subject,numAttachments,attachedMoney,codAmount)
	return returned == false and IsValidSubject(subject) and (numAttachments > 0 or attachedMoney > 0) and codAmount == 0 
end

local function IsEmptyReturned(id)
	local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(id)
	return returned == true and IsValidSubject(subjectText) and numAttachments == 0 and attachedMoney == 0 and codAmount == 0
end

local function TryParseOnOff(str)
	local on = (str == "+" or str == "on")
	local off = (str == "-" or str == "off")
	if on == false and off == false then return nil end
	return on
end

local function stringNilOrEmpty(str)
	return str == nil or str == ""
end

local function HookDescriptor(name,func)

	local d
	for i,v in ipairs(MAIL_SEND.staticKeybindStripDescriptor) do
		if v.name == name then
			d = v
			break
		end
	end
	
	if d.callback == nil then return end 
	
	local cb = d.callback
	
	d.callback = function(...)
		cb(...)
		func(...)
	end

end

local function TryOpenMailbox()
	if SCENE_MANAGER:IsShowing("mailInbox") then return false end

	RequestOpenMailbox()
	return true
end

local function TryCloseMailbox()
	if SCENE_MANAGER:IsShowing("mailInbox") then return false end

	CloseMailbox()
	return true
end

local function MailboxReturnMail(id)
	ReturnMail(id)
end

local function DelayedReturnMail(item,delay,callback)
	local id = item.id
	local key = zo_getSafeId64Key(id)
	
	if _pending[key] == nil then return end
	
	zo_callLater(function() 
		
		if _pending[key] == nil then return end
		_pending[key] = nil
		
		MailboxReturnMail(id)
		
		if callback ~= nil then 
			callback()
		end

	end,delay)
end

local function ReturnNext()

	local item = _tasks[1]
	if item == nil then 
		return 
	end
	
	table.remove(_tasks,1)
	
	DelayedReturnMail(item,item.delay,function() 
		d(item.text)
		if item.last == true then 
			TryCloseMailbox()
		else
			ReturnNext()
		end 
	end)

end

local function QueueMail(data,total,delay)

	data = data or {}
	local count 
	
	local cur = 0
	
	for k,v in pairs(data) do
	
		count = #v
		
		for i,item in ipairs(v) do
		
			cur = cur + 1
			
			local t = {id=item.id,last=cur==total,delay=delay,item=item,text=_prefix..item.sender.." mail "..tostring(i).." of "..tostring(count).." returned."}
			
			_pending[zo_getSafeId64Key(item.id)] = t
			
			table.insert(_tasks,t)
			
		end
		
	end
	

end

local function StartQueued()
	if #_tasks < 1 then return end 
	
	local id 
	for i,item in ipairs(_tasks) do
		ReadMail(item.id)
		if item.last then
			id = item.id
		end 
	end

	ReturnNext()
end

local function GetMailIds()

	local tbl = {}

	local id = GetNextMailId()
	
	while (id ~= nil) do
	
		table.insert(tbl,id)
		
		id = GetNextMailId(id)
		
	end
	
	return tbl
	
end

local function GetMailToReturn(ids)
	
	local count = 0 
	local senderCount = 0
	local _read = 0
	local total = #ids
	
	local data = {}
	local items = {}
	
	for i,id in ipairs(ids) do
		if IsPending(id) == false and IsMailReturnable(id) == true then
		
			local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(id)

			if IsReturnRequired(id,returned,subjectText,numAttachments,attachedMoney,codAmount) == true then
				
				local tbl = data[senderDisplayName]
				
				if tbl == nil then 
					senderCount = senderCount + 1
					tbl = {}
					data[senderDisplayName] = tbl
				end
				
				local item = {id = id, sender=senderDisplayName}
				
				table.insert(tbl,item)
				
				count = count + 1
			end
		end
		_read = _read + 1
	end
	return data,count,senderCount
end

local function MailReturn_Run(func)
	
	if _blocked == true then 
		_blockedrun = true 
		return 
	end 
	
	if _task ~= nil then return end
	_task = func 
	
	TryOpenMailbox()
	
end

local function ReturnTask()
	local ids = GetMailIds()

	local data,count,senderCount = GetMailToReturn(ids)
	
	if count > 0 then
		d(_prefix..tostring(count).." mail"..((count > 1 and "s") or "") .." to return to "..tostring(senderCount).." senders.")
		QueueMail(data,count,_settings.delay)
		StartQueued()
	else
		TryCloseMailbox()
	end
end

local function ClearCurrentMail()
	_currentMail.sendTo = ""
	_currentMail.subject = ""
end

local function UpdateFromCurrentMail()
	if IsValidSubject(_currentMail.subject) == true then 
		ZO_MailSendToField:SetText(_currentMail.sendTo)
		ZO_MailSendSubjectField:SetText(_currentMail.subject)
	end
	ClearCurrentMail()
end

local function UpdateCurrentMail()
	_currentMail.sendTo = ZO_MailSendToField:GetText()
	_currentMail.subject = ZO_MailSendSubjectField:GetText()
end

local function MailReturn_Player_Activated(eventCode)
	zo_callLater(function() -- delay on activate just in case
		MailReturn_Run(ReturnTask)
	end,15000)
end

local _unreadCalling = false
local function MailReturn_Mail_Num_Unread_Changed(eventCode,count)
-- suppress some more calls
	if count == 0 or _task ~= nil or _unreadCalling == true then return end
	
	_unreadCalling = true 
	
	zo_callLater(function() 
		MailReturn_Run(ReturnTask)
		_unreadCalling = false
	end,5000)
end

local function InitMailbox()
	-- fix for inaccessible mail bug =/. Ensures masterList is built and top mail is selected...whoops ZOS :P
	if MAIL_INBOX.masterList == nil then 
		MAIL_INBOX:BuildMasterList()
		MAIL_INBOX:FilterScrollList()
		MAIL_INBOX:SortScrollList()
		MAIL_INBOX:CommitScrollList()
		MAIL_INBOX:OnSelectionChanged(MAIL_INBOX.masterList[#MAIL_INBOX.masterList],MAIL_INBOX.masterList[#MAIL_INBOX.masterList])
	end
end

local function MailReturn_Open_Mailbox(eventCode)
	if _task == nil then return end
	

	if MAIL_INBOX.masterList == nil then 
		InitMailbox()
	end
	
	_task()
end

local function MailReturn_Close_Mailbox(eventCode)
	if _task == nil then return end
	_task = nil
end

local function MailReturn_Take_Attached_Item_Success(eventCode,id)
	if _settings.autoDeleteEmpty == true and IsEmptyReturned(id) == true then
		MAIL_INBOX:ConfirmDelete(id)
	end
end

local function MailReturn_Mail_Send_Success(eventCode)
	UpdateFromCurrentMail()
end


local function WindowOpen(eventCode)
	_blocked = true 
end

local function WindowClose(eventCode)
	_blocked = false
	if _blockedrun == true then 
		_blockedrun = false
		MailReturn_Run(ReturnTask)
	end 
end 

local function IsMailForReturn(id)
	local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(id)
	return IsReturnRequired(id,returned,subjectText,numAttachments,attachedMoney,codAmount) == true
end

local function InitProtection()
	local takeAttach_Keybind = MAIL_INBOX.selectionKeybindStripDescriptor[3]
	
	if takeAttach_Keybind ~= nil then 
		
		local orig_tryTakeAll = MAIL_INBOX.TryTakeAll
		
		local orig_takeAttachVisible = takeAttach_Keybind.visible
		
		MAIL_INBOX.TryTakeAll = function(self,...)
			
			local id = self.mailId
			
			if id and IsMailForReturn(id) == true then return end 

			orig_tryTakeAll(self,...)

		end 
		
		takeAttach_Keybind.visible = function()
			local id = MAIL_INBOX.mailId
			return orig_takeAttachVisible() and (id == nil or IsMailForReturn(id) == false)
		end 
	
	end 
end 

local function addEvent(eventId,func)
	EVENT_MANAGER:RegisterForEvent("MailReturn_"..tostring(eventId),eventId,func)
end

local function addEvents(func,...)

	local count = select('#',...)
	
	local id
	
	for i = 1, count do 
	
		id = select(i,...)
	
		addEvent(id,func)
	end 

end





local function Initialise()
	InitProtection()
	
	-- for refresh on login / travel / reloadui
	addEvent(EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	-- for refresh on receive
	addEvent(EVENT_MAIL_NUM_UNREAD_CHANGED,MailReturn_Mail_Num_Unread_Changed)
	
	-- for reading mailbox
	addEvent(EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	
	addEvent(EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)
	
	addEvent(EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,MailReturn_Take_Attached_Item_Success)
	
	addEvent(EVENT_MAIL_SEND_SUCCESS,MailReturn_Mail_Send_Success)
	
	-- prevent running during interactions
	
	addEvents(WindowOpen,EVENT_CRAFTING_STATION_INTERACT,EVENT_OPEN_BANK,EVENT_OPEN_GUILD_BANK,EVENT_OPEN_STORE,EVENT_OPEN_TRADING_HOUSE,EVENT_TRADE_INVITE_ACCEPTED)
	
	addEvents(WindowClose, EVENT_END_CRAFTING_STATION_INTERACT,EVENT_CLOSE_BANK,EVENT_CLOSE_GUILD_BANK,EVENT_CLOSE_STORE,EVENT_CLOSE_TRADING_HOUSE,EVENT_TRADE_SUCCEEDED,EVENT_TRADE_CANCELED)
	
	addEvent(EVENT_PLAYER_COMBAT_STATE,function(eventCode,inCombat)
		if inCombat == true then 
			WindowOpen()
		else
			WindowClose()
		end
	end)
	
	-- block for fishing and looting etc
	ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", function(control, hidden)
		_blocked = true
	end)
	
	ZO_PreHookHandler(RETICLE.interact, "OnHide",function(control, hidden)
		_blocked = false
	end)
	
	
	HookDescriptor(GetString(SI_MAIL_SEND_SEND),UpdateCurrentMail)
	
	HookDescriptor(GetString(SI_MAIL_SEND_CLEAR),ClearCurrentMail)
	
	local func = function()
		d(_prefix.."Refeshing...")
		MailReturn_Run(ReturnTask)
	end
	
	SLASH_COMMANDS["/return"] = func
	SLASH_COMMANDS["/ret"] = func
	SLASH_COMMANDS["/r"] = func
	
	local delfunc = function(arg)
		
		arg = trim(arg)
		
		local onOff = TryParseOnOff(arg)
	
		if onOff ~= nil then 
			_settings.autoDeleteEmpty = onOff
			d(table.concat({_prefix,"Empty Mail Delete ",((onOff == true and "Enabled") or "Disabled")}))
		end
	end
	
	SLASH_COMMANDS["/rdelete"] = delfunc
	
end

local function MailReturn_Loaded(eventCode, addOnName)

	if(addOnName ~= "MailReturn") then return end
	
	_settings = ZO_SavedVars:New("MailReturn_SavedVariables", "1", "", _settings, nil)
	
	Initialise()
end
EVENT_MANAGER:RegisterForEvent("MailReturn_Loaded", EVENT_ADD_ON_LOADED, MailReturn_Loaded)
