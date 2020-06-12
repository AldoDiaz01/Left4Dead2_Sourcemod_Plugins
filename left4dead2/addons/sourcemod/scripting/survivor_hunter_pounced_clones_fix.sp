#pragma semicolon 1
#include <sourcemod>
#include <sceneprocessor>

public Plugin:myinfo = { 
	name        = "Survivor Clones Hunter Pounced Warning Fix", 
	author        = "DeathChaos25", 
	description    = "Re-uses the Generic Hunter Pounced lines from C1M1 so that male L4D2 survivors can warn when their clones are pounced", 
	version        = "1.2", 
	url        = "https://forums.alliedmods.net/showthread.php?t=248776" 
}

static const String:MODEL_NICK[] 		= "models/survivors/survivor_gambler.mdl";
static const String:MODEL_COACH[] 		= "models/survivors/survivor_coach.mdl";
static const String:MODEL_ELLIS[] 		= "models/survivors/survivor_mechanic.mdl";
static const String:MODEL_ZOEY[] 		= "models/survivors/survivor_teenangst.mdl";
static const String:MODEL_LOUIS[] 		= "models/survivors/survivor_manager.mdl";

public OnPluginStart()
{
	HookEvent("lunge_pounce", LungePounce_Event);
}

public LungePounce_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "victim"));
	
	if (IsNick(client))
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsNick(i) && IsPlayerAlive(i) && client != i)
			{
				new random = GetRandomInt(1,3);
				switch(random)
				{
					case 1: PerformSceneEx(i, "", "scenes/Gambler/HunterPouncedC101.vcd");
					case 2: PerformSceneEx(i, "", "scenes/Gambler/HunterPouncedC102.vcd");
					case 3: PerformSceneEx(i, "", "scenes/Gambler/HunterPouncedC103.vcd");
					default: return;
				}
			}
		}
	}
	else if (IsCoach(client))
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsCoach(i) && IsPlayerAlive(i) && client != i)
			{
				new random = GetRandomInt(1,3);
				switch(random)
				{
					case 1: PerformSceneEx(i, "", "scenes/Coach/HunterPouncedC101.vcd");
					case 2: PerformSceneEx(i, "", "scenes/Coach/HunterPouncedC102.vcd");
					default: return;
				}
			}
		}
	}
	else if (IsEllis(client))
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsEllis(i) && IsPlayerAlive(i) && client != i)
			{
				new random = GetRandomInt(1,3);
				switch(random)
				{
					case 1: PerformSceneEx(i, "", "scenes/Mechanic/HunterPouncedC101.vcd");
					case 2: PerformSceneEx(i, "", "scenes/Mechanic/HunterPouncedC102.vcd");
					default: return;
				}
			}
		}
	}
	else if (IsLouis(client))
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsLouis(i) && IsPlayerAlive(i) && client != i)
			{
				new random = GetRandomInt(1,3);
				switch(random)
				{
					case 1: PerformSceneEx(i, "", "scenes/Manager/DLC1_C6M3_L4D11stSpot05.vcd");
					default: return;
				}
			}
		}
	}
	else if (IsZoey(client))
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsZoey(i) && IsPlayerAlive(i) && client != i)
			{
				new random = GetRandomInt(1,3);
				switch(random)
				{
					case 1: PerformSceneEx(i, "", "scenes/TeenGirl/DLC1_C6M3_L4D11stSpot08.vcd");
					default: return;
				}
			}
		}
	}
}

/* Stock Bools*/
stock bool:IsSurvivor(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2)
	{
		return true;
	}
	return false;
}

stock bool:IsCoach(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_COACH, false))
		{
			return true;
		}
	}
	return false;
}

stock bool:IsNick(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_NICK, false))
		{
			return true;
		}
	}
	return false;
}

stock bool:IsEllis(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_ELLIS, false))
		{
			return true;
		}
	}
	return false;
}

stock bool:IsLouis(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_LOUIS, false))
		{
			return true;
		}
	}
	return false;
}

stock bool:IsZoey(client)
{
	if (IsSurvivor(client))
	{
		decl String:model[42];
		GetEntPropString(client, Prop_Data, "m_ModelName", model, sizeof(model));
		if (StrEqual(model, MODEL_ZOEY, false))
		{
			return true;
		}
	}
	return false;
}
