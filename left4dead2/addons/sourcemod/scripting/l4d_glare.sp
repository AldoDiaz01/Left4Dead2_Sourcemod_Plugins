#define PLUGIN_VERSION 		"1.2"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D & L4D2] Light Glare
*	Author	:	SilverShot
*	Descrp	:	Attaches a beam and halo glare to flashlights.
*	Link	:	http://forums.alliedmods.net/showthread.php?t=181515
*	Plugins	:	http://sourcemod.net/plugins.php?exact=exact&sortby=title&search=1&author=Silvers

========================================================================================
	Change Log:

1.2 (05-May-2018)
	- Converted plugin source to the latest syntax utilizing methodmaps. Requires SourceMod 1.8 or newer.
	- Changed cvar "l4d_glare_modes_tog" now supports L4D1.

1.1.1 (31-Mar-2018)
	- Fixed not working in L4D1.
	- Did anyone use this or realize it wasn't working?

1.1 (10-May-2012)
	- Added commands "sm_glarepos" and "sm_glareang" to position the beam. Affects all players.
	- Fixed the beam sticking when players have no weapons.
	- Removed colors.inc include.

1.0 (30-Mar-2012)
	- Initial release.

======================================================================================*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define ATTACHMENT_BONE			"weapon_bone"
#define ATTACHMENT_PRIMARY		"primary"
#define ATTACHMENT_ARM			"armR_T"


ConVar g_hCvarAllow, g_hCvarAlpha, g_hCvarColor, g_hCvarHalo, g_hCvarLength, g_hCvarMPGameMode, g_hCvarModes, g_hCvarModesOff, g_hCvarModesTog, g_hCvarWidth;
int g_iCvarAlpha, g_iCvarColor, g_iCvarLength, g_iCvarWidth;
Menu g_hMenuAng, g_hMenuPos;
bool g_bCvarAllow, g_bLeft4Dead2;
float g_fCvarHalo;

int g_iLightIndex[MAXPLAYERS+1];
int g_iLightState[MAXPLAYERS+1];
int g_iPlayerEnum[MAXPLAYERS+1];
int g_iWeaponIndex[MAXPLAYERS+1];


enum ()
{
	ENUM_BLOCKED	= (1 << 0),
	ENUM_POUNCED	= (1 << 1),
	ENUM_ONLEDGE	= (1 << 2),
	ENUM_INREVIVE	= (1 << 3),
	ENUM_BLOCK		= (1 << 4)
}

enum ()
{
	TYPE_PISTOL = 1,
	TYPE_SMG,
	TYPE_MP5,
	TYPE_SG552,
	TYPE_RIFLE,
	TYPE_RIFLE_LONG,
	TYPE_SHOTGUN,
	TYPE_SHOTGUN_SHORT,
	TYPE_SHOTGUN_LONG,
	TYPE_GLAUNCHER,
	TYPE_M60,
	TYPE_SNIPER1,
	TYPE_SNIPER2,
	TYPE_SNIPER3,
	TYPE_SNIPER4
}



