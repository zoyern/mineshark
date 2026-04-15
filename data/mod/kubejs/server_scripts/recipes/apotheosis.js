ServerEvents.recipes((event) => {
  // REMOVALS
  event.remove({
    output: ['apotheosis:simple_reforging_table', 'apotheosis:reforging_table'],
  });

  // RECIPES
  event.shaped('4x apothic_enchanting:scrap_tome', ['IBI', 'BAB', 'IBI'], {
    B: 'minecraft:book',
    I: 'minecraft:netherite_ingot',
    A: 'minecraft:anvil',
  });
  event.shaped(Item.of('apotheosis:simple_reforging_table', 1), [' H ', 'SCS', 'PPP'], {
    H: 'betterend:iron_hammer',
    C: 'mythsandlegends:cursed_core',
    S: 'minecraft:stone',
    P: 'malum:runewood_planks',
  });
  event.recipes.create.item_application('apotheosis:reforging_table', ['apotheosis:simple_reforging_table', 'bosses_of_mass_destruction:obsidian_heart']);
});
