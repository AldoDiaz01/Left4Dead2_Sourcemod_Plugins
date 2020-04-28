#define PLUGIN_VERSION 		"1.1.1"

/*======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Real Zoey Unlock
*	Author	:	SilverShot
*	Descrp	:	Unlocks Zoey. No bugs. No crashes. No fakes. The Real Deal.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=308483
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.1.1 (22-June-2018)
	- Restricted to Windows only.

1.1 (22-June-2018)
	- Changed to support any future game updates without breaking.

1.0 (21-June-2018)
	- Initial release.

======================================================================================*/
/*
	0	server.dll + 0x201f55		UTIL_PlayerByIndex									<< Crash
	1	server.dll + 0x25481e		SurvivorResponseCachedInfo (windows splits in 2)	<< Patch call
	2	server.dll + 0x258598		SurvivorResponseCachedInfo::Update(int a1)			_ZN26SurvivorResponseCachedInfo6UpdateEv
	3	server.dll + 0x268398		CDirector::Update(void)								_ZN9CDirector6UpdateEv
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"

public Plugin myinfo =
{
	name = "[L4D2] Zoey Unlock",
	author = "SilverShot",
	description = "Unlocks Zoey. No bugs. No crashes. No fakes. The Real Deal.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=308483"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if( GetEngineVersion() != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d2_zoey_unlock_version", PLUGIN_VERSION, "Zoey Unlock plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegAdminCmd("sm_zoe", sm_zoe, ADMFLAG_ROOT, "Changes your survivor character into Zoey.");

	Handle hGameConf = LoadGameConfigFile("l4d2_zoey_unlock");
	if( hGameConf == null ) SetFailState("Failed to load gamedata/l4d2_zoey_unlock.");
	int offset = GameConfGetOffset(hGameConf, "ZoeyUnlock_Offset");
	if( offset == -1 ) SetFailState("Plugin is for Windows only.");
	Address patch = GameConfGetAddress(hGameConf, "ZoeyUnlock");
	delete hGameConf;
	if( !patch ) SetFailState("Error finding the 'ZoeyUnlock' signature.");

	int byte = LoadFromAddress(patch + view_as<Address>(offset), NumberType_Int8);
	if( byte == 0xE8 )
	{
		for( int i = 0; i < 5; i++ )
			StoreToAddress(patch + view_as<Address>(offset + i), 0x90, NumberType_Int8);
	}
	else if( byte != 0x90 )
	{
		SetFailState("Error: the 'ZoeyUnlock_Offset' is incorrect.");
	}
}

public void OnMapStart()
{
	PrecacheModel(MODEL_ZOEY);
}

public Action sm_zoe(int client, int args)
{
	if( client && GetClientTeam(client) == 2 )
	{
		SetEntityModel(client, MODEL_ZOEY);
		SetEntProp(client, Prop_Send, "m_survivorCharacter", 5);
	}
	return Plugin_Handled;
}