// ====================================================================================================
//					PLUGIN INFO / START / END
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Glare",
	author = "SilverShot",
	description = "Attaches a beam and halo glare to flashlights.",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=181515"
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
	g_hCvarAllow =			CreateConVar(	"l4d_glare_allow",		"1",			"0=Plugin off, 1=Plugin on.", FCVAR_NOTIFY );
	g_hCvarAlpha =			CreateConVar(	"l4d_glare_bright",		"155.0",		"Brightness of the beam.", FCVAR_NOTIFY );
	g_hCvarColor =			CreateConVar(	"l4d_glare_color",		"250 250 200",	"The beam color. RGB (red, green, blue) values (0-255).", FCVAR_NOTIFY );
	g_hCvarHalo =			CreateConVar(	"l4d_glare_halo",		"0.4",			"Brightness of the halo (glare).", FCVAR_NOTIFY );
	g_hCvarLength =			CreateConVar(	"l4d_glare_length",		"50",			"Length of the beam.", FCVAR_NOTIFY );
	g_hCvarModes =			CreateConVar(	"l4d_glare_modes",		"",				"Turn on the plugin in these game modes, separate by commas (no spaces). (Empty = all).", FCVAR_NOTIFY );
	g_hCvarModesOff =		CreateConVar(	"l4d_glare_modes_off",	"",				"Turn off the plugin in these game modes, separate by commas (no spaces). (Empty = none).", FCVAR_NOTIFY );
	g_hCvarModesTog =		CreateConVar(	"l4d_glare_modes_tog",	"0",			"Turn on the plugin in these game modes. 0=All, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge. Add numbers together.", FCVAR_NOTIFY );
	g_hCvarWidth =			CreateConVar(	"l4d_glare_width",		"10",			"Width of the beam.", FCVAR_NOTIFY );
	CreateConVar(							"l4d_glare_version",	PLUGIN_VERSION,	"Glare plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	AutoExecConfig(true,					"l4d_glare");

	RegAdminCmd("sm_glarepos", CmdGnomePos, ADMFLAG_ROOT);
	RegAdminCmd("sm_glareang", CmdGnomeAng, ADMFLAG_ROOT);

	g_hCvarMPGameMode = FindConVar("mp_gamemode");
	g_hCvarMPGameMode.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModes.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesOff.AddChangeHook(ConVarChanged_Allow);
	g_hCvarModesTog.AddChangeHook(ConVarChanged_Allow);
	g_hCvarAlpha.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarColor.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarLength.AddChangeHook(ConVarChanged_Cvars);
	g_hCvarWidth.AddChangeHook(ConVarChanged_Cvars);
}

public void OnPluginEnd()
{
	for( int i = 1; i <= MaxClients; i++ )
		DeleteLight(i);
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
	char sColor[16];
	g_hCvarColor.GetString(sColor, sizeof(sColor));
	g_iCvarColor = GetColor(sColor);
	g_iCvarAlpha = g_hCvarAlpha.IntValue;
	g_fCvarHalo = g_hCvarHalo.FloatValue;
	g_iCvarLength = g_hCvarLength.IntValue;
	g_iCvarWidth = g_hCvarWidth.IntValue;
}

int GetColor(char[] sTemp)
{
	char sColors[3][4];
	ExplodeString(sTemp, " ", sColors, 3, 4);

	int color;
	color = StringToInt(sColors[0]);
	color += 256 * StringToInt(sColors[1]);
	color += 65536 * StringToInt(sColors[2]);
	return color;
}

