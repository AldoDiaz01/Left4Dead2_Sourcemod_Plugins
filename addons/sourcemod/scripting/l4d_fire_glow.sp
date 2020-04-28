#define PLUGIN_VERSION 		"1.3"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Fire Glow
*	Author	:	SilverShot
*	Descrp	:	Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=186617
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.3 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_fire_glow_modes_tog" now supports L4D1.

1.2 (30-Jun-2012)
	- Fixed the plugin not working in L4D1.

1.1 (20-Jun-2012)
	- Added cvars "l4d_fire_glow_modes", "l4d_fire_glow_modes_off" and "l4d_fire_glow_modes_tog" to control which modes turn on the plugin.

1.0 (02-Jun-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS			FCVAR_NOTIFY
#define MAX_LIGHTS			8

ConVar g_hCvarAllow, g_hCvarColor1, g_hCvarColor2, g_hCvarDist, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hInferno;
int g_iEntities[MAX_LIGHTS][2];
bool g_bCvarAllow, g_bLeft4Dead2, g_bStarted;
char g_sCvarCols1[12], g_sCvarCols2[12];
float g_fCvarDist, g_fInferno;



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Fire Glow",
	author = "SilverShot",
	description = "Creates a dynamic light where Molotovs, Gascans and Firework Crates burn.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=186617"
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
	g_hCvarAllow =			CreateConVar(	"l4d_fire_glow_allow",			"1",			"0=Plugin off, 1=Plugin on.", CVAR_FLAGS );
	g_hCvarModes =			CreateConVar(	"l4d_fire_glow_modes",			"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", CVAR_FLAGS );
	g_hCvarModesOff =		CreateConVar(	"l4d_fire_glow_modes_off",		"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", CVAR_FLAGS );
	g_hCvarModesTog =		CreateConVar(	"l4d_fire_glow_modes_tog",		"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", CVAR_FLAGS );
	g_hCvarDist =			CreateConVar(	"l4d_fire_glow_distance",		"250.0",		"How far does the dynamic light illuminate the area.", CVAR_FLAGS );
	if( g_bLeft4Dead2 )
		g_hCvarColor1 =		CreateConVar(	"l4d_fire_glow_fireworks",		"255 100 0",	"The light color for Firework Crate explosions. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	g_hCvarColor2 =			CreateConVar(	"l4d_fire_glow_inferno",		"255 25 0",		"The light color for <olotov and Gascan fires. Three values between 0-255 separated by spaces. RGB Color255 - Red Green Blue.", CVAR_FLAGS );
	CreateConVar(							"l4d_fire_glow_version",		PLUGIN_VERSION,	"Molotov and Gascan Glow plugin version.", CVAR_FLAGS|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_fire_glow");

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hInferno = FindConVar("inferno_flame_lifetime");
	g_hInferno.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarDist.AddChangeHook(ConVarChanged_Cvars);
	if( g_bLeft4Dead2 )
		g_hCvarColor1.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor2.AddChangeHook(ConVarChanged_Cvars);
}

public void OnMapStart()
{
	g_bStarted = true;
}

public void OnMapEnd()
{
	g_bStarted = false;
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
	g_fCvarDist = g_hCvarDist.FloatValue;
	if( g_bLeft4Dead2 )
		g_hCvarColor1.GetString(g_sCvarCols1, sizeof(g_sCvarCols1));
	g_hCvarColor2.GetString(g_sCvarCols2, sizeof(g_sCvarCols2));
	g_fInferno = g_hInferno.FloatValue;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
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
//					LIGHTS
// ====================================================================================================
public void OnEntityDestroyed(int entity)
{
	if( g_bCvarAllow && g_bStarted && entity > MaxClients )
	{
		entity = EntIndexToEntRef(entity);

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( entity == g_iEntities[i][1] )
			{
				if( IsValidEntRef(g_iEntities[i][0]) )
				{
					AcceptEntityInput(g_iEntities[i][0], "Kill");
				}

				g_iEntities[i][0] = 0;
				g_iEntities[i][1] = 0;
				break;
			}
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if( g_bCvarAllow && g_bStarted )
	{
		if( strcmp(classname, "inferno") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
		else if( g_bLeft4Dead2 == true && strcmp(classname, "fire_cracker_blast") == 0 )
			CreateTimer(0.1, TimerCreate, EntIndexToEntRef(entity));
	}
}

public Action TimerCreate(Handle timer, any target)
{
	if( (target = EntRefToEntIndex(target)) != INVALID_ENT_REFERENCE )
	{
		int index = -1;

		for( int i = 0; i < MAX_LIGHTS; i++ )
		{
			if( IsValidEntRef(g_iEntities[i][0]) == false )
			{
				index = i;
				break;
			}
		}

		if( index == -1 )
			return;
	
		char sTemp[64];
		GetEdictClassname(target, sTemp, 2);
		int entity = CreateEntityByName("light_dynamic");
		if( entity == -1)
		{
			LogError("Failed to create 'light_dynamic'");
			return;
		}

		g_iEntities[index][0] = EntIndexToEntRef(entity);
		g_iEntities[index][1] = EntIndexToEntRef(target);

		float fInfernoTime = g_fInferno;
		if( sTemp[0] == 'i' )
		{
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols2);
		}
		else
		{
			fInfernoTime -= 1.5;
			Format(sTemp, sizeof(sTemp), "%s 255", g_sCvarCols1);
		}

		DispatchKeyValue(entity, "_light", sTemp);
		DispatchKeyValue(entity, "brightness", "3");
		DispatchKeyValueFloat(entity, "spotlight_radius", 32.0);
		DispatchKeyValueFloat(entity, "distance", 5.0);
		DispatchKeyValue(entity, "style", "6");
		DispatchSpawn(entity);

		float vPos[3], vAng[3];
		GetEntPropVector(target, Prop_Data, "m_vecOrigin", vPos);
		GetEntPropVector(target, Prop_Data, "m_angRotation", vAng);
		vPos[2] += 40.0;
		TeleportEntity(entity, vPos, vAng, NULL_VECTOR);
		AcceptEntityInput(entity, "TurnOn");

		// Fade in
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.2:-1", g_fCvarDist / 5);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.4:-1", (g_fCvarDist / 5) * 2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.6:-1", (g_fCvarDist / 5) * 3);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:0.8:-1", (g_fCvarDist / 5) * 4);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser1 !self:distance:%f:1.0:-1", g_fCvarDist);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser1");

		// Fade out
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 4, fInfernoTime - 0.6);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 3, fInfernoTime - 0.4);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", (g_fCvarDist / 5) * 2, fInfernoTime - 0.2);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		Format(sTemp, sizeof(sTemp), "OnUser2 !self:distance:%f:%f:-1", g_fCvarDist / 5, fInfernoTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser2");

		Format(sTemp, sizeof(sTemp), "OnUser3 !self:Kill::%f:-1", fInfernoTime);
		SetVariantString(sTemp);
		AcceptEntityInput(entity, "AddOutput");
		AcceptEntityInput(entity, "FireUser3");
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}