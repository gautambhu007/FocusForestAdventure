# Word Hunt — prompts for an image tool

Paste one prompt per image. **Save each result as a PNG with exactly the filename shown** into one folder (e.g. `~/Downloads/wordhunt-art/`), then tell Claude the folder — it removes backgrounds where needed and imports every file into the asset catalog under that name. Nothing else changes.

Priority: **mascots first** (one `_Idle` per sheet is enough — the game moves it for the other states), **then scenes**, then only the word pictures whose emoji is unclear. Keep the *same chat/session* for all of them so the style stays consistent.

## Style line (start every prompt with this)

> Children's educational game illustration for ages 4–7: soft rounded shapes, big friendly eyes, warm flat colours with gentle shading, clean edges, picture-book charm. Absolutely no text, letters, or watermark.

## Mascots — 40 (one per sheet)

Add after the style line: *"A single full-body cartoon character: {who}, mascot of a '{theme}' page. Standing relaxed with a gentle smile, facing slightly left. Centered, isolated on a plain solid white background, nothing else in frame. Square."*

| Save as | Who | Theme |
|---|---|---|
| `WS_CHAR_01_Idle.png` | a friendly bunny gardener holding a small watering can | Sunny Garden |
| `WS_CHAR_02_Idle.png` | a cute calf with a bell | Friendly Farm |
| `WS_CHAR_03_Idle.png` | a happy dolphin | Ocean Friends |
| `WS_CHAR_04_Idle.png` | a baby triceratops | Dinosaur Valley |
| `WS_CHAR_05_Idle.png` | a young astronaut in a puffy white suit | Space Adventure |
| `WS_CHAR_06_Idle.png` | a friendly monkey explorer wearing a safari hat | Jungle Explorer |
| `WS_CHAR_07_Idle.png` | a friendly orange fox | Enchanted Forest |
| `WS_CHAR_08_Idle.png` | a smiling yellow city bus with a face | Busy City |
| `WS_CHAR_09_Idle.png` | a cheerful little crab with a sun hat | Beach Day |
| `WS_CHAR_10_Idle.png` | a penguin in a woolly scarf | Winter Wonderland |
| `WS_CHAR_11_Idle.png` | a fluffy lamb | Spring Meadow |
| `WS_CHAR_12_Idle.png` | a green frog holding a tiny umbrella | Rainy Day |
| `WS_CHAR_13_Idle.png` | a squirrel holding an acorn | Autumn Park |
| `WS_CHAR_14_Idle.png` | a colourful toucan | Tropical Island |
| `WS_CHAR_15_Idle.png` | a tall friendly giraffe | Safari Adventure |
| `WS_CHAR_16_Idle.png` | a polar bear cub | Arctic Adventure |
| `WS_CHAR_17_Idle.png` | a smiling butterfly with big wings | Butterfly Garden |
| `WS_CHAR_18_Idle.png` | a friendly ladybird | Bug Explorer |
| `WS_CHAR_19_Idle.png` | a small round robin | Bird Paradise |
| `WS_CHAR_20_Idle.png` | a raccoon in a camping hat | Woodland Camp |
| `WS_CHAR_21_Idle.png` | a mountain goat with a tiny backpack | Mountain Adventure |
| `WS_CHAR_22_Idle.png` | a friendly octopus | Underwater Adventure |
| `WS_CHAR_23_Idle.png` | a bright clownfish | Coral Reef |
| `WS_CHAR_24_Idle.png` | a small round robot astronaut | Space Station |
| `WS_CHAR_25_Idle.png` | a cute little round robot with antenna | Robot World |
| `WS_CHAR_26_Idle.png` | a smiling builder child in a yellow hard hat | Construction Zone |
| `WS_CHAR_27_Idle.png` | a friendly steam engine with a face | Train Adventure |
| `WS_CHAR_28_Idle.png` | a child pilot in aviator goggles | Airport Adventure |
| `WS_CHAR_29_Idle.png` | a young wizard with a pointy hat | Magical Castle |
| `WS_CHAR_30_Idle.png` | a cute small green dragon | Dragon Valley |
| `WS_CHAR_31_Idle.png` | a parrot wearing a little pirate hat | Pirate Island |
| `WS_CHAR_32_Idle.png` | a friendly bat holding a lantern | Treasure Cave |
| `WS_CHAR_33_Idle.png` | a T-rex hatchling with a tiny brush | Dinosaur Fossil Hunt |
| `WS_CHAR_34_Idle.png` | a sleepy smiling sloth | Rainforest Adventure |
| `WS_CHAR_35_Idle.png` | a playful otter | River Adventure |
| `WS_CHAR_36_Idle.png` | a rooster in a straw hat | Farm Harvest |
| `WS_CHAR_37_Idle.png` | a puppy with a red bandana | Animal Rescue |
| `WS_CHAR_38_Idle.png` | a child explorer with a compass and hat | World Explorer |
| `WS_CHAR_39_Idle.png` | a curious hedgehog with a magnifying glass | Nature Discovery |
| `WS_CHAR_40_Idle.png` | a bunny in a party hat holding a balloon | Big Adventure |