void IsAllowed()
{
	bool bCvarAllow = g_hCvarAllow.BoolValue;
	bool bAllowMode = IsAllowedGameMode();
	GetCvars();

	if( g_bCvarAllow == false && bCvarAllow == true && bAllowMode == true )
	{
		g_bCvarAllow = true;
		HookEvents();
	}

	else if( g_bCvarAllow == true && (bCvarAllow == false || bAllowMode == false) )
	{
		g_bCvarAllow = false;
		UnhookEvents();

		for( int i = 1; i <= MaxClients; i++ )
		{
			DeleteLight(i);
		}
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
void HookEvents()
{
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_ledge_grab",		Event_LedgeGrab);
	HookEvent("revive_begin",			Event_ReviveStart);
	HookEvent("revive_end",				Event_ReviveEnd);
	HookEvent("revive_success",			Event_ReviveSuccess);
	HookEvent("player_death",			Event_Unblock);
	HookEvent("player_spawn",			Event_Unblock);
	HookEvent("lunge_pounce",			Event_BlockHunter);
	HookEvent("pounce_end",				Event_BlockEndHunt);
	HookEvent("tongue_grab",			Event_BlockStart);
	HookEvent("tongue_release",			Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		HookEvent("charger_pummel_start",	Event_BlockStart);
		HookEvent("charger_carry_start",	Event_BlockStart);
		HookEvent("charger_carry_end",		Event_BlockEnd);
		HookEvent("charger_pummel_end",		Event_BlockEnd);
	}
}

void UnhookEvents()
{
	UnhookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	UnhookEvent("player_ledge_grab",	Event_LedgeGrab);
	UnhookEvent("revive_begin",			Event_ReviveStart);
	UnhookEvent("revive_end",			Event_ReviveEnd);
	UnhookEvent("revive_success",		Event_ReviveSuccess);
	UnhookEvent("player_death",			Event_Unblock);
	UnhookEvent("player_spawn",			Event_Unblock);
	UnhookEvent("lunge_pounce",			Event_BlockHunter);
	UnhookEvent("pounce_end",			Event_BlockEndHunt);
	UnhookEvent("tongue_grab",			Event_BlockStart);
	UnhookEvent("tongue_release",		Event_BlockEnd);

	if( g_bLeft4Dead2 )
	{
		UnhookEvent("charger_pummel_start",		Event_BlockStart);
		UnhookEvent("charger_carry_start",		Event_BlockStart);
		UnhookEvent("charger_carry_end",		Event_BlockEnd);
		UnhookEvent("charger_pummel_end",		Event_BlockEnd);
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for( int i = 1; i < MAXPLAYERS; i++ )
		g_iPlayerEnum[i] = 0;
}

public void Event_BlockUserEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_BLOCKED;
}

public void Event_BlockStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_BLOCKED;
}

public void Event_BlockEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_BLOCKED;
}

public void Event_BlockHunter(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_POUNCED;
}

public void Event_BlockEndHunt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_POUNCED;
}

public void Event_LedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_ONLEDGE;
}

public void Event_ReviveStart(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_INREVIVE;

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] |= ENUM_INREVIVE;
}

public void Event_ReviveEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
}

public void Event_ReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if( client > 0 )
	{
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
		g_iPlayerEnum[client] &= ~ENUM_ONLEDGE;
	}

	client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0 )
		g_iPlayerEnum[client] &= ~ENUM_INREVIVE;
}

public void Event_Unblock(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if( client > 0)
		g_iPlayerEnum[client] = 0;
}



