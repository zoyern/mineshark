const $Result = Java.loadClass('net.neoforged.neoforge.event.entity.living.MobEffectEvent$Applicable$Result');
const $Player = Java.loadClass('net.minecraft.world.entity.player.Player');

NativeEvents.onEvent('net.neoforged.neoforge.event.entity.living.MobEffectEvent$Applicable', (event) => {
  if (event.getEntity() instanceof $Player && event.getEffectInstance().getEffect().is('hazennstuff:tyrants_grace')) event.setResult($Result.DO_NOT_APPLY);
});
