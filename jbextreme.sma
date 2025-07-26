#pragma tabsize 0
#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich> 
#include <fun>
#include <cstrike>
#include <colorchat>
#include <fakemeta_util>
#include <dhudmessage>

#define PLUGIN_NAME	"JailBreak Extreme"
#define PLUGIN_AUTHOR	"JoRoPiTo & emel-maks-va"
#define PLUGIN_VERSION	"1.9"
#define PLUGIN_CVAR	"jbextreme"

#define TASK_STATUS	2487000
#define TASK_FREEDAY	2487100
#define TASK_SAFETIME	2487400
#define TASK_FREEEND	2487500 
#define HUD_DELAY		Float:1.0
#define CELL_RADIUS	Float:200.0

#define TEAM_MENU		"#Team_Select_Spect"
#define TEAM_MENU2	"#Team_Select_Spect"

#define get_bit(%1,%2) 		( %1 &   1 << ( %2 & 31 ) )
#define set_bit(%1,%2)	 	%1 |=  ( 1 << ( %2 & 31 ) )
#define clear_bit(%1,%2)	%1 &= ~( 1 << ( %2 & 31 ) )

#define vec_len(%1)		floatsqroot(%1[0] * %1[0] + %1[1] * %1[1] + %1[2] * %1[2])
#define vec_mul(%1,%2)		( %1[0] *= %2, %1[1] *= %2, %1[2] *= %2)
#define vec_copy(%1,%2)		( %2[0] = %1[0], %2[1] = %1[1],%2[2] = %1[2])

// Offsets
#define m_iPrimaryWeapon	116
#define m_iVGUI			510
#define m_fGameHUDInitialized	349
#define m_fNextHudTextArgsGameTime	198

#define MAXPLAYERS            32

#define SetUserReversed(%1)		g_bMigraineux |= 1<<(%1 & 31)
#define ClearUserReversed(%1)		g_bMigraineux &= ~( 1<<(%1 & 31) )
#define HasUserMigraine(%1)		g_bMigraineux &  1<<(%1 & 31)

#define MODEL_LIFEBAR 		"sprites/duel.spr"

#define fm_cs_set_weapon_ammo(%1,%2)    set_pdata_int(%1, OFFSET_CLIPAMMO, %2, OFFSET_LINUX_WEAPONS)
#define OFFSET_CLIPAMMO        51
#define OFFSET_LINUX_WEAPONS    4

new g_lifebar[33]

enum _:GlobalState {None, Terrorists, Cts, All}

new g_bMigraineux
new Float:g_vecPunchAngles[MAXPLAYERS+1][3]
new g_iFfPlayerPreThink
new g_iGlobalState
 
enum _hud { _hudsync, Float:_x, Float:_y, Float:_time }
enum _lastrequest { _knife, _deagle, _freeday, _weapon }
enum _duel { _name[16], _csw, _entname[32], _opt[32], _sel[32] }

new g_Usert
new g_Userct
new g_Userta
new g_Usercta

new g_Days
new g_NowDay[128];
new g_DayType[128];
new g_FreedayTime

new g_Usevip[33]

new g_UserSpeed[33]

new g_PlayerSkin[33]
new g_Maketeamnum

new g_VoteMenu
new g_Votes[6]	
new g_Voting

new g_Countsimon

new g_msgScreenFade

new g_Gameday
new g_Gamenum
new g_GameNow
new g_Giveditem

new sec_game2
new sec_game4

new g_PlayerVoice

new gp_PrecacheSpawn
new gp_PrecacheKeyValue

new gp_RetryTime
new gp_RoundMax
new gp_ButtonShoot
new gp_Motd
new gp_NosimonRounds
new gp_TeamChange

new g_PunishType

new g_MsgStatusText
new g_MsgStatusIcon
new g_MsgVGUIMenu
new g_MsgShowMenu
new g_MsgClCorpse
new g_MsgMOTD

new gc_ButtonShoot

new Ent[33] 
new namesimon[33]
new wanted[1024]
new g_NowOneFd

new g_GameEng

new g_DuelOptions[5] //1.честная\нечестная 2.типы оружий 3.модель 4.глов и траил

// Precache
new const _FistModels[][] = { "models/we_mob/p_hands.mdl", "models/we_mob/v_hands.mdl" }
new const _CrowbarModels[][] = { "models/we_mob/p_crowbarnew.mdl", "models/we_mob/v_crowbarnew.mdl" }
new const _BatModels[][] = { "models/extreme-shop/p_palo.mdl", "models/extreme-shop/v_palo.mdl" }
new const _ScrewdriverModels[][] = { "models/we_mob/p_screwdriver.mdl", "models/we_mob/v_screwdriver.mdl" }
new const _ClutchesModels[][] = { "models/we_mob/p_clutches.mdl", "models/we_mob/v_clutches.mdl" }
new const _FistSounds[][] = { "weapons/cbar_hitbod2.wav", "weapons/cbar_hitbod1.wav", "weapons/bullet_hit1.wav", "weapons/bullet_hit2.wav" }
new const _RemoveEntities[][] = {
	"func_hostage_rescue", "info_hostage_rescue", "func_bomb_target", "info_bomb_target",
	"hostage_entity", "info_vip_start", "func_vip_safetyzone", "func_escapezone"
}

new const _WeaponsFree[][] = { "weapon_scout", "weapon_deagle", "weapon_mac10", "weapon_elite", "weapon_ak47", "weapon_m4a1", "weapon_mp5navy" }
new const _WeaponsFreeCSW[] = { CSW_SCOUT, CSW_DEAGLE, CSW_MAC10, CSW_ELITE, CSW_AK47, CSW_M4A1, CSW_MP5NAVY }
new const _WeaponsFreeAmmo[] = { 90, 35, 100, 120, 90, 90, 120 }

new const _Duel[][_duel] =
{
	{ "Deagle", CSW_DEAGLE, "weapon_deagle", "JBE_MENU_LASTREQ_OPT4", "JBE_MENU_LASTREQ_SEL4" },
	{ "Scout", CSW_SCOUT, "weapon_scout", "JBE_MENU_LASTREQ_OPT5", "JBE_MENU_LASTREQ_SEL5" },
	{ "Grenades", CSW_HEGRENADE, "weapon_hegrenade", "JBE_MENU_LASTREQ_OPT6", "JBE_MENU_LASTREQ_SEL6" },
	{ "Awp", CSW_AWP, "weapon_awp", "JBE_MENU_LASTREQ_OPT7", "JBE_MENU_LASTREQ_SEL7" }
}

// HudSync: 0=ttinfo / 1=info / 2=simon / 3=ctinfo / 4=player / 5=day / 6=center / 7=help / 8=timer
new const g_HudSync[][_hud] =
{
	{0,  0.6,  0.2,  2.0},
	{0, -1.0,  0.7,  5.0},
	{0,  0.1,  0.2,  2.0},
	{0,  0.1,  0.3,  2.0},
	{0, -1.0,  0.9,  3.0},
	{0,  0.6,  0.1,  3.0},
	{0, -1.0,  0.6,  3.0},
	{0,  0.8,  0.3, 20.0},
	{0, -1.0,  0.4,  3.0}
}

new Trie:g_CellManagers
new g_JailDay
new g_PlayerJoin
new g_PlayerSpect[33]
new g_PlayerSimon[33]
new g_PlayerNomic
new g_PlayerWanted
new g_PlayerCrowbar
new g_PlayerBat
new g_PlayerChain
new g_PlayerScrewdriver
new g_PlayerClutches
new g_PlayerRevolt
new g_PlayerFreeday
new g_PlayerLast
new g_FreedayAuto
new g_BoxStarted
new g_BoxClassic
new g_Simon
new g_SimonAllowed
new g_SimonTalking
new g_SimonVoice
new g_RoundStarted
new g_LastDenied
new g_Freeday
new g_BlockWeapons
new g_RoundEnd
new g_Duel
new g_DuelA
new g_DuelB
new g_Buttons[10]

new bool:ishooked[32]
new hookorigin[32][3]

new Sbeam

new g_Teleport[32]

new smokeSpr
new g_YouShot
new g_YouShotTime
 
native dr_set_user_money(id, szNum)
native dr_get_user_money(id)
native give_weapon_xm8(id, type)
native get_weapon_xm8(id)
native give_weapon_vsk(id, type)
native get_weapon_vsk(id)
native give_weapon_ele(id, type, mod)
native get_weapon_ele(id)
native give_weapon_anaconda(id, type)
native get_weapon_anaconda(id)
native give_weapon_m79(id, type)
native get_weapon_m79(id)
native make_troll()
native jb_game_chay()
native jb_game_killball()
native jb_game_hemod()
native jb_game_snowballs()
 
new const g_chain_weaponmodel[] = { "models/we_mob/p_moto.mdl" }
new const g_chain_viewmodel[] = { "models/we_mob/v_moto.mdl" }
 
public plugin_natives()
{
	register_native("jb_is_user_simon", "native_get_user_simon", 1)
	register_native("jb_is_user_duel", "native_get_user_duel", 1)
	register_native("jb_is_user_duel1", "native_get_user_duel1", 1)
	register_native("jb_is_user_duel2", "native_get_user_duel2", 1)
	register_native("jb_is_user_duel3", "native_get_user_duel3", 1)
	register_native("jb_is_user_duel4", "native_get_user_duel4", 1)
	register_native("jb_is_user_duel5", "native_get_user_duel5", 1)
}
 
public plugin_init()
{
	unregister_forward(FM_Spawn, gp_PrecacheSpawn)
	unregister_forward(FM_KeyValue, gp_PrecacheKeyValue)
 
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
	register_cvar(PLUGIN_CVAR, PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY)
 
	register_dictionary("jbextreme.txt")

	g_MsgStatusText = get_user_msgid("StatusText")
	g_MsgStatusIcon = get_user_msgid("StatusIcon")
	g_MsgVGUIMenu = get_user_msgid("VGUIMenu")
	g_MsgShowMenu = get_user_msgid("ShowMenu")
	g_MsgMOTD = get_user_msgid("MOTD")
	g_MsgClCorpse = get_user_msgid("ClCorpse")

	register_message(g_MsgStatusText, "msg_statustext")
	register_message(g_MsgStatusIcon, "msg_statusicon")
	register_message(g_MsgVGUIMenu, "msg_vguimenu")
	register_message(g_MsgShowMenu, "msg_showmenu")
	register_message(g_MsgMOTD, "msg_motd")
	register_message(g_MsgClCorpse, "msg_clcorpse")

	register_event("CurWeapon", "current_weapon", "be", "1=1", "2=29")
	register_event("CurWeapon","user_change_weapon","be","1=1")
	
	register_menucmd(register_menuid(TEAM_MENU), 51, "team_select") 
	register_menucmd(register_menuid(TEAM_MENU2), 51, "team_select") 

	register_impulse(100, "impulse_100")

	RegisterHam(Ham_Spawn, "player", "player_spawn", 1)
	RegisterHam(Ham_TakeDamage, "player", "player_damage")
	RegisterHam(Ham_TraceAttack, "player", "player_attack")
	RegisterHam(Ham_TraceAttack, "func_button", "button_attack")
	RegisterHam(Ham_Killed, "player", "player_killed", 1)
	RegisterHam(Ham_Touch, "weapon_hegrenade", "player_touchweapon")
	RegisterHam(Ham_Touch, "weaponbox", "player_touchweapon")
	RegisterHam(Ham_Touch, "armoury_entity", "player_touchweapon")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_deagle","f_weapon_attack")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_scout","f_weapon_attack")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_awp","f_weapon_attack")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_sg550","f_weapon_attack")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_p228","f_weapon_attack")
	RegisterHam(Ham_Weapon_PrimaryAttack ,"weapon_aug","f_weapon_attack")

	register_forward(FM_SetClientKeyValue, "set_client_kv")
	register_forward(FM_EmitSound, "sound_emit")
	register_forward(FM_Voice_SetClientListening, "voice_listening")
	register_forward(FM_CmdStart, "player_cmdstart", 1)
	register_forward(FM_SetModel, "Fw_SetModel")
	register_forward(FM_AddToFullPack, "fw_AddToFullPack", 1)

	register_logevent("round_end", 2, "1=Round_End")
	register_logevent("round_first", 2, "0=World triggered", "1&Restart_Round_")
	register_logevent("round_first", 2, "0=World triggered", "1=Game_Commencing")
	register_logevent("round_start", 2, "0=World triggered", "1=Round_Start")

	register_clcmd("+simonvoice", "cmd_voiceon")
	register_clcmd("-simonvoice", "cmd_voiceoff") 
	
	register_clcmd("say /voice", "cmd_simon_micr")	 
	register_clcmd("say /micr", "cmd_simon_micr")
	
	register_clcmd("+hook","hook_on")
	register_clcmd("-hook","hook_off")

	register_clcmd("say /fd", "cmd_freeday")
	register_clcmd("say /freeday", "cmd_freeday")
	register_clcmd("say /day", "cmd_freeday")
	register_clcmd("say /lr", "cmd_lastrequest")
	register_clcmd("say /lastrequest", "cmd_lastrequest")
	register_clcmd("say /duel", "cmd_lastrequest")
	register_clcmd("say /simon", "cmd_simon")
	register_clcmd("say /open", "cmd_open")
	register_clcmd("say /nomic", "cmd_nomic")
	register_clcmd("say /box", "cmd_box")
	
	register_clcmd("say /shop", "go_shop")
	register_clcmd("say /menu", "all_menu")
	register_clcmd("buy", "all_menu")
	register_clcmd("say /status", "status_menu")
	register_clcmd("menu", "all_menu")
	register_clcmd("say /smenu", "simon_menu")
	register_clcmd("say /shop2", "shopt2_menu")
	register_clcmd("say /shop3", "shopt3_menu")

	register_clcmd("jbe_freeday", "adm_freeday", ADMIN_KICK)
	register_concmd("jbe_nomic", "adm_nomic", ADMIN_KICK)
	register_concmd("jbe_open", "adm_open", ADMIN_KICK)
	register_concmd("jbe_box", "adm_box", ADMIN_KICK)
 
	gp_TeamChange = register_cvar("jbe_teamchange", "0") // 0-disable team change for tt / 1-enable team change
	gp_RetryTime = register_cvar("jbe_retrytime", "10.0")
	gp_RoundMax = register_cvar("jbe_freedayround", "400.0")
	gp_Motd = register_cvar("jbe_motd", "1")
	gp_NosimonRounds = register_cvar("jbe_nosimonrounds", "7")
	gp_ButtonShoot = register_cvar("jbe_buttonshoot", "1")	// 0-standard / 1-func_button shoots!
	
	g_msgScreenFade = get_user_msgid("ScreenFade")
 

	for(new i = 0; i < sizeof(g_HudSync); i++)
		g_HudSync[i][_hudsync] = CreateHudSyncObj()
		
	for(new i = 1; i <= MAXPLAYERS; i++)
	{
		g_lifebar[i] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
		if(!pev_valid(g_lifebar[i])) continue
		
		engfunc(EngFunc_SetModel, g_lifebar[i], MODEL_LIFEBAR)
		set_pev(g_lifebar[i], pev_movetype, MOVETYPE_FOLLOW)
		set_pev(g_lifebar[i], pev_solid , SOLID_NOT );
		set_pev(g_lifebar[i], pev_aiment, i)
		set_pev(g_lifebar[i], pev_scale, 0.35)
		
		set_pev(g_lifebar[i], pev_renderfx, kRenderFxNone)
		set_pev(g_lifebar[i], pev_rendercolor, Float:{0.0, 0.0, 0.0})
		set_pev(g_lifebar[i], pev_rendermode, kRenderTransAdd)
		set_pev(g_lifebar[i], pev_renderamt, 0.0)	
		dllfunc(DLLFunc_Spawn, g_lifebar[i])
	}

	setup_buttons()
}
 
public plugin_precache()
{

	precache_sound("hook/hook.wav")
	Sbeam = precache_model("sprites/hook/hook_CT.spr")
	precache_model(MODEL_LIFEBAR)
	smokeSpr = precache_model("sprites/steam1.spr")
	
	static i
	precache_model("models/player/we_mob_jb1/we_mob_jb1.mdl")
	precache_model("models/player/we_mob_jb2/we_mob_jb2.mdl")
 
	for(i = 0; i < sizeof(_FistModels); i++)
		precache_model(_FistModels[i])
 
	for(i = 0; i < sizeof(_CrowbarModels); i++)
		precache_model(_CrowbarModels[i])
		
	for(i = 0; i < sizeof(_BatModels); i++)
		precache_model(_BatModels[i])
		
	for(i = 0; i < sizeof(_ScrewdriverModels); i++)
		precache_model(_ScrewdriverModels[i])
 
	for(i = 0; i < sizeof(_ClutchesModels); i++)
		precache_model(_ClutchesModels[i])
 
	for(i = 0; i < sizeof(_FistSounds); i++)
		precache_sound(_FistSounds[i])

	precache_sound("jbextreme/Duel_Active.mp3")
	precache_sound("jbextreme/brass_bell_C.wav")
	precache_sound("jbextreme/foot.wav")
	precache_sound("jbextreme/1.wav")
	precache_sound("jbextreme/2.wav")
	precache_sound("jbextreme/3.wav")
	precache_sound("jbextreme/4.wav")
	precache_sound("jbextreme/5.wav")
	precache_sound("jbextreme/6.wav")
	precache_sound("jbextreme/7.wav")
	precache_sound("jbextreme/8.wav")
	precache_sound("jbextreme/9.wav")
	precache_sound("jbextreme/10.wav")
	precache_sound("jbextreme/rs.wav")
	
	precache_sound("jbextreme/eda.mp3")
	precache_sound("jbextreme/trava.mp3")
	precache_sound("jbextreme/kola.mp3")
	
	precache_sound( "weapons/chainsaw_draw.wav" )
	precache_sound( "weapons/chainsaw_slash1.wav" )
	precache_sound( "weapons/chainsaw_slash2.wav" )
	
	precache_sound( "weapons/screwdriver_draw.wav" )
	
	precache_model( "models/we_mob/p_moto.mdl" )
	precache_model( "models/we_mob/v_moto.mdl" )
	
	precache_sound( "weapons/dragontail_draw.wav" )
	precache_sound( "weapons/dragontail_stab1.wav" )
	precache_sound( "weapons/dragontail_stab2.wav" )
 
 	g_CellManagers = TrieCreate()
	gp_PrecacheSpawn = register_forward(FM_Spawn, "precache_spawn", 1)
	gp_PrecacheKeyValue = register_forward(FM_KeyValue, "precache_keyvalue", 1)
}

public precache_spawn(ent)
{
	if(is_valid_ent(ent))
	{
		static szClass[33]
		entity_get_string(ent, EV_SZ_classname, szClass, sizeof(szClass))
		for(new i = 0; i < sizeof(_RemoveEntities); i++)
			if(equal(szClass, _RemoveEntities[i]))
				remove_entity(ent)
	}
}

public precache_keyvalue(ent, kvd_handle)
{
	static info[32]
	if(!is_valid_ent(ent))
		return FMRES_IGNORED

	get_kvd(kvd_handle, KV_ClassName, info, charsmax(info))
	if(!equal(info, "multi_manager"))
		return FMRES_IGNORED

	get_kvd(kvd_handle, KV_KeyName, info, charsmax(info))
	TrieSetCell(g_CellManagers, info, ent)
	return FMRES_IGNORED
}