// ====================================================================================================
//					GLARE ON/OFF
// ====================================================================================================
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if( g_bCvarAllow )
	{
		int entity = g_iLightIndex[client];

		if( GetClientTeam(client) == 2 && IsPlayerAlive(client) )
		{
			if( IsValidEntRef(entity) == false )
			{
				CreateLight(client);
				g_iLightState[client] = 1;
			}
			else
			{
				int index = g_iWeaponIndex[client];
				int active = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

				if( index != active )
				{
					if( active == -1 )
					{
						g_iPlayerEnum[client] |= ENUM_BLOCK;
						AcceptEntityInput(entity, "LightOff");
						g_iLightState[client] = 0;
						g_iWeaponIndex[client] = active;
						return;
					}

					g_iWeaponIndex[client] = active;
					g_iPlayerEnum[client] &= ~ENUM_BLOCK;

					char sTemp[32];
					GetClientWeapon(client, sTemp, sizeof(sTemp));

					if( strcmp(sTemp, "weapon_pistol") == 0 || 	strcmp(sTemp, "weapon_pistol_magnum") == 0 )
						TeleportGlare(client, entity, TYPE_PISTOL);

					else if( strcmp(sTemp, "weapon_smg") == 0 || strcmp(sTemp, "weapon_smg_silenced") == 0 )
						TeleportGlare(client, entity, TYPE_SMG);

					else if( strcmp(sTemp, "weapon_smg_mp5") == 0 )
						TeleportGlare(client, entity, TYPE_MP5);

					else if( strcmp(sTemp, "weapon_rifle_sg552") == 0 )
						TeleportGlare(client, entity, TYPE_SG552);

					else if( strcmp(sTemp, "weapon_rifle_desert") == 0 )
						TeleportGlare(client, entity, TYPE_RIFLE);

					else if( strcmp(sTemp, "weapon_rifle_ak47") == 0 || strcmp(sTemp, "weapon_rifle") == 0 )
						TeleportGlare(client, entity, TYPE_RIFLE_LONG);

					else if( strcmp(sTemp, "weapon_autoshotgun") == 0 )
						TeleportGlare(client, entity, TYPE_SHOTGUN);

					else if( strcmp(sTemp, "weapon_pumpshotgun") == 0 )
						TeleportGlare(client, entity, TYPE_SHOTGUN_SHORT);

					else if( strcmp(sTemp, "weapon_shotgun_chrome") == 0 || strcmp(sTemp, "weapon_shotgun_spas") == 0 )
						TeleportGlare(client, entity, TYPE_SHOTGUN_LONG);

					else if( strcmp(sTemp, "weapon_sniper_awp") == 0 )
						TeleportGlare(client, entity, TYPE_SNIPER1);

					else if( strcmp(sTemp, "weapon_hunting_rifle") == 0 )
						TeleportGlare(client, entity, TYPE_SNIPER2);

					else if( strcmp(sTemp, "weapon_sniper_military") == 0 )
						TeleportGlare(client, entity, TYPE_SNIPER3);

					else if( strcmp(sTemp, "weapon_sniper_scout") == 0 )
						TeleportGlare(client, entity, TYPE_SNIPER4);

					else if( strcmp(sTemp, "weapon_grenade_launcher") == 0 )
						TeleportGlare(client, entity, TYPE_GLAUNCHER);

					else if( strcmp(sTemp, "weapon_rifle_m60") == 0 )
						TeleportGlare(client, entity, TYPE_M60);

					else
						g_iPlayerEnum[client] |= ENUM_BLOCK;
				}

				int effects;

				if( g_iPlayerEnum[client] != 0 )
					effects = 0;
				else
					effects = GetEntProp(client, Prop_Send, "m_fEffects");

				if( effects == 4 )
				{
					if( g_iLightState[client] == 0 )
					{
						AcceptEntityInput(entity, "LightOn");
						g_iLightState[client] = 1;
					}
				}
				else
				{
					if( g_iLightState[client] == 1 )
					{
						AcceptEntityInput(entity, "LightOff");
						g_iLightState[client] = 0;
					}
				}
			}
		}
		else
		{
			if( IsValidEntRef(entity) == true )
				DeleteLight(client);
		}
	}
}

void DeleteLight(int client)
{
	int entity = g_iLightIndex[client];
	if( IsValidEntRef(entity) )
	{
		AcceptEntityInput(entity, "Kill");
		SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);
	}
}

void CreateLight(int client)
{
	int entity = g_iLightIndex[client];
	if( IsValidEntRef(entity) )
		return;

	entity = CreateEntityByName("beam_spotlight");
	if( entity == -1)
		return;

	SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmitLight);

	DispatchKeyValue(entity, "SpotlightWidth", "15");
	DispatchKeyValue(entity, "spawnflags", "3");

	char sTemp[8];

	DispatchKeyValue(entity, "HaloScale", "250");
	IntToString(g_iCvarWidth, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "SpotlightWidth", sTemp);
	IntToString(g_iCvarLength, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "SpotlightLength", sTemp);
	IntToString(g_iCvarAlpha, sTemp, sizeof(sTemp));
	DispatchKeyValue(entity, "renderamt", sTemp);
	DispatchKeyValueFloat(entity, "HDRColorScale", g_fCvarHalo);
	SetEntProp(entity, Prop_Send, "m_clrRender", g_iCvarColor);

	DispatchSpawn(entity);

	SetVariantString("!activator");
	AcceptEntityInput(entity, "SetParent", client);

	TeleportGlare(client, entity, 1);

	g_iLightIndex[client] = EntIndexToEntRef(entity);
}

