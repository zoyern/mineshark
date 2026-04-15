ServerEvents.recipes((event) => {
  // REMOVALS
  event.remove({
    output: [
      //Essences
      'ars_elemental:anima_essence',
      'ars_nouveau:water_essence',
      'ars_nouveau:manipulation_essence',
      'ars_nouveau:abjuration_essence',
      'ars_nouveau:conjuration_essence',
      'ars_nouveau:fire_essence',
      'ars_nouveau:air_essence',
      'ars_nouveau:earth_essence',
      //Runes
      'irons_spellbooks:ender_rune',
      'irons_spellbooks:evocation_rune',
      'irons_spellbooks:fire_rune',
      'irons_spellbooks:holy_rune',
      'irons_spellbooks:ice_rune',
      'irons_spellbooks:lightning_rune',
      'irons_spellbooks:nature_rune',
      'irons_spellbooks:blood_rune',
      // Crafting
      'ars_nouveau:arcane_pedestal',
      'ars_nouveau:arcane_core',
      'ars_nouveau:enchanting_apparatus',
      'ars_nouveau:imbuement_chamber',
      'ars_nouveau:source_jar',
      // Stuff
      'ars_nouveau:warp_scroll',
      'ars_nouveau:stable_warp_scroll',
      'irons_spellbooks:shriving_stone',
      'irons_spellbooks:iron_spell_book',
      'ars_nouveau:enchanters_fishing_rod',
      'ars_nouveau:dull_trinket',
      'ars_nouveau:amulet_of_mana_boost',
      'ars_nouveau:amulet_of_mana_regen',
      'ars_nouveau:mundane_belt',
      'ars_nouveau:ring_of_potential',
      'ars_nouveau:drygmy_charm',
      /// Books
      'ars_nouveau:novice_spell_book',
      'ars_nouveau:archmage_spell_book',
    ],
  });
  // RECIPES
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x irons_spellbooks:arcane_essence', 'irons_spellbooks:ender_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_nouveau:abjuration_essence', 'irons_spellbooks:holy_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_nouveau:fire_essence', 'irons_spellbooks:fire_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x kubejs:ice_essence', 'irons_spellbooks:ice_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_nouveau:manipulation_essence', 'irons_spellbooks:evocation_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_nouveau:air_essence', 'irons_spellbooks:lightning_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_elemental:anima_essence', 'irons_spellbooks:blood_rune', 'block.stone.break');
  event.recipes.malum.runeworking('irons_spellbooks:blank_rune', '16x ars_nouveau:earth_essence', 'irons_spellbooks:nature_rune', 'block.stone.break');
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'kubejs:ice_essence', 2000, ['malum:aqueous_spirit', 'irons_spellbooks:icy_fang', 'irons_spellbooks:frozen_bone']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:abjuration_essence', 2000, ['malum:sacred_spirit', 'minecraft:fermented_spider_eye', 'supplementaries:soap']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:conjuration_essence', 2000, ['malum:wicked_spirit', 'ars_nouveau:wilden_horn', 'eidolon_repraised:offering_incense']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:manipulation_essence', 2000, ['malum:arcane_spirit', 'minecraft:stone_button', 'minecraft:clock']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:water_essence', 2000, ['malum:aqueous_spirit', 'minecraft:water_bucket', 'minecraft:seagrass']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:fire_essence', 2000, ['malum:infernal_spirit', 'mythsandlegends:fire_heart', 'minecraft:gunpowder']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:earth_essence', 2000, ['malum:earthen_spirit', '#c:ingots/iron', 'minecraft:dirt']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_nouveau:air_essence', 2000, ['malum:aerial_spirit', 'minecraft:feather', '#minecraft:arrows']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'ars_elemental:anima_essence', 3000, ['malum:eldritch_spirit', 'eidolon_repraised:bloodlust_incense', 'irons_spellbooks:blood_vial']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'irons_spellbooks:arcane_essence', 3000, ['minecraft:nether_star', 'malum:arcane_spirit', 'malum:eldritch_spirit']);
  event.recipes.ars_nouveau.imbuement(['#c:gems/source'], 'irons_spellbooks:cinder_essence', 3000, ['minecraft:netherite_ingot', 'malum:wicked_spirit', 'malum:infernal_spirit']);

  event.recipes.ars_nouveau.enchanting_apparatus(['iceandfire:fire_dragon_blood', 'malum:warp_flux', 'eternal_starlight:starlit_diamond'], 'eternal_starlight:starfire', 'iceandfire:summoning_crystal_fire', 1000);
  event.recipes.ars_nouveau.enchanting_apparatus(['iceandfire:ice_dragon_blood', 'malum:warp_flux', 'eternal_starlight:starlit_diamond'], 'iceandfire:sapphire_gem', 'iceandfire:summoning_crystal_ice', 1000);
  event.recipes.ars_nouveau.enchanting_apparatus(['iceandfire:lightning_dragon_blood', 'malum:warp_flux', 'eternal_starlight:starlit_diamond'], 'minecraft:amethyst_shard', 'iceandfire:summoning_crystal_lightning', 1000);

  event.recipes.ars_nouveau.enchanting_apparatus(
    ['create:golden_sheet', 'create:golden_sheet', 'ars_nouveau:source_gem_block', 'createaddition:iron_rod', 'create:golden_sheet', 'createaddition:iron_rod', 'ars_nouveau:source_gem_block', 'create:golden_sheet'],
    'create:potato_cannon',
    'ars_nouveau:splash_flask_cannon',
    2000,
  );
  event.recipes.ars_nouveau.enchanting_apparatus(
    ['malum:warp_flux', 'royalvariations:royal_ender_pearl', 'malum:warp_flux', 'royalvariations:royal_ender_pearl', 'malum:warp_flux', 'royalvariations:royal_ender_pearl', 'malum:warp_flux', 'royalvariations:royal_ender_pearl'],
    'ars_nouveau:warp_scroll',
    'ars_nouveau:stable_warp_scroll',
    10000,
  );
  
  event.recipes.ars_nouveau.enchanting_apparatus(
    ['ars_elemental:mark_of_mastery', 'ars_elemental:mark_of_mastery', 'eternal_starlight:wind_crystal', 'eternal_starlight:terra_crystal', 'irons_spellbooks:divine_soulshard', 'eternal_starlight:blaze_crystal', 'eternal_starlight:water_crystal', 'ars_elemental:mark_of_mastery'],
    'ars_nouveau:apprentice_spell_book',
    'ars_nouveau:archmage_spell_book',
    20000,
  );
  event.recipes.eidolon_repraised.worktable('ars_nouveau:ring_of_potential', ['   ', 'IGI', ' I '], ['SSSS'], {
    S: 'create:iron_sheet',
    G: 'ars_nouveau:source_gem',
    I: 'minecraft:iron_nugget',
    A: 'irons_spellbooks:arcane_essence',
  });
  event.shapeless('ars_nouveau:arcane_pedestal', 'ars_nouveau:arcane_platform');
  event.recipes.eidolon_repraised.worktable('ars_nouveau:imbuement_chamber', [' P ', 'PSP', ' P '], ['HHHH'], {
    S: 'unify:gold_sheet',
    P: 'ars_nouveau:archwood_planks',
    H: 'malum:hallowed_gold_ingot',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:arcane_pedestal', ['BGB', 'IBI', 'IBI'], ['SSSS'], {
    S: 'create:golden_sheet',
    G: 'ars_nouveau:source_gem',
    I: 'malum:hallowed_gold_ingot',
    B: 'ars_nouveau:sourcestone',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:arcane_core', ['BGB', 'B B', 'BGB'], ['IIII'], {
    G: 'ars_nouveau:source_gem',
    I: 'malum:hallowed_gold_ingot',
    B: 'ars_nouveau:sourcestone',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:enchanting_apparatus', [' H ', 'HBH', ' H '], ['SSSS'], {
    S: 'create:golden_sheet',
    B: 'ars_nouveau:source_gem_block',
    H: 'malum:hallowed_gold_ingot',
  });
  event.recipes.eidolon_repraised.worktable('8x ars_nouveau:warp_scroll', ['PPP', 'PEP', 'PPP'], ['AAAA'], {
    P: 'minecraft:map',
    E: 'royalvariations:royal_ender_pearl',
    A: 'irons_spellbooks:arcane_essence',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:dull_trinket', [' L ', 'LBL', 'IGI'], ['AAAA'], {
    L: 'minecraft:leather',
    B: 'create:brass_ingot',
    I: 'iceandfire:silver_nugget',
    G: 'ars_nouveau:source_gem',
    A: 'irons_spellbooks:arcane_essence',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:novice_spell_book', ['   ', 'SBS', '   '], ['AAAA'], {
    S: 'unify:gold_sheet',
    B: 'minecraft:book',
    A: 'irons_spellbooks:arcane_essence',
  });
  event.recipes.eidolon_repraised.worktable('ars_nouveau:source_jar', ['SNS', 'IJI', 'III'], ['AAAA'], {
    S: 'ars_nouveau:archwood_slab',
    N: 'malum:hallowed_gold_nugget',
    I: 'malum:hallowed_gold_ingot',
    J: 'supplementaries:jar',
    A: 'irons_spellbooks:arcane_essence',
  });
});
