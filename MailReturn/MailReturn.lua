--------------------------------------
--  Auto Mail Return Version 0.0.3  --
--------------------------------------

local _refresh = false 
local _data = {}

local _pending = {}
local _delay = 1500
local _prefix = "[AutoMailReturn]"

local _subjects = {"/return","/ret","/r"}

function stringStartWith(str,strstart)
   return string.sub(str,1,string.len(strstart))==strstart
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

local function MailReturn_Refresh()
	if _refresh == true then return end
	_refresh = true 
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
			
			if _pending[id] == nil then
			
				_pending[id] = id
				
				zo_callLater(function() 
					
					ReturnMail(id)

					d(_prefix..": "..item.sender.." mail "..tostring(i).." of "..tostring(count).." returned.")
					
					
					_pending[id] = nil
					
					if last == true then
						MAIL_INBOX:RefreshData()
						CloseMailbox()
					end
					
				end,delay)
				
			end
		end
	end
end

local function MailReturn_Player_Activated(eventCode)
	MailReturn_Refresh()
end

local function MailReturn_Mail_Num_Unread_Changed(eventCode,count)
	MailReturn_Refresh()
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
	local _read = 0
	local total = #ids
	
	local data = {}
	
	for i,id in ipairs(ids) do
		if _pending[id] == nil and IsMailReturnable(id) == true then
			local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(id)

			if IsReturnRequired(id,returned,subjectText,numAttachments,attachedMoney,codAmount) == true then
			
				local tbl = _data[senderDisplayName] or {}

				table.insert(tbl,{id = id, sender=senderDisplayName})

				data[senderDisplayName] = tbl

				count = count + 1

				d("returnable: "..tostring(_read).." of "..tostring(_total).." "..senderDisplayName.." "..subjectText.." "..numAttachments)
			
			end
		end
		_read = _read + 1
	end
	
	return data,count
end

local function MailReturn_Open_Mailbox(eventCode)
	if _refresh == false then return end
	
	local ids = GetMailIds()

	local data,count = GetMailToReturn(ids)
	
	if count > 0 then
		d(_prefix..": "..tostring(_count).." mail"..((count > 1 and "s") or "") .." to return to "..tostring(#_data).." senders.")
		ReturnAllMail(data,count,_delay)
	else
		MAIL_INBOX:RefreshData()
		CloseMailbox()
	end
	
end

local function MailReturn_Close_Mailbox(eventCode)
	if _refresh == false then return end
	_refresh = false
end

local function Initialise()

	-- for refresh on login / travel / reloadui
	EVENT_MANAGER:RegisterForEvent("MailReturn_Player_Activated", EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	-- for refresh on receive
	EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Num_Unread_Changed",EVENT_MAIL_NUM_UNREAD_CHANGED,MailReturn_Mail_Num_Unread_Changed)
	
	-- for reading mailbox
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Mailbox", EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Mailbox", EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)
	
	MAIL_INBOX:EndRead()
end

local function MailReturn_Loaded(eventCode, addOnName)

	if(addOnName ~= "MailReturn") then return end
	
	Initialise()
end
EVENT_MANAGER:RegisterForEvent("MailReturn_Loaded", EVENT_ADD_ON_LOADED, MailReturn_Loaded)