public Action Hook_SetTransmitLight(int entity, int client)
{
	if( g_iLightIndex[client] == EntIndexToEntRef(entity) )
		return Plugin_Handled;
	return Plugin_Continue;
}

void TeleportGlare(int client, int entity, int type)
{
	float vOrigin[3], vAngles[3];

	if( g_bLeft4Dead2 == false )
	{
		SetVariantString(ATTACHMENT_ARM); // Was Bone, no one reported wrong for L4D1..
		AcceptEntityInput(entity, "SetParentAttachment");

		// if( bone == 0 ) // Most survivors
		// {
		// }
		// else if( bone == 1 ) // Louis
		// {
		// }
		// else // Zoey
		{
			if( type == TYPE_PISTOL )
			{
				vAngles = view_as<float>({ -15.0, 90.0, 0.0 });
				vOrigin = view_as<float>({ 3.0, 20.5, 0.0 });
			}
			else if( type == TYPE_RIFLE )
			{
				vAngles = view_as<float>({ 0.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 0.0, 0.0 });
			}
			else if( type == TYPE_RIFLE_LONG )
			{
				vAngles = view_as<float>({ 0.0, 110.0, 10.0 });
				vOrigin = view_as<float>({ -6.5, 33.0, -3.0 });
			}
			else if( type == TYPE_SMG )
			{
				vAngles = view_as<float>({ 0.0, 110.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 22.0, 0.0 });
			}
			else if( type == TYPE_SHOTGUN )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 15.0, 25.0, 0.0 });
			}
			else if( type == TYPE_SHOTGUN_SHORT )
			{
				vAngles = view_as<float>({ 8.5, 31.0, -5.0 });
				vOrigin = view_as<float>({ 15.0, 25.0, 0.0 });
			}
			else if( type == TYPE_SHOTGUN_LONG )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 1.0, 24.0 });
			}
			else if( type == TYPE_SNIPER1 )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 20.0 });
			}
			else if( type == TYPE_SNIPER2 )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 20.0 });
			}
			else if( type == TYPE_SNIPER3 )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 20.0 });
			}
			else if( type == TYPE_SNIPER4 )
			{
				vAngles = view_as<float>({ 0.0, 75.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 20.0 });
			}
			else if( type == TYPE_SG552 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 15.0 });
			}
			else if( type == TYPE_MP5 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 8.0 });
			}
		}
	}
	else
	{
		int bone = GetSurvivorType(client);

		if( bone == 0 ) // Most survivors
		{
			SetVariantString(ATTACHMENT_BONE);
			AcceptEntityInput(entity, "SetParentAttachment");

			if( type == TYPE_PISTOL )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 0.0, 6.0 });
			}
			else if( type == TYPE_SG552 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 15.0 });
			}
			else if( type == TYPE_RIFLE )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 15.0 });
			}
			else if( type == TYPE_RIFLE_LONG )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 21.0 });
			}
			else if( type == TYPE_SMG )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 8.0 });
			}
			else if( type == TYPE_MP5 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 2.0, 8.0 });
			}
			else if( type == TYPE_SHOTGUN )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({  0.0, 1.0, 19.0 });
			}
			else if( type == TYPE_SHOTGUN_SHORT )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 1.0, 24.5 });
			}
			else if( type == TYPE_SHOTGUN_LONG )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 1.5, 26.0 });
			}
			else if( type == TYPE_GLAUNCHER )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({  0.5, 3.0, 19.0 });
			}
			else if( type == TYPE_M60 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({  0.5, 3.0, 19.0 });
			}
			else if( type == TYPE_SNIPER1 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 0.0, 18.0 });
			}
			else if( type == TYPE_SNIPER2 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.5, 2.0, 19.0 });
			}
			else if( type == TYPE_SNIPER3 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.5, 2.0, 19.0 });
			}
			else if( type == TYPE_SNIPER4 )
			{
				vAngles = view_as<float>({ -90.0, 0.0, 0.0 });
				vOrigin = view_as<float>({ 0.5, 2.0, 19.0 });
			}
		}
		else if( bone == 1 ) // Louis
		{
			SetVariantString(ATTACHMENT_ARM);
			AcceptEntityInput(entity, "SetParentAttachment");

			if( g_bLeft4Dead2 )
			{
				if( type == TYPE_PISTOL )
				{
					vAngles = view_as<float>({ -20.0, 100.0, 0.0 });
					vOrigin = view_as<float>({ 8.0, 18.0, 0.0 });
				}
				else if( type == TYPE_SG552 )
				{
					vAngles = view_as<float>({ -15.0, 125.0, 30.0 });
					vOrigin = view_as<float>({ 1.0, 24.5, 4.5 });
				}
				else if( type == TYPE_RIFLE )
				{
					vAngles = view_as<float>({ 25.0, 80.0, 0.0 });
					vOrigin = view_as<float>({  11.5, 26.5, 1.0 });
				}
				else if( type == TYPE_RIFLE_LONG )
				{
					vAngles = view_as<float>({ -10.0, 75.0, 0.0 });
					vOrigin = view_as<float>({ 13.0, 26.5, 0.0 });
				}
				else if( type == TYPE_SMG )
				{
					vAngles = view_as<float>({ -10.0, 110.0, 0.0 });
					vOrigin = view_as<float>({ 0.0, 22.0, 0.0 });
				}
				else if( type == TYPE_MP5 )
				{
					vAngles = view_as<float>({ 15.0, 70.0, 5.0 });
					vOrigin = view_as<float>({ 10.0, 23.0, 0.0 });
				}
				else if( type == TYPE_SHOTGUN )
				{
					vAngles = view_as<float>({ 0.0, 85.0, 0.0 });
					vOrigin = view_as<float>({ 11.5, 34.0, -2.5 });
				}
				else if( type == TYPE_SHOTGUN_SHORT )
				{
					vAngles = view_as<float>({ 0.0, 80.0, 0.0 });
					vOrigin = view_as<float>({ 8.5, 37.0, 0.5 });
				}
				else if( type == TYPE_SHOTGUN_LONG )
				{
					vAngles = view_as<float>({ 5.0, 75.0, 0.0 });
					vOrigin = view_as<float>({  9.5, 35.0, 0.5 });
				}
				else if( type == TYPE_GLAUNCHER )
				{
					vAngles = view_as<float>({ 0.0, 80.0, 0.0 });
					vOrigin = view_as<float>({ 9.5, 33.5, -1.5 });
				}
				else if( type == TYPE_M60 )
				{
					vAngles = view_as<float>({ 30.0, 55.0, 0.0 });
					vOrigin = view_as<float>({ 11.0, 27.5, -9.0 });
				}
				else if( type == TYPE_SNIPER1 )
				{
					vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
					vOrigin = view_as<float>({ -2.5, 29.5, 6.0 });
				}
				else if( type == TYPE_SNIPER2 )
				{
					vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
					vOrigin = view_as<float>({ -2.5, 29.5, 6.0 });
				}
				else if( type == TYPE_SNIPER3 )
				{
					vAngles = view_as<float>({ 25.0, 60.0, 0.0 });
					vOrigin = view_as<float>({ 13.0, 32.5, -6.5});
				}
				else if( type == TYPE_SNIPER4 )
				{
					vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
					vOrigin = view_as<float>({ -2.5, 29.5, 6.0 });
				}
			}
		}
		else // Zoey
		{
			SetVariantString(ATTACHMENT_ARM);
			AcceptEntityInput(entity, "SetParentAttachment");

			if( type == TYPE_PISTOL )
			{
				vAngles = view_as<float>({ 0.0, 90.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 20.0, 0.0 });
			}
			else if( type == TYPE_SG552 )
			{
				vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
				vOrigin = view_as<float>({ -4.0, 25.0, 0.0 });
			}
			else if( type == TYPE_RIFLE )
			{
				vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
				vOrigin = view_as<float>({ -4.0, 25.0, 0.0 });
			}
			else if( type == TYPE_RIFLE_LONG )
			{
				vAngles = view_as<float>({ 0.0, 120.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 20.0, 0.0 });
			}
			else if( type == TYPE_SMG )
			{
				vAngles = view_as<float>({ 0.0, 110.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 22.0, 0.0 });
			}
			else if( type == TYPE_MP5 )
			{
				vAngles = view_as<float>({ 0.0, 110.0, 0.0 });
				vOrigin = view_as<float>({ 0.0, 22.0, 0.0 });
			}
			else if( type == TYPE_SHOTGUN )
			{
				vAngles = view_as<float>({ -5.0, 105.0, 60.0 });
				vOrigin = view_as<float>({ -2.5, 32.5, 1.0 });
			}
			else if( type == TYPE_SHOTGUN_SHORT )
			{
				vAngles = view_as<float>({ 0.0, 80.0, 0.0 });
				vOrigin = view_as<float>({ 8.5, 37.0, 0.5 });
			}
			else if( type == TYPE_SHOTGUN_LONG )
			{
				vAngles = view_as<float>({ 5.0, 75.0, 0.0 });
				vOrigin = view_as<float>({  9.5, 35.0, 0.5 });
			}
			else if( type == TYPE_GLAUNCHER )
			{
				vAngles = view_as<float>({ -165.0, -100.0, 20.0 });
				vOrigin = view_as<float>({ 8.0, 21.5, -1.0 });
			}
			else if( type == TYPE_M60 )
			{
				vAngles = view_as<float>({ -195.0, -115.0, 20.0 });
				vOrigin = view_as<float>({ 15.0, 30.5, -5.5 });
			}
			else if( type == TYPE_SNIPER1 )
			{
				vAngles = view_as<float>({ 0.0, 130.0, 0.0 });
				vOrigin = view_as<float>({ -10.5, 23.5, 3.5 });
			}
			else if( type == TYPE_SNIPER2 )
			{
				vAngles = view_as<float>({ -165.0, -50.0, 25.0 });
				vOrigin = view_as<float>({ -9.5, 26.0, 0.0 });
			}
			else if( type == TYPE_SNIPER3 )
			{
				vAngles = view_as<float>({ 25.0, 60.0, 0.0 });
				vOrigin = view_as<float>({ 15.0, 33.0, -6.5 });
			}
			else if( type == TYPE_SNIPER4 )
			{
				vAngles = view_as<float>({ -165.0, -50.0, 25.0 });
				vOrigin = view_as<float>({ -9.5, 26.0, 0.0 });
			}
		}
	}

	TeleportEntity(entity, vOrigin, vAngles, NULL_VECTOR);
}