public client_putinserver(id)
{
	clear_bit(g_PlayerJoin, id)
	clear_bit(g_PlayerCrowbar, id)
	clear_bit(g_PlayerBat, id)
	clear_bit(g_PlayerChain, id)
	clear_bit(g_PlayerScrewdriver, id)
	clear_bit(g_PlayerClutches, id)
	clear_bit(g_PlayerNomic, id)
	clear_bit(g_PlayerWanted, id)
	clear_bit(g_SimonTalking, id)
	clear_bit(g_SimonVoice, id)
	g_PlayerSpect[id] = 0
	g_PlayerSimon[id] = 0
	g_Usevip[id] = 0
	g_UserSpeed[id] = 0
	remove_hook(id)
}

public client_authorized(id)
{
	client_cmd(id, "bind ^"F3^" ^"menu^"")
}

public client_disconnect(id)
{
	remove_hook(id)
	if(g_Simon == id)
	{
		g_Simon = 0
		ClearSyncHud(0, g_HudSync[2][_hudsync])
		player_hudmessage(0, 2, 5.0, _, "%L", LANG_SERVER, "JBE_SIMON_HASGONE")
	}
	else if(g_PlayerLast == id || (g_Duel && (id == g_DuelA || id == g_DuelB)))
	{
		Kill_Trail(g_DuelA)
		Kill_Trail(g_DuelB)
		g_Duel = 0
		g_DuelA = 0
		g_YouShot = 0
		g_YouShotTime = 0
		g_DuelB = 0
		g_LastDenied = 0
		g_BlockWeapons = 0
		g_PlayerLast = 0
	}
	Count_Players()
	who_fd()
	who_simon()
}

public client_infochanged(id)
{
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE
			 
	new szModel[32]
	new szModelDefault[32] = "we_mob_jb1"
	new szModelDefault2[32] = "we_mob_jb2"
			 
	get_user_info(id, "model", szModel, charsmax( szModel ))
			 
	if(!(equal(szModel, szModelDefault)) && !(equal(szModel, szModelDefault2)))
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 5)
		user_silentkill(id)
		ColorChat(id, RED, "^4[Модели]^3 Ай ай ай, так делать нельзя.")
	}
	return PLUGIN_CONTINUE
}
 
public msg_statustext(msgid, dest, id)
{
	return PLUGIN_HANDLED
}

public msg_statusicon(msgid, dest, id)
{
	static icon[5] 
	get_msg_arg_string(2, icon, charsmax(icon))
	if(icon[0] == 'b' && icon[2] == 'y' && icon[3] == 'z')
	{
		set_pdata_int(id, 235, get_pdata_int(id, 235) & ~(1<<0))
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

public msg_vguimenu(msgid, dest, id)
{
	static msgarg1
	static CsTeams:team

	msgarg1 = get_msg_arg_int(1)
	if(msgarg1 == 2)
	{
		team = cs_get_user_team(id)
		if((team == CS_TEAM_T) && !is_user_admin(id) && (is_user_alive(id) || !get_pcvar_num(gp_TeamChange)))
		{
			client_print(id, print_center, "%L", LANG_SERVER, "JBE_TEAM_CANTCHANGE")
			return PLUGIN_HANDLED
		}
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE
}

public msg_showmenu(msgid, dest, id)
{
	static msgarg1, roundloop
	static CsTeams:team
	msgarg1 = get_msg_arg_int(1)

	if(msgarg1 != 531 && msgarg1 != 563)
		return PLUGIN_CONTINUE

	roundloop = floatround(get_pcvar_float(gp_RetryTime) / 2)
	team = cs_get_user_team(id)

	if(team == CS_TEAM_T)
	{
		if(!is_user_admin(id) && (is_user_alive(id) || (g_RoundStarted >= roundloop) || !get_pcvar_num(gp_TeamChange)))
		{
			client_print(id, print_center, "%L", LANG_SERVER, "JBE_TEAM_CANTCHANGE")
			return PLUGIN_HANDLED
		}
	}

	return PLUGIN_CONTINUE
}

public msg_motd(msgid, dest, id)
{
	if(get_pcvar_num(gp_Motd))
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

public msg_clcorpse(msgid, dest, id)
{
	return PLUGIN_HANDLED
}

public current_weapon(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE

	if(get_bit(g_PlayerCrowbar, id))
	{
		set_pev(id, pev_viewmodel2, _CrowbarModels[1])
		set_pev(id, pev_weaponmodel2, _CrowbarModels[0])
	}
	else if(get_bit(g_PlayerScrewdriver, id))
	{
		set_pev(id, pev_viewmodel2, _ScrewdriverModels[1])
		set_pev(id, pev_weaponmodel2, _ScrewdriverModels[0])
	}
	else if(get_bit(g_PlayerBat, id))
	{
		set_pev(id, pev_viewmodel2, _BatModels[1])
		set_pev(id, pev_weaponmodel2, _BatModels[0])
	}
	else if(get_bit(g_PlayerClutches, id))
	{
		set_pev(id, pev_viewmodel2, _ClutchesModels[1])
		set_pev(id, pev_weaponmodel2, _ClutchesModels[0])
	}
	else if(get_bit(g_PlayerChain, id))
	{
		set_pev(id, pev_viewmodel2, g_chain_viewmodel)
		set_pev(id, pev_weaponmodel2, g_chain_weaponmodel)
	}
	else
	{
		set_pev(id, pev_viewmodel2, _FistModels[1])
		set_pev(id, pev_weaponmodel2, _FistModels[0])
	}
	return PLUGIN_CONTINUE
}

public user_change_weapon(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE

	if(g_UserSpeed[id])
	{
		set_user_maxspeed(id, 500.0)
	}
	
	if(g_Duel == 3)
	{
		if((g_DuelA == id || g_DuelB == id) && is_user_connected(id) && is_user_alive(id) && get_user_weapon(id) != CSW_KNIFE) 
		{
			strip_user_weapons(id)
			give_item(id, "weapon_knife")
		}
	}
	else if(g_Duel == 4)
	{
		if((g_DuelA == id || g_DuelB == id) && is_user_connected(id) && is_user_alive(id)) 
		{
			if(!g_DuelOptions[0] && get_user_weapon(id) != CSW_DEAGLE)
			{
				giveweap(id)
			}
			if(g_DuelOptions[0] && get_user_weapon(id) != CSW_DEAGLE)
			{
				set_task(0.2, "giveana", id)
			}
		}

	}
	else if(g_Duel == 5)
	{
		if((g_DuelA == id || g_DuelB == id) && is_user_connected(id) && is_user_alive(id)) 
		{
			if(!g_DuelOptions[0] && get_user_weapon(id) != CSW_SCOUT)
			{
				giveweap(id)
			}
			if(g_DuelOptions[0] && get_user_weapon(id) != CSW_SG550)
			{
				set_task(0.2, "givevsk", id)
			}
		}
	}
	else if(g_Duel == 6)
	{
		if((g_DuelA == id || g_DuelB == id) && is_user_connected(id) && is_user_alive(id)) 
		{
			if(!g_DuelOptions[0] && get_user_weapon(id) != CSW_HEGRENADE)
			{
				strip_user_weapons(id)
				give_item(id, "weapon_hegrenade")
			}
			if(g_DuelOptions[0] && get_user_weapon(id) != CSW_P228)
			{
				set_task(0.2, "givem79", id)
			}
		}

	}
	else if(g_Duel == 7)
	{
		if((g_DuelA == id || g_DuelB == id) && is_user_connected(id) && is_user_alive(id)) 
		{
			if(!g_DuelOptions[0] && get_user_weapon(id) != CSW_AWP)
			{
				giveweap(id)
			}
			if(g_DuelOptions[0] && get_user_weapon(id) != CSW_AUG)
			{
				set_task(0.2, "giveele", id)
			}
		}
	}

	
	if(g_GameNow == 1)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && (get_user_weapon(id) != CSW_M3 && get_user_weapon(id) != CSW_KNIFE)) 
		{
			strip_user_weapons(id)	
			give_item( id, "weapon_m3" )
			give_item( id, "weapon_knife" )
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
		}
		else
		{
			if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T && get_user_weapon(id) != CSW_KNIFE) 
			{
				strip_user_weapons(id)
				give_item( id, "weapon_knife" );
			}
		}
	}
	else if(g_GameNow == 2)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && (get_user_weapon(id) != CSW_M3 && get_user_weapon(id) != CSW_KNIFE && get_user_weapon(id) != CSW_SMOKEGRENADE && get_user_weapon(id) != CSW_FLASHBANG)) 
		{
			strip_user_weapons(id)	
			give_item( id, "weapon_m3" );
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "ammo_buckshot")
			give_item( id, "weapon_knife" )
		}
		else
		{
			if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T && (get_user_weapon(id) != CSW_KNIFE && get_user_weapon(id) != CSW_SMOKEGRENADE && get_user_weapon(id) != CSW_FLASHBANG)) 
			{
				strip_user_weapons(id)
				give_item( id, "weapon_knife" )
			}
		}
	}
	else if(g_GameNow == 3)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && get_user_weapon(id) != CSW_KNIFE) 
		{
			strip_user_weapons(id)
			give_item( id, "weapon_knife" )
		}
	}
	else if(g_GameNow == 4)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && get_user_weapon(id) != CSW_KNIFE) 
		{
			strip_user_weapons(id)
			give_item( id, "weapon_knife" )
		}
	}
	else if(g_GameNow == 7)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T && get_user_weapon(id) != CSW_KNIFE) 
		{
			strip_user_weapons(id)
			give_item( id, "weapon_knife" )
		}
		else
		{
			if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && (get_user_weapon(id) != CSW_M4A1 && get_user_weapon(id) != CSW_KNIFE)) 
			{
				strip_user_weapons(id)
				give_item( id, "weapon_knife" );
				give_item( id, "weapon_m4a1" );
				cs_set_user_bpammo( id, CSW_M4A1, 500);
			}
		}
	}
	else if(g_GameNow == 9)
	{
		if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T && get_user_weapon(id) != CSW_KNIFE) 
		{
			strip_user_weapons(id)
			give_item( id, "weapon_knife" )
		}
		else
		{
			if (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && (get_user_weapon(id) != CSW_M249 && get_user_weapon(id) != CSW_KNIFE)) 
			{
				strip_user_weapons(id)
				give_item( id, "weapon_knife" );
				give_item( id, "weapon_m249" );
               	cs_set_user_bpammo( id, CSW_M249, 500);
			}
		}
	}
	
	return PLUGIN_CONTINUE
}

public impulse_100(id)
{
	if(cs_get_user_team(id) == CS_TEAM_T)
		return PLUGIN_HANDLED

	return PLUGIN_CONTINUE
}

public player_spawn(id)
{
	if( is_user_alive(id) )
	{
		switch( g_iGlobalState )
		{
			case Terrorists, Cts:
			{
				if( g_iGlobalState == _:cs_get_user_team(id) )
				{
					SetUserReversed(id)
				}
				else
				{
					ClearUserReversed(id)
					CheckForward()
				}
			}
			case All:
			{
				SetUserReversed(id)
				CheckForward()
			}
		}
	}

	static CsTeams:team

	if(!is_user_connected(id))
		return HAM_IGNORED

	set_pdata_float(id, m_fNextHudTextArgsGameTime, get_gametime() + 999999.0)
	player_strip_weapons(id)
	if(g_RoundEnd)
	{
		g_RoundEnd = 0
		g_JailDay++
		if(g_Days < 7)
		{
			g_Days++
		}
		else
		{
			g_Days = 1
		}
	}

	set_user_rendering(id, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)

	clear_bit(g_PlayerCrowbar, id)
	clear_bit(g_PlayerBat, id)
	clear_bit(g_PlayerScrewdriver, id)
	clear_bit(g_PlayerClutches, id)
	clear_bit(g_PlayerWanted, id)
	clear_bit(g_PlayerChain, id)
	team = cs_get_user_team(id)

	switch(team)
	{
		case(CS_TEAM_T):
		{
			g_PlayerLast = 0
			set_user_info(id, "model", "we_mob_jb1")
			entity_set_int(id, EV_INT_body, 2)
			if(is_freeday() || get_bit(g_FreedayAuto, id))
			{
				freeday_set(0, id)
				clear_bit(g_FreedayAuto, id)
			}
			else
			{
				g_PlayerSkin[id] = random_num(0, 4)
				entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
			}

			cs_set_user_armor(id, 0, CS_ARMOR_NONE)
		}
		case(CS_TEAM_CT):
		{
			g_PlayerSimon[id]++
			set_user_info(id, "model", "we_mob_jb2")
			entity_set_int(id, EV_INT_body, 2)
			cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
		}
	}
	first_join(id)
	return HAM_IGNORED
}

public player_damage(victim, ent, attacker, Float:damage, bits, damage_type)
{
	if(!is_user_connected(victim) || !is_user_connected(attacker) || victim == attacker)
		return HAM_IGNORED
		
		if(!g_BoxStarted && cs_get_user_team(victim) == CS_TEAM_T && cs_get_user_team(attacker) == CS_TEAM_T)
			SetHamParamFloat(4, damage * 0)

	switch(g_Duel)
	{
		case(0):
		{
		 if(g_GameNow == 2)
		 {
			if(attacker == ent && cs_get_user_team(victim) != CS_TEAM_T)
			{
				if(g_Teleport[attacker])
				{
					ExecuteHamB(Ham_CS_RoundRespawn, victim)
					SetHamParamFloat(4, damage * 0)
					new namect[32]
               				get_user_name(victim,namect,31)
					new namet[32]
                			get_user_name(attacker,namet,31)
					set_hudmessage(255, 0, 0, 0.23, 0.26, 0, 6.0, 2.5)
					show_hudmessage(0, "%s телепортировался, %s перепрятывается!",namect, namet)
					g_Teleport[attacker]--
				}
				return HAM_SUPERCEDE
			}
		 }
		 if(attacker == ent && get_user_weapon(attacker) == CSW_KNIFE && get_bit(g_PlayerCrowbar, attacker))
		 {
			if((g_BoxClassic && cs_get_user_team(victim) == CS_TEAM_T) || cs_get_user_team(victim) != CS_TEAM_T)
			{
				SetHamParamFloat(4, damage * 2.5)
				return HAM_OVERRIDE
			}
		 }
		 if(attacker == ent && get_user_weapon(attacker) == CSW_KNIFE && get_bit(g_PlayerBat, attacker))
		 {
		 	if((g_BoxClassic && cs_get_user_team(victim) == CS_TEAM_T) || cs_get_user_team(victim) != CS_TEAM_T)
			{
				SetHamParamFloat(4, damage * 1.5)
				return HAM_OVERRIDE
			}
		 }
		 if(attacker == ent && get_user_weapon(attacker) == CSW_KNIFE && get_bit(g_PlayerScrewdriver, attacker))
		 {
		 	if((g_BoxClassic && cs_get_user_team(victim) == CS_TEAM_T) || cs_get_user_team(victim) != CS_TEAM_T)
			{
				SetHamParamFloat(4, damage * 4)
				return HAM_OVERRIDE
			}
		 }
		 if(attacker == ent && get_user_weapon(attacker) == CSW_KNIFE && get_bit(g_PlayerClutches, attacker))
		 {
		 	if((g_BoxClassic && cs_get_user_team(victim) == CS_TEAM_T) || cs_get_user_team(victim) != CS_TEAM_T)
			{
				SetHamParamFloat(4, damage * 8)
				return HAM_OVERRIDE
			}
		 }
		 if(attacker == ent && get_user_weapon(attacker) == CSW_KNIFE && get_bit(g_PlayerChain, attacker))
		 {
		 	if((g_BoxClassic && cs_get_user_team(victim) == CS_TEAM_T) || cs_get_user_team(victim) != CS_TEAM_T)
			{
				SetHamParamFloat(4, damage * 6)
				return HAM_OVERRIDE
			}
		 }
		}
		case(2):
		{
			if(attacker != g_PlayerLast)
				return HAM_SUPERCEDE
		}
		default:
		{
			if((victim == g_DuelA && attacker == g_DuelB) || (victim == g_DuelB && attacker == g_DuelA))
				return HAM_IGNORED
	
			return HAM_SUPERCEDE
		}
	}

	return HAM_IGNORED
}

public player_attack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	static CsTeams:vteam, CsTeams:ateam
	if(!is_user_connected(victim) || !is_user_connected(attacker) || victim == attacker)
		return HAM_IGNORED

	vteam = cs_get_user_team(victim)
	ateam = cs_get_user_team(attacker)

	if(ateam == CS_TEAM_CT && vteam == CS_TEAM_CT)
		return HAM_SUPERCEDE
		
	if(g_GameNow == 4)
	{
		if(vteam == CS_TEAM_T && ateam == CS_TEAM_CT)
		{
			set_user_rendering(attacker,kRenderFxGlowShell,0,0,0,kRenderNormal,50)
			remove_task(attacker)
			set_task(0.8, "Giveinviz", attacker)
		}
	}
		
	switch(g_Duel)
	{
		case(0):
		{
			if(ateam == CS_TEAM_CT && vteam == CS_TEAM_T && !g_Gameday)
			{
				if(get_bit(g_PlayerRevolt, victim)) 
				{
					clear_bit(g_PlayerRevolt, victim)
					hud_status(0)
					
				}
				return HAM_IGNORED
			}
		}
		case(2):
		{
			if(attacker != g_PlayerLast)
				return HAM_SUPERCEDE
		}
		default:
		{
			if((victim == g_DuelA && attacker == g_DuelB) || (victim == g_DuelB && attacker == g_DuelA))
				return HAM_IGNORED

			return HAM_SUPERCEDE
		}
	}

	if(ateam == CS_TEAM_T && vteam == CS_TEAM_T && !g_BoxStarted)
		return HAM_SUPERCEDE

	if(ateam == CS_TEAM_T && vteam == CS_TEAM_CT)
	{
		set_bit(g_PlayerRevolt, attacker)
	}

	return HAM_IGNORED
}

public button_attack(button, id, Float:damage, Float:direction[3], tracehandle, damagebits)
{
	if(is_valid_ent(button) && gc_ButtonShoot)
	{
		ExecuteHamB(Ham_Use, button, id, 0, 2, 1.0)
		entity_set_float(button, EV_FL_frame, 0.0)
	}

	return HAM_IGNORED
}

public player_killed(victim, attacker, shouldgib)
{
	if(get_bit(g_PlayerFreeday, victim))
	{
		who_fd()
	}

	static CsTeams:vteam, CsTeams:kteam
	if(!(0 < attacker <= MAXPLAYERS) || !is_user_connected(attacker))
		kteam = CS_TEAM_UNASSIGNED
	else
		kteam = cs_get_user_team(attacker)

	vteam = cs_get_user_team(victim)
	if(g_Simon == victim)
	{
		g_Simon = 0
		ClearSyncHud(0, g_HudSync[2][_hudsync])
		player_hudmessage(0, 2, 5.0, _, "%L", LANG_SERVER, "JBE_SIMON_KILLED")
	}

	switch(g_Duel)
	{
		case(0):
		{
			switch(vteam)
			{
				case(CS_TEAM_CT):
				{
					if(kteam == CS_TEAM_T && !get_bit(g_PlayerWanted, attacker))
					{
						set_bit(g_PlayerWanted, attacker)
						g_PlayerSkin[attacker] = 6
						entity_set_int(attacker, EV_INT_skin, g_PlayerSkin[attacker])
					}
					who_simon()
				}
				case(CS_TEAM_T):
				{
					clear_bit(g_PlayerRevolt, victim)
					clear_bit(g_PlayerWanted, victim)
				}
			}
		}
		default:
		{
			if(g_Duel != 2 && (victim == g_DuelA || victim == g_DuelB))
			{
				if(is_user_connected(g_DuelA) && is_user_alive(g_DuelA))
				{
					Kill_Trail(g_DuelA)
					set_user_rendering(g_DuelA, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
					set_user_info(g_DuelA, "model", "we_mob_jb1")
					entity_set_int(g_DuelA, EV_INT_body, 6)
					g_PlayerSkin[g_DuelA] = random_num(0, 4)
					entity_set_int(g_DuelA, EV_INT_skin, g_PlayerSkin[g_DuelA])
				}
				if(is_user_connected(g_DuelB) && is_user_alive(g_DuelB))
				{
					Kill_Trail(g_DuelB)
					set_user_rendering(g_DuelB, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
					set_user_info(g_DuelB, "model", "we_mob_jb1")
					entity_set_int(g_DuelB, EV_INT_body, 5)
				}

				g_Duel = 0
				g_DuelA = 0
				g_DuelB = 0
				g_LastDenied = 0
				g_BlockWeapons = 0
				g_PlayerLast = 0
			}
		}
	}
	Count_Players()
	hud_status(0)
	return HAM_IGNORED
}

public f_weapon_attack(weapon)
{
	if(g_Duel > 3 && g_DuelA && g_DuelB && g_DuelOptions[1])
	{
		new id = pev(weapon,pev_owner)
		if(id == g_DuelA || id == g_DuelB)
		{
			if(g_YouShot == id)
			{
				if(g_YouShot == g_DuelA)
				{
					g_YouShot = g_DuelB
					fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelB, 373), 1)
				}
				else
				{
					g_YouShot = g_DuelA
					fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelA, 373), 1)
				}
				g_YouShotTime = 15
			}
			else
			{
				return HAM_SUPERCEDE
			}
		}
	}
	hud_status(0)
	return HAM_IGNORED
}

