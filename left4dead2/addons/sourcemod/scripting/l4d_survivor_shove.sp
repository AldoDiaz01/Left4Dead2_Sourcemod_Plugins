#define PLUGIN_VERSION 		"1.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Survivor Shove
*	Author	:	SilverShot
*	Descrp	:	Allows shoving to stagger survivors. Stumbles a survivor when shoved by another survivor.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=318694
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (03-Dec-2019)
	- Added command "sm_sshove" to turn on/off the feature for individual clients. Requested by "Tonblader".
	- Potentially fixed shove not working with no flags specified.

1.2 (20-Sep-2019)
	- Changed flags cvar, now requires clients to only have 1 of the specified flags.

1.1 (17-Sep-2019)
	- Added cvar "l4d_survivor_shove_flags" to control who has access to the feature.

1.0 (15-Sep-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define CVAR_FLAGS			FCVAR_NOTIFY

ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarFlags;
bool g_bCvarAllow, g_bLeft4Dead2, g_bCanShove[MAXPLAYERS + 1];
Handle g_hConfStagger;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Survivor Shove",
	author = "SilverShot",
	description = "Allows shoving to stagger survivors. Stumbles a survivor when shoved by another survivor.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=318694"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test == Engine_Left4Dead ) g_bLeft4Dead2 = false;
	else if( test == Engine_Left4Dead2 ) g_bLeft4Dead2 = true;
	else
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 1 & 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// GAMEDATA
	if( !g_bLeft4Dead2 )
	{
		// Stagger: SDKCall method
		Handle hConf = LoadGameConfigFile("l4d_survivor_shove");
		if( hConf == null )
			SetFailState("Missing required 'gamedata/l4d_survivor_shove.txt', please re-download.");

		StartPrepSDKCall(SDKCall_Entity);
		if( PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CTerrorPlayer::OnStaggered") == false )
			SetFailState("Could not load the 'CTerrorPlayer::OnStaggered' gamedata signature.");

		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
		g_hConfStagger = EndPrepSDKCall();
		if( g_hConfStagger == null )
			SetFailState("Could not prep the 'CTerrorPlayer::OnStaggered' function.");
	}

	// CVARS
	g_hCvarAllow = CreateConVar(	"l4d_survivor_shove_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarFlags = CreateConVar(	"l4d_survivor_shove_flags",			"z",			"Players with one of these flags have access to the shove feature.", CVAR_FLAGS );
	g_hCvarModes = CreateConVar(	"l4d_survivor_shove_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff = CreateConVar(	"l4d_survivor_shove_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog = CreateConVar(	"l4d_survivor_shove_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	CreateConVar(					"l4d_survivor_shove_version",		PLUGIN_VERSION,	"Survivor Shove plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,			"l4d_survivor_shove");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);

	// CMDS
	RegAdminCmd("sm_sshove", CmdShove, ADMFLAG_ROOT, "Turn on/off ability to shove. No args = toggle. Usage: sm_sshove [optional 0=Off. 1=On.]");
}



// ====================================================================================================
//					COMMANDS
// ====================================================================================================
public Action CmdShove(int client, int args)
{
	if( !client )
	{
		ReplyToCommand(client, "[Shove] Command may only be used in-game on a dedicated server.");
		return Plugin_Handled;
	}

	if( args == 0 )
		g_bCanShove[client] = !g_bCanShove[client];
	else
	{
		char temp[4];
		GetCmdArg(1, temp, sizeof temp);
		g_bCanShove[client] = view_as<bool>(StringToInt(temp));
	}

	ReplyToCommand(client, "[Shove] Turned %s.", g_bCanShove[client] ? "On" : "Off");
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	g_bCanShove[client] = true;
}



// ====================================================================================================
//					CVARS
// ====================================================================================================
public void OnConfigsExecuted()
{
	IsAllowed();
}

public void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvent("player_shoved", Event_PlayerShoved);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvent("player_shoved", Event_PlayerShoved);
	}
}