int GetSurvivorType(int client)
{
	if( !g_bLeft4Dead2 )
		return 1; // All survivors should use the "louis" position, since L4D1 models have no weapon_bone attachment.

	char sModel[30];
	GetEntPropString(client, Prop_Data, "m_ModelName", sModel, sizeof(sModel));

	if( sModel[26] == 't' )								// t = Teenangst
		return 2;
	else if( sModel[26] == 'm' && sModel[27] == 'a')	// ma = Manager
		return 1;
	else
		return 0;
}



// ====================================================================================================
//					CREATE MENUS
// ====================================================================================================
void CreateMenus()
{
	if( g_hMenuAng == null )
	{
		g_hMenuAng = new Menu(AngMenuHandler);
		g_hMenuAng.AddItem("", "X + 5.0");
		g_hMenuAng.AddItem("", "Y + 5.0");
		g_hMenuAng.AddItem("", "Z + 5.0");
		g_hMenuAng.AddItem("", "X - 5.0");
		g_hMenuAng.AddItem("", "Y - 5.0");
		g_hMenuAng.AddItem("", "Z - 5.0");
		g_hMenuAng.SetTitle("Set Angle");
		g_hMenuAng.ExitButton = true;
	}
	if( g_hMenuPos == null )
	{
		g_hMenuPos = new Menu(PosMenuHandler);
		g_hMenuPos.AddItem("", "X + 0.5");
		g_hMenuPos.AddItem("", "Y + 0.5");
		g_hMenuPos.AddItem("", "Z + 0.5");
		g_hMenuPos.AddItem("", "X - 0.5");
		g_hMenuPos.AddItem("", "Y - 0.5");
		g_hMenuPos.AddItem("", "Z - 0.5");
		g_hMenuPos.SetTitle("Set Position");
		g_hMenuPos.ExitButton = true;
	}
}