public player_touchweapon(id, ent)
{
	static model[32], class[32]
	if(g_BlockWeapons)
		return HAM_SUPERCEDE

	if(is_valid_ent(id) && g_Duel != 6 && is_user_alive(ent) && cs_get_user_team(ent) == CS_TEAM_CT)
	{
		entity_get_string(id, EV_SZ_model, model, charsmax(model))
		if(model[7] == 'w' && model[9] == 'h' && model[10] == 'e' && model[11] == 'g')
		{
			entity_get_string(id, EV_SZ_classname, class, charsmax(class))
			if(equal(class, "weapon_hegrenade"))
				remove_entity(id)

			return HAM_SUPERCEDE
		}

	}

	return HAM_IGNORED
}

public set_client_kv(id, const info[], const key[])
{
	if(equal(key, "model"))
		return FMRES_SUPERCEDE

	return FMRES_IGNORED
}

public sound_emit(id, channel, sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!get_bit(g_PlayerChain, id) && !get_bit(g_PlayerScrewdriver, id) && !get_bit(g_PlayerClutches, id) && is_user_alive(id) && equal(sample, "weapons/knife_", 14))
	{
		switch(sample[17])
		{
			case('b'):
			{
				emit_sound(id, CHAN_WEAPON, "weapons/cbar_hitbod2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
			case('w'):
			{
				emit_sound(id, CHAN_WEAPON, "weapons/cbar_hitbod1.wav", 1.0, ATTN_NORM, 0, PITCH_LOW)
			}
			case('1', '2'):
			{
				emit_sound(id, CHAN_WEAPON, "weapons/bullet_hit2.wav", random_float(0.5, 1.0), ATTN_NORM, 0, PITCH_NORM)
			}
		}
		return FMRES_SUPERCEDE
	}
	else if(get_bit(g_PlayerChain, id) && !get_bit(g_PlayerScrewdriver, id) && !get_bit(g_PlayerClutches, id) && is_user_alive(id) && equal(sample[8], "kni", 3))
	{
		volume = 0.6;
		
		if (equal(sample[14], "sla", 3))
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/chainsaw_slash1.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
		if(equal(sample,"weapons/knife_deploy1.wav"))
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/chainsaw_draw.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
		if (equal(sample[14], "hit", 3))
		{
			if (sample[17] == 'w') 
			{
				engfunc(EngFunc_EmitSound, id, channel,"weapons/chainsaw_slash1.wav", volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
			else 
			{
				engfunc(EngFunc_EmitSound, id, channel, "weapons/chainsaw_slash2.wav", volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
		}
		if (equal(sample[14], "sta", 3)) 
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/chainsaw_slash2.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
	}
	else if(!get_bit(g_PlayerChain, id) && get_bit(g_PlayerScrewdriver, id) && !get_bit(g_PlayerClutches, id) && is_user_alive(id) && equal(sample[8], "kni", 3))
	{
		volume = 0.6;

		if(equal(sample,"weapons/knife_deploy1.wav"))
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/screwdriver_draw.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
	}
	else if(!get_bit(g_PlayerChain, id) && !get_bit(g_PlayerScrewdriver, id) && get_bit(g_PlayerClutches, id) && is_user_alive(id) && equal(sample[8], "kni", 3))
	{
		volume = 0.6;
		
		if (equal(sample[14], "sla", 3))
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/dragontail_stab1.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
		if(equal(sample,"weapons/knife_deploy1.wav"))
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/dragontail_draw.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
		if (equal(sample[14], "hit", 3))
		{
			if (sample[17] == 'w') 
			{
				engfunc(EngFunc_EmitSound, id, channel,"weapons/dragontail_stab1.wav", volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
			else 
			{
				engfunc(EngFunc_EmitSound, id, channel, "weapons/dragontail_stab2.wav", volume, attn, flags, pitch);
				return FMRES_SUPERCEDE;
			}
		}
		if (equal(sample[14], "sta", 3)) 
		{
			engfunc(EngFunc_EmitSound, id, channel, "weapons/dragontail_stab2.wav", volume, attn, flags, pitch);
			return FMRES_SUPERCEDE;
		}
	}
	return FMRES_IGNORED
}

public voice_listening(receiver, sender, bool:listen)
{
	if((receiver == sender))
		return FMRES_IGNORED

	if(is_user_admin(sender))
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, true)
		return FMRES_SUPERCEDE
	}
	if(!is_user_alive(sender))
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, false)
		return FMRES_SUPERCEDE
	}
	if(cs_get_user_team(sender) == CS_TEAM_CT)
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, true)
		return FMRES_SUPERCEDE
	}
	if(cs_get_user_team(sender) == CS_TEAM_T && get_bit(g_PlayerVoice, sender))
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, true)
		return FMRES_SUPERCEDE
	}
	if(cs_get_user_team(sender) == CS_TEAM_T && !get_bit(g_PlayerVoice, sender))
	{
		engfunc(EngFunc_SetClientListening, receiver, sender, false)
		return FMRES_SUPERCEDE
	}
	engfunc(EngFunc_SetClientListening, receiver, sender, false)
	return FMRES_SUPERCEDE
}

public player_cmdstart(id, uc, random)
{
	if(g_Duel > 3 && !g_DuelOptions[1])
	{
		if(g_DuelOptions[0])
		{
			if(g_Duel == 4)
			{
				cs_set_user_bpammo(id, CSW_DEAGLE, 1)
			}
			else if(g_Duel == 5)
			{
				cs_set_user_bpammo(id, CSW_SG550, 1)
			}
			else if(g_Duel == 6)
			{
				cs_set_user_bpammo(id, CSW_P228, 1)
			}
			else if(g_Duel == 7)
			{
				cs_set_user_bpammo(id, CSW_AUG, 1)
			}
		}
		else
		{
			cs_set_user_bpammo(id, _Duel[g_Duel - 4][_csw], 1)
		}
	}
}

public Fw_SetModel(entity, const model[])
{
	if(g_Gameday)
	{
		RemoveItems(entity)
	}
}

public fw_AddToFullPack(es, e, ent, host)
{
	if(!g_Duel && g_DuelA && g_DuelB)
	{
		return
	}
	static i
	for(i = 1; i <= MAXPLAYERS; i++)
		if(g_lifebar[i] == ent)
		{				
			if(!is_user_connected(i) || !is_user_alive(i) || i == host || (i != g_DuelA && i != g_DuelB))
				return
				
			static Float: fOrigin[3]
			pev(i, pev_origin, fOrigin)						
			fOrigin[2] += 37.0
			set_es(es, ES_AimEnt, 0)
			set_es(es, ES_Origin, fOrigin)
			set_es(es, ES_RenderAmt, 255.0)
		}
}

public round_first()
{
	g_JailDay = 0
	g_Days = 0
	for(new i = 1; i <= MAXPLAYERS; i++)
		g_PlayerSimon[i] = 0

	set_cvar_num("sv_alltalk", 1)
	set_cvar_num("mp_roundtime", 2)
	set_cvar_num("mp_limitteams", 0)
	set_cvar_num("mp_autoteambalance", 0)
	set_cvar_num("mp_tkpunish", 0)
	set_cvar_num("mp_friendlyfire", 1)
	round_end()
}

public round_end()
{
	clear_bit(g_PlayerFreeday, 0) 
	who_fd()
	set_lights("#OFF")
	g_GameNow = 0
	new iPlayer
	g_bMigraineux = 0
	g_iGlobalState = None
	CheckForward()
	ClearUserReversed(iPlayer)
	for(new i; i<sizeof(g_vecPunchAngles); i++)
	{
	g_vecPunchAngles[iPlayer][0] = 0.0
	g_vecPunchAngles[iPlayer][1] = 0.0
	}
	
	for(new i = 0; i <= MAXPLAYERS; i++)
	{
		remove_task( i , _ );
		if(is_user_alive(i)) strip_user_weapons(i)	
		g_Usevip[i] = 0
		g_UserSpeed[i] = 0
	}

	static CsTeams:team
	static maxnosimon
	g_PlayerRevolt = 0
	g_PlayerLast = 0
	g_PlayerFreeday = 0
	g_BoxStarted = 0
	g_BoxClassic = 0
	g_Simon = 0
	g_SimonAllowed = 0
	g_RoundStarted = 0
	g_LastDenied = 0
	g_BlockWeapons = 0
	g_Freeday = 0
	g_Gameday = 0
	g_RoundEnd = 1
	g_Duel = 0
	g_DuelA = 0
	g_DuelB = 0
	g_Votes[0] = 0
	g_Votes[1] = 0
	g_Votes[2] = 0
	g_Votes[3] = 0
	g_Votes[4] = 0
	g_Votes[5] = 0
	g_GameEng = 0
	
	remove_task(TASK_STATUS)
	remove_task(TASK_FREEDAY)
	remove_task(TASK_FREEEND)
	maxnosimon = get_pcvar_num(gp_NosimonRounds)
	for(new i = 1; i <= MAXPLAYERS; i++)
	{
		if(!is_user_connected(i))
			continue

		menu_cancel(i)
		team = cs_get_user_team(i)
		player_strip_weapons(i)
		switch(team)
		{
			case(CS_TEAM_CT):
			{
				if(g_PlayerSimon[i] > maxnosimon)
				{
					cmd_nomic(i)
				}
			}
		}
	}
	for(new i = 0; i < sizeof(g_HudSync); i++)
		ClearSyncHud(0, g_HudSync[i][_hudsync])

}

public round_start()
{
	if(g_RoundEnd)
		return
		
	g_NowOneFd = 0
	Count_Players()
	who_simon()
	who_fd()
	
	if(g_Days == 1)
	{
		g_NowDay = "понедельник";
	}
	else if(g_Days == 2)
	{
		g_NowDay = "вторник";
	}
	else if(g_Days == 3)
	{
		g_NowDay = "среда";
	}
	else if(g_Days == 4)
	{
		g_NowDay = "четверг";
	}
	else if(g_Days == 5)
	{
		g_NowDay = "пятница";
	}
	else if(g_Days == 6)
	{
		if(g_Gamenum)
		{
			g_Gamenum = 0
		}
		else
		{
			g_Gamenum = 1
		}
		g_NowDay = "суббота";
		g_Gameday = 1
		StartVote()
		set_task(HUD_DELAY, "hud_status", TASK_STATUS, _, _, "b")
	}
	else if(g_Days == 7)
	{
		g_NowDay = "воскресенье";
		g_Freeday = 1
		emit_sound(0, CHAN_AUTO, "jbextreme/brass_bell_C.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		check_freeday(TASK_FREEDAY)
	}
	
	if(!g_Simon && is_freeday() && !g_Freeday)
	{
		g_Freeday = 1
		emit_sound(0, CHAN_AUTO, "jbextreme/brass_bell_C.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		check_freeday(TASK_FREEDAY)
	}
	else
	{
		set_task(60.0, "check_freeday", TASK_FREEDAY)
	}
	if(g_Days != 6)
	{
		set_task(HUD_DELAY, "hud_status", TASK_STATUS, _, _, "b")
		g_FreedayTime = 180
		set_task(1.0, "freeday_check")
	}
	g_SimonAllowed = 1
	g_DuelOptions[0] = 0
	g_DuelOptions[1] = 0
	g_DuelOptions[2] = 0
	g_DuelOptions[3] = 1
	set_task(3.1, "Count_Players2", 75955642, _, _, "b")
}

public StartVote()
{
	g_DayType = "Голосование игр";
	g_VoteMenu = menu_create("\rВыбирете игру:", "menu_handler")
	if(g_Gamenum)
	{
		menu_additem(g_VoteMenu, "День зомби", "0", 0)
		menu_additem(g_VoteMenu, "День пряток", "1", 0)
		menu_additem(g_VoteMenu, "День приведений", "2", 0)
		menu_additem(g_VoteMenu, "День пришельца", "3", 0)
		menu_additem(g_VoteMenu, "День чай-чай", "4", 0)
		menu_additem(g_VoteMenu, "День алкоголиков", "5", 0)
	}
	else
	{
		menu_additem(g_VoteMenu, "День Трол-гоприков", "0", 0)
		menu_additem(g_VoteMenu, "День снежков", "1", 0)
		menu_additem(g_VoteMenu, "День мяса", "2", 0)
		menu_additem(g_VoteMenu, "День подрывателей", "3", 0)
		menu_additem(g_VoteMenu, "День чай-чай", "4", 0)
		menu_additem(g_VoteMenu, "День вышибал", "5", 0)
	}        
	new s_Players[32], i_Num, i_Player
	get_players(s_Players, i_Num)

	for (new i; i < i_Num; i++)
	{
		i_Player = s_Players[i]

		menu_display(i_Player, g_VoteMenu, 0)

		// Увеличиваем, чтобы узнать сколько игроков голосуют
		g_Voting++
	}
	ScreenFade()
	Blockmoveall() 
	g_GameEng = 10
    // Останавливаем голосование через 10 секунд
    set_task(1.0, "TaskEndVote")

    return PLUGIN_HANDLED
}

public TaskEndVote()
{
	if(!g_GameEng)
	{
		EndVote()
	}
	else
	{
		set_task(0.6, "TaskEndVote")
	}
}
     
public menu_handler(id, menu, item)
{
    if (item == MENU_EXIT)
        return PLUGIN_HANDLED

    new s_Data[6], s_Name[64], i_Access, i_Callback
    menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)

    // Полчаем информацию о том, какая опция была выбрана
    new i_Vote = str_to_num(s_Data)

    // Увеличиваем количество голосов по данной опции
    g_Votes[i_Vote]++

return PLUGIN_HANDLED
}
     
public EndVote()
{
	jail_open()
	DelScreenFade()
	Unblockmoveall() 
	g_Gameday = 1
    // Если первая опция набрала больше голосов, чем вторая
    if (g_Votes[0] > g_Votes[1] && g_Votes[0] > g_Votes[2] && g_Votes[0] > g_Votes[3] && g_Votes[0] > g_Votes[4] && g_Votes[0] > g_Votes[5])
	{
		if(g_Gamenum)
		{
			set_task(1.0,"started1")
			g_GameNow = 1
			g_DayType = "День зомби";
		}
		else
		{
			set_task(1.0,"started7")
			g_GameNow = 7
			g_DayType = "День Трол-гопников";
		}
	}
	else if (g_Votes[1] > g_Votes[0] && g_Votes[1] > g_Votes[2] && g_Votes[1] > g_Votes[3] && g_Votes[1] > g_Votes[4] && g_Votes[1] > g_Votes[5])
	{
		if(g_Gamenum)
		{
			set_task(1.0,"started2")
			g_GameNow = 2
			g_DayType = "День пряток";
		}
		else
		{
			jb_game_snowballs()
			g_GameNow = 8
			g_DayType = "День снежков";
		}
	}
	else if (g_Votes[2] > g_Votes[0] && g_Votes[2] > g_Votes[1] && g_Votes[2] > g_Votes[3] && g_Votes[2] > g_Votes[4] && g_Votes[2] > g_Votes[5])
	{
		if(g_Gamenum)
		{
			set_task(1.0,"started3")
			g_GameNow = 3
			g_DayType = "День приведений";
		}
		else
		{
			set_task(1.0,"started9")
			g_GameNow = 9
			g_DayType = "День мяса";
		}
	}
	else if (g_Votes[3] > g_Votes[0] && g_Votes[3] > g_Votes[2] && g_Votes[3] > g_Votes[1] && g_Votes[3] > g_Votes[4] && g_Votes[3] > g_Votes[5])
	{
		if(g_Gamenum)
		{
			set_task(1.0,"started4")
			g_GameNow = 4
			g_DayType = "День пришельца";
		}
		else
		{
			jb_game_hemod()
			g_GameNow = 10
			g_DayType = "Подрывателей";
		}
	}
	else if (g_Votes[4] > g_Votes[0] && g_Votes[4] > g_Votes[2] && g_Votes[4] > g_Votes[3] && g_Votes[4] > g_Votes[1] && g_Votes[4] > g_Votes[5])
	{
		if(g_Gamenum)
		{
			jb_game_chay()
			g_GameNow = 5
			g_DayType = "День чай-чай";
		}
		else
		{
			jb_game_chay()
			g_GameNow = 5
			g_DayType = "День чай-чай";
		}
	}
	else if (g_Votes[5] > g_Votes[0] && g_Votes[5] > g_Votes[2] && g_Votes[5] > g_Votes[3] && g_Votes[5] > g_Votes[4] && g_Votes[5] > g_Votes[1])
	{
		if(g_Gamenum)
		{
			set_task(1.0,"started6")
			g_GameNow = 6
			g_DayType = "День алкашей";
		}
		else
		{
			jb_game_killball()
			g_GameNow = 12
			g_DayType = "День вышибал";
		}
	}
	else
	{
		g_Votes[0] = random_num(0, 999)
		g_Votes[1] = random_num(0, 999)
		g_Votes[2] = random_num(0, 999)
		g_Votes[3] = random_num(0, 999)
		g_Votes[4] = random_num(0, 999)
		g_Votes[5] = random_num(0, 999)
		EndVote()
	}
	
	g_GameEng = 200

    // Сбрасываем информацию о том, что игроки голосуют
    g_Voting = 0
} 

public ScreenFade() {
	message_begin(MSG_ALL, g_msgScreenFade, _, 0)
	write_short(1<<0)
	write_short(1<<0)
	write_short(1<<2)
	write_byte(0)
	write_byte(0)
	write_byte(0)
	write_byte(255)
	message_end()
}

public DelScreenFade() 
{
	message_begin(MSG_ALL, g_msgScreenFade, _, 0)
	write_short(1<<0)
	write_short(1<<0)
	write_short(1<<0)
	write_byte(0)
	write_byte(0)
	write_byte(0)
	write_byte(0)
	message_end()
}

public Blockmove(id) 
{
	set_pev(id, pev_flags, pev(id, pev_flags) | FL_FROZEN)
}

public Blockmoveall() 
{
	for(new i = 0; i <= MAXPLAYERS; i++)
	{
		if(is_user_connected(i) && is_user_alive(i))
		{
			set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN)
		}
	}
}

public Unblockmove(id) 
{
	set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN)
}

public Unblockmoveall() 
{
	for(new i = 0; i <= MAXPLAYERS; i++)
	{
		if(is_user_connected(i) && is_user_alive(i))
		{
			set_pev(i, pev_flags, pev(i, pev_flags) & ~FL_FROZEN)
		}
	}
}

