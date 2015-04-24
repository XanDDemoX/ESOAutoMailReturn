--------------------------------------
--  Auto Mail Return Version 0.0.1  --
--------------------------------------

local _refresh = false 
local _data = {}
local _count = 0 
local _pending = {}
local _delay = 1000
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
	return IsMailReturnable(id) and returned == false and IsValidSubject(subject) and (numAttachments > 0 or attachedMoney > 0) and codAmount == 0 
end

local function MailReturn_Refresh()
	if _refresh == true then return end
	_refresh = true
	_count = 0
	_data = {}
	local result = RequestOpenMailbox()
end

local function ReturnAllMail()
	if _refresh == true then return end 
	local count = 0
	local id 
	for k,v in pairs(_data) do 
		count = #v
		for i,item in ipairs(v) do 
		
			id = item.id
			
			if _pending[id] == nil then
				_pending[id] = id
				zo_callLater(function() 
					
					ReturnMail(id)
					
					d(_prefix..": "..item.sender.." mail "..tostring(i).." of "..tostring(count).." returned.")
					
					_pending[id] = nil
					
				end,_delay)
			end
		end
	end
end

local function MailReturn_Player_Activated(eventCode)
	MailReturn_Refresh()
end

local function MailReturn_Mail_Num_Unread_Changed(eventCode,count)
	if _refresh == true then return end
	if count == 0 then return end
	
	MailReturn_Refresh()
end

local function MailReturn_Open_Mailbox(eventCode)
	if _refresh == false then return end
	
	local mailId = GetNextMailId()
	
	while (mailId ~= nil) do
	
		RequestReadMail(mailId)
		
		mailId = GetNextMailId(mailId)

	end
	
	if _count > 0 then
		d(_prefix..": "..tostring(_count).." mail"..((_count > 1 and "s") or "") .." to return to "..tostring(#_data).." senders.")
	end

	CloseMailbox()
end

local function MailReadable_Mail_Readable(eventCode,mailId)
	if _refresh == false then return end
	
	local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(mailId)

	if IsReturnRequired(mailId,returned,subjectText,numAttachments,attachedMoney,codAmount) == true then
		local tbl = _data[senderDisplayName] or {}

		table.insert(tbl,{id = mailId, sender=senderDisplayName})
	
		_data[senderDisplayName] = tbl
		
		_count = _count + 1
	end
end

local function MailReturn_Close_Mailbox(eventCode)
	if _refresh == false then return end
	_refresh = false
	ReturnAllMail()
end

local function Initialise()
	EVENT_MANAGER:RegisterForEvent("MailReturn_Player_Activated", EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Mailbox", EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Mailbox", EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)
    EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Readable", EVENT_MAIL_READABLE, MailReadable_Mail_Readable)
end

local function MailReturn_Loaded(eventCode, addOnName)

	if(addOnName ~= "MailReturn") then return end
	
	Initialise()
end
EVENT_MANAGER:RegisterForEvent("MailReturn_Loaded", EVENT_ADD_ON_LOADED, MailReturn_Loaded)
