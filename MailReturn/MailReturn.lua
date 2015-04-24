--------------------------------------
--  Auto Mail Return Version 0.0.2  --
--------------------------------------

local _refresh = false 
local _data = {}
local _count = 0 
local _pending = {}
local _delay = 1500
local _prefix = "[AutoMailReturn]"
local _total = 0
local _read = 0

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
	return IsMailReturnable(id) == true and returned == false and IsValidSubject(subject) and (numAttachments > 0 or attachedMoney > 0) and codAmount == 0 
end

local function MailReturn_Refresh()
	if _refresh == true then return end
	_refresh = true
	_count = 0
	_data = {}
	RequestOpenMailbox()
end

local function ReturnAllMail()
	local count = 0
	local id 
	
	local cur = 0
	
	local last = false
	
	for k,v in pairs(_data) do 
		count = #v
		for i,item in ipairs(v) do 
		
			cur = cur + 1 
			
			id = item.id
			
			last = cur == _count 
			
			if _pending[id] == nil then
			
				_pending[id] = id
				
				zo_callLater(function() 
					
					ReturnMail(id)
									
					d(_prefix..": "..item.sender.." mail "..tostring(i).." of "..tostring(count).." returned.")
					
					_pending[id] = nil
					
					if last == true then
						CloseMailbox()
					end
					
				end,_delay)
				
			end
		end
	end
end

local function MailReturn_Player_Activated(eventCode)
	if _refresh == true then return end
	MailReturn_Refresh()
end

local function MailReturn_Mail_Num_Unread_Changed(eventCode,count)
	if _refresh == true then return end
	MailReturn_Refresh()
end

local function GetMailIds()

	local tbl = {}

	local mailId = GetNextMailId()
	
	while (mailId ~= nil) do
	
		table.insert(tbl,mailId)
		
		mailId = GetNextMailId(mailId)
		
	end
	
	return tbl
	
end

local function MailReturn_Open_Mailbox(eventCode)
	if _refresh == false then return end
	
	local ids = GetMailIds()
	
	_total = #ids
	
	for i,id in ipairs(ids) do
		RequestReadMail(id)
	end

end

local function MailReadable_Mail_Readable(eventCode,mailId)
	if _refresh == false then return end
	
	--d(mailId)
	
	if _read < _total then
	
		if _pending[mailId] == nil then
		
			local senderDisplayName, senderCharacterName, subjectText, mailIcon, unread, fromSystem, fromCustomerService, returned, numAttachments, attachedMoney, codAmount, expiresInDays, secsSinceReceived = GetMailItemInfo(mailId)

			if IsReturnRequired(mailId,returned,subjectText,numAttachments,attachedMoney,codAmount) == true then
				local tbl = _data[senderDisplayName] or {}

				table.insert(tbl,{id = mailId, sender=senderDisplayName})
			
				_data[senderDisplayName] = tbl
				
				_count = _count + 1
				
				--d("returnable: "..tostring(_read).." of "..tostring(_total).." "..senderDisplayName.." "..subjectText.." "..numAttachments)
			end
			
		end
		
		_read = _read + 1
		
	end
	
	if _read >= _total then
		_read = 0 
		_total = 0
		
		if _count > 0 then
			d(_prefix..": "..tostring(_count).." mail"..((_count > 1 and "s") or "") .." to return to "..tostring(#_data).." senders.")
			ReturnAllMail()
		else
			CloseMailbox()
		end
		
	end
end

local function MailReturn_Close_Mailbox(eventCode)
	if _refresh == false then return end
	_refresh = false
	MAIL_INBOX:RefreshData()
end

local function Initialise()

	-- for refresh on login / travel / reloadui
	EVENT_MANAGER:RegisterForEvent("MailReturn_Player_Activated", EVENT_PLAYER_ACTIVATED, MailReturn_Player_Activated)
	
	-- for refresh on receive
	EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Num_Unread_Changed",EVENT_MAIL_NUM_UNREAD_CHANGED,MailReturn_Mail_Num_Unread_Changed)
	
	-- for reading mailbox
	EVENT_MANAGER:RegisterForEvent("MailReturn_Open_Mailbox", EVENT_MAIL_OPEN_MAILBOX, MailReturn_Open_Mailbox)
	
	EVENT_MANAGER:RegisterForEvent("MailReturn_Close_Mailbox", EVENT_MAIL_CLOSE_MAILBOX, MailReturn_Close_Mailbox)
	
    EVENT_MANAGER:RegisterForEvent("MailReturn_Mail_Readable", EVENT_MAIL_READABLE, MailReadable_Mail_Readable)
	
end

local function MailReturn_Loaded(eventCode, addOnName)

	if(addOnName ~= "MailReturn") then return end
	
	Initialise()
end
EVENT_MANAGER:RegisterForEvent("MailReturn_Loaded", EVENT_ADD_ON_LOADED, MailReturn_Loaded)
