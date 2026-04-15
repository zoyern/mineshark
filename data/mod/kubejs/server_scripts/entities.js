EntityJSEvents.biomeSpawns((event) => {
  event.addSpawn('cataclysm:ender_golem', ['nullscape:crystal_peaks'], 20, 1, 1);
  event.addSpawn('minecraft:blaze', ['minecraft:nether_wastes'], 20, 1, 2);
  event.addSpawn('irons_spellbooks:ice_spider', ['eternal_starlight:starlight_permafrost_forest'], 5, 1, 1);
  event.addSpawn('hazennstuff:void_wanderer', ['eternal_starlight:starlight_forest'], 5, 1, 1);

  event.removeSpawn('reanimal:sea_urchin', ['#minecraft:is_overworld']);
});

PlayerEvents.tick((event) => {
  const { player } = event;

  if (player.hasEffect('tombstone:ghostly_shape')) {
    player.potionEffects.add('minecraft:speed', 4, 2);
    player.potionEffects.add('minecraft:jump_boost', 4, 2);
  }
});
