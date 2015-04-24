--------------------------------------
--  Auto Mail Return Version 0.0.5  --
--------------------------------------

local _task = nil 

local _pending = {}
local _delay = 1500
local _prefix = "[AutoMailReturn]"

local _subjects = {"/return","/ret","/r"}

function stringStartWith(str,strstart)
   return string.sub(str,1,string.len(strstart))==strstart
end

local function IsPending(id)
	local item =_pending[id] 
	return item ~= nil,item
end

local function QueueTask(id,callback)
	_pending[id] = {id=id,last=last,callback=function(...) 
		callback(...) 
		_pending[id] = nil
	end}
	RequestReadMail(id)
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

local function MailReturn_Run(func)
	
	if _task ~= nil then return end
	_task = func 
	RequestOpenMailbox()

end

local function ReturnAllMail(data,total,delay)

	data = data or {}
	local count 
	local id 
	
	local cur = 0
	
	local last = false
	
	for k,v in pairs(data) do 
		count = #v
		for i,item in ipairs(v) do 
		
			cur = cur + 1 
			
			id = item.id
			
			last = cur == total 
			
			if IsPending(id) == false then
			
				QueueTask(id,function(item)
					zo_callLater(function() 
						
						ReturnMail(id)
						MAIL_INBOX:RefreshData()
						
						d(_prefix..": "..item.sender.." mail "..tostring(i).." of "..tostring(count).." returned.")
												
						if last == true then
							CloseMailbox()
						end
						
					end,delay)
				end)

			end
		end
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

				table.insert(tbl,{id = id, sender=senderDisplayName})
				
				count = count + 1

				--d("returnable: "..tostring(_read).." of "..tostring(_total).." "..senderDisplayName.." "..subjectText.." "..numAttachments)
			
			end
		end
		_read = _read + 1
	end
	
	return data,count,senderCount
end

local function ReturnTask()
	local ids = GetMailIds()

	local data,count,senderCount = GetMailToReturn(ids)
	
	if count > 0 then
		d(_prefix..": "..tostring(count).." mail"..((count > 1 and "s") or "") .." to return to "..tostring(senderCount).." senders.")
		ReturnAllMail(data,count,_delay)
	else
		MAIL_INBOX:RefreshData()
		CloseMailbox()
	end
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
	local pending, item = IsPending(mailId)
	
	if pending == true then
	
		MAIL_INBOX:EndRead()
		
		item:callback()
	end
end

local function MailReturn_Close_Mailbox(eventCode)
	if _task == nil then return end
	_task = nil
end

local function Initialise()

	-- for refresh on login / travel / reloadui
	EVENT_MANAGER:RegisterForEvent("MailReturn_Player_Activated", EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	-- for refresh on receive
	EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Num_Unread_Changed",EVENT_MAIL_NUM_UNREAD_CHANGED,MailReturn_Mail_Num_Unread_Changed)
	
	-- for reading mailbox
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Mailbox", EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Mailbox", EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)

	EVENT_MANAGER:RegisterForEvent("MailReturn_Read_Mail",EVENT_MAIL_READABLE,MailReturn_Read_Mail)
	
	SLASH_COMMANDS["/rrepair"] = function()

		MailReturn_Run(function()
			local ids = GetMailIds()
			d(#ids)
			for i,id in ipairs(ids) do
				QueueTask(id,function(item) 

				end)
			end
		
		end)
		
	end
end

local function MailReturn_Loaded(eventCode, addOnName)

	if(addOnName ~= "MailReturn") then return end
	
	Initialise()
end
EVENT_MANAGER:RegisterForEvent("MailReturn_Loaded", EVENT_ADD_ON_LOADED, MailReturn_Loaded)
