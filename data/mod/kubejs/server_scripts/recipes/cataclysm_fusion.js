ServerEvents.recipes((event) => {
  // Remove all existing recipes for the target items
  event.remove({
    output: ['crystal_chronicles:paladin_sword', 'crystal_chronicles:ice_hammer', 'crystal_chronicles:staff', 'crystal_chronicles:blood_scythe', 'crystal_chronicles:spear', 'crystal_chronicles:lightning_bident', 'crystal_chronicles:chakram', 'crystal_chronicles:paladin_shield'],
  });

  // Add your custom weapon fusion recipes
  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_longsword' },
    addition: { item: 'crystal_chronicles:divinite_shard' },
    result: {
      item: 'crystal_chronicles:paladin_sword',
      id: 'crystal_chronicles:paladin_sword',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_greataxe' },
    addition: { item: 'crystal_chronicles:ice_shard' },
    result: {
      item: 'crystal_chronicles:ice_hammer',
      id: 'crystal_chronicles:ice_hammer',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_greathammer' },
    addition: { item: 'crystal_chronicles:voidstone_shard' },
    result: {
      item: 'crystal_chronicles:staff',
      id: 'crystal_chronicles:staff',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_scythe' },
    addition: { item: 'crystal_chronicles:hemalite_shard' },
    result: {
      item: 'crystal_chronicles:blood_scythe',
      id: 'crystal_chronicles:blood_scythe',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_claymore' },
    addition: { item: 'crystal_chronicles:floralite_shard' },
    result: {
      item: 'crystal_chronicles:spear',
      id: 'crystal_chronicles:spear',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_spear' },
    addition: { item: 'crystal_chronicles:voltite_shard' },
    result: {
      item: 'crystal_chronicles:lightning_bident',
      id: 'crystal_chronicles:lightning_bident',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'simplyswords:runic_chakram' },
    addition: { item: 'crystal_chronicles:volcanite_shard' },
    result: {
      item: 'crystal_chronicles:chakram',
      id: 'crystal_chronicles:chakram',
    },
  });

  event.custom({
    type: 'cataclysm:weapon_fusion',
    base: { item: 'cataclysm:azure_sea_shield' },
    addition: { item: 'crystal_chronicles:divinite_shard' },
    result: {
      item: 'crystal_chronicles:paladin_shield',
      id: 'crystal_chronicles:paladin_shield',
    },
  });
});