Optional extra poses per sheet (same character, same filename stem): `_Celebrate` — jumping with both arms up, big grin; `_Hint` — leaning forward, pointing left, curious; `_Encourage` — kind smile, friendly wave; `_WordFound` — happy hop, eyes closed with delight.

## Scenes — 40

Add after the style line: *"A tall portrait background scene for a '{theme}' page: environment only, no characters, no people, no text. The centre of the image must stay calm and uncluttered (a puzzle panel sits there); the interesting detail — foliage, objects, sky — lives around the edges. Portrait 2:3."*

| Save as | Theme |
|---|---|
| `WS_ENV_01.png` | Sunny Garden |
| `WS_ENV_02.png` | Friendly Farm |
| `WS_ENV_03.png` | Ocean Friends |
| `WS_ENV_04.png` | Dinosaur Valley |
| `WS_ENV_05.png` | Space Adventure |
| `WS_ENV_06.png` | Jungle Explorer |
| `WS_ENV_07.png` | Enchanted Forest |
| `WS_ENV_08.png` | Busy City |
| `WS_ENV_09.png` | Beach Day |
| `WS_ENV_10.png` | Winter Wonderland |
| `WS_ENV_11.png` | Spring Meadow |
| `WS_ENV_12.png` | Rainy Day |
| `WS_ENV_13.png` | Autumn Park |
| `WS_ENV_14.png` | Tropical Island |
| `WS_ENV_15.png` | Safari Adventure |
| `WS_ENV_16.png` | Arctic Adventure |
| `WS_ENV_17.png` | Butterfly Garden |
| `WS_ENV_18.png` | Bug Explorer |
| `WS_ENV_19.png` | Bird Paradise |
| `WS_ENV_20.png` | Woodland Camp |
| `WS_ENV_21.png` | Mountain Adventure |
| `WS_ENV_22.png` | Underwater Adventure |
| `WS_ENV_23.png` | Coral Reef |
| `WS_ENV_24.png` | Space Station |
| `WS_ENV_25.png` | Robot World |
| `WS_ENV_26.png` | Construction Zone |
| `WS_ENV_27.png` | Train Adventure |
| `WS_ENV_28.png` | Airport Adventure |
| `WS_ENV_29.png` | Magical Castle |
| `WS_ENV_30.png` | Dragon Valley |
| `WS_ENV_31.png` | Pirate Island |
| `WS_ENV_32.png` | Treasure Cave |
| `WS_ENV_33.png` | Dinosaur Fossil Hunt |
| `WS_ENV_34.png` | Rainforest Adventure |
| `WS_ENV_35.png` | River Adventure |
| `WS_ENV_36.png` | Farm Harvest |
| `WS_ENV_37.png` | Animal Rescue |
| `WS_ENV_38.png` | World Explorer |
| `WS_ENV_39.png` | Nature Discovery |
| `WS_ENV_40.png` | Big Adventure |

## Word pictures — 249 (optional; the emoji shown already does this job)

