#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_laststand;

init()
{
    // Initialize effects and get machine entities
    level._effect["multi_mule_kick"] = loadfx("misc/fx_zombie_cola_arsenal_on");
    level._effect["multi_juggernog"] = loadfx("misc/fx_zombie_cola_jugg_on");
    level.multi_mule_kick_machine = getEnt("vending_additionalprimaryweapon", "targetname");
    level.multi_juggernog_machine = getEnt("vending_jugg", "targetname");
    level.get_player_weapon_limit = ::custom_get_player_weapon_limit;
    
    level thread onPlayerConnect();
}

// Create a trigger radius at the specified origin
create_trigger_radius(hint_text, origin)
{
    trigger = spawn("trigger_radius", origin, 1, 70, 70);
    trigger setcursorhint("HINT_ACTIVATE");
    trigger sethintstring(hint_text);
    trigger setvisibletoall();
    return trigger;
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    level endon("game_ended");
    for(;;)
    {
        self waittill("spawned_player");
        self reset_perk_values();
        self thread check_proximity_to_machines();
        self thread perk_bought_check();
    }
}

reset_perk_values()
{
    // Mule Kick values
    self.hasMuleKickOnce = false;
    self.multi_mule_kick_counter = 1;
    self.starting_mule_kick_price = 4000;
    self.mule_kick_price = self.starting_mule_kick_price;
    self.weapon_limit_counter = 3;

    // Juggernog values
    self.hasJuggernogOnce = false;
    self.multi_juggernog_counter = 1;
    self.starting_jugger_price = 5000;
    self.jugger_price = self.starting_jugger_price;

    // Shared values
    self.machine_is_in_use = false;
    self.can_buy_multi_mule = false;
    self.can_buy_multi_jugger = false;
    self.perkarray = [];
    self.num_perks = 0;
    self.perk_reminder = 0;
    self.perk_count = 0;
    self.perks_given = 0;
    self.original_mule_kick_machine_location = undefined;
    self.original_jugger_machine_location = undefined;
    self.current_mule_kick_trigger = undefined;
    self.current_jugger_trigger = undefined;
    self.last_mule_kick_purchase_time = 0;
    self.last_jugger_purchase_time = 0;
    self.is_purchasing = false;
}

check_proximity_to_machines()
{
    self endon("disconnect");
    self endon("death");
    
    while(true)
    {
        if(self hasPerk("specialty_additionalprimaryweapon") && !self.is_purchasing)
        {
            self check_mule_kick_proximity();
        }
        
        if(self hasPerk("specialty_armorvest") && !self.is_purchasing)
        {
            self check_juggernog_proximity();
        }
        
        wait 0.2;
    }
}

check_mule_kick_proximity()
{
    if(isDefined(self.original_mule_kick_machine_location))
    {
        if(distance(self.origin, self.original_mule_kick_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_mule_kick_purchase_time >= 200)
            {
                self thread show_multi_mule_kick_prompt();
            }
        }
        else if(isDefined(self.current_mule_kick_trigger))
        {
            self.current_mule_kick_trigger delete();
            self.current_mule_kick_trigger = undefined;
        }
    }
}

check_juggernog_proximity()
{
    if(isDefined(self.original_jugger_machine_location))
    {
        if(distance(self.origin, self.original_jugger_machine_location) <= 70 && !self.machine_is_in_use)
        {
            current_time = GetTime();
            if(current_time - self.last_jugger_purchase_time >= 200)
            {
                self thread show_multi_juggernog_prompt();
            }
        }
        else if(isDefined(self.current_jugger_trigger))
        {
            self.current_jugger_trigger delete();
            self.current_jugger_trigger = undefined;
        }
    }
}

