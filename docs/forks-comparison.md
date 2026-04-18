# Forks Paper — comparaison et choix MineShark

Quand on lance un serveur Minecraft « plugin », on choisit un **fork** de Paper. Un fork = un dérivé qui ajoute des optimisations ou des features tout en restant compatible avec l'écosystème plugin Spigot/Bukkit. Ce document explique pourquoi MineShark tourne sur **Purpur** et quelles sont les alternatives si l'arbitrage change.

## Généalogie

```
                    Bukkit  (2011, abandonné légalement en 2014)
                       │
                    Spigot   (fork anti-lag de Bukkit, semi-open)
                       │
                    Paper    (2015, vrai open-source + optims massives)
                  ┌────┴────┐
           Pufferfish    Purpur
                │           │
              Folia      (utilise Pufferfish comme base)
              (Paper-based)
```

Paper est la **référence** : 99 % des plugins sont écrits pour l'API Paper/Spigot/Bukkit. Tout fork qui garde cette API (Pufferfish, Purpur, Leaves) garde la compat plugins. Folia **casse** cette API — il oblige les plugins à être écrits pour son modèle multi-thread.

## Tableau comparatif

| Fork | Base | Features ajoutées | Perf vs Paper | Compat plugins | Maturité 2026 | Cas d'usage |
|---|---|---|---|---|---|---|
| **Paper** | — | — | référence | 100% | ⭐⭐⭐⭐⭐ très stable | Safe choice. Premier fork testé par tout plugin. |
| **Pufferfish** | Paper | Aucune gameplay ; optims IA, spawner, ticks | +10 à 20% | 100% | ⭐⭐⭐⭐ stable | Si tu veux juste + de TPS sans changer le gameplay. |
| **Purpur** | Pufferfish | ~250 toggles gameplay (double-jump, mobs rideables, AFK, utility belt…) | +10 à 20% (hérite Pufferfish) | 100% | ⭐⭐⭐⭐ stable | **Choix MineShark** — features lobby/survie cool, perfs Pufferfish, API Paper. |
| **Leaves** | Paper | Bedrock natif intégré (pas besoin de Geyser) + optims | +5 à 10% | 95% | ⭐⭐⭐ jeune mais actif | Quand on veut Bedrock sans le couple Geyser+Floodgate. |
| **Folia** | Paper | Multi-thread régionalisé (un thread par région de chunks) | +200% sur serveurs 100+ joueurs | **incompatible** avec la majorité des plugins | ⭐⭐ niche | Super-serveurs (500+ joueurs). À fuir pour un serveur classique. |

## Pourquoi Purpur pour MineShark ?

Trois raisons, dans l'ordre :

1. **Gameplay lobby gratuit** — double-jump, launchpads, AFK detection, mobs rideables… C'est ce qui donne le « feel » d'un lobby pro (type Hypixel) sans devoir coder un plugin custom. Tu actives dans `purpur.yml`, terminé.
2. **Perfs Pufferfish incluses** — mobs spawners optimisés, pathfinding lazy, IA allégée quand aucun joueur ne regarde. Gain concret : +15 % TPS sur un serveur survie actif.
3. **Compat plugin 100 %** — tous les plugins Paper tournent sans modification. Y compris WorldEdit, Multiverse, LuckPerms, Essentials — tout.

Les trade-offs assumés :

- Maintenance : Purpur suit Paper à J+24-48h en général. Pas un pb pour un serveur qui boote en 2026 (la 1.21.x est mature).
- Bugs gameplay : les features Purpur ajoutent de la surface bug potentielle. On les active uniquement celles qu'on utilise, via les toggles.

## Et Leaves ?

Leaves est intéressant parce qu'il élimine Geyser+Floodgate : il parle RakNet (Bedrock) nativement. **Mais** : notre infra Velocity+Geyser+Floodgate marche déjà, est mature, et Geyser/Floodgate sont maintenus par MCXboxBroadcast et ont une communauté énorme. Leaves fait doublon, et en prime il est plus jeune (premier release stable 2023).

**Décision** : on ne bascule pas. Re-évaluation dans un an si Leaves gagne en traction.

## Purpur — les features qu'on active sur MineShark

Ce qui est activé par défaut dans `config/purpur.yml` (setup pro lobby + survie) :

| Feature | Où ? | Utilité |
|---|---|---|
| `afk.tick-nearby-entities: false` | global | Joueurs AFK ne tickent plus les mobs autour → libère du CPU |
| `villager.lobotomize.enabled: true` | global | Villagers bloqués cessent de pathfinder → PERF énorme sur villes |
| `respawn_anchor.explode.enabled-in: [nether, end]` | global | L'ancre de réapparition explose aussi dans l'End (détail fun) |
| `player.totem-of-undying.works-in-inventory: false` | global | Empêche abus totem dans le sac (garde vanilla) |
| `movement.double-jump.enabled: false` | global OFF | Activé UNIQUEMENT sur lobby via `lobby/purpur-world.yml` |
| `command.uptime.enabled: true` | global | `/uptime` pour savoir depuis quand le serveur tourne |
| `command.ping.enabled: true` | global | `/ping` client side, utile pour débug lag |

Pour voir tout ce qu'on peut activer : <https://purpurmc.org/docs/Configuration/>.

## Si tu veux passer sur un autre fork

Il suffit de changer `SERVER_TYPE` dans `.env` :

```bash
# .env
SERVER_TYPE=PAPER       # ou PURPUR, PUFFERFISH
```

Puis :

```bash
make re    # ou make docker-re pour le dev local
```

itzg gère la bascule : il télécharge la bonne jar au boot. Tes mondes et tes plugins ne sont pas touchés — seul le jar serveur change.

**Attention** : si tu quittes Purpur, les configs `purpur.yml` et `purpur-world.yml` sont ignorées. Les features gameplay Purpur s'éteignent (double-jump etc.). Les mondes restent intacts.

## Liens utiles

- Paper : <https://papermc.io/> | Docs : <https://docs.papermc.io/paper>
- Pufferfish : <https://pufferfish.host/>
- Purpur : <https://purpurmc.org/> | Docs : <https://purpurmc.org/docs>
- Leaves : <https://leavesmc.org/>
- Folia (pour comprendre pourquoi on l'écarte) : <https://papermc.io/software/folia>
