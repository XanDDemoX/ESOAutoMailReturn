ESOAutoMailReturn v1.0.1
=============

A lightweight mail return/bounce addon for The Elder Scrolls Online. Automatically returns any mail with attachments received from another player that starts with one of the following subject prefixes (case insensitive):

* /r
* /b
* /ret 
* /return
* /bounce
* return
* bounce 
* /rts
* rts

Optionally any other text may follow the subject prefix e.g:

/r Extract Items

Additional Features
=============
* Protects mails for return from Take Attachments.
* Avoids running during combat and menu interactions (e.g bank/crafting)
* Optionally automatically deletes returned mails upon all attachments being taken (on by default). 

Installation
=============

1. [Download the latest version](https://raw.githubusercontent.com/XanDDemoX/ESOAutoMailReturn/master/zips/Auto%20Mail%20Return%201.0.1.zip)
2. Extract or copy the "MailReturn" folder into your addons folder:

"Documents\Elder Scrolls Online\live\Addons"

"Documents\Elder Scrolls Online\liveeu\Addons"

For example:

"Documents\Elder Scrolls Online\live\Addons\MailReturn"

"Documents\Elder Scrolls Online\liveeu\Addons\MailReturn"

Usage
=============
Install and tell your friends! They can bounce their mails with: 

* /r
* /b
* /ret 
* /return
* /bounce
* return
* bounce 

Optionally any other text may follow the subject prefix e.g:

/r Extract Items

Slash Commands
=============

* /r, /ret, /return - Force refresh and attempt to return any unsent mails.
* /rdelete +/-, on/off - Enable or disable automatic deletion of emptied returned mail 

Change Log
=============
* **Version 1.0.1**
  * Added /rts and rts subjects
* **Version 1.0.0**
  * Added string trims for sanity
* **Version 0.0.10**
  * Added protection from returner taking attachments that are intended for a returnee. 


DISCLAIMER
=============
THIS ADDON IS NOT CREATED BY, ENDORSED, MAINTAINED OR SUPPORTED BY ZENIMAX OR ANY OF ITS AFFLIATES.