// ====================================================================================================
//					MENU ANGLE
// ====================================================================================================
public Action CmdGnomeAng(int client, int args)
{
	ShowMenuAng(client);
	return Plugin_Handled;
}

void ShowMenuAng(int client)
{
	CreateMenus();
	g_hMenuAng.Display(client, MENU_TIME_FOREVER);
}

public int AngMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		SetAngle(client, index);
		ShowMenuAng(client);
	}
}

void SetAngle(int client, int index)
{
	float vAng[3];
	int entity;
	bool saved;

	for( int i = 1; i <= MaxClients; i++ )
	{
		entity = g_iLightIndex[i];

		if( IsClientInGame(i) && IsValidEntRef(entity) )
		{
			if( saved == false )
			{
				saved = true;
				GetEntPropVector(entity, Prop_Send, "m_angRotation", vAng);
				if( index == 0 ) vAng[0] += 5.0;
				else if( index == 1 ) vAng[1] += 5.0;
				else if( index == 2 ) vAng[2] += 5.0;
				else if( index == 3 ) vAng[0] -= 5.0;
				else if( index == 4 ) vAng[1] -= 5.0;
				else if( index == 5 ) vAng[2] -= 5.0;
				PrintToChat(client, "Angle: %0.1f, %0.1f, %0.1f", vAng[0], vAng[1], vAng[2]);
			}

			TeleportEntity(entity, NULL_VECTOR, vAng, NULL_VECTOR);
		}
	}
}

