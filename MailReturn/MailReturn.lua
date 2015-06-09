
local _task = nil 

local _pending = {}
local _tasks = {}

local _delay = 1250
local _prefix = "[AutoMailReturn]: "

local _subjects = {"/r","/b","/ret","return","bounce","/return","/bounce"}

local _settings = {autoDeleteEmpty = true, delay = _delay}

local _currentMail = { sendTo="", subject="" }

local _blocked = false
local _blockedrun = false

function stringStartWith(str,strstart)
   return string.sub(str,1,string.len(strstart))==strstart
end

local function IsPending(id)
	local item =_pending[id] 
	return item ~= nil,item
end

local function IsValidSubject(subject)
	subject = string.lower(subject)
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


local function isOnString(str)
	str = string.lower(str)
	return str == "+" or str == "on"
end

local function isOffString(str)
	str = string.lower(str)
	return str == "-" or str == "off"
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

local function DelayedReturnMail(item,delay,callback)
	local id = item.id
	zo_callLater(function() 
		
		ReturnMail(id)
		
		_pending[id] = nil
		
		MAIL_INBOX:RefreshData()
									
		if item.last == true then
			CloseMailbox()
		end
		
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
		ReturnNext()
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
			
			_pending[item.id] = t
			
			table.insert(_tasks,t)
			
		end
		
	end
	
	for i,item in ipairs(_tasks) do
		RequestReadMail(item.id)
	end

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

				--d("returnable: "..tostring(_read).." of "..tostring(_total).." "..senderDisplayName.." "..subjectText.." "..numAttachments)
			
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
	
	RequestOpenMailbox()

end

local function ReturnTask()
	local ids = GetMailIds()

	local data,count,senderCount = GetMailToReturn(ids)
	
	if count > 0 then
		d(_prefix..tostring(count).." mail"..((count > 1 and "s") or "") .." to return to "..tostring(senderCount).." senders.")
		QueueMail(data,count,_settings.delay)
	else
		MAIL_INBOX:RefreshData()
		CloseMailbox()
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
	MailReturn_Run(ReturnTask)
end

local function MailReturn_Mail_Num_Unread_Changed(eventCode,count)
	if count == 0 then return end 
	MailReturn_Run(ReturnTask)
end

local function MailReturn_Open_Mailbox(eventCode)
	if _task == nil then return end
	_task()
end

local function MailReturn_Read_Mail(eventCode,mailId)
	local pending,item = IsPending(mailId)
	
	if pending == true then
	
		MAIL_INBOX:EndRead()
		
		if item.last == true then 
			ReturnNext()
		end
		
	end
end

local function MailReturn_Close_Mailbox(eventCode)
	if _task == nil then return end
	_task = nil
end

local function MailReturn_Take_Attached_Item_Success(eventCode,id)
	if _settings.autoDeleteEmpty == true and IsEmptyReturned(id) == true then
		DeleteMail(id,false)
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

local function InitProtection()
	local takeAttach_Keybind = MAIL_INBOX.selectionKeybindStripDescriptor[3]
	
	if takeAttach_Keybind ~= nil then 
		
		local orig_tryTakeAll = MAIL_INBOX.TryTakeAll
		
		local orig_takeAttachVisible = takeAttach_Keybind.visible
		
		MAIL_INBOX.TryTakeAll = function(self,...)
			
			local id = self.mailId
			
			if id and IsMailReturnable(id) == true then return end 

			orig_tryTakeAll(self,...)

		end 
		
		takeAttach_Keybind.visible = function()
			local id = MAIL_INBOX.mailId
			return orig_takeAttachVisible() and (id == nil or IsMailReturnable(id) == false)
		end 
	
	end 
end 

local function Initialise()
	InitProtection()
	
	-- for refresh on login / travel / reloadui
	EVENT_MANAGER:RegisterForEvent("MailReturn_Player_Activated", EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	-- for refresh on receive
	EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Num_Unread_Changed",EVENT_MAIL_NUM_UNREAD_CHANGED,MailReturn_Mail_Num_Unread_Changed)
	
	-- for reading mailbox
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Mailbox", EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Mailbox", EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)

	EVENT_MANAGER:RegisterForEvent("MailReturn_Read_Mail",EVENT_MAIL_READABLE,MailReturn_Read_Mail)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Take_Attached_Item_Success",EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,MailReturn_Take_Attached_Item_Success)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Send_Success",EVENT_MAIL_SEND_SUCCESS,MailReturn_Mail_Send_Success)
	
	-- prevent running during interactions
	EVENT_MANAGER:RegisterForEvent("MailReturn_Crafting_Station_Interact",EVENT_CRAFTING_STATION_INTERACT,WindowOpen)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_End_Crafting_Station_Interact",EVENT_END_CRAFTING_STATION_INTERACT,WindowClose)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Bank",EVENT_OPEN_BANK,WindowOpen)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Bank",EVENT_CLOSE_BANK,WindowClose)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Guild_Bank",EVENT_OPEN_GUILD_BANK,WindowOpen)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Guild_Bank",EVENT_CLOSE_GUILD_BANK,WindowClose)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Store",EVENT_OPEN_STORE,WindowOpen)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Store",EVENT_CLOSE_STORE,WindowClose)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Trading_House",EVENT_OPEN_TRADING_HOUSE,WindowOpen)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Trading_House",EVENT_CLOSE_TRADING_HOUSE,WindowClose)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Trade_Invite_Accepted",EVENT_TRADE_INVITE_ACCEPTED,WindowOpen)
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Trade_Succeeded",EVENT_TRADE_SUCCEEDED,WindowClose)
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Trade_Cancelled",EVENT_TRADE_CANCELED ,WindowClose)
	
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
		if isOnString(arg) then
			_settings.autoDeleteEmpty = true
			d(_prefix.."Empty Mail Delete Enabled")
		elseif isOffString(arg) then
			_settings.autoDeleteEmpty = false
			d(_prefix.."Empty Mail Delete Disabled")
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