public started1()
{
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
			
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
		{	
				give_item( i, "weapon_m3" );
				give_item( i, "weapon_knife")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				give_item( i, "ammo_buckshot")
				set_user_health(i,200)
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
			{
				give_item( i, "weapon_knife" );
				set_user_health(i,1100)
				entity_set_int(i, EV_INT_body, 3)
				cs_set_user_nvg (i,true);
			}
		}
	}
	set_lights("b")
}

public started2()
{
	for (new i = 0; i <= MAXPLAYERS; i++)
	{
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
		{
			strip_user_weapons(i)	
			set_user_godmode(i,1)
			give_item( i, "weapon_m3" );
			give_item( i, "weapon_knife")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "ammo_buckshot")
			give_item( i, "weapon_knife" )
			Blockmove(i)
		}
		else if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
		{
			strip_user_weapons(i)
			give_item( i, "weapon_knife" )
			g_Teleport[i] = 3
		}
	}
	set_lights("c")
	sec_game2 = 30
	countdown_game2()
	set_task(30.0, "Unblockmoveall")
}

public countdown_game2()
{   	
	set_dhudmessage(0, 255, 0, -1.0, 0.28, 2, 0.02, 1.0, 0.01, 10.0, false); 
	show_dhudmessage(0, "Охрана идет искать через %i сек",sec_game2);
	
	sec_game2 -= 1
	
	if(sec_game2 >= 1)
	{
		set_task(1.0, "countdown_game2")
	}
	else
	{
		for (new i = 0; i <= MAXPLAYERS; i++)
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
			{
				set_user_godmode(i,0)
			}
		}
	}
} 

public started3()
{
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
			
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
		{
			give_item( i, "weapon_knife" );
			set_user_noclip(i, 1)
			set_user_health(i,250)
			set_user_info(i, "model", "we_mob_jb2")
			entity_set_int(i, EV_INT_body, 1)
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
			{
				give_item( i, "weapon_m249" );
               	cs_set_user_bpammo( i, CSW_M249, 500);
				set_user_health(i,150)
			}
		}
	}
}

public started4()
{
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
			
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
		{
			strip_user_weapons(i)
            set_user_gravity( i, 0.5)
			set_user_health(i,200)
			entity_set_int(i, EV_INT_body, 5)
        	set_user_rendering(i,kRenderFxGlowShell,0,0,0,kRenderTransAlpha,0)
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
			{
				strip_user_weapons(i)
				give_item( i, "weapon_m4a1" );
                cs_set_user_bpammo( i, CSW_M4A1, 180);
				set_user_health(i,100)
				give_item( i, "weapon_knife" )
			}
		}
		g_Giveditem = 0
		set_task(1.0, "check_weapon4", i, _, _, "b");
		sec_game4 = 15
		set_task(1.0, "countdown_game4")
	}
}

public check_weapon4(id)
{
	if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT && get_user_weapon(id) != CSW_KNIFE) 
	{
		strip_user_weapons(id)
		if(g_Giveditem)
		{
			give_item( id, "weapon_knife" )
		}
	}
}

public Giveinviz(attacker)
{
	set_user_rendering(attacker,kRenderFxGlowShell,0,0,0,kRenderTransAlpha,0)
}

public Giveitem()
{	
	for(new i = 0; i <= MAXPLAYERS; i++)
	{
		if(is_user_connected(i) && is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
		{
			g_Giveditem = 1	
			give_item(i, "weapon_knife")
			set_bit(g_PlayerCrowbar, i)
		}
	}
}

public countdown_game4()
{   	
	if(sec_game4)
	{	
		set_dhudmessage(255, 106, 0, -1.0, 0.28, 2, 0.02, 1.0, 0.01, 10.0, false); 
		show_dhudmessage(0, "Алиен начнет убийства через %i сек", sec_game4);
		sec_game4 -= 1
		set_task(1.0, "countdown_game4")
	}
	else
	{
		set_dhudmessage(255, 255, 255, -1.0, 0.28, 2, 0.02, 1.0, 0.01, 10.0, false); 
		show_dhudmessage(0, "Алиен идет за кровью!");
		Giveitem()
	}
} 

public started6()
{
	g_iGlobalState = Terrorists
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
			
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
		{
			give_item( i, "weapon_knife" );
			set_user_health(i,120)
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
			{
				give_item( i, "weapon_knife" );
				SetUserReversed(i)
				g_vecPunchAngles[i][0] = 0.0
				g_vecPunchAngles[i][1] = 0.0
			}
		}
	}
		CheckForward()
}

public started7()
{
	g_iGlobalState = Terrorists
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
			
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
		{
			give_item( i, "weapon_knife" );
			set_user_health(i,500)
			set_user_info(i, "model", "we_mob_jb1")
			new g_body = random_num(5, 6)
			entity_set_int(i, EV_INT_body, g_body)
			if(g_body == 5)
			{
				set_bit(g_PlayerBat, i)
				set_pev(i, pev_viewmodel2, _BatModels[1])
				set_pev(i, pev_weaponmodel2, _BatModels[0])
			}
			else
			{
				set_bit(g_PlayerScrewdriver, i)
				set_pev(i, pev_viewmodel2, _ScrewdriverModels[1])
				set_pev(i, pev_weaponmodel2, _ScrewdriverModels[0])
			}
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
			{
				give_item( i, "weapon_knife" );
				give_item( i, "weapon_m4a1" );
				cs_set_user_bpammo( i, CSW_M4A1, 500);
			}
		}
	}
		CheckForward()
}

public started9()
{
	g_iGlobalState = Terrorists
    for(new i = 0; i <= MAXPLAYERS; i++)
    {
		if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T) 
		{
			give_item( i, "weapon_knife" );
			set_user_health(i,400)
			set_user_info(i, "model", "we_mob_jb1")
			entity_set_int(i, EV_INT_body, 4)
			set_bit(g_PlayerChain, i)
			set_pev(i, pev_viewmodel2, g_chain_viewmodel)
			set_pev(i, pev_weaponmodel2, g_chain_weaponmodel)
		}
		else
		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT) 
			{
				give_item( i, "weapon_knife" );
				give_item( i, "weapon_m249" );
               	cs_set_user_bpammo( i, CSW_M249, 500);
				set_user_health(i,200)
			}
		}
	}
	CheckForward()
}

public PlayerPreThink( id )
{
	if(HasUserMigraine(id) && is_user_alive(id))
	{
		if( g_vecPunchAngles[id][1] < 180.0 )
		{
			g_vecPunchAngles[id][1] += 2.0
			g_vecPunchAngles[id][0] = g_vecPunchAngles[id][1] * 2.0
		}
		else
		{
			g_vecPunchAngles[id][0] = 0.0
		}

		static Float:vecPunchAngle[3]
		vecPunchAngle[0] = g_vecPunchAngles[id][0]
		vecPunchAngle[1] = g_vecPunchAngles[id][0]
		vecPunchAngle[2] = g_vecPunchAngles[id][1]

		set_pev(id, pev_punchangle, vecPunchAngle)
	}
}

CheckForward()
{
	if( !g_bMigraineux != !g_iFfPlayerPreThink )
	{
		if( g_bMigraineux )
		{
			g_iFfPlayerPreThink = register_forward(FM_PlayerPreThink, "PlayerPreThink")
		}
		else
		{
			unregister_forward(FM_PlayerPreThink, g_iFfPlayerPreThink)
			g_iFfPlayerPreThink = 0
		}
	}
}

public cmd_voiceon(id)
{
	client_cmd(id, "+voicerecord")
	set_bit(g_SimonVoice, id)
	if(g_Simon == id || is_user_admin(id))
		set_bit(g_SimonTalking, id)

	return PLUGIN_HANDLED
}

public cmd_voiceoff(id)
{
	client_cmd(id, "-voicerecord")
	clear_bit(g_SimonVoice, id)
	if(g_Simon == id || is_user_admin(id))
		clear_bit(g_SimonTalking, id)

	return PLUGIN_HANDLED
}

public cmd_simon(id)
{
	static CsTeams:team
	if(!is_user_connected(id))
		return PLUGIN_HANDLED

	team = cs_get_user_team(id)
	if(g_SimonAllowed && !g_Freeday && is_user_alive(id) && team == CS_TEAM_CT && !g_Simon)
	{
		g_Simon = id
		who_simon()
		set_user_info(id, "model", "we_mob_jb2")
		entity_set_int(id, EV_INT_body, 3)
		g_PlayerSimon[id]--

		hud_status(0)
	}
	return PLUGIN_HANDLED
}

public cmd_open(id)
{
	if(id == g_Simon || g_Gameday || g_Freeday || g_PlayerLast)
		jail_open()
	return PLUGIN_HANDLED
}

public cmd_nomic(id)
{
	static CsTeams:team
	team = cs_get_user_team(id)
	if(team == CS_TEAM_CT)
	{
		server_print("JBE Transfered guard to prisoners team client #%i", id)
		if(g_Simon == id)
		{
			g_Simon = 0
			player_hudmessage(0, 2, 5.0, _, "%L", LANG_SERVER, "JBE_SIMON_TRANSFERED")
		}
		if(!is_user_admin(id))
			set_bit(g_PlayerNomic, id)

		user_silentkill(id)
		cs_set_user_team(id, CS_TEAM_T)
	}
	return PLUGIN_HANDLED
}

public cmd_box(id)
{
	if(!g_Gameday)
	{
		if(g_BoxStarted)
		{
			cmd_offbox(id)
		}
		else if(!g_BoxStarted)
		{
			cmd_onbox(id)
		}
	}
}

public cmd_onbox(id)
{
	static i
	if((id < 0) || (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT))
	{
			for(i = 1; i <= MAXPLAYERS; i++)
				if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
					set_user_health(i, 100)

			set_cvar_num("mp_tkpunish", 0)
			set_cvar_num("mp_friendlyfire", 1)
			g_BoxStarted = 1
			player_hudmessage(0, 1, 3.0, _, "%L", LANG_SERVER, "JBE_GUARD_BOX")
	}
	return PLUGIN_HANDLED
}

public cmd_offbox(id)
{
	static i
	if((id < 0) || (is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT))
	{
			for(i = 1; i <= MAXPLAYERS; i++)
				if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
					set_user_health(i, 100)

			set_cvar_num("mp_tkpunish", 0)
			set_cvar_num("mp_friendlyfire", 0)
			g_BoxStarted = 0
			player_hudmessage(0, 1, 3.0, _, "%L", LANG_SERVER, "JBE_GUARD_OFFBOX")
	}
	return PLUGIN_HANDLED
}

public cmd_freeday(id)
{
	static menu, menuname[32], option[64]
	if(!is_freeday() && ((is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT) || is_user_admin(id)))
	{
		formatex(menuname, charsmax(menuname), "%L", LANG_SERVER, "JBE_MENU_FREEDAY")
		menu = menu_create(menuname, "freeday_choice")

		formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_FREEDAY_PLAYER")
		menu_additem(menu, option, "1", 0)

		formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_FREEDAY_ALL")
		menu_additem(menu, option, "2", 0)

		menu_display(id, menu)
	}
	return PLUGIN_HANDLED
}

public cmd_freeday_player(id)
{
	if((is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT) || is_user_admin(id))
		menu_players(id, CS_TEAM_T, id, 1, "freeday_select", "%L", LANG_SERVER, "JBE_MENU_FREEDAY")

	return PLUGIN_CONTINUE
}

public cmd_lastrequest(id)
{
	static menu, menuname[32], option[64]
	if(g_Gameday || g_LastDenied || id != g_PlayerLast || g_RoundEnd || !is_user_alive(id) || g_Duel)
		return PLUGIN_CONTINUE

	formatex(menuname, charsmax(menuname), "%L", LANG_SERVER, "JBE_MENU_LASTREQ")
	menu = menu_create(menuname, "lastrequest_select")

	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT1")
	menu_additem(menu, option, "1", 0)

	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT2")
	menu_additem(menu, option, "2", 0)
	
	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT3")
	menu_additem(menu, option, "3", 0)

	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT4")
	menu_additem(menu, option, "4", 0)
	
	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT5")
	menu_additem(menu, option, "5", 0)
	
	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT6")
	menu_additem(menu, option, "6", 0)
	
	formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_MENU_LASTREQ_OPT7")
	menu_additem(menu, option, "7", 0)
	
	menu_display(id, menu)
	return PLUGIN_CONTINUE
}

public adm_freeday(id)
{
	static player, user[32]
	if(!is_user_admin(id))
		return PLUGIN_CONTINUE

	read_argv(1, user, charsmax(user))
	player = cmd_target(id, user, 2)
	if(is_user_connected(player) && cs_get_user_team(player) == CS_TEAM_T)
	{
		freeday_set(id, player)
	}
	return PLUGIN_HANDLED
}

public adm_nomic(id)
{
	static player, user[32]
	if(id == 0 || is_user_admin(id))
	{
		read_argv(1, user, charsmax(user))
		player = cmd_target(id, user, 3)
		if(is_user_connected(player))
		{
			cmd_nomic(player)
		}
	}
	return PLUGIN_HANDLED
}

public adm_open(id)
{
	if(!is_user_admin(id))
		return PLUGIN_CONTINUE

	jail_open()
	return PLUGIN_HANDLED
}

public adm_box(id)
{
	if(!is_user_admin(id))
		return PLUGIN_CONTINUE

	cmd_box(-1)
	return PLUGIN_HANDLED
}

public team_select(id, key)
{
	Count_Players()
}

public Count_Players2()
{
	g_Userta = 0
	g_Usercta = 0
	for(new i = 1; i <= MAXPLAYERS; i++)
	{
		if(is_user_connected(i))
		{
			if(cs_get_user_team(i) == CS_TEAM_T)
			{
				g_Userta++
			}
			else if(cs_get_user_team(i) == CS_TEAM_CT)
			{
				g_Usercta++
			}
		}
	}
}

public Count_Players()
{
	g_Usert = 0
	g_Userta = 0
	g_Userct = 0
	g_Usercta = 0
	
	for(new i = 1; i <= MAXPLAYERS; i++)
	{
		if(is_user_connected(i))
		{
			if(cs_get_user_team(i) == CS_TEAM_T)
			{
				g_Userta++
				if(is_user_alive(i))
				{
					g_Usert++
				}
			}
			else if(cs_get_user_team(i) == CS_TEAM_CT)
			{
				g_Usercta++
				if(is_user_alive(i))
				{
					g_Userct++
				}
			}
		}
	}
	
	if(g_Usert != 1)
	{
		if(g_Duel || g_DuelA || g_DuelB)
		{
			if(is_user_alive(g_DuelA))
			{
				set_user_rendering(g_DuelA, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
				player_strip_weapons(g_DuelA)
			}

			if(is_user_alive(g_DuelB))
			{
				set_user_rendering(g_DuelB, kRenderFxNone, 0, 0, 0, kRenderNormal, 0)
				player_strip_weapons(g_DuelB)
			}

		}
		g_PlayerLast = 0
		Kill_Trail(g_DuelA)
		Kill_Trail(g_DuelB)
		g_DuelA = 0
		g_YouShot = 0
		g_YouShotTime = 0
		g_DuelB = 0
		g_Duel = 0
	}
	else if(!g_Gameday && !g_PlayerLast)
	{
		if(g_Usert == 1)
		{
			for(new i = 1; i <= MAXPLAYERS; i++)
			{
				if(is_user_connected(i) && is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T )
				{
					g_PlayerLast = i
					cmd_lastrequest(i)
				}
			}
		}
	}
}

public who_simon()
{
	if(g_Simon)
	{
		get_user_name(g_Simon, namesimon, charsmax(namesimon))
	}
	else
	{
		namesimon = "не выбран";
	}
}

public who_fd()
{
	g_NowOneFd = 0
	arrayset(wanted,0,1024)
	if(!g_Freeday && g_PlayerFreeday)
	{
		new n
		new name2[32]
		n = 0
		n = strlen(wanted)
		for(new i = 0; i < MAXPLAYERS; i++)
		{
			if(get_bit(g_PlayerFreeday, i) && is_user_connected(i) && is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
			{
				get_user_name(i, name2, charsmax(name2))
				n += copy(wanted[n], charsmax(wanted) - n, "^n^t")
				n += copy(wanted[n], charsmax(wanted) - n, name2)
				g_NowOneFd++
			}
		}
	}
}

public hud_status(task)
{ 
	if(g_RoundStarted < (get_pcvar_num(gp_RetryTime) / 2))
		g_RoundStarted++

		
	if(!g_Gameday && !g_PlayerLast)
	{		
		if(!g_Freeday)
		{
			g_DayType = "обычный";
		}
		else
		{
			formatex(g_DayType, 31, "свободный [%i]",g_FreedayTime);
		}

		if(g_Freeday || !g_PlayerFreeday)
		{
			set_hudmessage(200, 200, 15, 0.05, 0.15, 0, 6.0, 3.0)
			show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL1", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType) 
		}
		if(g_PlayerFreeday && g_NowOneFd)
		{
			set_hudmessage(200, 200, 15, 0.05, 0.15, 0, 6.0, 3.0)
			show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL1_2", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, g_NowOneFd, g_FreedayTime, wanted)
		}
	}
	else if(g_Gameday)
	{
		set_hudmessage(200, 200, 15, 0.05, 0.15, 0, 6.0, 3.0)
		show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL2", g_JailDay, g_NowDay, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, g_GameEng)
		
		if(g_GameEng)
		{
			g_GameEng--
		}
		else
		{
			for(new i = 1; i <= MAXPLAYERS; i++)
			{
				if(is_user_connected(i) && is_user_alive(i))
				{
					if(((g_GameNow == 1 || g_GameNow == 6 || g_GameNow == 7 || g_GameNow == 8 || g_GameNow == 9 || g_GameNow == 10) && cs_get_user_team(i) == CS_TEAM_T) || (!g_Usert && cs_get_user_team(i) == CS_TEAM_CT))
					{
						user_silentkill(i)
					}
					if(((g_GameNow == 2 || g_GameNow == 3 || g_GameNow == 4 || g_GameNow == 5 || g_GameNow == 11 || g_GameNow == 12) && cs_get_user_team(i) == CS_TEAM_CT) || (!g_Usert && cs_get_user_team(i) == CS_TEAM_CT))
					{
						user_silentkill(i)
					}
				}
			}
		}
	}
	else if(!g_Gameday && g_PlayerLast)
	{
		if(g_Duel > 2 && g_DuelA && g_DuelB)
		{
			//g_DayType = "дуэль";
			new nameA[32]
			new nameB[32]
			get_user_name(g_DuelA, nameA, charsmax(nameA))
			get_user_name(g_DuelB, nameB, charsmax(nameB))
			set_hudmessage(200, 200, 15, 0.05, 0.15, 0, 6.0, 3.0)
			if(!g_DuelOptions[1])
			{
				show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL4_1", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, nameA, get_user_health(g_DuelA), nameB, get_user_health(g_DuelB))
			}
			else
			{
				if(g_YouShot == g_DuelA)
				{
					show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL4_2", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, nameA, get_user_health(g_DuelA), g_YouShotTime, nameB, get_user_health(g_DuelB))
				}
				if(g_YouShot == g_DuelB)
				{
					show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL4_3", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, nameA, get_user_health(g_DuelA), nameB, get_user_health(g_DuelB), g_YouShotTime)
				}
				g_YouShotTime--
				if(!g_YouShotTime)
				{
					if(g_YouShot == g_DuelA)
					{
						fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelB, 373), 1)
						fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelA, 373), 0)
						g_YouShot = g_DuelB
					}
					else if(g_YouShot == g_DuelB)
					{
						fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelA, 373), 1)
						fm_cs_set_weapon_ammo(get_pdata_cbase(g_DuelB, 373), 0)
						g_YouShot = g_DuelA
					}
					g_YouShotTime = 15
				}
			}
		}
		if(!g_DuelA || !g_DuelB)
		{
			if(g_Duel != 2)
			{
				g_DayType = "последний зек";
			}
			else
			{
				g_DayType = "месть зека";
			}
			new name2[32]
			get_user_name(g_PlayerLast, name2, charsmax(name2))
			set_hudmessage(200, 200, 15, 0.05, 0.15, 0, 6.0, 3.0)
			show_hudmessage(0, "%L", LANG_SERVER, "JBE_STATUS_ALL3", g_JailDay, g_NowDay, namesimon, g_Userct, g_Usercta, g_Usert, g_Userta, g_DayType, name2)
		}
	}
	
	gc_ButtonShoot = get_pcvar_num(gp_ButtonShoot)

}