show_multi_mule_kick_prompt()
{
    self endon("disconnect");
    self endon("death");
    
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing || !self.can_buy_multi_mule)
    {
        return;
    }
    
    if(!isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Multi-Mule Kick [Cost: " + self.mule_kick_price + "]",
            self.original_mule_kick_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_mule_kick_trigger) && 
          self hasPerk("specialty_additionalprimaryweapon") && 
          !self.machine_is_in_use && 
          !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= self.mule_kick_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_mule_kick_trigger))
            {
                self.current_mule_kick_trigger delete();
                self.current_mule_kick_trigger = undefined;
            }
            if(distance(self.origin, self.original_mule_kick_machine_location) <= 70)
            {
                self thread process_multi_mule_kick_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.mule_kick_price)
        {
            if(distance(self.origin, self.original_mule_kick_machine_location) <= 70)
            {
                self playsound("zmb_no_cha_ching");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
            }
        }
        wait 0.1;
    }
    
    if(isDefined(self.current_mule_kick_trigger))
    {
        self.current_mule_kick_trigger delete();
        self.current_mule_kick_trigger = undefined;
    }
}

show_multi_juggernog_prompt()
{
    self endon("disconnect");
    self endon("death");
    
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing || !self.can_buy_multi_jugger)
    {
        return;
    }
    
    if(!isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger = create_trigger_radius(
            "Hold ^3[{+activate}]^7 for Multi-Juggernog [Cost: " + self.jugger_price + "]",
            self.original_jugger_machine_location + (0, 0, 30)
        );
    }
    
    while(self isTouching(self.current_jugger_trigger) && 
          self hasPerk("specialty_armorvest") && 
          !self.machine_is_in_use && 
          !self.is_purchasing)
    {
        if(self useButtonPressed() && self.score >= self.jugger_price && 
           !self maps\mp\zombies\_zm_laststand::player_is_in_laststand())
        {
            if(isDefined(self.current_jugger_trigger))
            {
                self.current_jugger_trigger delete();
                self.current_jugger_trigger = undefined;
            }
            if(distance(self.origin, self.original_jugger_machine_location) <= 70)
            {
                self thread process_multi_juggernog_purchase();
            }
            break;
        }
        else if(self useButtonPressed() && self.score < self.jugger_price)
        {
            if(distance(self.origin, self.original_jugger_machine_location) <= 70)
            {
                self playsound("zmb_no_cha_ching");
                self maps\mp\zombies\_zm_audio::create_and_play_dialog("general", "perk_deny", undefined, 0);
            }
        }
        wait 0.1;
    }
    
    if(isDefined(self.current_jugger_trigger))
    {
        self.current_jugger_trigger delete();
        self.current_jugger_trigger = undefined;
    }
}

