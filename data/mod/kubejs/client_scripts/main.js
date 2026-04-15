// Visit the wiki for more info - https://kubejs.com/
console.info('Hello, World! (Loaded client example script)');

ItemEvents.modifyTooltips((event) => {
  // Add tooltip to all of these items
  event.add(['malum:astral_weave'], 'Gotten from mob killed by scythe');
});