public check_freeday(task)
{
	static Float:roundmax, i
	if(!g_Simon && !g_PlayerLast && !g_Gameday)
	{
		make_troll()
		g_Freeday = 1
		hud_status(0)
		roundmax = get_pcvar_float(gp_RoundMax)
		if(roundmax > 0.0)
		{
			for(i = 1; i <= MAXPLAYERS; i++)
			{
				if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
				{
					freeday_set(0, i)
				}
			}
			emit_sound(0, CHAN_AUTO, "jbextreme/brass_bell_C.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			player_hudmessage(0, 8, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_STATUS_ENDTIMER", floatround(roundmax - 60.0))
		}
	}
	jail_open()
}

public freeday_end()
{
	if((g_Freeday || g_PlayerFreeday) && !g_Gameday)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/brass_bell_C.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		player_hudmessage(0, 8, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_STATUS_ENDFREEDAY")
		for(new i = 0; i <= MAXPLAYERS; i++)
   		{
			if (is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T && !get_bit(g_PlayerRevolt, i)) 
			{
				if(g_Freeday || get_bit(g_PlayerFreeday, i))
				{
					set_user_info(i, "model", "we_mob_jb1")
					entity_set_int(i, EV_INT_body, 2)
					g_PlayerSkin[i] = random_num(0, 4)
					entity_set_int(i, EV_INT_skin, g_PlayerSkin[i])
				}
			}
		}
		g_Freeday = 0
		g_PlayerFreeday = 0
		who_fd()
	}
}

public freeday_check()
{
	g_FreedayTime--
	if(g_FreedayTime)
	{
		set_task(1.0, "freeday_check")
	}
	else if(g_Freeday || g_PlayerFreeday)
	{
		freeday_end()
	}
}

public prisoner_last(id)
{
	static name[32]
	if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T)
	{
		get_user_name(id, name, charsmax(name))
		g_PlayerLast = id
		player_hudmessage(0, 6, 5.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PRISONER_LAST", name)
		cmd_lastrequest(id)
	}
}

public freeday_select(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static dst[32], data[5], player, access, callback

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	player = str_to_num(data)
	freeday_set(id, player)
	hud_status(0)
	return PLUGIN_HANDLED
}

public Kill_Trail(id)
{
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(99); // TE_KILLBEAM
	write_short(id)
	message_end()
}

public duel_knives(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		g_LastDenied = 0
		g_Duel = 0
		g_DuelA = 0
		g_DuelB = 0
		return PLUGIN_HANDLED
	}

	static dst[32], data[5], access, callback, player, src[32]

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	get_user_name(id, src, charsmax(src))
	player = str_to_num(data)

	strip_user_weapons(id)
	strip_user_weapons(player)
	
	g_DuelA = id
	clear_bit(g_PlayerCrowbar, id)
	clear_bit(g_PlayerBat, id)
	clear_bit(g_PlayerChain, id)
	clear_bit(g_PlayerScrewdriver, id)
	clear_bit(g_PlayerClutches, id)
	set_user_godmode(id,0)
	player_strip_weapons(id)
	set_user_health(id, 100)

	g_DuelB = player
	player_strip_weapons(player)
	set_user_godmode(player,0)
	set_user_health(player, 100)
	
	if(g_DuelOptions[2] == 1)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 6)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb1")
		entity_set_int(player, EV_INT_body, 5)
	}
	else if(g_DuelOptions[2] == 2)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 4)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb1")
		entity_set_int(player, EV_INT_body, 3)
	}
	else if(g_DuelOptions[2] == 3)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 1)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb2")
		entity_set_int(player, EV_INT_body, 3)
	}
	else
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 2)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb2")
		entity_set_int(player, EV_INT_body, 3)
	}
	
	Kill_Trail(id)
	Kill_Trail(player)
	
	if(g_DuelOptions[3] == 1)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 50)
	}
	else if(g_DuelOptions[3] == 2)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 50)

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(id)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(255)
		write_byte(0)
		write_byte(0)
		write_byte(192)
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(player)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		write_byte(192)
		message_end()
	}
	else if(g_DuelOptions[3] == 3)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(id)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(255)
		write_byte(0)
		write_byte(0)
		write_byte(192)
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(player)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		write_byte(192)
		message_end()
	}
	else if(g_DuelOptions[3] == 0)
	{
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderFxNone, 0)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 0, kRenderFxNone, 0)
	}
	g_BlockWeapons = 1
	if(g_DuelOptions[0])
	{
		set_user_health(player, 1000)
		set_user_health(id, 1000)
		set_bit(g_PlayerClutches, player)
		set_bit(g_PlayerClutches, id)
	}
	return PLUGIN_HANDLED
}

public duel_guns(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		g_LastDenied = 0
		g_Duel = 0
		g_DuelA = 0
		g_DuelB = 0
		return PLUGIN_HANDLED
	}
	
	static gun, dst[32], data[5], access, callback, player, src[32]

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	get_user_name(id, src, charsmax(src))
	player = str_to_num(data)
	client_cmd(0, "mp3 play sound/jbextreme/Duel_Active.mp3"); 

	strip_user_weapons(id)
	strip_user_weapons(player)
	g_DuelA = id
	clear_bit(g_PlayerCrowbar, id)
	clear_bit(g_PlayerBat, id)
	clear_bit(g_PlayerChain, id)
	clear_bit(g_PlayerScrewdriver, id)
	clear_bit(g_PlayerClutches, id)
	player_strip_weapons(id)
	set_user_godmode(id,0)
	
	set_user_health(player, 100)
	set_user_health(id, 100)
	if(!g_DuelOptions[0])
	{
		if(!g_DuelOptions[1] || g_Duel == 6)
		{
			gun = give_item(id, _Duel[g_Duel - 4][_entname])
			cs_set_weapon_ammo(gun, 1)
			gun = give_item(player, _Duel[g_Duel - 4][_entname])
			cs_set_weapon_ammo(gun, 1)
			if(g_Duel == 4)
			{
				g_DayType = "дуэль на диглах [не честная]";
			}
			else if(g_Duel == 5)
			{
				g_DayType = "дуэль на мухах [не честная]";
			}
			else if(g_Duel == 6)
			{
				g_DayType = "дуэль на гренах [не честная]";
			}
			else if(g_Duel == 7)
			{
				g_DayType = "дуэль на авп [не честная]";
			}
		}
		else
		{
			g_YouShot = id
			g_YouShotTime = 15
			gun = give_item(id, _Duel[g_Duel - 4][_entname])
			cs_set_weapon_ammo(gun, 1)
			gun = give_item(player, _Duel[g_Duel - 4][_entname])
			cs_set_weapon_ammo(gun, 0)
			if(g_Duel == 4)
			{
				g_DayType = "дуэль на диглах [честная]";
			}
			else if(g_Duel == 5)
			{
				g_DayType = "дуэль на мухах [честная]";
			}
			else if(g_Duel == 7)
			{
				g_DayType = "дуэль на авп [честная]";
			}
		}
	}
	else
	{
		if(g_Duel == 4)
		{
			if(g_DuelOptions[1])
			{
				g_YouShot = id
				g_YouShotTime = 15
				g_DayType = "дуэль на анакондах [честная]";
			}
			else
			{
				g_DayType = "дуэль на анакондах [не честная]";
			}
			set_task(0.2, "giveana", id)
			set_task(0.2, "giveana", player)
		}
		else if(g_Duel == 5)
		{
			if(g_DuelOptions[1])
			{
				g_YouShot = id
				g_YouShotTime = 15
				g_DayType = "дуэль на vsk [честная]";
			}
			else
			{
				g_DayType = "дуэль на vsk [не честная]";
			}
			set_task(0.2, "givevsk", id)
			set_task(0.2, "givevsk", player)
		}
		else if(g_Duel == 6)
		{
			if(g_DuelOptions[1])
			{
				g_YouShot = id
				g_YouShotTime = 15
				g_DayType = "дуэль на m79 [честная]";
			}
			else
			{
				g_DayType = "дуэль на m79 [не честная]";
				give_item(id, "weapon_hegrenade")
				give_item(player, "weapon_hegrenade")
			}
			set_task(0.2, "givem79", id)
			set_task(0.2, "givem79", player)
			set_user_health(player, 300)
			set_user_health(id, 300)
		}
		else if(g_Duel == 7)
		{
			if(g_DuelOptions[1])
			{
				g_YouShot = id
				g_YouShotTime = 15
				g_DayType = "дуэль на плазмах [честная]";
			}
			else
			{
				g_DayType = "дуэль на плазмах [не честная]";
			}
			set_task(0.2, "giveele", id)
			set_task(0.2, "giveele", player)
		}
	}

	g_DuelB = player
	set_user_godmode(player,0)
	player_strip_weapons(player)

	if(g_DuelOptions[2] == 1)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 6)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb1")
		entity_set_int(player, EV_INT_body, 5)
	}
	else if(g_DuelOptions[2] == 2)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 4)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb1")
		entity_set_int(player, EV_INT_body, 3)
	}
	else if(g_DuelOptions[2] == 3)
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 1)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb2")
		entity_set_int(player, EV_INT_body, 3)
	}
	else
	{
		set_user_info(id, "model", "we_mob_jb1")
		entity_set_int(id, EV_INT_body, 2)
		g_PlayerSkin[id] = random_num(0, 4)
		entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
		set_user_info(player, "model", "we_mob_jb2")
		entity_set_int(player, EV_INT_body, 3)
	}
	
	Kill_Trail(id)
	Kill_Trail(player)
	
	if(g_DuelOptions[3] == 1)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 50)
	}
	else if(g_DuelOptions[3] == 2)
	{
		set_user_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 50)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 50)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(id)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(255)
		write_byte(0)
		write_byte(0)
		write_byte(192)
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(player)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		write_byte(192)
		message_end()
	}
	else if(g_DuelOptions[3] == 3)
	{	
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(id)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(255)
		write_byte(0)
		write_byte(0)
		write_byte(192)
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(player)
		write_short(smokeSpr)
		write_byte(10)
		write_byte(5)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		write_byte(192)
		message_end()
	}
	else if(g_DuelOptions[3] == 0)
	{
		set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderFxNone, 0)
		set_user_rendering(player, kRenderFxGlowShell, 0, 0, 0, kRenderFxNone, 0)
	}

	
	g_BlockWeapons = 1
	return PLUGIN_HANDLED
}

public giveweap(id)
{
	if(is_user_connected(id) && is_user_alive(id) && g_Duel)
	{
		strip_user_weapons(id)
		give_item(id, _Duel[g_Duel - 4][_entname])
		if(!g_DuelOptions[1])
		{
			fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
		}
		else
		{
			if(g_YouShot == id)
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			}
			else
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 0)
			}
			new wId = get_user_weapon(id)
			cs_set_user_bpammo(id,wId,0)
		}
	}
}

public giveana(id)
{
	if(is_user_connected(id) && is_user_alive(id) && g_Duel)
	{
		strip_user_weapons(id)
		give_weapon_anaconda(id, 1)
		if(!g_DuelOptions[1])
		{
			fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			cs_set_user_bpammo( id, CSW_DEAGLE, 1);
		}
		else
		{
			if(g_YouShot == id)
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			}
			else
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 0)
			}
			cs_set_user_bpammo( id, CSW_DEAGLE, 0);
		}
	}
}

public givem79(id)
{
	if(is_user_connected(id) && is_user_alive(id) && g_Duel)
	{
		strip_user_weapons(id)
		give_weapon_m79(id, 1)
		if(!g_DuelOptions[1])
		{
			fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			cs_set_user_bpammo( id, CSW_P228, 1);
		}
		else
		{
			if(g_YouShot == id)
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			}
			else
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 0)
			}
			cs_set_user_bpammo( id, CSW_P228, 0);
		}
	}
}

public giveele(id)
{
	if(is_user_connected(id) && is_user_alive(id) && g_Duel)
	{
		strip_user_weapons(id)
		give_weapon_ele(id, 1, 1)
		if(!g_DuelOptions[1])
		{
			fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			cs_set_user_bpammo( id, CSW_AUG, 1);
		}
		else
		{
			if(g_YouShot == id)
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			}
			else
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 0)
			}
			cs_set_user_bpammo( id, CSW_AUG, 0);
		}
	}
}

public givevsk(id)
{
	if(is_user_connected(id) && is_user_alive(id) && g_Duel)
	{
		strip_user_weapons(id)
		give_weapon_vsk(id, 1)
		if(!g_DuelOptions[1])
		{
			fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			cs_set_user_bpammo( id, CSW_SG550, 1);
		}
		else
		{
			if(g_YouShot == id)
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 1)
			}
			else
			{
				fm_cs_set_weapon_ammo(get_pdata_cbase(id, 373), 0)
			}
			cs_set_user_bpammo( id, CSW_SG550, 0);
		}
	}
}

public freeday_choice(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static dst[32], data[5], access, callback

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	menu_destroy(menu)
	get_user_name(id, dst, charsmax(dst))
	switch(data[0])
	{
		case('1'):
		{
			cmd_freeday_player(id)
		}
		case('2'):
		{
			if((id == g_Simon) || is_user_admin(id))
			{
				g_Simon = 0
				get_user_name(id, dst, charsmax(dst))
				client_print(0, print_console, "%s gives freeday for everyone", dst)
				server_print("JBE Client %i gives freeday for everyone", id)
				check_freeday(TASK_FREEDAY)
			}
		}
	}
	return PLUGIN_HANDLED
}

public lastrequest_select(id, menu, item)
{
	if (g_Duel)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static i, dst[32], data[5], access, callback, option[64]

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	get_user_name(id, dst, charsmax(dst))
	switch(data[0])
	{
		case('1'):
		{
			formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_SELECT_LASTREQ_SEL1", dst)
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, option)
			set_bit(g_FreedayAuto, id)
			user_silentkill(id)
		}
		case('2'):
		{
			formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_SELECT_LASTREQ_SEL2", dst)
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, option)
			dr_set_user_money(id, dr_get_user_money(id) + 350)
			user_silentkill(id)
		}
		case('3'):
		{
			formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_SELECT_LASTREQ_SEL3", dst)
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, option)
			set_bit(g_PlayerVoice, id)
			user_silentkill(id)
		}
		case('4'):
		{
			last_menu(id)
		}
		case('5'):
		{
			new g_Lastmoney = random_num(0, 700)
			dr_set_user_money(id, dr_get_user_money(id) + g_Lastmoney)
			user_silentkill(id)
			formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_SELECT_LASTREQ_SEL5", dst, g_Lastmoney)
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, option)
		}
		case('6'):
		{
			last_duel(id)
		}
		case('7'):
		{
			formatex(option, charsmax(option), "%L", LANG_SERVER, "JBE_SELECT_LASTREQ_SEL7", dst)
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, option)
			g_Duel = 2
			player_strip_weapons_all()
			i = random_num(0, sizeof(_WeaponsFree) - 1)
			give_item(id, _WeaponsFree[i])
			g_BlockWeapons = 1
			cs_set_user_bpammo(id, _WeaponsFreeCSW[i], _WeaponsFreeAmmo[i])
		}			
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public setup_buttons()
{
	new ent[3]
	new Float:origin[3]
	new info[32]
	new pos

	while((pos <= sizeof(g_Buttons)) && (ent[0] = engfunc(EngFunc_FindEntityByString, ent[0], "classname", "info_player_deathmatch")))
	{
		pev(ent[0], pev_origin, origin)
		while((ent[1] = engfunc(EngFunc_FindEntityInSphere, ent[1], origin, CELL_RADIUS)))
		{
			if(!is_valid_ent(ent[1]))
				continue

			entity_get_string(ent[1], EV_SZ_classname, info, charsmax(info))
			if(!equal(info, "func_door"))
				continue

			entity_get_string(ent[1], EV_SZ_targetname, info, charsmax(info))
			if(!info[0])
				continue

			if(TrieKeyExists(g_CellManagers, info))
			{
				TrieGetCell(g_CellManagers, info, ent[2])
			}
			else
			{
				ent[2] = engfunc(EngFunc_FindEntityByString, 0, "target", info)
			}

			if(is_valid_ent(ent[2]) && (in_array(ent[2], g_Buttons, sizeof(g_Buttons)) < 0))
			{
				g_Buttons[pos] = ent[2]
				pos++
				break
			}
		}
	}
	TrieDestroy(g_CellManagers)
}

stock in_array(needle, data[], size)
{
	for(new i = 0; i < size; i++)
	{
		if(data[i] == needle)
			return i
	}
	return -1
}

stock freeday_set(id, player)
{
	static src[32], dst[32]
	get_user_name(player, dst, charsmax(dst))

	if(is_user_alive(player) && !get_bit(g_PlayerWanted, player))
	{
		set_bit(g_PlayerFreeday, player)
		g_PlayerSkin[player] = 5
		entity_set_int(player, EV_INT_skin, g_PlayerSkin[player])
		who_fd()

		if(0 < id <= MAXPLAYERS)
		{
			get_user_name(id, src, charsmax(src))
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_GUARD_FREEDAYGIVE", src, dst)
		}
		else if(!is_freeday())
		{
			player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PRISONER_HASFREEDAY", dst)
		}
	}
}

stock first_join(id)
{
	if(!get_bit(g_PlayerJoin, id))
	{
		set_bit(g_PlayerJoin, id)
	}
}

stock player_hudmessage(id, hudid, Float:time = 0.0, color[3] = {0, 255, 0}, msg[], any:...)
{
	static text[512], Float:x, Float:y
	x = g_HudSync[hudid][_x]
	y = g_HudSync[hudid][_y]
	
	if(time > 0)
		set_hudmessage(color[0], color[1], color[2], x, y, 0, 0.00, time, 0.00, 0.00)
	else
		set_hudmessage(color[0], color[1], color[2], x, y, 0, 0.00, g_HudSync[hudid][_time], 0.00, 0.00)

	vformat(text, charsmax(text), msg, 6)
	ShowSyncHudMsg(id, g_HudSync[hudid][_hudsync], text)
}

stock menu_players(id, CsTeams:team, skip, alive, callback[], title[], any:...)
{
	static i, name[32], num[5], menu, menuname[32]
	vformat(menuname, charsmax(menuname), title, 7)
	menu = menu_create(menuname, callback)
	for(i = 1; i <= MAXPLAYERS; i++)
	{
		if(!is_user_connected(i) || (alive && !is_user_alive(i)) || (skip == i))
			continue

 		if(!(team == CS_TEAM_T || team == CS_TEAM_CT) || ((team == CS_TEAM_T || team == CS_TEAM_CT) && (cs_get_user_team(i) == team)))
		{
			get_user_name(i, name, charsmax(name))
			num_to_str(i, num, charsmax(num))
			menu_additem(menu, name, num, 0)
		}
	}
	menu_display(id, menu)
}

stock player_glow(id, color[3], amount=40)
{
	set_user_rendering(id, kRenderFxGlowShell, color[0], color[1], color[2], kRenderNormal, amount)
}