Add after the style line: *"A single simple icon-style picture of: {word}. One object only, readable when tiny, centered, isolated on a plain solid white background. Square."*

| Sheet | Save as | Word | Emoji today |
|---|---|---|---|
| 01 | `WS_WORD_SEED.png` | seed | 🌱 |
| 01 | `WS_WORD_BUD.png` | bud | 🌷 |
| 01 | `WS_WORD_HOSE.png` | hose | 🚿 |
| 01 | `WS_WORD_WORM.png` | worm | 🪱 |
| 02 | `WS_WORD_COW.png` | cow | 🐮 |
| 02 | `WS_WORD_PIG.png` | pig | 🐷 |
| 02 | `WS_WORD_HEN.png` | hen | 🐔 |
| 02 | `WS_WORD_GOAT.png` | goat | 🐐 |
| 03 | `WS_WORD_CRAB.png` | crab | 🦀 |
| 03 | `WS_WORD_SEAL.png` | seal | 🦭 |
| 03 | `WS_WORD_FISH.png` | fish | 🐟 |
| 03 | `WS_WORD_WHALE.png` | whale | 🐳 |
| 04 | `WS_WORD_EGG.png` | egg | 🥚 |
| 04 | `WS_WORD_TAIL.png` | tail | 🦕 |
| 04 | `WS_WORD_HORN.png` | horn | 🦏 |
| 04 | `WS_WORD_ROAR.png` | roar | 🦖 |
| 05 | `WS_WORD_SUN.png` | sun | ☀️ |
| 05 | `WS_WORD_MOON.png` | moon | 🌙 |
| 05 | `WS_WORD_COMET.png` | comet | ☄️ |
| 05 | `WS_WORD_SKY.png` | sky | 🌌 |
| 06 | `WS_WORD_APE.png` | ape | 🦍 |
| 06 | `WS_WORD_VINE.png` | vine | 🌿 |
| 06 | `WS_WORD_FROG.png` | frog | 🐸 |
| 06 | `WS_WORD_SNAKE.png` | snake | 🐍 |
| 07 | `WS_WORD_OWL.png` | owl | 🦉 |
| 07 | `WS_WORD_FOX.png` | fox | 🦊 |
| 07 | `WS_WORD_DEER.png` | deer | 🦌 |
| 07 | `WS_WORD_FAIRY.png` | fairy | 🧚 |
| 08 | `WS_WORD_BUS.png` | bus | 🚌 |
| 08 | `WS_WORD_TAXI.png` | taxi | 🚕 |
| 08 | `WS_WORD_SHOP.png` | shop | 🏪 |
| 08 | `WS_WORD_ROAD.png` | road | 🛣️ |
| 09 | `WS_WORD_SAND.png` | sand | 🏖️ |
| 09 | `WS_WORD_SHELL.png` | shell | 🐚 |
| 09 | `WS_WORD_PAIL.png` | pail | 🪣 |
| 09 | `WS_WORD_KITE.png` | kite | 🪁 |
| 10 | `WS_WORD_SNOW.png` | snow | ❄️ |
| 10 | `WS_WORD_SLED.png` | sled | 🛷 |
| 10 | `WS_WORD_SCARF.png` | scarf | 🧣 |
| 10 | `WS_WORD_ICE.png` | ice | 🧊 |
| 11 | `WS_WORD_LAMB.png` | lamb | 🐑 |
| 11 | `WS_WORD_TULIP.png` | tulip | 🌷 |
| 11 | `WS_WORD_GRASS.png` | grass | 🌱 |
| 11 | `WS_WORD_DAISY.png` | daisy | 🌼 |
| 11 | `WS_WORD_BUNNY.png` | bunny | 🐰 |
| 11 | `WS_WORD_BREEZE.png` | breeze | 🍃 |
| 12 | `WS_WORD_CLOUD.png` | cloud | ☁️ |
| 12 | `WS_WORD_BOOT.png` | boot | 🥾 |
| 12 | `WS_WORD_DRIP.png` | drip | 💧 |
| 12 | `WS_WORD_PUDDLE.png` | puddle | 🌧️ |
| 12 | `WS_WORD_COAT.png` | coat | 🧥 |
| 12 | `WS_WORD_SPLASH.png` | splash | 💦 |
| 13 | `WS_WORD_LEAF.png` | leaf | 🍁 |
| 13 | `WS_WORD_MAPLE.png` | maple | 🍁 |
| 13 | `WS_WORD_RAKE.png` | rake | 🧹 |
| 13 | `WS_WORD_WIND.png` | wind | 💨 |
| 13 | `WS_WORD_APPLE.png` | apple | 🍎 |
| 13 | `WS_WORD_BENCH.png` | bench | 🪑 |
| 14 | `WS_WORD_PALM.png` | palm | 🌴 |
| 14 | `WS_WORD_TOUCAN.png` | toucan | 🦜 |
| 14 | `WS_WORD_MANGO.png` | mango | 🥭 |
| 14 | `WS_WORD_HUT.png` | hut | 🛖 |
| 14 | `WS_WORD_LAGOON.png` | lagoon | 🏝️ |
| 14 | `WS_WORD_SURF.png` | surf | 🏄 |
| 15 | `WS_WORD_LION.png` | lion | 🦁 |
| 15 | `WS_WORD_ZEBRA.png` | zebra | 🦓 |
| 15 | `WS_WORD_HIPPO.png` | hippo | 🦛 |
| 15 | `WS_WORD_JEEP.png` | jeep | 🚙 |
| 15 | `WS_WORD_RHINO.png` | rhino | 🦏 |
| 15 | `WS_WORD_MANE.png` | mane | 🦁 |
| 16 | `WS_WORD_WALRUS.png` | walrus | 🦭 |
| 16 | `WS_WORD_IGLOO.png` | igloo | 🏠 |
| 16 | `WS_WORD_ORCA.png` | orca | 🐋 |
| 16 | `WS_WORD_MITTEN.png` | mitten | 🧤 |
| 16 | `WS_WORD_FROST.png` | frost | ❄️ |
| 16 | `WS_WORD_SKATE.png` | skate | ⛸️ |
| 17 | `WS_WORD_WING.png` | wing | 🦋 |
| 17 | `WS_WORD_NECTAR.png` | nectar | 🍯 |
| 17 | `WS_WORD_PETAL.png` | petal | 🌸 |
| 17 | `WS_WORD_LILY.png` | lily | 🌺 |
| 17 | `WS_WORD_POLLEN.png` | pollen | 🌼 |
| 17 | `WS_WORD_COCOON.png` | cocoon | 🐛 |
| 18 | `WS_WORD_ANT.png` | ant | 🐜 |
| 18 | `WS_WORD_SNAIL.png` | snail | 🐌 |
| 18 | `WS_WORD_WEB.png` | web | 🕸️ |
| 18 | `WS_WORD_SPIDER.png` | spider | 🕷️ |
| 18 | `WS_WORD_BEE.png` | bee | 🐝 |
| 18 | `WS_WORD_MOTH.png` | moth | 🦋 |
| 19 | `WS_WORD_ROBIN.png` | robin | 🐦 |
| 19 | `WS_WORD_NEST.png` | nest | 🪺 |
| 19 | `WS_WORD_BEAK.png` | beak | 🐤 |
| 19 | `WS_WORD_PERCH.png` | perch | 🌳 |
| 19 | `WS_WORD_CHIRP.png` | chirp | 🎵 |
| 19 | `WS_WORD_FLOCK.png` | flock | 🐦‍⬛ |
| 20 | `WS_WORD_TENT.png` | tent | ⛺ |
| 20 | `WS_WORD_LOG.png` | log | 🪵 |
| 20 | `WS_WORD_PATH.png` | path | 🥾 |
| 20 | `WS_WORD_BADGE.png` | badge | 🎖️ |
| 20 | `WS_WORD_TWIG.png` | twig | 🌿 |
| 20 | `WS_WORD_EMBER.png` | ember | 🔥 |
| 21 | `WS_WORD_PEAK.png` | peak | 🏔️ |
| 21 | `WS_WORD_HIKE.png` | hike | 🥾 |
| 21 | `WS_WORD_TRAIL.png` | trail | 🪧 |
| 21 | `WS_WORD_CLIMB.png` | climb | 🧗 |
| 21 | `WS_WORD_CABIN.png` | cabin | 🏡 |
| 21 | `WS_WORD_EAGLE.png` | eagle | 🦅 |
| 21 | `WS_WORD_SUMMIT.png` | summit | ⛰️ |
| 22 | `WS_WORD_OCTOPUS.png` | octopus | 🐙 |
| 22 | `WS_WORD_DOLPHIN.png` | dolphin | 🐬 |
| 22 | `WS_WORD_SEAHORSE.png` | seahorse | 🐴 |
| 22 | `WS_WORD_SQUID.png` | squid | 🦑 |
| 22 | `WS_WORD_BUBBLE.png` | bubble | 🫧 |
| 22 | `WS_WORD_DIVER.png` | diver | 🤿 |
| 22 | `WS_WORD_KELP.png` | kelp | 🌿 |
| 23 | `WS_WORD_CORAL.png` | coral | 🪸 |
| 23 | `WS_WORD_ANEMONE.png` | anemone | 🌸 |
| 23 | `WS_WORD_TURTLE.png` | turtle | 🐢 |
| 23 | `WS_WORD_URCHIN.png` | urchin | 🟣 |
| 23 | `WS_WORD_CLAM.png` | clam | 🐚 |
| 23 | `WS_WORD_SPONGE.png` | sponge | 🧽 |
| 23 | `WS_WORD_LOBSTER.png` | lobster | 🦞 |
| 24 | `WS_WORD_ROCKET.png` | rocket | 🚀 |
| 24 | `WS_WORD_PLANET.png` | planet | 🪐 |
| 24 | `WS_WORD_ORBIT.png` | orbit | 🛰️ |
| 24 | `WS_WORD_ALIEN.png` | alien | 👽 |
| 24 | `WS_WORD_HELMET.png` | helmet | ⛑️ |
| 24 | `WS_WORD_LAUNCH.png` | launch | 🚀 |
| 24 | `WS_WORD_GALAXY.png` | galaxy | 🌌 |
| 25 | `WS_WORD_ROBOT.png` | robot | 🤖 |
| 25 | `WS_WORD_GEAR.png` | gear | ⚙️ |
| 25 | `WS_WORD_WIRE.png` | wire | 🔌 |
| 25 | `WS_WORD_BATTERY.png` | battery | 🔋 |
| 25 | `WS_WORD_BUTTON.png` | button | 🔘 |
| 25 | `WS_WORD_SCREEN.png` | screen | 📺 |
| 25 | `WS_WORD_MOTOR.png` | motor | 🔧 |
| 26 | `WS_WORD_CRANE.png` | crane | 🏗️ |
| 26 | `WS_WORD_DIGGER.png` | digger | 🚜 |
| 26 | `WS_WORD_HAMMER.png` | hammer | 🔨 |
| 26 | `WS_WORD_BRICK.png` | brick | 🧱 |
| 26 | `WS_WORD_CEMENT.png` | cement | 🪣 |
| 26 | `WS_WORD_LADDER.png` | ladder | 🪜 |
| 26 | `WS_WORD_DRILL.png` | drill | 🔩 |
| 27 | `WS_WORD_TRAIN.png` | train | 🚂 |
| 27 | `WS_WORD_TRACK.png` | track | 🛤️ |
| 27 | `WS_WORD_ENGINE.png` | engine | 🚂 |
| 27 | `WS_WORD_TUNNEL.png` | tunnel | 🕳️ |
| 27 | `WS_WORD_TICKET.png` | ticket | 🎫 |
| 27 | `WS_WORD_WHISTLE.png` | whistle | 📯 |
| 27 | `WS_WORD_STATION.png` | station | 🚉 |
| 28 | `WS_WORD_AIRPLANE.png` | airplane | ✈️ |
| 28 | `WS_WORD_PILOT.png` | pilot | 🧑‍✈️ |
| 28 | `WS_WORD_RUNWAY.png` | runway | 🛫 |
| 28 | `WS_WORD_LUGGAGE.png` | luggage | 🧳 |
| 28 | `WS_WORD_TOWER.png` | tower | 🗼 |
| 28 | `WS_WORD_TAKEOFF.png` | takeoff | 🛫 |
| 29 | `WS_WORD_CASTLE.png` | castle | 🏰 |
| 29 | `WS_WORD_PRINCE.png` | prince | 🤴 |
| 29 | `WS_WORD_CROWN.png` | crown | 👑 |
| 29 | `WS_WORD_WIZARD.png` | wizard | 🧙 |
| 29 | `WS_WORD_THRONE.png` | throne | 🪑 |
| 29 | `WS_WORD_MOAT.png` | moat | 🌊 |
| 29 | `WS_WORD_UNICORN.png` | unicorn | 🦄 |
| 30 | `WS_WORD_DRAGON.png` | dragon | 🐉 |
| 30 | `WS_WORD_FLAME.png` | flame | 🔥 |
| 30 | `WS_WORD_SCALE.png` | scale | 🐲 |
| 30 | `WS_WORD_CAVE.png` | cave | 🕳️ |
| 30 | `WS_WORD_SMOKE.png` | smoke | 💨 |
| 30 | `WS_WORD_GLIDE.png` | glide | 🪁 |
| 30 | `WS_WORD_SPIKE.png` | spike | 🦔 |
| 31 | `WS_WORD_PIRATE.png` | pirate | 🏴‍☠️ |
| 31 | `WS_WORD_CAPTAIN.png` | captain | 🧑‍✈️ |
| 31 | `WS_WORD_ANCHOR.png` | anchor | ⚓ |
| 31 | `WS_WORD_COMPASS.png` | compass | 🧭 |
| 31 | `WS_WORD_SAIL.png` | sail | ⛵ |
| 31 | `WS_WORD_DECK.png` | deck | 🚢 |
| 31 | `WS_WORD_PLANK.png` | plank | 🪵 |
| 31 | `WS_WORD_SPYGLASS.png` | spyglass | 🔭 |
| 32 | `WS_WORD_TREASURE.png` | treasure | 💰 |
| 32 | `WS_WORD_GOLD.png` | gold | 🥇 |
| 32 | `WS_WORD_CHEST.png` | chest | 🧰 |
| 32 | `WS_WORD_JEWEL.png` | jewel | 💍 |
| 32 | `WS_WORD_TORCH.png` | torch | 🔦 |
| 32 | `WS_WORD_CRYSTAL.png` | crystal | 🔮 |
| 32 | `WS_WORD_DIAMOND.png` | diamond | 💎 |
| 32 | `WS_WORD_RUBY.png` | ruby | ❤️ |
| 33 | `WS_WORD_FOSSIL.png` | fossil | 🦴 |
| 33 | `WS_WORD_SKULL.png` | skull | 💀 |
| 33 | `WS_WORD_STONE.png` | stone | 🪨 |
| 33 | `WS_WORD_BRUSH.png` | brush | 🖌️ |
| 33 | `WS_WORD_SHOVEL.png` | shovel | 🪏 |
| 33 | `WS_WORD_MUSEUM.png` | museum | 🏛️ |
| 33 | `WS_WORD_FOOTPRINT.png` | footprint | 🐾 |
| 33 | `WS_WORD_BONE.png` | bone | 🦴 |
| 34 | `WS_WORD_SLOTH.png` | sloth | 🦥 |
| 34 | `WS_WORD_JAGUAR.png` | jaguar | 🐆 |
| 34 | `WS_WORD_MONKEY.png` | monkey | 🐒 |
| 34 | `WS_WORD_ORCHID.png` | orchid | 🌸 |
| 34 | `WS_WORD_CANOPY.png` | canopy | 🌳 |
| 34 | `WS_WORD_MACAW.png` | macaw | 🦜 |
| 34 | `WS_WORD_LIZARD.png` | lizard | 🦎 |
| 34 | `WS_WORD_FERN.png` | fern | 🌿 |
| 35 | `WS_WORD_OTTER.png` | otter | 🦦 |
| 35 | `WS_WORD_BEAVER.png` | beaver | 🦫 |
| 35 | `WS_WORD_TROUT.png` | trout | 🐟 |
| 35 | `WS_WORD_CANOE.png` | canoe | 🛶 |
| 35 | `WS_WORD_PADDLE.png` | paddle | 🏓 |
| 35 | `WS_WORD_BRIDGE.png` | bridge | 🌉 |
| 35 | `WS_WORD_REED.png` | reed | 🌾 |
| 35 | `WS_WORD_STREAM.png` | stream | 🏞️ |
| 36 | `WS_WORD_WHEAT.png` | wheat | 🌾 |
| 36 | `WS_WORD_TRACTOR.png` | tractor | 🚜 |
| 36 | `WS_WORD_PUMPKIN.png` | pumpkin | 🎃 |
| 36 | `WS_WORD_BARN.png` | barn | 🏚️ |
| 36 | `WS_WORD_STRAW.png` | straw | 🌾 |
| 36 | `WS_WORD_BASKET.png` | basket | 🧺 |
| 36 | `WS_WORD_SCARECROW.png` | scarecrow | 🎃 |
| 36 | `WS_WORD_ORCHARD.png` | orchard | 🍎 |
| 37 | `WS_WORD_RESCUE.png` | rescue | 🚑 |
| 37 | `WS_WORD_LEASH.png` | leash | 🦮 |
| 37 | `WS_WORD_BANDAGE.png` | bandage | 🩹 |
| 37 | `WS_WORD_SHELTER.png` | shelter | 🏠 |
| 37 | `WS_WORD_PUPPY.png` | puppy | 🐶 |
| 37 | `WS_WORD_KITTEN.png` | kitten | 🐱 |
| 37 | `WS_WORD_BLANKET.png` | blanket | 🛏️ |
| 37 | `WS_WORD_MEDICINE.png` | medicine | 💊 |
| 38 | `WS_WORD_PYRAMID.png` | pyramid | 🔺 |
| 38 | `WS_WORD_GLOBE.png` | globe | 🌍 |
| 38 | `WS_WORD_PASSPORT.png` | passport | 🛂 |
| 38 | `WS_WORD_TEMPLE.png` | temple | 🛕 |
| 38 | `WS_WORD_DESERT.png` | desert | 🏜️ |
| 38 | `WS_WORD_VOLCANO.png` | volcano | 🌋 |
| 38 | `WS_WORD_JOURNEY.png` | journey | 🗺️ |
| 38 | `WS_WORD_BACKPACK.png` | backpack | 🎒 |
| 39 | `WS_WORD_BINOCULARS.png` | binoculars | 🔭 |
| 39 | `WS_WORD_NOTEBOOK.png` | notebook | 📓 |
| 39 | `WS_WORD_PEBBLE.png` | pebble | 🪨 |
| 39 | `WS_WORD_FEATHER.png` | feather | 🪶 |
| 39 | `WS_WORD_MUSHROOM.png` | mushroom | 🍄 |
| 39 | `WS_WORD_POND.png` | pond | 🐸 |
| 39 | `WS_WORD_RAINBOW.png` | rainbow | 🌈 |
| 39 | `WS_WORD_INSECT.png` | insect | 🐞 |
| 40 | `WS_WORD_ADVENTURE.png` | adventure | 🗺️ |
| 40 | `WS_WORD_EXPLORE.png` | explore | 🧭 |
| 40 | `WS_WORD_BALLOON.png` | balloon | 🎈 |
| 40 | `WS_WORD_PICNIC.png` | picnic | 🧺 |
| 40 | `WS_WORD_PARADE.png` | parade | 🎺 |
| 40 | `WS_WORD_FRIEND.png` | friend | 🤝 |
| 40 | `WS_WORD_CELEBRATE.png` | celebrate | 🎉 |
| 40 | `WS_WORD_TROPHY.png` | trophy | 🏆 |