int g_iCurrentMode;
bool IsAllowedGameMode()
{
	if( g_hCvarMPGameMode == null )
		return false;

	int iCvarModesTog = g_hCvarModesTog.IntValue;
	if( iCvarModesTog != 0 )
	{
		g_iCurrentMode = 0;

		int entity = CreateEntityByName("info_gamemode");
		DispatchSpawn(entity);
		HookSingleEntityOutput(entity, "OnCoop", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnSurvival", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnVersus", OnGamemode, true);
		HookSingleEntityOutput(entity, "OnScavenge", OnGamemode, true);
		ActivateEntity(entity);
		AcceptEntityInput(entity, "PostSpawnActivate");
		AcceptEntityInput(entity, "Kill");

		if( g_iCurrentMode == 0 )
			return false;

		if( !(iCvarModesTog & g_iCurrentMode) )
			return false;
	}

	char sGameModes[64], sGameMode[64];
	g_hCvarMPGameMode.GetString(sGameMode, sizeof(sGameMode));
	Format(sGameMode, sizeof(sGameMode), ",%s,", sGameMode);

	g_hCvarModes.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) == -1 )
			return false;
	}

	g_hCvarModesOff.GetString(sGameModes, sizeof(sGameModes));
	if( strcmp(sGameModes, "") )
	{
		Format(sGameModes, sizeof(sGameModes), ",%s,", sGameModes);
		if( StrContains(sGameModes, sGameMode, false) != -1 )
			return false;
	}

	return true;
}

public void OnGamemode(const char[] output, int caller, int activator, float delay)
{
	if( strcmp(output, "OnCoop") == 0 )
		g_iCurrentMode = 1;
	else if( strcmp(output, "OnSurvival") == 0 )
		g_iCurrentMode = 2;
	else if( strcmp(output, "OnVersus") == 0 )
		g_iCurrentMode = 4;
	else if( strcmp(output, "OnScavenge") == 0 )
		g_iCurrentMode = 8;
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("attacker"));

	// Turned off.
	if( !g_bCanShove[client] ) return;

	// Flags
	bool access;
	int flags;
	char sTemp[32];
	g_hCvarFlags.GetString(sTemp, sizeof sTemp);

	if( sTemp[0] == 0 )
		access = true;
	else
	{
		char sVal[2];
		for( int i = 0; i < strlen(sTemp); i++ )
		{
			sVal[0] = sTemp[i];
			flags = ReadFlagString(sVal);

			if( CheckCommandAccess(client, "", flags, true) == true )
			{
				access = true;
				break;
			}
		}
	}

	if( access == false )
		return;

	// Event
	int userid = event.GetInt("userid");
	int target = GetClientOfUserId(userid);
	if( GetClientTeam(client) == 2 && GetClientTeam(target) == 2 )
	{
		float vPos[3];
		GetClientAbsOrigin(client, vPos);

		if( g_bLeft4Dead2 )
			StaggerClient(userid, vPos);
		else
			SDKCall(g_hConfStagger, target, target, vPos); // Stagger: SDKCall method
	}
}

// Credit to Timocop on VScript function
void StaggerClient(int userid, const float vPos[3])
{
	static int iScriptLogic = INVALID_ENT_REFERENCE;
	if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
	{
		iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
		if(iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
			LogError("Could not create 'logic_script");

		DispatchSpawn(iScriptLogic);
	}

	char sBuffer[96];
	Format(sBuffer, sizeof(sBuffer), "GetPlayerFromUserID(%d).Stagger(Vector(%d,%d,%d))", userid, RoundFloat(vPos[0]), RoundFloat(vPos[1]), RoundFloat(vPos[2]));
	SetVariantString(sBuffer);
	AcceptEntityInput(iScriptLogic, "RunScriptCode");
	AcceptEntityInput(iScriptLogic, "Kill");
}