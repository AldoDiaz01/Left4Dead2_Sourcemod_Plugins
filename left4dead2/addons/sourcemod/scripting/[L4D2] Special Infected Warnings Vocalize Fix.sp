/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
* [L4D2] Special Infected Warnings Vocalize Fix
* 
* About : This plugin aims to be a simple fix for some
*  special infected warnings never being called upon.
* 
* =============================
* ===      Change Log       ===
* =============================
* Version 1.0    2014-08-24
* - Initial Release
* =============================
* Version 1.1    2014-08-25
* - Added a cvar that allows to change the chance of a vocalization warning
* =============================
* Version 1.2	 2014-08-25
* - Added HeardBoomer, HeardSmoker and HeardTank support for L4D1 Survivors
* =============================
* Version 1.3	 2014-08-26 (50+ views)
* - Added new CVARs to control the delays for how much a survivor must wait
*   being able to vocalize for hearing the same special again, and another for
*   how much a survivor should wait between different specials
* =============================
* Version 1.4    2014-09-11
* - Added a check to see if a survivor isn't already vocalizing before
*   attempting to warn for an infected, as nt doing so would cause the
*   vocalization to fail but still run the timer to delay for the next
*   infected warning.
* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */


#include <sourcemod>
#include <sdktools>
#include <sceneprocessor> 

#define MODEL_NICK "models/survivors/survivor_gambler.mdl"
#define MODEL_ROCHELLE "models/survivors/survivor_producer.mdl"
#define MODEL_COACH "models/survivors/survivor_coach.mdl"
#define MODEL_ELLIS "models/survivors/survivor_mechanic.mdl"

#define MODEL_BILL "models/survivors/survivor_namvet.mdl"
#define MODEL_FRANCIS "models/survivors/survivor_biker.mdl"
#define MODEL_LOUIS "models/survivors/survivor_manager.mdl"
#define MODEL_ZOEY "models/survivors/survivor_teenangst.mdl"

#define ZOMBIECLASS_SMOKER 1
#define ZOMBIECLASS_BOOMER 2
#define ZOMBIECLASS_HUNTER 3
#define ZOMBIECLASS_SPITTER 4
#define ZOMBIECLASS_JOCKEY 5
#define ZOMBIECLASS_CHARGER 6
#define ZOMBIECLASS_TANK 8

#define PLUGIN_VERSION "1.2"

/* Delays to be applied from convars */
static g_iVocalizeChance
static Float:g_iBoomerWarnDelay
static Float:g_iSmokerWarnDelay
static Float:g_iSpitterWarnDelay
static Float:g_iTankWarnDelay
static Float:g_iChargerWarnDelay 
static Float:g_iSpecialWarnDelay

/* Bools to see if the delay requirement has been met */
static bool:g_bIsWarnBoomer[MAXPLAYERS+1] = true
static bool:g_bIsWarnSmoker[MAXPLAYERS+1] = true
static bool:g_bIsWarnSpitter[MAXPLAYERS+1] = true
static bool:g_bIsWarnTank[MAXPLAYERS+1] = true
static bool:g_bIsWarnCharger[MAXPLAYERS+1] = true
static bool:g_bIsWarnSpecial[MAXPLAYERS+1] = true

/* bools to see if a timer is already active,
* this is to prevent the creation of too many timers
* for a single event */

static bool:g_bBoomerTimer[MAXPLAYERS+1] = false
static bool:g_bSmokerTimer[MAXPLAYERS+1] = false
static bool:g_bSpitterTimer[MAXPLAYERS+1] = false
static bool:g_bTankTimer[MAXPLAYERS+1] = false
static bool:g_bChargerTimer[MAXPLAYERS+1] = false
static bool:g_bSpecialTimer[MAXPLAYERS+1] = false

public Plugin:myinfo =
{
	name = "[L4D2] Special Infected Warnings Vocalize Fix",
	author = "DeathChaos25",
	description = "Fixes the 'I heard a (Insert Special Infected here)' warning lines not working for some specific Special Infected.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2189049",
}