process_multi_mule_kick_purchase()
{
    if(!self hasPerk("specialty_additionalprimaryweapon") || self.is_purchasing)
    {
        return;
    }
    
    if(!isDefined(self.original_mule_kick_machine_location) || 
       distance(self.origin, self.original_mule_kick_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.mule_kick_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_additionalprimaryweapon";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self.weapon_limit_counter++;
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.multi_mule_kick_counter++;
    self.mule_kick_price = self.starting_mule_kick_price * self.multi_mule_kick_counter;
    
    self.last_mule_kick_purchase_time = GetTime();

    self iprintln("^1Mule Kick Level " + self.multi_mule_kick_counter + 
                  "\n^2Weapon Limit increased to " + self.weapon_limit_counter);
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

process_multi_juggernog_purchase()
{
    if(!self hasPerk("specialty_armorvest") || self.is_purchasing)
    {
        return;
    }
    
    if(!isDefined(self.original_jugger_machine_location) || 
       distance(self.origin, self.original_jugger_machine_location) > 70)
    {
        return;
    }
    
    self.is_purchasing = true;
    self.machine_is_in_use = true;
    self playsound("zmb_cha_ching");
    self.score -= self.jugger_price;
    
    self allowProne(false);
    self allowSprint(false);
    self disableOffhandWeapons();
    self disableWeaponCycling();
    
    weapona = self getCurrentWeapon();
    bottle = "zombie_perk_bottle_jugg";
    self giveWeapon(bottle);
    self switchToWeapon(bottle);
    self waittill("weapon_change_complete");
    
    self.maxhealth += 150;
    self.health = self.maxhealth;
    
    self enableOffhandWeapons();
    self enableWeaponCycling();
    self takeWeapon(bottle);
    self switchToWeapon(weapona);
    
    self maps\mp\zombies\_zm_audio::playerexert("burp");
    self setBlur(4, 0.1);
    wait 0.1;
    self setBlur(0, 0.1);
    self allowProne(true);
    self allowSprint(true);
    
    self.multi_juggernog_counter++;
    self.jugger_price = self.starting_jugger_price * self.multi_juggernog_counter;
    
    self.last_jugger_purchase_time = GetTime();
    
    self.hits_counter = int(self.maxhealth / 50);

    self iprintln("^1Juggernog Level " + self.multi_juggernog_counter + 
                  "\n^2Health increased to " + self.maxhealth + 
                  "\n^8Now you resist " + self.hits_counter + " Hits!");
    
    wait 0.5;
    self.machine_is_in_use = false;
    self.is_purchasing = false;
}

perk_bought_check()
{
    self endon("death");
    self endon("disconnect");
    
    self thread monitor_perk_status();
    
    for(;;)
    {
        self.perk_reminder = self.num_perks;
        self waittill("perk_acquired");
        
        if(self hasPerk("specialty_additionalprimaryweapon"))
        {
            if(!isDefined(self.original_mule_kick_machine_location))
            {
                self.original_mule_kick_machine_location = level.multi_mule_kick_machine.origin;
                self.last_mule_kick_purchase_time = GetTime();
                
                self.can_buy_multi_mule = false;
                wait 1;
                self.can_buy_multi_mule = true;
            }
        }
        
        if(self hasPerk("specialty_armorvest"))
        {
            if(!isDefined(self.original_jugger_machine_location))
            {
                self.original_jugger_machine_location = level.multi_juggernog_machine.origin;
                self.last_jugger_purchase_time = GetTime();
                
                self.can_buy_multi_jugger = false;
                wait 1;
                self.can_buy_multi_jugger = true;
            }
        }
        
        n = 1;
        if(!(self.num_perks > self.perk_reminder))
        {
            n = (self.num_perks - self.perk_reminder);
            self.num_perks = (self.perk_reminder + n);
        }
        self.perk_reminder = self.num_perks;
        self.perk_count += n;
    }
}

monitor_perk_status()
{
    self endon("death");
    self endon("disconnect");
    
    while(true)
    {
        if(!self hasPerk("specialty_additionalprimaryweapon"))
        {
            self.multi_mule_kick_counter = 1;
            self.mule_kick_price = self.starting_mule_kick_price;
            self.original_mule_kick_machine_location = undefined;
            self.last_mule_kick_purchase_time = 0;
            self.weapon_limit_counter = 3;
            
            if(isDefined(self.current_mule_kick_trigger))
            {
                self.current_mule_kick_trigger delete();
                self.current_mule_kick_trigger = undefined;
            }
        }
        
        if(!self hasPerk("specialty_armorvest"))
        {
            self.multi_juggernog_counter = 1;
            self.jugger_price = self.starting_jugger_price;
            self.original_jugger_machine_location = undefined;
            self.last_jugger_purchase_time = 0;
            
            if(isDefined(self.current_jugger_trigger))
            {
                self.current_jugger_trigger delete();
                self.current_jugger_trigger = undefined;
            }
        }
        
        wait 0.5;
    }
}

custom_get_player_weapon_limit(player)
{
    weapon_limit = 2;
    
    if(player hasPerk("specialty_additionalprimaryweapon"))
    {
        weapon_limit = player.weapon_limit_counter;
    } 
    else 
    {
        weapons = player getWeaponsListPrimaries();
        if(weapons.size > 2)
        {
            player takeWeapon(weapons[2]);
        }
    }
    return weapon_limit;
}