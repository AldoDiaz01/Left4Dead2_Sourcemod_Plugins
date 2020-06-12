#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Car Alarm - Bots Trigger
*	Author	:	SilverShot
*	Descrp	:	Sets off the car alarm when bots shoot the vehicle or stand on it.
*	Link	:	https://forums.alliedmods.net/showthread.php?t=319435
*	Plugins	:	https://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (05-Nov-2019)
	- Fixed hooking entities when the plugin should be turned off.

1.1 (01-Nov-2019)
	- Renamed plugin and cvar config and restricted to L4D2 only since it's not required in L4D1.

1.0 (01-Nov-2019)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define GAMEDATA			"l4d2_car_alarm_bots"
#define MAX_COUNT			6



ConVar g_hCvarAllow, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarType;
bool g_bCvarAllow;
int g_iCvarType, g_ByteCount, g_ByteMatch;
int g_ByteSaved[MAX_COUNT];
Address g_Address;

enum ()
{
	TYPE_SHOOT = (1<<0),
	TYPE_STAND = (1<<1)
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D2] Car Alarm - Bots Trigger",
	author = "SilverShot",
	description = "Sets off the car alarm when bots shoot the vehicle or stand on it.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=319435"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if( test != Engine_Left4Dead2 )
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	// GAMEDATA
	// ====================================================================================================
	Handle hGamedata = LoadGameConfigFile(GAMEDATA);
	if( hGamedata == null ) SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_Address = GameConfGetAddress(hGamedata, "CCarProp::InputSurvivorStandingOnCar");
	if( !g_Address ) SetFailState("Failed to load \"CCarProp::InputSurvivorStandingOnCar\" address.");

	int offset = GameConfGetOffset(hGamedata, "InputSurvivorStandingOnCar_Offset");
	if( offset == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Offset\" offset.");

	g_ByteMatch = GameConfGetOffset(hGamedata, "InputSurvivorStandingOnCar_Byte");
	if( g_ByteMatch == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Byte\" byte.");

	g_ByteCount = GameConfGetOffset(hGamedata, "InputSurvivorStandingOnCar_Count");
	if( g_ByteCount == -1 ) SetFailState("Failed to load \"InputSurvivorStandingOnCar_Count\" count.");
	if( g_ByteCount > MAX_COUNT ) SetFailState("Error: byte count exceeds scripts defined value (%d/%d).", g_ByteCount, MAX_COUNT);

	g_Address += view_as<Address>(offset);

	for( int i = 0; i < g_ByteCount; i++ )
	{
		g_ByteSaved[i] = LoadFromAddress(g_Address + view_as<Address>(i), NumberType_Int8);
	}
	if( g_ByteSaved[0] != g_ByteMatch ) SetFailState("Failed to load, byte mis-match. %d (0x%02X - 0x%02X)", offset, g_ByteSaved[0], g_ByteMatch);

	delete hGamedata;

	// ====================================================================================================
	// CVARS
	// ====================================================================================================
	g_hCvarAllow =			CreateConVar(	"l4d2_car_alarm_bots_allow",			"1",				"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d2_car_alarm_bots_modes",			"",					"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d2_car_alarm_bots_modes_off",		"",					"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d2_car_alarm_bots_modes_tog",		"0",				"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarType =			CreateConVar(	"l4d2_car_alarm_bots_type",				"3",				"1=Trigger alarm when bots shoot the car. 2=Trigger alarm when bots stand on the car. 3=Both.", CVAR_FLAGS );
	CreateConVar(							"l4d2_car_alarm_bots_version",			PLUGIN_VERSION,		"Car Alarm - Bots Trigger plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d2_car_alarm_bots");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarType.AddChangeHook(ConVarChanged_Cvars);

	IsAllowed();
}

public void OnPluginEnd()
{
	PatchAddress(false);
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

public void ConVarChanged_Cvars(Handle convar, const char[] oldValue, const char[] newValue)
{
	GetCvars();
}

void GetCvars()
{
	g_iCvarType = g_hCvarType.IntValue;

	PatchAddress(g_iCvarType & TYPE_STAND);
	HookEntities(g_iCvarType & TYPE_SHOOT);
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		PatchAddress(g_iCvarType & TYPE_STAND);
		HookEntities(g_iCvarType & TYPE_SHOOT);
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		PatchAddress(false);
		HookEntities(g_iCvarType & TYPE_SHOOT);
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
//					PATCH / HOOK
// ====================================================================================================
void PatchAddress(int patch)
{
	static bool patched;

	if( !patched && patch )
	{
		patched = true;
		for( int i = 0; i < g_ByteCount; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteMatch == 0x0F ? 0x90 : 0xEB, NumberType_Int8);
	}
	else if( patched && !patch )
	{
		patched = false;
		for( int i = 0; i < g_ByteCount; i++ )
			StoreToAddress(g_Address + view_as<Address>(i), g_ByteSaved[i], NumberType_Int8);
	}
}

void HookEntities(int hook)
{
	static bool hooked;

	if( !hooked && hook )
	{
		hooked = true;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "prop_car_alarm")) != INVALID_ENT_REFERENCE )
		{
			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
	else if( hooked && !hook )
	{
		hooked = false;

		int entity = -1;
		while( (entity = FindEntityByClassname(entity, "prop_car_alarm")) != INVALID_ENT_REFERENCE )
		{
			SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}



// ====================================================================================================
//					EVENTS
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && g_iCvarType & TYPE_SHOOT && strcmp(classname, "prop_car_alarm") == 0 )
	{
		SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if( attacker >= 1 && attacker <= MaxClients && IsFakeClient(attacker) )
	{
		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(true);
		AcceptEntityInput(entity, "SurvivorStandingOnCar", attacker, attacker);
		if( !(g_iCvarType & TYPE_STAND) ) PatchAddress(false);
		SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}