public OnPluginStart() 
{ 
	HookEvent("player_spawn", PlayerSpawn_Event) 
	CreateConVar("l4d2_si_warnings_vocalize_fix_version", PLUGIN_VERSION, "[L4D2] Special Infected Warnings Vocalize Fix", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD) 
	
	new Handle:VocalizeChance = CreateConVar("vocalize_chance", "33", "Chance out of 100 (i.e 25 for 25% chance) that a survivor will vocalize the 'I heard' lines upon the Infected's spawn", FCVAR_PLUGIN, true, 1.0, true, 100.0) 
	HookConVarChange(VocalizeChance, ConVarVocalizeChance) 
	g_iVocalizeChance = GetConVarInt(VocalizeChance) 
	
	new Handle:BoomerWarnDelay = CreateConVar("boomer_delay", "300", "How many seconds must survivors wait to warn for hearing boomers again", FCVAR_PLUGIN, true, 1.0, true, 360.0) 
	HookConVarChange(BoomerWarnDelay, ConVarBoomerWarnDelay) 
	g_iBoomerWarnDelay = GetConVarFloat(BoomerWarnDelay) 
	
	new Handle:SmokerWarnDelay = CreateConVar("smoker_delay", "300", "How many seconds must survivors wait to warn for hearing smokers again", FCVAR_PLUGIN, true, 1.0, true, 360.0) 
	HookConVarChange(SmokerWarnDelay, ConVarSmokerWarnDelay) 
	g_iSmokerWarnDelay = GetConVarFloat(SmokerWarnDelay) 
	
	new Handle:SpitterWarnDelay = CreateConVar("spitter_delay", "300", "How many seconds must survivors wait to warn for hearing spitters again", FCVAR_PLUGIN, true, 1.0, true, 360.0) 
	HookConVarChange(SmokerWarnDelay, ConVarSpitterWarnDelay) 
	g_iSpitterWarnDelay = GetConVarFloat(SpitterWarnDelay)
	
	new Handle:ChargerWarnDelay = CreateConVar("charger_delay", "300", "How many seconds must survivors wait to warn for hearing chargers again", FCVAR_PLUGIN, true, 1.0, true, 360.0) 
	HookConVarChange(ChargerWarnDelay, ConVarChargerWarnDelay) 
	g_iChargerWarnDelay = GetConVarFloat(ChargerWarnDelay) 
	
	new Handle:TankWarnDelay = CreateConVar("tank_delay", "300", "How many seconds must survivors wait to warn for hearing tanks again", FCVAR_PLUGIN, true, 1.0, true, 360.0) 
	HookConVarChange(TankWarnDelay, ConVarTankWarnDelay) 
	g_iTankWarnDelay = GetConVarFloat(TankWarnDelay) 
	
	new Handle:SpecialWarnDelay = CreateConVar("special_delay", "30", "How many seconds must survivors wait to warn between each different special infected type", FCVAR_PLUGIN, true, 1.0, true, 90.0) 
	HookConVarChange(SpecialWarnDelay, ConVarSpecialWarnDelay) 
	g_iSpecialWarnDelay = GetConVarFloat(SpecialWarnDelay) 
	
	AutoExecConfig(true, "l4d2_si_warnings_vocalize_fix")
	
	new maxplayers = GetMaxClients();
	for (new i = 1; i <= maxplayers; i++)
	{
		if (IsClientInGame(i)) {
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
				g_bIsWarnSpecial[i] = true 
				g_bIsWarnBoomer[i] = true 
				g_bIsWarnCharger[i] = true  
				g_bIsWarnSpitter[i] = true 
				g_bIsWarnTank[i] = true 
				g_bIsWarnSmoker[i] = true 
				
				g_bBoomerTimer[i] = false 
				g_bSpitterTimer[i] = false 
				g_bTankTimer[i] = false 
				g_bSmokerTimer[i] = false 
				g_bChargerTimer[i] = false 
				g_bSpecialTimer[i] = false 
			}
		}
	}
}