// ====================================================================================================
//					MENU ORIGIN
// ====================================================================================================
public Action CmdGnomePos(int client, int args)
{
	ShowMenuPos(client);
	return Plugin_Handled;
}

void ShowMenuPos(int client)
{
	CreateMenus();
	g_hMenuPos.Display(client, MENU_TIME_FOREVER);
}

public int PosMenuHandler(Menu menu, MenuAction action, int client, int index)
{
	if( action == MenuAction_Select )
	{
		SetOrigin(client, index);
		ShowMenuPos(client);
	}
}

void SetOrigin(int client, int index)
{
	float vPos[3]; int entity; bool saved;

	for( int i = 1; i <= MaxClients; i++ )
	{
		entity = g_iLightIndex[i];

		if( IsClientInGame(i) && IsValidEntRef(entity) )
		{
			if( saved == false )
			{
				GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vPos);
				saved = true;
				if( index == 0 ) vPos[0] += 0.5;
				else if( index == 1 ) vPos[1] += 0.5;
				else if( index == 2 ) vPos[2] += 0.5;
				else if( index == 3 ) vPos[0] -= 0.5;
				else if( index == 4 ) vPos[1] -= 0.5;
				else if( index == 5 ) vPos[2] -= 0.5;

				PrintToChat(client, "Origin: %0.1f, %0.1f, %0.1f", vPos[0], vPos[1], vPos[2]);
			}

			TeleportEntity(entity, vPos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

bool IsValidEntRef(int entity)
{
	if( entity && EntRefToEntIndex(entity) != INVALID_ENT_REFERENCE )
		return true;
	return false;
}