stock player_strip_weapons(id)
{
	strip_user_weapons(id)
	give_item(id, "weapon_knife")
	set_pdata_int(id, m_iPrimaryWeapon, 0)
}

stock player_strip_weapons_all()
{
	for(new i = 1; i <= MAXPLAYERS; i++)
	{
		if(is_user_alive(i))
		{
			player_strip_weapons(i)
		}
	}
}

stock is_freeday()
{
	return (g_Freeday || g_Days == 7)
}

stock is_gameday()
{
	return (g_Days == 6)
}

public jail_open()
{
	static i
	for(i = 0; i < sizeof(g_Buttons); i++)
	{
		if(g_Buttons[i])
		{
			ExecuteHamB(Ham_Use, g_Buttons[i], 0, 0, 1, 1.0)
			entity_set_float(g_Buttons[i], EV_FL_frame, 0.0)
		}
	}
}

public native_get_user_simon(id)
{
	if(cs_get_user_team(id) != CS_TEAM_CT)
	return false

	return g_Simon == id? true : false
}

public native_get_user_duel(id)
{
	if(g_DuelA == id || g_DuelB == id)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public native_get_user_duel1(id)
{
	if((g_DuelA == id || g_DuelB == id) && g_Duel == 3)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public native_get_user_duel2(id)
{
	if((g_DuelA == id || g_DuelB == id) && g_Duel == 4)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public native_get_user_duel3(id)
{
	if((g_DuelA == id || g_DuelB == id) && g_Duel == 5)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public native_get_user_duel4(id)
{
	if((g_DuelA == id || g_DuelB == id) && g_Duel == 6)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public native_get_user_duel5(id)
{
	if((g_DuelA == id || g_DuelB == id) && g_Duel == 7)
	{
		return true
	}
	else
	{
		return false
	}
	
	return PLUGIN_CONTINUE
}

public last_duel(id)
{
	if(!g_Duel)
	{
		new i_Menuduel = menu_create("\rМеню дуэлей", "menu_lastduel")

		if(!g_DuelOptions[0])
		{
			if(g_DuelOptions[1])
			{
				menu_additem(i_Menuduel, "\wДуэль на \yкулаках\d(обычная)", "1", 0)
			}
			else
			{
				menu_additem(i_Menuduel, "\wДуэль на \yкулаках", "1", 0)
			}
			menu_additem(i_Menuduel, "\wДуэль на \yдиглах", "2", 0)
			menu_additem(i_Menuduel, "\wДуэль на \yмухах", "3", 0)
			if(g_DuelOptions[1])
			{
				menu_additem(i_Menuduel, "\wДуэль на \yгренах\d(обычная)", "4", 0)
			}
			else
			{
				menu_additem(i_Menuduel, "\wДуэль на \yгренах", "4", 0)
			}
			menu_additem(i_Menuduel, "\wДуэль на \yавп", "5", 0)
			
			
			menu_additem(i_Menuduel, "\wОружия: \rстандартные", "6", 0)
		}
		else
		{
			if(g_DuelOptions[1])
			{
				menu_additem(i_Menuduel, "\wДуэль на \yкогтях\d(обычная)", "1", 0)
			}
			else
			{
				menu_additem(i_Menuduel, "\wДуэль на \yкогтях", "1", 0)
			}
			menu_additem(i_Menuduel, "\wДуэль на \yанакондах", "2", 0)
			menu_additem(i_Menuduel, "\wДуэль на \yvsk94", "3", 0)
			menu_additem(i_Menuduel, "\wДуэль на \yгранатометах", "4", 0)
			menu_additem(i_Menuduel, "\wДуэль на \yплазмах", "5", 0)
			
			
			menu_additem(i_Menuduel, "\wОружия: \rновые", "6", 0)
		}
		

		if(g_DuelOptions[1])
		{
			menu_additem(i_Menuduel, "\wТип дуэли: \rчестная", "7", 0)
		}
		else
		{
			menu_additem(i_Menuduel, "\wТип дуэли: \rне честная", "7", 0)
		}
		if(g_DuelOptions[2] == 1)
		{
			menu_additem(i_Menuduel, "\wТуловище: \rtroll face", "8", 0)
		}
		else if(g_DuelOptions[2] == 2)
		{
			menu_additem(i_Menuduel, "\wТуловище: \rzombie", "8", 0)
		}
		else if(g_DuelOptions[2] == 3)
		{
			menu_additem(i_Menuduel, "\wТуловище: \ragent", "8", 0)
		}
		else
		{
			menu_additem(i_Menuduel, "\wТуловище: \rобычное", "8", 0)
		}
		
		if(g_DuelOptions[3] == 1)
		{
			menu_additem(i_Menuduel, "\wЭффекты: \rтолько свечение", "9", 0)
		}
		else if(g_DuelOptions[3] == 2)
		{
			menu_additem(i_Menuduel, "\wЭффекты: \rсвечение и траил", "9", 0)
		}
		else if(g_DuelOptions[3] == 3)
		{
			menu_additem(i_Menuduel, "\wЭффекты: \rтолько траил", "9", 0)
		}
		else
		{
			menu_additem(i_Menuduel, "\wЭффекты: \rнет", "9", 0)
		}
		menu_additem(i_Menuduel, "\yВыход", "0", 0)
		
		

		// Устанавливаем свойства меню
		menu_setprop(i_Menuduel,MEXIT_ALL, 0)

		// Отображение меню игроку
		menu_display(id, i_Menuduel, 0)
	}
	return PLUGIN_HANDLED
}

public menu_lastduel(id, menu, item)
{
	if (g_Duel)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		g_Duel = 0
		g_DuelA = 0
		g_DuelB = 0		
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 0:
		{
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}
		case 1:
		{
			g_Duel = 3
			menu_players(id, CS_TEAM_CT, 0, 1, "duel_knives", "%L", LANG_SERVER, "JBE_MENU_DUEL")
		}
		case 2:
		{
			g_Duel = 4
			menu_players(id, CS_TEAM_CT, 0, 1, "duel_guns", "%L", LANG_SERVER, "JBE_MENU_DUEL")
		}
		case 3:
		{
			g_Duel = 5
			menu_players(id, CS_TEAM_CT, 0, 1, "duel_guns", "%L", LANG_SERVER, "JBE_MENU_DUEL")
		}
		case 4:
		{
			g_Duel = 6
			menu_players(id, CS_TEAM_CT, 0, 1, "duel_guns", "%L", LANG_SERVER, "JBE_MENU_DUEL")
		}
		case 5:
		{
			g_Duel = 7
			menu_players(id, CS_TEAM_CT, 0, 1, "duel_guns", "%L", LANG_SERVER, "JBE_MENU_DUEL")
		}
		case 6:
		{
			if(g_DuelOptions[0])
			{
				g_DuelOptions[0] = 0
			}
			else
			{
				g_DuelOptions[0] = 1
			}
			last_duel(id)
		}
		case 7:
		{
			if(g_DuelOptions[1])
			{
				g_DuelOptions[1] = 0
			}
			else
			{
				g_DuelOptions[1] = 1
			}
			last_duel(id)
		}
		case 8:
		{
			if(!g_DuelOptions[2])
			{
				g_DuelOptions[2] = 1
			}
			else if(g_DuelOptions[2] == 1)
			{
				g_DuelOptions[2] = 2
			}
			else if(g_DuelOptions[2] == 2)
			{
				g_DuelOptions[2] = 3
			}
			else if(g_DuelOptions[2] == 3)
			{
				g_DuelOptions[2] = 1
			}
			last_duel(id)
		}
		case 9:
		{
			if(g_DuelOptions[3] == 0)
			{
				g_DuelOptions[3] = 1
			}
			else if(g_DuelOptions[3] == 1)
			{
				g_DuelOptions[3] = 2
			}
			else if(g_DuelOptions[3] == 2)
			{
				g_DuelOptions[3] = 3
			}
			else if(g_DuelOptions[3] == 3)
			{
				g_DuelOptions[3] = 0
			}
			last_duel(id)
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public last_menu(id)
{
	if(!g_Duel)
	{
		new i_Menulast = menu_create("\rУправление охраной:", "menu_lastcontrol")

		menu_additem(i_Menulast, "\wТелепорт в ганрум", "1", 0)
		menu_additem(i_Menulast, "\wЗабрать оружее", "2", 0)
		menu_additem(i_Menulast, "\wУбить", "3", 0)
		menu_additem(i_Menulast, "\wОставить 1хп", "4", 0)
		menu_additem(i_Menulast, "\wОткрыть клетки", "5", 0)
		menu_additem(i_Menulast, "\wДать дробовик (вам)", "6", 0)

		// Устанавливаем свойства меню
		menu_setprop(i_Menulast,MEXIT_ALL, MPROP_EXIT)

		// Отображение меню игроку
		menu_display(id, i_Menulast, 0)
	}
	return PLUGIN_HANDLED
}

public menu_lastcontrol(id, menu, item)
{
	if (item == MENU_EXIT || g_Duel)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			for(new i = 0; i <= MAXPLAYERS; i++)
			{
				if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_CT)
				{
					spawn(i)
				}
			}
		}
		case 2:
		{
			g_PunishType = 2
			menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_CHOOSECT")
		}
		case 3:
		{
			g_PunishType = 1
			menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_CHOOSECT")
		}
		case 4:
		{
			g_PunishType = 3
			menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_CHOOSECT")
		}
		case 5:
		{
			jail_open()
		}
		case 6:
		{
			for(new i = 0; i <= MAXPLAYERS; i++)
			{
				if(is_user_alive(i) && cs_get_user_team(i) == CS_TEAM_T)
				{
					give_item( i, "weapon_m3" );
					give_item( i, "weapon_knife")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
					give_item( i, "ammo_buckshot")
				}
			}
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public punish_menu(id)
{
	new i_Menupunish = menu_create("\rНаказать охрану", "menu_punish")

	menu_additem(i_Menupunish, "\wУбить", "1", 0)
	menu_additem(i_Menupunish, "\wОтобрать оружее", "2", 0)
	menu_additem(i_Menupunish, "\wОставить 1хп", "3", 0)
	menu_additem(i_Menupunish, "\wПеревести за зеков", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menupunish,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menupunish, 0)
	return PLUGIN_HANDLED
}

public menu_punish(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		simon_menu(id)
		return PLUGIN_HANDLED
	}
	if((get_user_flags(id) & ADMIN_LEVEL_B) || g_Simon == id || g_PlayerLast == id)
	{
		new s_Data[6], s_Name[64], i_Access, i_Callback
		menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
		new i_Key = str_to_num(s_Data)

		switch(i_Key)
		{
			case 1:
			{
				g_PunishType = 1
				menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_PUNISH")
			}
			case 2:
			{
				g_PunishType = 2
				menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_PUNISH")
			}
			case 3:
			{
				g_PunishType = 3
				menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_PUNISH")
			}
			case 4:
			{
				g_PunishType =4
				menu_players(id, CS_TEAM_CT, 0, 1, "punish_enable_select", "%L", LANG_SERVER, "JBE_MENU_PUNISH")
			}
		}
	}
	return PLUGIN_HANDLED
}

public punish_enable_select(id, menu, item)
{
	if(!g_PlayerLast && g_Simon != id)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if(g_PlayerLast && g_PlayerLast != id)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static dst[32], data[5], player, access, callback

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	player = str_to_num(data)
	enable_player_punish(id, player)	
	return PLUGIN_HANDLED
}

public enable_player_punish(id, player)
{
	new src[32]
	get_user_name(id,src,31)
	new dst[32]
	get_user_name(player,dst,31)

	if (id == player) 
	{
		return PLUGIN_HANDLED
	}
	if(g_PlayerLast && g_PlayerLast != id)
	{
		return PLUGIN_HANDLED
	}
	if(!g_PlayerLast && g_Simon != id)
	{
		return PLUGIN_HANDLED
	}
	
	if(g_PunishType == 1)
	{
		user_silentkill(player)
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PUNISH1", src, dst)
	}		
	else if(g_PunishType == 2)
	{
		player_strip_weapons(player)
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PUNISH2", src, dst)
	}	
	else if(g_PunishType == 3)
	{
		set_user_health(player, 1)
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PUNISH3", src, dst)
	}	
	else if(g_PunishType == 4)
	{
		cs_set_user_team(player, CS_TEAM_T)
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_PUNISH4", src, dst)
	}	
	return PLUGIN_HANDLED
}

public box_menu(id)
{
	if(g_Simon != id || g_Gameday || g_Freeday)
	{
		return PLUGIN_HANDLED
	}

	new i_Menuteam = menu_create("\rУправление боксом", "menu_box")

	if(!g_BoxStarted)
	{
		menu_additem(i_Menuteam, "\wБокс: \rвыключен", "1", 0)
	}
	else
	{
		menu_additem(i_Menuteam, "\wБокс: \rвключен", "1", 0)
	}
	if(g_BoxClassic)
	{
		menu_additem(i_Menuteam, "\wУрон инструментов: \rда", "2", 0)
	}
	else
	{
		menu_additem(i_Menuteam, "\wУрон инструментов: \rнет", "2", 0)
	}
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menuteam,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menuteam, 0)
	return PLUGIN_HANDLED
}

public menu_box(id, menu, item)
{
if (item == MENU_EXIT || g_Simon != id || g_Gameday || g_Freeday)
{
	menu_destroy(menu)
	simon_menu(id)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		client_cmd(id, "say /box")
	}
	case 2:
	{
		if(g_BoxClassic)
		{
			g_BoxClassic = 0
		}
		else
		{
			g_BoxClassic = 1
		}
	}
}
menu_destroy(menu)
box_menu(id)
return PLUGIN_HANDLED
}

public team_menu(id)
{
if(g_Simon != id || g_Gameday || g_Freeday)
{
	return PLUGIN_HANDLED
}

	new i_Menuteam = menu_create("\rУправление командами", "menu_team")

	menu_additem(i_Menuteam, "\wРазделить на 2 команды", "1", 0)
	menu_additem(i_Menuteam, "\wРазделить на 3 команды", "2", 0)
	menu_additem(i_Menuteam, "\wРазделить на 4 команды", "3", 0)
	menu_additem(i_Menuteam, "\wСмешать игроков", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menuteam,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menuteam, 0)
	return PLUGIN_HANDLED
}

public menu_team(id, menu, item)
{
if (item == MENU_EXIT || g_Simon != id || g_Gameday || g_Freeday)
{
	menu_destroy(menu)
	simon_menu(id)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		make_2team()
	}
	case 2:
	{
		make_3team()
	}
	case 3:
	{
		make_4team()
	}
	case 4:
	{
		remove_team()
	}
}
menu_destroy(menu)
team_menu(id)
return PLUGIN_HANDLED
}

public make_2team()
{
	if(g_Usert < 4)
	{
		return PLUGIN_HANDLED
	}
	g_Maketeamnum = 0
	for(new iteam = 0; iteam <= MAXPLAYERS; iteam++)
	{
		if (is_user_alive(iteam) && cs_get_user_team(iteam) == CS_TEAM_T && !get_bit(g_PlayerFreeday, iteam) && !get_bit(g_PlayerWanted, iteam) && !g_Freeday && !g_Gameday)
		{
			if(!g_Maketeamnum)
			{
				g_Maketeamnum = 1
				g_PlayerSkin[iteam] = 0
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else
			{
				g_Maketeamnum = 0
				g_PlayerSkin[iteam] = 4
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
		}
	}
	return PLUGIN_HANDLED
}

public make_3team()
{
	if(g_Usert < 6)
	{
		return PLUGIN_HANDLED
	}
	g_Maketeamnum = 0
	for(new iteam = 0; iteam <= MAXPLAYERS; iteam++)
	{
		if (is_user_alive(iteam) && cs_get_user_team(iteam) == CS_TEAM_T && !get_bit(g_PlayerFreeday, iteam) && !get_bit(g_PlayerWanted, iteam) && !g_Freeday && !g_Gameday)
		{
			if(!g_Maketeamnum)
			{
				g_Maketeamnum = 1
				g_PlayerSkin[iteam] = 0
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else if(g_Maketeamnum == 1)
			{
				g_Maketeamnum = 2
				g_PlayerSkin[iteam] = 4
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else if(g_Maketeamnum == 2)
			{
				g_Maketeamnum = 0
				g_PlayerSkin[iteam] = 1
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
		}
	}
	return PLUGIN_HANDLED
}

public make_4team()
{
	if(g_Usert < 8)
	{
		return PLUGIN_HANDLED
	}
	g_Maketeamnum = 0
	for(new iteam = 0; iteam <= MAXPLAYERS; iteam++)
	{
		if (is_user_alive(iteam) && cs_get_user_team(iteam) == CS_TEAM_T && !get_bit(g_PlayerFreeday, iteam) && !get_bit(g_PlayerWanted, iteam) && !g_Freeday && !g_Gameday)
		{
			if(!g_Maketeamnum)
			{
				g_Maketeamnum = 1
				g_PlayerSkin[iteam] = 0
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else if(g_Maketeamnum == 1)
			{
				g_Maketeamnum = 2
				g_PlayerSkin[iteam] = 4
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else if(g_Maketeamnum == 2)
			{
				g_Maketeamnum = 3
				g_PlayerSkin[iteam] = 1
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
			else if(g_Maketeamnum == 3)
			{
				g_Maketeamnum = 0
				g_PlayerSkin[iteam] = 3
				entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
			}
		}
	}
	return PLUGIN_HANDLED
}

public remove_team()
{
	for(new iteam = 0; iteam <= MAXPLAYERS; iteam++)
	{
		if (is_user_alive(iteam) && cs_get_user_team(iteam) == CS_TEAM_T && !get_bit(g_PlayerFreeday, iteam) && !get_bit(g_PlayerWanted, iteam) && !g_Freeday && !g_Gameday)
		{
			g_PlayerSkin[iteam] = random_num(0, 4)
			entity_set_int(iteam, EV_INT_skin, g_PlayerSkin[iteam])
		}
	}
	return PLUGIN_HANDLED
}

public sound_menu(id)
{
if(g_Simon != id || g_Gameday || g_Freeday)
{
	return PLUGIN_HANDLED
}

	new i_Menuteam = menu_create("\rотсчет, звуки", "menu_sound")

	menu_additem(i_Menuteam, "\wСтукнуть в гонг", "1", 0)
	menu_additem(i_Menuteam, "\wСвиснуть", "2", 0)
	menu_additem(i_Menuteam, "\wотсчет от 5 сек", "3", 0)
	menu_additem(i_Menuteam, "\wотсчет от 10 сек", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menuteam,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menuteam, 0)
	return PLUGIN_HANDLED
}

public menu_sound(id, menu, item)
{
if (item == MENU_EXIT || g_Simon != id || g_Gameday || g_Freeday)
{
	menu_destroy(menu)
	simon_menu(id)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/brass_bell_C.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	case 2:
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/foot.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	case 3:
	{
		g_Countsimon = 6
		Simon_count()
	}
	case 4:
	{
		g_Countsimon = 11
		Simon_count()
	}
}
menu_destroy(menu)
sound_menu(id)
return PLUGIN_HANDLED
}

public Simon_count()
{
	g_Countsimon--
	if(g_Countsimon > 0)
	set_task(1.0, "Simon_count")
	if(g_Countsimon == 10)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/10.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 9)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/9.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 8)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/8.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 7)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/7.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 6)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/6.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 5)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/5.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 4)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/4.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 3)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/3.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 2)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	if(g_Countsimon == 1)
	{
		emit_sound(0, CHAN_AUTO, "jbextreme/1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	}
	return PLUGIN_HANDLED
}

public simon_menu(id)
{
if(g_Simon != id || g_Gameday || g_Freeday)
{
	return PLUGIN_HANDLED
}

	new i_Menusimon = menu_create("\rМеню саймона", "menu_simon")

	menu_additem(i_Menusimon, "\wОткрыть клетки", "1", 0)
	menu_additem(i_Menusimon, "\wДать фд", "2", 0)
	menu_additem(i_Menusimon, "\wДать, забрать голос", "3", 0)
	menu_additem(i_Menusimon, "\wНаказать охрану", "4", 0)
	menu_additem(i_Menusimon, "\wУправление боксом", "5", 0)
	menu_additem(i_Menusimon, "\wУправление командами", "6", 0)
	menu_additem(i_Menusimon, "\wЗвуки, отсчет", "7", 0)
	menu_additem(i_Menusimon, "\wУправление мячом", "8", 0)
	menu_additem(i_Menusimon, "\yВыход", "0", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menusimon,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menusimon, 0)
	return PLUGIN_HANDLED
}

public menu_simon(id, menu, item)
{
if (item == MENU_EXIT || g_Simon != id || g_Gameday || g_Freeday)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 0:
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	case 1:
	{
		client_cmd(id, "say /open")
		simon_menu(id)
	}
	case 2:
	{
		client_cmd(id, "say /fd")
	}
	case 3:
	{
		client_cmd(id, "say /voice")
	}
	case 4:
	{
		punish_menu(id)
	}
	case 5:
	{
		box_menu(id)
	}
	case 6:
	{
		team_menu(id) 
	}
	case 7:
	{
		sound_menu(id)
	}
	case 8:
	{
		client_cmd(id, "jailmenuball")
	}

}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopt1_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
{
	return PLUGIN_HANDLED
}

	new i_Menushopt1 = menu_create("\rМагазин инструментов", "menu_shopt1")

	menu_additem(i_Menushopt1, "\wВантуз \y[урон \rх1,5\y] \r250руб$", "1", 0)
	menu_additem(i_Menushopt1, "\wЛомик \y[урон \rх2,5\y] \r370руб$", "2", 0)
	menu_additem(i_Menushopt1, "\wОтвертка \y[урон \rх4\y] \r500руб$", "3", 0)
	menu_additem(i_Menushopt1, "\wБинзопила \y[урон \rх6\y]\r625руб$", "4", 0)
	menu_additem(i_Menushopt1, "\wКогти \y[урон \rх8\y] \r650руб$", "5", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopt1,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopt1, 0)
	return PLUGIN_HANDLED
}

public menu_shopt1(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		if(dr_get_user_money(id) >= 250)
		{
			if(get_bit(g_PlayerChain, id) || get_bit(g_PlayerClutches, id) || get_bit(g_PlayerScrewdriver, id) || get_bit(g_PlayerCrowbar, id) || get_bit(g_PlayerBat, id))
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть оружее ^3ближнего боя")
			}
			else
			{
				set_bit(g_PlayerBat, id)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3вантуз")
				dr_set_user_money(id, dr_get_user_money(id) - 250)
				set_pev(id, pev_viewmodel2, _BatModels[1])
				set_pev(id, pev_weaponmodel2, _BatModels[0])
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 2:
	{
		if(dr_get_user_money(id) >= 370)
		{
			if(get_bit(g_PlayerChain, id) || get_bit(g_PlayerClutches, id) || get_bit(g_PlayerScrewdriver, id) || get_bit(g_PlayerCrowbar, id) || get_bit(g_PlayerBat, id))
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть оружее ^3ближнего боя")
			}
			else
			{
				set_bit(g_PlayerCrowbar, id)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3ломик")
				dr_set_user_money(id, dr_get_user_money(id) - 370)
				set_pev(id, pev_viewmodel2, _CrowbarModels[1])
				set_pev(id, pev_weaponmodel2, _CrowbarModels[0])
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 3:
	{
		if(dr_get_user_money(id) >= 500)
		{
			if(get_bit(g_PlayerChain, id) || get_bit(g_PlayerClutches, id) || get_bit(g_PlayerScrewdriver, id) || get_bit(g_PlayerCrowbar, id) || get_bit(g_PlayerBat, id))
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть оружее ^3ближнего боя")
			}
			else
			{
				set_bit(g_PlayerScrewdriver, id)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3отвертку")
				dr_set_user_money(id, dr_get_user_money(id) - 500)
				set_pev(id, pev_viewmodel2, _ScrewdriverModels[1])
				set_pev(id, pev_weaponmodel2, _ScrewdriverModels[0])
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 4:
	{
		if(dr_get_user_money(id) >= 625)
		{
			if(get_bit(g_PlayerChain, id) || get_bit(g_PlayerClutches, id) || get_bit(g_PlayerScrewdriver, id) || get_bit(g_PlayerCrowbar, id) || get_bit(g_PlayerBat, id))
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть оружее ^3ближнего боя")
			}
			else
			{
				set_bit(g_PlayerChain, id)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3бензопилу")
				dr_set_user_money(id, dr_get_user_money(id) - 625)
				set_pev(id, pev_viewmodel2, g_chain_viewmodel)
				set_pev(id, pev_weaponmodel2, g_chain_weaponmodel)
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 5:
	{
		if(dr_get_user_money(id) >= 650)
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				if(get_bit(g_PlayerChain, id) || get_bit(g_PlayerClutches, id) || get_bit(g_PlayerScrewdriver, id) || get_bit(g_PlayerCrowbar, id) || get_bit(g_PlayerBat, id))
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть оружее ^3ближнего боя")
				}
				else
				{
					set_bit(g_PlayerClutches, id)
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3когти")
					dr_set_user_money(id, dr_get_user_money(id) - 650)
					set_pev(id, pev_viewmodel2, _ClutchesModels[1])
					set_pev(id, pev_weaponmodel2, _ClutchesModels[0])
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1когти доступны только для ^3вип и выше")
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopt2_menu(id)
{
	if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		return PLUGIN_HANDLED
	}

	new i_Menushopt2 = menu_create("\rМагазин вещей, еды", "menu_shopt2")

	menu_additem(i_Menushopt2, "\wНайк \y[грава] \r300руб$", "1", 0)
	menu_additem(i_Menushopt2, "\wАдидас \y[скорость] \r350руб$", "2", 0)
	menu_additem(i_Menushopt2, "\wРибок \y[скорость, грава] \r360руб$", "3", 0)
	menu_additem(i_Menushopt2, "\wКит кат \y[50 хп] \r250руб$", "4", 0)
	menu_additem(i_Menushopt2, "\wТвикс \y[100 хп] \r425руб$", "5", 0)
	menu_additem(i_Menushopt2, "\wСникерс \y[150 хп] \r450руб$", "6", 0)
	menu_additem(i_Menushopt2, "\wКока кола \y[200 ап] \r250руб$", "7", 0)
	menu_additem(i_Menushopt2, "\wКосяк травы \y[свечение] \r50руб$", "8", 0)
	menu_additem(i_Menushopt2, "\yВыход", "9", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopt2,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menushopt2, 0)
	return PLUGIN_HANDLED
}

public menu_shopt2(id, menu, item)
{
	if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(dr_get_user_money(id) >= 300)
			{
				if(Ent[id] < 1) 
				{ 
					set_user_gravity(id, 0.45)
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3найк шапку ^4(дает граву)")
					dr_set_user_money(id, dr_get_user_money(id) - 300)
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть ^3шапка")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 2:
		{
			if(dr_get_user_money(id) >= 350)
			{
				if(Ent[id] < 1) 
				{ 
					set_user_maxspeed(id, 500.0)
					g_UserSpeed[id] = 1
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3адидас шапку ^4(дает скорость)")
					dr_set_user_money(id, dr_get_user_money(id) - 350)
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть ^3шапка")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 3:
		{
			if(dr_get_user_money(id) >= 360)
			{
				if(get_user_flags(id) & ADMIN_LEVEL_A)
				{
					if(Ent[id] < 1) 
					{ 
						set_user_gravity(id, 0.45)
						set_user_maxspeed(id, 600.0)
						g_UserSpeed[id] = 1
						ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3рибок шапку ^4(дает скорость, граву)")
						dr_set_user_money(id, dr_get_user_money(id) - 360)
					}
					else
					{
						ColorChat(id,NORMAL,"^4[Магазин] ^1у вас уже есть ^3шапка")
					}
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1шипка рибок только для ^3вип и выше")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 4:
		{
			if(dr_get_user_money(id) >= 250)
			{
				set_user_health(id, get_user_health(id) + 50)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3пикник ^4(дает 50 хп)")
				dr_set_user_money(id, dr_get_user_money(id) - 250)
				client_cmd(id, "mp3 play sound/jbextreme/eda.mp3"); 
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 5:
		{
			if(dr_get_user_money(id) >= 425)
			{
				set_user_health(id, get_user_health(id) + 100)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3твикс ^4(дает 100 хп)")
				dr_set_user_money(id, dr_get_user_money(id) - 425)
				client_cmd(id, "mp3 play sound/jbextreme/eda.mp3"); 
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		
		case 6:
		{
			if(dr_get_user_money(id) >= 450)
			{
				if(get_user_flags(id) & ADMIN_LEVEL_A)
				{
					set_user_health(id, get_user_health(id) + 150)
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3сникерс ^4(дает 150 хп)")
					dr_set_user_money(id, dr_get_user_money(id) - 450)
					client_cmd(id, "mp3 play sound/jbextreme/eda.mp3"); 
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1сникерс только для ^3вип и выше")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 7:
		{
			if(dr_get_user_money(id) >= 250)
			{
				 set_user_armor(id,200)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3кока-колу ^4(дает 200 ап)")
				dr_set_user_money(id, dr_get_user_money(id) - 250)
				client_cmd(id, "mp3 play sound/jbextreme/kola.mp3"); 
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 8:
		{
			if(dr_get_user_money(id) >= 50)
			{
				client_cmd(id, "mp3 play sound/jbextreme/trava.mp3"); 
				new Red = random_num(100,255)
				new Green = random_num(70,255)
				new Blue = random_num(50,255)
				set_user_rendering(id,kRenderFxGlowShell,Red,Green,Blue,kRenderNormal,25)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3косячок травы")
				dr_set_user_money(id, dr_get_user_money(id) - 50)
				Render(id,kRenderFxGlowShell,165,165,165,kRenderNormal,15);
				message_begin(MSG_ONE,get_user_msgid("SetFOV"),{0,0,0},id);
				write_byte(170);
				message_end();
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 9:
		{
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public shopt3_menu(id)
{
	if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		return PLUGIN_HANDLED
	}

	new i_Menushopt3 = menu_create("\rМагазин инструментов", "menu_shopt3")

	menu_additem(i_Menushopt3, "\wГраната \y[осколочная] \r225руб", "1", 0)
	menu_additem(i_Menushopt3, "\wГраната \y[дымовая] \r200руб", "2", 0)
	menu_additem(i_Menushopt3, "\wДигл \y[3 потрона]\r750руб", "3", 0)
	menu_additem(i_Menushopt3, "\wГлок \y[10 потронов] \r750руб", "4", 0)
	menu_additem(i_Menushopt3, "\wУзи \y[15 потронов] \r800руб", "5", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopt3,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopt3, 0)
	return PLUGIN_HANDLED
}

public menu_shopt3(id, menu, item)
{
	if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(dr_get_user_money(id) >= 225)
			{
				give_item(id, "weapon_hegrenade")
				dr_set_user_money(id, dr_get_user_money(id) - 225)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 2:
		{
			if(dr_get_user_money(id) >= 200)
			{
					give_item(id, "weapon_smokegrenade")
					dr_set_user_money(id, dr_get_user_money(id) - 200)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 3:
		{
			if(dr_get_user_money(id) >= 750)
			{
				cs_set_weapon_ammo(give_item(id, "weapon_deagle"), 3)
				dr_set_user_money(id, dr_get_user_money(id) - 750)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 4:
		{
			if(dr_get_user_money(id) >= 750)
			{
				cs_set_weapon_ammo(give_item(id, "weapon_glock18"), 10)
				dr_set_user_money(id, dr_get_user_money(id) - 750)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 5:
		{
			if(dr_get_user_money(id) >= 800)
			{
				cs_set_weapon_ammo(give_item(id, "weapon_mac10"), 15)
				dr_set_user_money(id, dr_get_user_money(id) - 800)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public shopt4_menu(id)
{
	if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		return PLUGIN_HANDLED
	}

	new i_Menushopt4 = menu_create("\rМагазин крысы", "menu_shopt4")

	menu_additem(i_Menushopt4, "\wСвободный день \r800руб", "1", 0)
	menu_additem(i_Menushopt4, "\wМаскировка \r800руб", "2", 0)
	menu_additem(i_Menushopt4, "\wЗакрыть дело \r600руб", "3", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopt4,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopt4, 0)
	return PLUGIN_HANDLED
}

public menu_shopt4(id, menu, item)
{
	if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(dr_get_user_money(id) >= 800)
			{
				if(!get_bit(g_PlayerFreeday, id) && !g_Freeday && g_FreedayTime && !get_bit(g_PlayerWanted, id))
				{
					freeday_set(0, id)
					dr_set_user_money(id, dr_get_user_money(id) - 800)
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 свободный день")
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1ты не можешь получить фд")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 2:
		{
			if(dr_get_user_money(id) >= 800)
			{
				if(!get_bit(g_PlayerWanted, id))
				{
					set_user_info(id, "model", "we_mob_jb2")
					entity_set_int(id, EV_INT_body, 2)
					dr_set_user_money(id, dr_get_user_money(id) - 800)
					ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3маскировку")
				}
				else
				{
					ColorChat(id,NORMAL,"^4[Магазин] ^1ты не можешь получить маскировку - ^3ты в розыске!")
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		case 3:
		{
			if(dr_get_user_money(id) >= 600)
			{
				if(!get_bit(g_PlayerWanted, id))
				{
					clear_bit(g_PlayerWanted, id)
					dr_set_user_money(id, dr_get_user_money(id) - 600)
					ColorChat(id,NORMAL,"^4[Магазин] ^1теперь ты не в ^3розыске")
					if(g_Freeday)
					{
						freeday_set(0, id)
					}
					else
					{
						g_PlayerSkin[id] = random_num(0, 4)
						entity_set_int(id, EV_INT_skin, g_PlayerSkin[id])
					}
				}
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
				emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public go_shop(id)
{
	if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_T)
	{
		shopt_menu(id)
	}
	else if(is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT)
	{
		shopct_menu(id)
	}
	else
	{
		ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3живых")
	}
}

public shopt_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
{
	return PLUGIN_HANDLED
}

	new i_Menushopt = menu_create("\rМагазин зеков", "menu_shopt")

	menu_additem(i_Menushopt, "\wМагазин \r[инструментов]", "1", 0)
	menu_additem(i_Menushopt, "\wМагазин \r[вещей, еды]", "2", 0)
	menu_additem(i_Menushopt, "\wМагазин \r[оружия]", "3", 0)
	menu_additem(i_Menushopt, "\wМагазин \r[крысы]", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopt,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopt, 0)
	return PLUGIN_HANDLED
}

public menu_shopt(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_T)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		shopt1_menu(id)
	}
	case 2:
	{
		shopt2_menu(id)
	}
	case 3:
	{
		shopt3_menu(id)
	}
	case 4:
	{
		shopt4_menu(id)
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopct_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	return PLUGIN_HANDLED
}

	new i_Menushopct = menu_create("\rМагазин охраны", "menu_shopct")

	menu_additem(i_Menushopct, "\wМагазин \r[жизней]", "1", 0)
	menu_additem(i_Menushopct, "\wМагазин \r[оружия]", "2", 0)
	menu_additem(i_Menushopct, "\r[Левый] \wмагазин", "3", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopct,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopct, 0)
	return PLUGIN_HANDLED
}

public menu_shopct(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		shopct1_menu(id)
	}
	case 2:
	{
		shopct2_menu(id)
	}
	case 3:
	{
		shopct3_menu(id)
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopct1_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	return PLUGIN_HANDLED
}

	new i_Menushopct1 = menu_create("\rМагазин хп", "menu_shopct1")

	menu_additem(i_Menushopct1, "\w50 жизней \r150руб", "1", 0)
	menu_additem(i_Menushopct1, "\w75 жизней \r175руб", "2", 0)
	menu_additem(i_Menushopct1, "\w100 жизней \r250руб", "3", 0)
	menu_additem(i_Menushopct1, "\w150 жизней \r325руб", "4", 0)
	menu_additem(i_Menushopct1, "\w225 жизней \r400руб", "5", 0)
	menu_additem(i_Menushopct1, "\w350 жизней \r500руб", "6", 0)
	menu_additem(i_Menushopct1, "\w500 жизней \r700руб", "7", 0)
	menu_additem(i_Menushopct1, "\w700 жизней \r800руб", "8", 0)
	menu_additem(i_Menushopct1, "\rВыход", "9", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopct1,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menushopct1, 0)
	return PLUGIN_HANDLED
}

public menu_shopct1(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		if(dr_get_user_money(id) >= 150)
		{
			set_user_health(id, get_user_health(id) + 50)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 50хп")
			dr_set_user_money(id, dr_get_user_money(id) - 150)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 2:
	{
		if(dr_get_user_money(id) >= 175)
		{
			set_user_health(id, get_user_health(id) + 75)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 75хп")
			dr_set_user_money(id, dr_get_user_money(id) - 175)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 3:
	{
		if(dr_get_user_money(id) >= 250)
		{
			set_user_health(id, get_user_health(id) + 100)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 100хп")
			dr_set_user_money(id, dr_get_user_money(id) - 250)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 4:
	{
		if(dr_get_user_money(id) >= 325)
		{
			set_user_health(id, get_user_health(id) + 150)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 150хп")
			dr_set_user_money(id, dr_get_user_money(id) - 325)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 5:
	{
		if(dr_get_user_money(id) >= 400)
		{
			set_user_health(id, get_user_health(id) + 225)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 225хп")
			dr_set_user_money(id, dr_get_user_money(id) - 400)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 6:
	{
		if(dr_get_user_money(id) >= 500)
		{
			set_user_health(id, get_user_health(id) + 350)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 350хп")
			dr_set_user_money(id, dr_get_user_money(id) - 500)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 7:
	{
		if(dr_get_user_money(id) >= 700)
		{
			set_user_health(id, get_user_health(id) + 500)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 500хп")
			dr_set_user_money(id, dr_get_user_money(id) - 700)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 8:
	{
		if(dr_get_user_money(id) >= 800)
		{
			set_user_health(id, get_user_health(id) + 700)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3 700хп")
			dr_set_user_money(id, dr_get_user_money(id) - 800)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 9:
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopct2_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	return PLUGIN_HANDLED
}

	new i_Menushopct2 = menu_create("\rМагазин оружий", "menu_shopct2")

	menu_additem(i_Menushopct2, "\wАнаконда \y[пистолет] \r50руб", "1", 0)
	menu_additem(i_Menushopct2, "\wVSK-49 \y[снайперка] \r125руб", "2", 0)
	menu_additem(i_Menushopct2, "\wХМ-8 \y[винтовка] \r200руб", "3", 0)
	menu_additem(i_Menushopct2, "\wПлазма \y[винтовка] \r250руб", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopct2,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopct2, 0)
	return PLUGIN_HANDLED
}

public menu_shopct2(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		if(dr_get_user_money(id) >= 50)
		{
			give_weapon_anaconda(id, 1)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3анаконду")
			dr_set_user_money(id, dr_get_user_money(id) - 50)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 2:
	{
		if(dr_get_user_money(id) >= 125)
		{
			give_weapon_vsk(id, 1)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3vsk-94")
			dr_set_user_money(id, dr_get_user_money(id) - 125)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 3:
	{
		if(dr_get_user_money(id) >= 200)
		{
			give_weapon_xm8(id, 1)
			ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3хм-8")
			dr_set_user_money(id, dr_get_user_money(id) - 200)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 4:
	{
		if(dr_get_user_money(id) >= 250)
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				give_weapon_ele(id, 1, 1)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы купили ^3плазму")
				dr_set_user_money(id, dr_get_user_money(id) - 250)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1плазма только для ^3вип и выше")
			}
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public shopct3_menu(id)
{
if(!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	return PLUGIN_HANDLED
}

	new i_Menushopct3 = menu_create("\rМагазин способностей", "menu_shopct3")

	menu_additem(i_Menushopct3, "\wСкорость \r250руб", "1", 0)
	menu_additem(i_Menushopct3, "\wГравитация \r250руб", "2", 0)
	menu_additem(i_Menushopct3, "\wМаскировка \r500руб", "3", 0)
	menu_additem(i_Menushopct3, "\wНевидемость \r800руб", "4", 0)
	
	// Устанавливаем свойства меню
	menu_setprop(i_Menushopct3,MEXIT_ALL, MPROP_EXIT)

	// Отображение меню игроку
	menu_display(id, i_Menushopct3, 0)
	return PLUGIN_HANDLED
}

public menu_shopct3(id, menu, item)
{
if (!is_user_alive(id) || g_Gameday || cs_get_user_team(id) != CS_TEAM_CT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		if(dr_get_user_money(id) >= 250)
		{
			set_user_maxspeed(id, 500.0)
			g_UserSpeed[id] = 1
			dr_set_user_money(id, dr_get_user_money(id) - 250)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 2:
	{
		if(dr_get_user_money(id) >= 250)
		{
			set_user_gravity(id, 0.45)
			dr_set_user_money(id, dr_get_user_money(id) - 250)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 3:
	{
		if(dr_get_user_money(id) >= 500)
		{
			entity_set_int(id, EV_INT_body, 2)
			entity_set_int(id, EV_INT_skin, 5)
			dr_set_user_money(id, dr_get_user_money(id) - 500)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	case 4:
	{
		if(dr_get_user_money(id) >= 800)
		{
			set_user_rendering(id,kRenderFxGlowShell,0,0,0,kRenderTransAlpha,0)
			dr_set_user_money(id, dr_get_user_money(id) - 800)
		}
		else
		{
			ColorChat(id,NORMAL,"^4[Магазин] ^1недостаточно ^3денег")
			emit_sound(id, CHAN_AUTO, "jbextreme/rs.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
		}
	}
}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public all_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wсервера\y]\d:", "menu_handler1")

	// Теперь добавим некоторые опции для меню
	if(g_Freeday || g_Gameday || g_Simon == id)
	{
		menu_additem(i_Menu, "\wОткрыть клетки", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dОткрыть клетки", "1", 0)
	}
	if(!g_Freeday && !g_Gameday && !g_Simon && is_user_alive(id) && cs_get_user_team(id) == CS_TEAM_CT)
	{
		menu_additem(i_Menu, "\wСтать начальником", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dСтать начальником", "2", 0)
	}
	if(g_Simon == id)
	{
		menu_additem(i_Menu, "\wМеню начальника", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dМеню начальника", "3", 0)
	}
	if(is_user_alive(id) && !g_Gameday)
	{
		menu_additem(i_Menu, "\wМагазин", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dМагазин", "4", 0)
	}
	if(is_user_alive(id) && id == g_PlayerLast)
	{
		menu_additem(i_Menu, "\wПоследний зек", "5", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dПоследний зек", "5", 0)
	}
	menu_additem(i_Menu, "\wВаш профиль", "6", 0)
	menu_additem(i_Menu, "\wИнформация", "7", 0)
	menu_additem(i_Menu, "\wСистема привелегий", "8", 0)
	menu_additem(i_Menu, "\yВыход", "9", 0)

	// Устанавливаем свойства меню
	menu_setprop(i_Menu,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_handler1(id, menu, item)
{
if (item == MENU_EXIT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		client_cmd(id, "say /open")
	}
	case 2:
	{
		client_cmd(id, "say /simon")
	}
	case 3:
	{
		client_cmd(id, "say /smenu")
	}
	case 4:
	{
		client_cmd(id, "say /shop")
	}
	case 5:
	{
		client_cmd(id, "say /lr")
	}
	case 6:
	{
		client_cmd(id, "say /prof")
	}
	case 7:
	{
		show_motd(id,"rules.txt","Правила сервера:")
	}
	case 8:
	{
		client_cmd(id, "say /status")
	}
	case 9:
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public status_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wсервера\y]\d:", "menu_status")

	// Теперь добавим некоторые опции для меню
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВип меню", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВип меню", "1", 0)
	}
	if(get_user_flags(id) & ADMIN_BAN)
	{
		menu_additem(i_Menu, "\wАмксмод меню", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dАмксмодменю", "2", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wАдмин меню", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dАдмин меню", "3", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wПремиум меню", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dПремиум меню", "4", 0)
	}
	menu_additem(i_Menu, "\yВыход", "5", 0)

	// Устанавливаем свойства меню
	menu_setprop(i_Menu,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_status(id, menu, item)
{
if (item == MENU_EXIT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

new s_Data[6], s_Name[64], i_Access, i_Callback
menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
new i_Key = str_to_num(s_Data)

switch(i_Key)
{
	case 1:
	{
		vip_menu(id)
	}
	case 2:
	{
		client_cmd(id, "amxmodmenu")
	}
	case 3:
	{
		admin_menu(id)
	}
	case 4:
	{
		super_menu(id)
	}
	case 5:
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

}
menu_destroy(menu)
return PLUGIN_HANDLED
}

public vip_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wвипа\y]\d:", "menu_vip")

	// Теперь добавим некоторые опции для меню
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВостановить хп", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВостановить хп", "1", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wПрибавить 30 хп", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dПрибавить 30 хп", "2", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВзять 100 брони", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять 100 брони", "3", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВзять he гранату", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять he гранату", "4", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВзять fl гранату", "5", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять fl гранату", "5", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wВзять 15 рублей", "6", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять 15 рублей", "6", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_A)
	{
		menu_additem(i_Menu, "\wСыграть лотерею", "7", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dСыграть лотерею", "7", 0)
	}
	menu_additem(i_Menu, "\yВыход", "8", 0)

	// Устанавливаем свойства меню
	menu_setprop(i_Menu,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_vip(id, menu, item)
{	
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if (!is_user_alive(id))
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, вы ^3мертв")
		return PLUGIN_HANDLED
	}
	if (g_PlayerLast)
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, активен ^3последний зек")
		return PLUGIN_HANDLED
		
	}
	if (g_Gameday)
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, время ^3игр")
		return PLUGIN_HANDLED
		
	}
	if (g_Usevip[id])
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, вы уже пользовались ^3меню привелеги")
		return PLUGIN_HANDLED
		
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				set_user_health(id,100)
				ColorChat(id,NORMAL,"^4[Магазин] ^1ваши хп востановлены до ^3 100")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 2:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				set_user_health(id,get_user_health(id) + 30)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы взяли 30 ^3хп")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 3:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы взяли 100 ^3брони")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 4:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				give_item( id, "weapon_hegrenade" );
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы взяли ^3осколочную гранату")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 5:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				give_item( id, "weapon_flashbang" );
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы взяли ^3слеповую гранату")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 6:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				dr_set_user_money(id, dr_get_user_money(id) + 15)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы взяли ^3 15 рублей")
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 7:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_A)
			{
				new g_Rmoney = random_num(1, 30)
				dr_set_user_money(id, dr_get_user_money(id) + g_Rmoney)
				ColorChat(id,NORMAL,"^4[Магазин] ^1вы выйграли ^3 %i рублей", g_Rmoney)
				g_Usevip[id] = 1
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Магазин] ^1только для ^3вип и выше")
			}
		}
		case 8:
		{
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}

	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public admin_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wадмина\y]\d:", "menu_admin")

	// Теперь добавим некоторые опции для меню
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wПоказ правил игроку", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dПоказ правил игроку", "1", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wНаказать КТ", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dНаказать КТ", "2", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДать, забрать голос", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДать, забрать голос", "3", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДать фд", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДать фд", "4", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДни игр", "5", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДни игр", "5", 0)
	}
	menu_additem(i_Menu, "\yВыход", "6", 0)

	// Устанавливаем свойства меню
	menu_setprop(i_Menu,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_admin(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				menu_players(id, CS_TEAM_T, 0, 1, "rules_enable_select", "Показать правила:")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 2:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				punish_menu(id)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 3:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				cmd_simon_micr(id)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 4:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				cmd_freeday(id)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 5:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				cmd_game_menu(id)
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 6:
		{
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}

	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public cmd_game_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wигр\y]\d:", "menu_game")

	// Теперь добавим некоторые опции для меню
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wГолосование [1 группа]", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dГолосование [1 группа]", "1", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wГолосование [2 группа]", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dГолосование [2 группа]", "2", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень зомби", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень зомби", "3", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень пряток", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень пряток", "4", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень приведений", "5", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень приведений", "5", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень пришельца", "6", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень пришельца", "6", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень чай-чай", "7", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень чай-чай", "7", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень алкоголиков", "8", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень алкоголиков", "8", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень Трол-гоприков", "9", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень Трол-гоприков", "9", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень снежков", "10", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень снежков", "10", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень мяса", "11", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень мяса", "11", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень подрывателей", "12", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень подрывателей", "12", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		menu_additem(i_Menu, "\wДень вышибал", "13", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dДень вышибал", "13", 0)
	}

	// Устанавливаем свойства меню
	menu_setprop(i_Menu, MPROP_EXIT, MEXIT_ALL)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_game(id, menu, item)
{
	if (item == MENU_EXIT || g_Gameday)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				g_Gamenum = 1
				g_Gameday = 1
				StartVote()
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 2:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				g_Gamenum = 0
				g_Gameday = 1
				StartVote()
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 3:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started1")
				g_GameNow = 1
				g_Gameday = 1
				g_DayType = "День зомби";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 4:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started2")
				g_GameNow = 2
				g_Gameday = 1
				g_DayType = "День пряток";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 5:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started3")
				g_GameNow = 3
				g_Gameday = 1
				g_DayType = "День приведений";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 6:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started4")
				g_GameNow = 4
				g_Gameday = 1
				g_DayType = "День пришельца";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 7:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				jb_game_chay()
				g_GameNow = 5
				g_Gameday = 1
				g_DayType = "День чай-чай";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 8:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started6")
				g_GameNow = 6
				g_Gameday = 1
				g_DayType = "День алкашей";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 9:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started7")
				g_GameNow = 7
				g_Gameday = 1
				g_DayType = "День Трол-гопников";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 10:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				jb_game_snowballs()
				g_GameNow = 8
				g_Gameday = 1
				g_DayType = "День снежков";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 11:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				set_task(1.0,"started9")
				g_GameNow = 9
				g_Gameday = 1
				g_DayType = "День мяса";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 12:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				jb_game_hemod()
				g_GameNow = 10
				g_Gameday = 1
				g_DayType = "Подрывателей";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}
		case 13:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_B)
			{
				jb_game_killball()
				g_GameNow = 12
				g_Gameday = 1
				g_DayType = "День вышибал";
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3админа и выше")
			}
		}

	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public super_menu(id)
{
	new i_Menu = menu_create("\rМеню \y[\wадмина\y]\d:", "menu_super")

	// Теперь добавим некоторые опции для меню
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wВоскреснуть", "1", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВоскреснуть", "1", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wВзять 100 рублей", "2", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять 100 рублей", "2", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wВзять 110 хп", "3", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять 110 хп", "3", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wВзять 500 брони", "4", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dВзять 500 брони", "4", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wБезшумные шаги", "5", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dБезшумные шаги", "5", 0)
	}
	if(get_user_flags(id) & ADMIN_LEVEL_C)
	{
		menu_additem(i_Menu, "\wКосяк  травы", "6", 0)
	}
	else
	{
		menu_additem(i_Menu, "\dКосяк  травы", "6", 0)
	}
	menu_additem(i_Menu, "\yВыход", "7", 0)

	// Устанавливаем свойства меню
	menu_setprop(i_Menu,MEXIT_ALL, 0)

	// Отображение меню игроку
	menu_display(id, i_Menu, 0)
}

public menu_super(id, menu, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}
	if (g_PlayerLast)
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, активен ^3последний зек")
		return PLUGIN_HANDLED
		
	}
	if (g_Gameday)
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, время ^3игр")
		return PLUGIN_HANDLED
		
	}
	if (g_Usevip[id])
	{
		menu_destroy(menu)
		ColorChat(id,NORMAL,"^4[Система статуса] ^1запрещено, вы уже пользовались ^3меню привелеги")
		return PLUGIN_HANDLED
		
	}


	new s_Data[6], s_Name[64], i_Access, i_Callback
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback)
	new i_Key = str_to_num(s_Data)

	switch(i_Key)
	{
		case 1:
		{
			if((get_user_flags(id) & ADMIN_LEVEL_C) && !is_user_alive(id))
			{
				ExecuteHamB(Ham_CS_RoundRespawn, id)
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли ^3возрождение")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 2:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_C)
			{
				dr_set_user_money(id, dr_get_user_money(id) + 100)
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли^3 100 рублей")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 3:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_C)
			{
				set_user_health(id,get_user_health(id) + 110)
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли^3 110 хп")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 4:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_C)
			{
				cs_set_user_armor(id, 500, CS_ARMOR_VESTHELM)
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли^3 500 брони")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 5:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_C)
			{
				set_user_footsteps(id,1)
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли^3 бесшумные шаги")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 6:
		{
			if(get_user_flags(id) & ADMIN_LEVEL_C)
			{
				client_cmd(id, "mp3 play sound/jbextreme/trava.mp3"); 
				new Red = random_num(100,255)
				new Green = random_num(70,255)
				new Blue = random_num(50,255)
				set_user_rendering(id,kRenderFxGlowShell,Red,Green,Blue,kRenderNormal,25)
				Render(id,kRenderFxGlowShell,165,165,165,kRenderNormal,15);
				message_begin(MSG_ONE,get_user_msgid("SetFOV"),{0,0,0},id);
				write_byte(170);
				message_end();
				g_Usevip[id] = 1
				ColorChat(id,NORMAL,"^4[Система статуса] ^1вы взяли^3 косяк травы")
			}
			else
			{
				ColorChat(id,NORMAL,"^4[Система статуса] ^1только для ^3премиума")
			}
		}
		case 7:
		{
			menu_destroy(menu)
			return PLUGIN_HANDLED
		}

	}
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

public enable_player_rules(id, player)
{
	show_motd(player,"rules.txt","Правила сервера:")
}

public rules_enable_select(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu)
		return PLUGIN_HANDLED
	}

	static dst[32], data[5], player, access, callback

	menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
	player = str_to_num(data)
	enable_player_rules(id, player)	
	return PLUGIN_HANDLED
}

public enable_player_voice(id, player)
{
static src[32], dst[32]
get_user_name(player, dst, charsmax(dst))


if (!get_bit(g_PlayerVoice, player)) 
	
{
	set_bit(g_PlayerVoice, player)
	if(0 < id <= MAXPLAYERS)
	{
		get_user_name(id, src, charsmax(src))
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_GUARD_VOICEENABLED", src, dst)
	}
}

else
	
{
	clear_bit(g_PlayerVoice, player)
	if(0 < id <= MAXPLAYERS)
	{
		get_user_name(id, src, charsmax(src))
		player_hudmessage(0, 6, 3.0, {0, 255, 0}, "%L", LANG_SERVER, "JBE_GUARD_VOICEDISABLED", src, dst)
	}		
	
}



}

public voice_enable_select(id, menu, item)
{

if(item == MENU_EXIT)
{
	menu_destroy(menu)
	return PLUGIN_HANDLED
}

static dst[32], data[5], player, access, callback

menu_item_getinfo(menu, item, access, data, charsmax(data), dst, charsmax(dst), callback)
player = str_to_num(data)
enable_player_voice(id, player)	
return PLUGIN_HANDLED
}
public cmd_simon_micr(id)
{
if (g_Simon == id || is_user_admin(id)) 
{
	menu_players(id, CS_TEAM_T, 0, 1, "voice_enable_select", "%L", LANG_SERVER, "JBE_MENU_VOICE")
	
}
} 

public hook_on(id,level,cid) {
	if(!is_user_alive(id) || g_Gameday)
		return PLUGIN_HANDLED
	
	if(get_user_flags(id) & ADMIN_LEVEL_B)
	{
		get_user_origin(id,hookorigin[id-1],3)
	
		ishooked[id-1] = true
	
		emit_sound(id,CHAN_STATIC,"hook/hook.wav",1.0,ATTN_NORM,0,PITCH_NORM)
		set_task(0.1,"hook_task",id,"",0,"ab")
		hook_task(id)
	}
	
	return PLUGIN_HANDLED
}

public is_hooked(id) {
	return ishooked[id-1]
}

public hook_off(id) {
	remove_hook(id)
	
	return PLUGIN_HANDLED
}

public hook_task(id) {
	if(!is_user_connected(id) || !is_user_alive(id))
		remove_hook(id)
	
	remove_beam(id)
	draw_hook(id)
	
	new origin[3], Float:velocity[3]
	get_user_origin(id,origin) 
	new distance = get_distance(hookorigin[id-1],origin)
	if(distance > 25)  { 
		velocity[0] = (hookorigin[id-1][0] - origin[0]) * (2.0 * 300 / distance)
		velocity[1] = (hookorigin[id-1][1] - origin[1]) * (2.0 * 300 / distance)
		velocity[2] = (hookorigin[id-1][2] - origin[2]) * (2.0 * 300 / distance)
		
		entity_set_vector(id,EV_VEC_velocity,velocity)
	} 
	else {
		entity_set_vector(id,EV_VEC_velocity,Float:{0.0,0.0,0.0})
		remove_hook(id)
	}
}

public draw_hook(id) {
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(1)				// TE_BEAMENTPOINT
	write_short(id)				// entid
	write_coord(hookorigin[id-1][0])	// origin
	write_coord(hookorigin[id-1][1])	// origin
	write_coord(hookorigin[id-1][2])	// origin
	write_short(Sbeam)			// sprite index
	write_byte(0)				// start frame
	write_byte(0)				// framerate
	write_byte(100)				// life
	write_byte(10)				// width
	write_byte(0)				// noise
	if(get_user_team(id) == 1) {		// Terrorist
		write_byte(255)			// r
		write_byte(255)			// g
		write_byte(255)			// b
	}
	else {					// Counter-Terrorist
		write_byte(255)			// r
		write_byte(255)			// g
		write_byte(255)			// b
	}
	write_byte(150)				// brightness
	write_byte(0)				// speed
	message_end()
}

public remove_hook(id) {
	if(task_exists(id))
		remove_task(id)
	remove_beam(id)
	ishooked[id-1] = false
}

public remove_beam(id) {
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(99) // TE_KILLBEAM
	write_short(id)
	message_end()
}

Render(index, fx=kRenderFxNone, r=255, g=255, b=255,render=kRenderNormal,amount=16)
{
	set_pev(index, pev_renderfx, fx);
	new Float:RenderColor[3];
	RenderColor[0] = float(r);  
	RenderColor[1] = float(g);  
	RenderColor[2] = float(b); 
	set_pev(index, pev_rendercolor, RenderColor);
	set_pev(index, pev_rendermode, render);  
	set_pev(index, pev_renderamt, float(amount));
	return 1; 
}

public RemoveItems(entity)
{
	static Class[10]
	pev(entity, pev_classname, Class, sizeof Class - 1)
		
	if (equal(Class, "weaponbox"))
	{
		set_pev(entity, pev_nextthink, 1)
		return;
	}
}