public PlayerSpawn_Event(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3) {
		return
	}
	
	decl String:model[PLATFORM_MAX_PATH] 
	new class = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	new i_Vocalize, i_Rand, i
	new String:s_Vocalize[PLATFORM_MAX_PATH] = ""
	new maxplayers = GetMaxClients();
	
	for (i = 1; i <= maxplayers; i++)
	{
		if (IsClientInGame(i)) {
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
				if (IsActorBusy(i) == true) {
					return
				}
			}
		}
	}
	
	for (i = 1; i <= maxplayers; i++)
	{
		if (IsClientInGame(i)) {
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
				if (g_bSpecialTimer[i] == true) {
					return
				}
			}
		}
	}
	
	for (i = 1; i <= maxplayers; i++)
	{
		if (IsClientInGame(i)) {
			if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
				if (g_bIsWarnSpecial[i] == false) {
					g_bSpecialTimer[i] = true
					CreateTimer(g_iSpecialWarnDelay, SpecialBoolReset, i) 
					return
				}
			}
		}
	}
	
	if (class == ZOMBIECLASS_BOOMER){
		for (i = 1; i <= maxplayers; i++)
		{
			if (IsClientInGame(i)) {
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
				}
				if (g_bBoomerTimer[i] == true) {
					return
				}
				if (g_bIsWarnBoomer[i] == false) {
					CreateTimer(g_iBoomerWarnDelay, BoomerBoolReset, i) 
					g_bBoomerTimer[i] = true
					return 
				}
				i_Vocalize = GetRandomInt(1, 100) 
				if  (i_Vocalize > g_iVocalizeChance){
					return
				}
				i_Rand = GetRandomInt(1, 6) 
				GetClientModel(i, model, sizeof(model)) 
				
				if (StrEqual(model, MODEL_COACH)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/coach/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				else if (StrEqual(model, MODEL_ELLIS)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/mechanic/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				
				else if (StrEqual(model, MODEL_NICK)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/gambler/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				else if (StrEqual(model, MODEL_ROCHELLE)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/producer/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				else if (StrEqual(model, MODEL_FRANCIS)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/biker/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				else if (StrEqual(model, MODEL_BILL)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/namvet/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}	
				else if (StrEqual(model, MODEL_LOUIS)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/manager/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
				else if (StrEqual(model, MODEL_ZOEY)) {
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/teengirl/HeardBoomer0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnBoomer[i] = false
				}
			}
		}
	}
	
	
	else if (class == ZOMBIECLASS_CHARGER) {
		for (i = 1; i <= maxplayers; i++)
		{
			if (IsClientInGame(i)) {
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
					if (g_bChargerTimer[i] == true) {
						return 
					}
					if (g_bIsWarnCharger[i] == false) {
						g_bChargerTimer[i] = true 
						CreateTimer(g_iChargerWarnDelay, ChargerBoolReset, i) 
						return 
					}
					i_Vocalize = GetRandomInt(1, 100) 
					if  (i_Vocalize > g_iVocalizeChance){
						return
					}
					GetClientModel(i, model, sizeof(model)) 
					
					if (StrEqual(model, MODEL_COACH)) {
						i_Rand = GetRandomInt(1, 4) 
						Format(s_Vocalize, sizeof(s_Vocalize), "scenes/coach/HeardCharger0%i.vcd", i_Rand)
						PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
						g_bIsWarnCharger[i] = false
					}
					
					else if (StrEqual(model, MODEL_ELLIS)) {
						i_Rand = GetRandomInt(1, 3) 
						Format(s_Vocalize, sizeof(s_Vocalize),"scenes/mechanic/HeardCharger0%i.vcd", i_Rand)
						PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
						g_bIsWarnCharger[i] = false
					}
					
					else if (StrEqual(model, MODEL_NICK)) {
						i_Rand = GetRandomInt(1, 7) 
						Format(s_Vocalize, sizeof(s_Vocalize),"scenes/gambler/HeardCharger0%i.vcd", i_Rand)
						PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
						g_bIsWarnCharger[i] = false
					}
					
					else if (StrEqual(model, MODEL_ROCHELLE)){
						i_Rand = GetRandomInt(1, 5) 
						Format(s_Vocalize, sizeof(s_Vocalize),"scenes/producer/HeardCharger0%i.vcd", i_Rand)
						PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
						g_bIsWarnCharger[i] = false
					}
				}
			}
		}	
	}
	
	else if (class == ZOMBIECLASS_SMOKER) {
		for (i = 1; i <= maxplayers; i++)
		{
			if (IsClientInGame(i)) {
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
					if (g_bSmokerTimer[i] == true) 
						return
				}
				if (g_bIsWarnSmoker[i] == false) {
					g_bSmokerTimer[i] = true 
					CreateTimer(g_iSmokerWarnDelay, SmokerBoolReset, i) 
					return 
				}
				i_Vocalize = GetRandomInt(1, 100) 
				if  (i_Vocalize > g_iVocalizeChance){
					return
				}
				GetClientModel(i, model, sizeof(model)) 
				
				if (StrEqual(model, MODEL_COACH)) {
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/coach/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_ELLIS)) {
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/mechanic/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_NICK)) {
					i_Rand = GetRandomInt(1, 4) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/gambler/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_ROCHELLE)){
					i_Rand = GetRandomInt(1, 5) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/producer/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_BILL)){
					i_Rand = GetRandomInt(1, 7) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/namvet/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_FRANCIS)){
					i_Rand = GetRandomInt(1, 7) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/biker/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_LOUIS)){
					i_Rand = GetRandomInt(1, 8) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/manager/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
				else if (StrEqual(model, MODEL_ZOEY)){
					i_Rand = GetRandomInt(1, 16) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/teengirl/HeardSmoker0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSmoker[i] = false
				}
			}
		}
	}
	
	else if (class == ZOMBIECLASS_SPITTER) {
		for (i = 1; i <= maxplayers; i++) {
			if (IsClientInGame(i)) {
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) {
					if (g_bSpitterTimer[i] == true) 
					return
				}
				if (g_bIsWarnSpitter[i] == false) {
					g_bSpitterTimer[i] = true 
					CreateTimer(g_iSpitterWarnDelay, SpitterBoolReset, i) 
					return 
				}
				i_Vocalize = GetRandomInt(1, 100) 
				if  (i_Vocalize > g_iVocalizeChance){
					return
				}
				GetClientModel(i, model, sizeof(model)) 
				
				if (StrEqual(model, MODEL_COACH)) {
					i_Rand = GetRandomInt(1, 5) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/coach/HeardSpitter0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSpitter[i] = false
				}
				else if (StrEqual(model, MODEL_ELLIS)) {
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/mechanic/HeardSpitter0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSpitter[i] = false
				}
				else if (StrEqual(model, MODEL_NICK)) {
					i_Rand = GetRandomInt(1, 6) 
					Format(s_Vocalize, sizeof(s_Vocalize),"scenes/gambler/HeardSpitter0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSpitter[i] = false
				}
				else if (StrEqual(model, MODEL_ROCHELLE)){
					i_Rand = GetRandomInt(1, 6) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/producer/HeardSpitter0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnSpitter[i] = false
				}
			}
		}	
	}	
	
	else if (class == ZOMBIECLASS_TANK) {
		for (i = 1; i <= maxplayers; i++)
		{
			if (IsClientInGame(i)) {
				if (GetClientTeam(i) == 2 && IsPlayerAlive(i)) { 
					if (g_bTankTimer[i] == true) 
					return
				}
				if (g_bIsWarnTank[i] == false) {
					g_bTankTimer[i] = true 
					CreateTimer(g_iTankWarnDelay, TankBoolReset, i)
					return 
				}
				i_Vocalize = GetRandomInt(1, 100) 
				if  (i_Vocalize > g_iVocalizeChance){
					return
				}
				GetClientModel(i, model, sizeof(model)) 
				
				if (StrEqual(model, MODEL_COACH)) {
					i_Rand = GetRandomInt(1, 4) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/coach/HeardHulk0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_ELLIS)) {
					i_Rand = GetRandomInt(1, 6) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/mechanic/HeardHulk0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_NICK)) {
					i_Rand = GetRandomInt(1, 6) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/gambler/HeardHulk0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_ROCHELLE)){
					i_Rand = GetRandomInt(1, 4) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/producer/HeardHulk0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_BILL)){
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/namvet/WarnTank0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_LOUIS)){
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/manager/WarnTank0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_FRANCIS)){
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/biker/WarnTank0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
				else if (StrEqual(model, MODEL_ZOEY)){
					i_Rand = GetRandomInt(1, 3) 
					Format(s_Vocalize, sizeof(s_Vocalize), "scenes/teengirl/WarnTank0%i.vcd", i_Rand)
					PerformSceneEx(i, "", s_Vocalize, 2.0, 1.0)
					g_bIsWarnTank[i] = false
				}
			}	
		}	
	}
}
public ConVarVocalizeChance(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iVocalizeChance = GetConVarInt(convar) 
}

public ConVarBoomerWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iBoomerWarnDelay = GetConVarFloat(convar) 
}

public ConVarSmokerWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSmokerWarnDelay = GetConVarFloat(convar) 
}

public ConVarSpitterWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSpitterWarnDelay = GetConVarFloat(convar) 
}

public ConVarChargerWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iChargerWarnDelay = GetConVarFloat(convar) 
}

public ConVarTankWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iTankWarnDelay = GetConVarFloat(convar) 
}

public ConVarSpecialWarnDelay(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iSpecialWarnDelay = GetConVarFloat(convar) 
}

public Action:SpecialBoolReset(Handle:timer, any:i)
{
	g_bIsWarnSpecial[i] = true 
	g_bSpecialTimer[i] = false
}

public Action:BoomerBoolReset(Handle:timer, any:i)
{
	g_bIsWarnBoomer[i] = true
	g_bBoomerTimer[i] = false
}

public Action:ChargerBoolReset(Handle:timer, any:i)
{
	g_bIsWarnCharger[i] = true 
	g_bChargerTimer[i] = false
}

public Action:SmokerBoolReset(Handle:timer, any:i)
{
	g_bIsWarnSmoker[i] = true 
	g_bSmokerTimer[i] = false
}

public Action:SpitterBoolReset(Handle:timer, any:i)
{
	g_bIsWarnSpitter[i] = true 
	g_bSpitterTimer[i] = false
}

public Action:TankBoolReset(Handle:timer, any:i)
{
	g_bIsWarnTank[i] = true 
	g_bTankTimer[i] = false
}